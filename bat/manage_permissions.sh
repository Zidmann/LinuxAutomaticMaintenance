#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will be used to apply the appropriate permissions
##################################################################################
## 2021/06/23 - First release of the script
##################################################################################


##################################################################################
# Beginning of the script - definition of the variables
##################################################################################
SCRIPT_VERSION="0.0.1"

# Return code
RETURN_CODE=0

# Flag to execute the exit function
EXECUTE_EXIT_FUNCTION=0

# Trap management
function exit_function_auxi(){
	if [ -f "$TMP_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing the temporary file $TMP_PATH"
		rm "$TMP_PATH" 2>/dev/null
	fi

	# Elapsed time - end date and length
	if [ "$BEGIN_DATE" != "" ]
	then 
		END_DATE=$(date +%s)
		ELAPSED_TIME=$((END_DATE - BEGIN_DATE))

		echo "------------------------------------------------------"
		echo "Elapsed time : $ELAPSED_TIME sec"
		echo "Ending time  : $(date)"
	fi
	echo "------------------------------------------------------"
	echo "Exit code = $RETURN_CODE"
	echo "------------------------------------------------------"
}
function exit_function(){
	if [ "$EXECUTE_EXIT_FUNCTION" != "0" ]
	then
		if [ -f "$LOG_PATH" ]
		then
			exit_function_auxi | tee -a "$LOG_PATH"
		else
			exit_function_auxi
		fi
	fi
}
function interrupt_script_auxi(){
	echo "------------------------------------------------------"
	echo "[-] A signal $1 was trapped"
}
function interrupt_script(){
	if [ -f "$LOG_PATH" ]
	then
		interrupt_script_auxi "$1" | tee -a "$LOG_PATH"
	else
		interrupt_script_auxi "$1"
	fi
}

trap exit_function              EXIT
trap "interrupt_script SIGINT"  SIGINT
trap "interrupt_script SIGQUIT" SIGQUIT
trap "interrupt_script SIGTERM" SIGTERM

# Analysis of the path and the names
DIRNAME=$(dirname "$(dirname "$(readlink -f "$0")")")
CONF_DIR="$DIRNAME/conf"

PREFIX_NAME=$(basename "$(readlink -f "$0")")
NBDELIMITER=$(echo "$PREFIX_NAME" | awk -F"." '{print NF-1}')

if [ "$NBDELIMITER" != "0" ]
then
	PREFIX_NAME=$(echo "$PREFIX_NAME" | awk 'BEGIN{FS="."; OFS="."; ORS="\n"} NF{NF-=1};1')
fi

if [ -f "$CONF_DIR/$PREFIX_NAME.env" ]
then
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
elif [ -f "$CONF_DIR/manage_permissions.env" ]
then
	PREFIX_NAME="manage_permissions"
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
else
	echo "[-] Impossible to find a valid configuration file"
	exit "$RETURN_CODE"
fi

# Loading configuration file
source "$CONF_PATH"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "[-] Impossible to source the configuration file"
	exit "$RETURN_CODE"
fi;

LOG_DIR="$DIRNAME/log"

# Log file path
LOG_PATH=${1:-"${LOG_DIR}/$PREFIX_NAME.$(hostname).$TODAYDATE.$TODAYTIME.log"}
mkdir -p "$(dirname "$LOG_PATH")"

# Temporary file paths
TMP_PATH="$TMP_DIR/$PREFIX_NAME.1.$$.tmp"
mkdir -p "$(dirname "$TMP_PATH")"

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

EXECUTE_EXIT_FUNCTION=1

##################################################################################
# 
##################################################################################
function change_permission(){
	local OWNER="$1"
	shift
	local DIRECTORY="$*"

	# Change the owner and group of the directory
	GROUP=$OWNER
	chown "$OWNER":"$GROUP" "$DIRECTORY"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	# Remove all the ACL of the directory (if the command exists)
	ACL_ENABLED=$(type setfacl 2>/dev/null | wc -l)
	if [ "$ACL_ENABLED" != "0" ]
	then
		setfacl -bn "$DIRECTORY"
		RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")	
	fi

	# Remove the group and other rights
	chmod og-rwx "$DIRECTORY"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")
}

function main_code(){
	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= SCRIPT TO MANAGE PERMISSIONS                       ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"
	echo "TMP_PATH=$TMP_PATH"

	# Check if the configuration file with the users to maintain
	echo "----------------------------------------------------------"
	"$UTIL_DIR/file_exists.sh" "$CONF_DIR/users.conf"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" == "0" ]
	then
		echo "----------------------------------------------------------"
		echo "[i] Reading the users whose the directory will be processed"
		sort "$CONF_DIR/users.conf" 2>/dev/null | grep -vP "^#" | awk -F' ' '{if(NF==1){print $0}}' | sort | uniq > "$TMP_PATH"

		echo "----------------------------------------------------------"
		echo "[i] Processing the different users"
		while read -r USER
		do
			if [ "$USER" != "" ]
			then
				FLG_USERS_UPDATED=1;
				DIRNAME=$(awk -v vUSER="$USER" -F':' '{if($1==vUSER){print $6}}' /etc/passwd)
				if [ "$DIRNAME" != "" ]
				then
					echo " [+] Processing the permission of the $USER user and the home directory (DIR=$DIRNAME)"
					change_permission "$USER" "$DIRNAME"
					RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")
				else
					echo " [-] Failed to find the home directory of the user $USER"
				fi
			fi
		done < "$TMP_PATH"
	fi;

	if [ "$FLG_USERS_UPDATED" != "1" ]
	then
		echo "----------------------------------------------------------"
		echo "No users to update"
		RETURN_CODE=0
	fi;

	exit "$RETURN_CODE"
}
main_code > >(tee "$LOG_PATH") 2>&1
RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

##################################################################################
exit "$RETURN_CODE"
