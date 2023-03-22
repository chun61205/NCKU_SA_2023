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
    type=`file "${i}" | cut -d ' ' -f 2`
    if [[ "${type}" = "CSV" ]]; then
	while IFS=',' read username password shell_ groups; do
	    if [[ "${username}" = "username" ]]; then
		continue
	    fi
	    usernames+=("${username}")
	    passwords+=("${password}")
	    shells+=("${shell_}")
	    groupss+=("${groups}")
	done < "${i}"
    elif [[ "${type}" = "JSON" ]]; then
	usernames+=($(cat "${i}" | jq -r '.[] | .username'))
	passwords+=($(cat "${i}" | jq -r '.[] | .password'))
	shells+=($(cat "${i}" | jq -r '.[] | .shell'))
	groupss+=($(cat "${i}" | jq -r '.[] | .groups'))
    else
	echo "Error: Invalid file format." >&2
	exit 1
    fi
done

echo -n "This script will create the following user(s): "
echo -n "${usernames[@]} "
echo -n "Do you want to continue? [y/n]:"

read ans
if [[ "${ans}" = "n" ]] || [[ -z "${ans}" ]]; then
    exit 0;
fi

echo "un: ${#usernames[@]}"
echo "gn: ${#groupss[@]}"

for (( i=0; i<${#{usernames[@]}}; i++ )); do
    if user_exits "${usernames[i]}"; then
        echo "Waring: user ${usernames[i]} already exits."
    else
	useradd -m -s "${shells[i]}" -p "${passwords[i]}" "${usernames[i]}""
    fi
done

exit 0
