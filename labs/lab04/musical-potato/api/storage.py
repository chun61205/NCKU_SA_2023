import base64
import hashlib
import sys
import os
import shutil
from pathlib import Path
from typing import List

import schemas
from config import settings
from fastapi import UploadFile, status
from fastapi.exceptions import HTTPException
from loguru import logger


class Storage:
    def __init__(self, is_test: bool):
        self.block_path: List[Path] = [
            Path("/var/raid") / f"{settings.FOLDER_PREFIX}-{i}-test"
            if is_test
            else Path(settings.UPLOAD_PATH) / f"{settings.FOLDER_PREFIX}-{i}"
            for i in range(settings.NUM_DISKS)
        ]
        self.__create_block()

    def __create_block(self):
        for path in self.block_path:
            logger.warning(f"Creating folder: {path}")
            path.mkdir(parents=True, exist_ok=True)
    
    def delete_block(self, file_path):
        for path in file_path:
            if Path(path).exists():
                os.remove(path)


    async def file_integrity(self, filename: str) -> bool:
        N = settings.NUM_DISKS
        file_path = []
        for i in range(N):
            block_id = "block-" + str(i)
            file_path.append(os.path.join("/var/raid", block_id, filename))
        
        size = 0
        
        for i in range(N):
            if Path(file_path[i]).exists():
                with open(file_path[i], 'rb') as file0:
                    size = len(file0.read())
                break

        parity = bytearray(size)

        for i, path in enumerate(file_path):
            if not Path(path).exists():
                self.delete_block(file_path)
                return False
            with open(path, 'rb') as filex:
                filex_content = filex.read()
                if size != (len(filex_content)):
                    self.delete_block(file_path)
                    return False
                if i != (N - 1):
                    for j, byte in enumerate(filex_content):
                        parity[j] ^= byte
        with open(file_path[N - 1], 'rb') as file_last:
            if parity != file_last.read():
                self.delete_block(file_path)
                return False 
        
        return True

    async def create_file(self, file: UploadFile) -> schemas.File:
        all_block_dirs = [os.path.join("/var/raid", f"block-{i}") for i in range(settings.NUM_DISKS)]
        all_files = set()
        for all_block_dir in all_block_dirs:
            for filename in os.listdir(all_block_dir):
                all_files.add(filename)
        all_files = list(all_files)
        for filename in all_files:
            await self.file_integrity(filename)
        
        content = await file.read()
        L = len(content)
        N = settings.NUM_DISKS
        for i in range(N):
            block_id = "block-" + str(i)
            output_path = os.path.join("/var/raid", block_id, file.filename)

            if os.path.exists(output_path):
                raise HTTPException(status_code = status.HTTP_409_CONFLICT, detail="File already exists")
        if L > settings.MAX_SIZE:
            raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large")
        
        block_size, remainder = divmod(L, N - 1)
        block_sizes = [block_size + 1 if i < remainder else block_size for i in range(N - 1)]

        max_block_size = max(block_sizes)
        xor_result = bytearray(max_block_size)

        for i, block_size in enumerate(block_sizes):
            block_id = "block-" + str(i)
            output_path = os.path.join("/var/raid", block_id, file.filename)
            block_content = content[sum(block_sizes[: i]): sum(block_sizes[: (i + 1)])]
            if max_block_size > block_size:
                block_content += b'\x00'
            for j, byte in enumerate(block_content):
                xor_result[j] ^= byte
            with open(output_path, 'wb') as output_file:
                output_file.write(block_content)
        
        last_block_id = "block-" + str(N - 1)
        last_output_path = os.path.join("/var/raid", last_block_id, file.filename)
        with open(last_output_path, 'wb') as output_file:
            output_file.write(xor_result)

        return schemas.File(
            name=file.filename,
            size=L,
            checksum=hashlib.md5(content).hexdigest(),
            content=base64.b64encode(content).decode('utf-8'),
            content_type=file.content_type
        )

    async def retrieve_file(self, filename: str) -> bytes:
        all_block_dirs = [os.path.join("/var/raid", f"block-{i}") for i in range(settings.NUM_DISKS)]
        all_files = set()
        for all_block_dir in all_block_dirs:
            for data in os.listdir(all_block_dir):
                all_files.add(data)
        all_files = list(all_files)
        for data in all_files:
            await self.file_integrity(data)

        file_path = os.path.join("/var/raid/block-0", filename)
        if not Path(file_path).exists():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")

        file_fragments = []

        for i in range(settings.NUM_DISKS - 1):
            block_id = "block-" + str(i)
            block_path = Path("/var/raid") / block_id / filename

            with open(block_path, 'rb') as file:
                content = file.read()
                if content[-1:] == b'\x00':
                    content = content[:-1]
                file_fragments.append(content)

        full_file = b''.join(file_fragments)
        return full_file

    async def update_file(self, file: UploadFile) -> schemas.File:
        all_block_dirs = [os.path.join("/var/raid", f"block-{i}") for i in range(settings.NUM_DISKS)]
        all_files = set()
        for all_block_dir in all_block_dirs:
            for data in os.listdir(all_block_dir):
                all_files.add(data)
        all_files = list(all_files)
        for data in all_files:
            await self.file_integrity(data)

        file_path = os.path.join("/var/raid/block-0", file.filename)
        if not Path(file_path).exists():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")

        content = await file.read()
        L = len(content)
        N = settings.NUM_DISKS
        if L > settings.MAX_SIZE:
            raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large")
        
        file_path = []
        for i in range(N):
            block_id = "block-" + str(i)
            file_path.append(os.path.join("/var/raid", block_id, file.filename))
        
        self.delete_block(file_path)

        block_size, remainder = divmod(L, N - 1)
        block_sizes = [block_size + 1 if i < remainder else block_size for i in range(N - 1)]

        max_block_size = max(block_sizes)
        xor_result = bytearray(max_block_size)

        for i, block_size in enumerate(block_sizes):
            block_id = "block-" + str(i)
            output_path = os.path.join("/var/raid", block_id, file.filename)
            block_content = content[sum(block_sizes[: i]): sum(block_sizes[: (i + 1)])]
            if max_block_size > block_size:
                block_content += b'\x00'
            for j, byte in enumerate(block_content):
                xor_result[j] ^= byte
            with open(output_path, 'wb') as output_file:
                output_file.write(block_content)

        last_block_id = "block-" + str(N - 1)
        last_output_path = os.path.join("/var/raid", last_block_id, file.filename)
        with open(last_output_path, 'wb') as output_file:
            output_file.write(xor_result)

        return schemas.File(
            name=file.filename,
            size=L,
            checksum=hashlib.md5(content).hexdigest(),
            content=base64.b64encode(content).decode('utf-8'),
            content_type=file.content_type
        )

    async def delete_file(self, filename: str) -> None:
        N = settings.NUM_DISKS
        file_path = []
        for i in range(N):
            block_id = "block-" + str(i)
            file_path.append(os.path.join("/var/raid", block_id, filename))
        
        for curr_file in file_path:
            if not Path(curr_file).exists():
                self.delete_block(file_path)
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")
                pass
        
        size = 0

        for i in range(N):
            if Path(file_path[i]).exists():
                with open(file_path[i], 'rb') as file0:
                    size = len(file0.read())
                break

        parity = bytearray(size)

        for i, path in enumerate(file_path):
            with open(path, 'rb') as filex:
                filex_content = filex.read()
                if size != (len(filex_content)):
                    self.delete_block(file_path)
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")
                    pass

                if i != (N - 1):
                    for j, byte in enumerate(filex_content):
                        parity[j] ^= byte
        
        with open(file_path[N - 1], 'rb') as file_last:
            if parity != file_last.read():
                self.delete_block(file_path)
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")
                pass
        
        self.delete_block(file_path)
        pass

    async def fix_block(self, block_id: int) -> None:
        block_dirs = [os.path.join("/var/raid", f"block-{i}") for i in range(settings.NUM_DISKS)]
        if block_id == 0:
            file_names = os.listdir(block_dirs[1])
        else:
            file_names = os.listdir(block_dirs[0])

        for file_name in file_names:
            bytes_from_blocks = []
            for i, block_dir in enumerate(block_dirs):
                if i != block_id:
                    file_path = os.path.join(block_dir, file_name)
                    with open(file_path, 'rb') as file:
                        bytes_from_blocks.append(file.read())
        
            missing_bytes = bytearray()
            for byte_position in range(len(bytes_from_blocks[0])):
                xor_result = 0
                for block_bytes in bytes_from_blocks:
                    xor_result ^= block_bytes[byte_position]
                missing_bytes.append(xor_result)
        
            missing_block_path = os.path.join(block_dirs[block_id], file_name)
            with open(missing_block_path, 'wb') as file:
                file.write(missing_bytes)
        pass


storage: Storage = Storage(is_test="pytest" in sys.modules)
