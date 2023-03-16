#!/bin/sh

usage() {
	echo -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -f files ... \n\n---sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

if [ $# -eq 1 ] && [ "$1" = "-h" ]; then
	usage
	exit 1
fi


exit 0
