#!/usr/local/bin/bash

# usage
usage() {
    echo -n -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -i files ...\n\n--sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

# Parse arguments

hash_type=""
hashes=()
input_files=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h)
	    usage
	    exit 0
	;;
	--md5)
	    if [[ ${#hash_type} -gt 0 ]]; then
		echo "Error: Only one type of hash function is allowed." >&2
		exit 1
	    fi
	    hash_type="md5"
	    shift
	    while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
		hashes+=("$1")
		shift
	    done
	;;
	--sha256)
	    if [[ ${#hash_type} -gt 0 ]]; then
		echo "Error: Only one type of hash function is allowed." >&2
		exit 1
	    fi
	    hash_type="sha2565"
	    shift
	    while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
		hashes+=("$1")
		shift
	    done
	;;
	-i)
	    shift
	    while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
		input_files+=("$1")
		shift
	    done
	;;
	*)
	    echo "Error: Invalid arguments." >&2
	    usage
	    exit 1
	;;
    esac 
done

# Chech if the number of hash funciton inputs match the number of files.
#if [[ ${#hashes[@]} -ne ${#input_files[@]} ]]; then
#    echo "Error: Invalid values." >&2
#    exit 1
#fi

# Validate hashes
#for (( i=0; i<${#hashes[@]}; i++)); do
#    curr="${hashes[$i]}"
#    file="${input_files[$i]}"
#    if [[ "$hash_type" == "md5" ]]; then
#	checksum=`md5sum "$file" | awk '{print $1}'`
#    else
#	checksum=`sha256sum "$file" | awk '{print $1}'`
#    fi
#
#    if [[ "$curr" != "$checksum" ]]; then
#	echo "Error: Invalid checksum." >&2
#	exit 1
#    fi
#done

usernames=()
passwords=()
shells=()
groupss=()


for i in "${input_files[@]}"; do
    if head -n1 "${i}" | grep -q "username,password,shell,groups"; then
	while IFS=',' read username password shell_ groups; do
	    echo "$username"
	    echo "$password"
	    echo "$shell_"
	    echo "$groups"
	    usernames=username
	    passwords=password
	    shells=shell_
	    groupss=groups
	done < "${i}"
    elif `cat "${i}" | jq -r '.[0] | keys[]' | grep -q "groups password shell username"`; then
	echo "good"
    else
	echo `cat "${i}" | jq -r '.[0] | keys[]'`
	echo "Error: Invalid file format." >&2
	exit 1
    fi
done

echo "This script will create the following user(s): Do you want to continue? [y/n]:"

exit 0
