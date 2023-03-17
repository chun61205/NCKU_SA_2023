#!/bin/sh -x

# usage
usage() {
    echo -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -f files ... \n\n---sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

# Parse arguments
for i in "$@" ; do
    case $i in
        -h)
	    usage
	    exit 0
	;;
	--md5)
	    shift
	    md5_hash=("$@")
	;;
	--sha256)
	    shift
	    sha256_hash=("$@")
	    
	;;
	-i)
	    shift
	    input_file=("$@")
	    
	;;
	*)
	    echo "Error: Invalid arguments." >&2
	    usage >&2
	    exit 1
	;;
    esac 
done

# Check if two  type of hash function are used.
if [ ${#md5_hash[@]} -gt 0 ] && [ ${#sha256_hash[@]} -gt 0 ]; then
    echo "Error: Only one type of hash function is allowed." >&2
    exit 1
fi

# Chech if the number of hash funciton inputs match the number of files.
if [ ${#md5_hash[@]} -ne ${#input_file[@]} ] && [ ${#sha256_hash[@]} -ne ${#input_files[@]} ]; then
    echo "Error: Invalid values."
    exit 1
fi

# Validate hashes
if [ ${#md5_hashes[@]} -gt 0 ]; then
    for i in "${!input_files[@]}"; do
	md5sum_result=$(md5sum "${input_files[$i]}")
	if [ "${md5sum_result%% *}" != != "${md5_hash[$i]}" ]; then
	    echo "Error: Invalid checksum." >&2
	    exit 1
	fi
    done
elif [ ${#sha256_hash[@]} -gt 0 ]; then
    for i in "${!input_files[@]}"; do
	sha256sum_result=$(sha256sum "${input_files[$i]}")
	if [ "${sha256sum_result%% *}" != "${sha256_hash[$i]}" ]; then
	    echo "Error: Invalid checksum." >&2
	    exit 1
	fi
    done
fi

exit 0
