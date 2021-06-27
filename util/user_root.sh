#!/bin/bash

# Auxiliary script to check if the current user is root

USERID=$UID
USER=$(whoami)

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

echo "----------------------------------"
echo " PRIVILEGE USER CHECK             "
echo "----------------------------------"

if [ "$USERID" == "0" ]
then
	echo "[+] User is root"
	exit_line 0
elif [ "$USERID" == "" ]
then
	echo "[-] User is not identified"
	exit_line 2
else
	echo "[-] User $USER(ID=$USERID) is not root"
	exit_line 1
fi

