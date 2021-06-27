#!/bin/bash

# Auxiliary script to check if a file exists or not

FILEPATH="$*"
EXISTS=$(stat "$FILEPATH" 2>/dev/null | wc -l)

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

echo "----------------------------------"
echo " FILE EXISTENCE CHECK             "
echo "----------------------------------"

if [ "$EXISTS" == "0" ]
then
	echo "[-] File $FILEPATH doesn't exist"
	exit_line 1
else
	echo "[+] File $FILEPATH exists"
	exit_line 0
fi

