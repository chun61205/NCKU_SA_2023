import schemas
from urllib.parse import quote
from fastapi import APIRouter, Response, UploadFile, status
from storage import storage

router = APIRouter()


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=schemas.File,
    name="file:create_file",
)
async def create_file(file: UploadFile) -> schemas.File: 
    return await storage.create_file(file)

@router.get("/", status_code=status.HTTP_200_OK, name="file:retrieve_file")
async def retrieve_file(filename: str) -> Response:
    encoded_filename = quote(filename, encoding="utf-8")
    return Response(
        await storage.retrieve_file(filename),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}"},
    )


@router.put("/", status_code=status.HTTP_200_OK, name="file:update_file")
async def update_file(file: UploadFile) -> schemas.File:
    return await storage.update_file(file)


@router.delete("/", status_code=status.HTTP_200_OK, name="file:delete_file")
async def delete_file(filename: str) -> str:
    await storage.delete_file(filename)
    return schemas.Msg(detail="File deleted")
