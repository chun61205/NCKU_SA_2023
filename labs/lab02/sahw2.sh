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

# Check if the number of hash funciton inputs match the number of files.
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

#    if [[ "$curr" != "$checksum" ]]; then
#	echo "Error: Invalid checksum." >&2
#	exit 1
#    fi
#done

usernames=()
passwords=()
shells=()
groupss=()

# Check if the file is CSV or JSON, if it is, parse the values and store in arraies.
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
	tmp=($(cat "${i}" | jq -r '.[] | .groups' | sed 's/\[\]/[ @ ]/g' ))
	bracket=0
	count=${#groupss[@]}
	for j in "${tmp[@]}"; do
	    if [[ "${j}" = '[' ]]; then
	        bracket=1
		groupss[count]=""
	    elif [[ "${j}" = ']' ]]; then
		bracket=0
		count=$((count+1))
	    else
	    	if [[ "${j:0:1}" = "\"" ]]; then
		    groupss[count]+=$(echo "${j}" | cut -d '"' -f2)
		    groupss[count]+=" "
		fi
	    fi		
	done
    else
	echo "Error: Invalid file format." >&2
	exit 1
    fi
done

# Read, if the input is "n" or Enter, then exit.
echo -n "This script will create the following user(s): "
echo -n "${usernames[@]} "
echo -n "Do you want to continue? [y/n]:"

read ans
if [[ "${ans}" = "n" ]] || [[ -z "${ans}" ]]; then
    exit 0;
fi

# Create users.
for (( i=0; i<${#usernames[@]}; i++ )); do
    if id "${usernames[i]}" &>/dev/null; then
        echo "Warning: user ${usernames[i]} already exists."
    else
	pw user add -s "${shells[i]}" -n "${usernames[i]}"
	echo "${passwords[i]}" |  pw user mod "${usernames[i]}" -h 0
	groupss_tmp=${groupss[i]}
	if [[ ! -z $groupss_tmp ]]; then
	    group_list=""
	    for j in $groupss_tmp; do
	        if ! getent group ${j} >/dev/null; then
		   pw group add ${j}
		fi
		group_list+="${j},"
	    done
	    pw user mod ${usernames[i]} -G $group_list
	fi
    fi
done    

exit 0
