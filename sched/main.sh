#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will launch all the different scripts dedicated to maintain
## the device
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
	if [ -f "$LOCK_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing the lock file $LOCK_PATH"
		rm "$LOCK_PATH"
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
elif [ -f "$CONF_DIR/main.env" ]
then
	PREFIX_NAME="main"
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
LOG_PATH="${LOG_DIR}/$PREFIX_NAME.sched.$(hostname).$TODAYDATE.$TODAYTIME.log"
mkdir -p "$(dirname "$LOG_PATH")"

# Lock file path
LOCK_PATH="${TMP_DIR}/$PREFIX_NAME.lock.pid"
if [ -f "$LOCK_PATH" ]
then
	PIDFILE=$(tail -n1 "$LOCK_PATH" 2>/dev/null)
	PIDEXISTS=$(ps -aux | awk -F' ' -v v_PID="$PIDFILE" '{if($2==v_PID){print 1}}' | tail -n1 | wc -l)
	if [ "$PIDEXISTS" != "0" ]
	then
		echo "[-] Lock file already exists on an existing PID"
		exit 1
	else
		echo "[-] Lock file already exists but with an unused PID and will be removed"
		rm "$LOCK_PATH"
	fi
fi
echo "$$" >> "$LOCK_PATH"
sleep 2
PIDFILE=$(tail -n1 "$LOCK_PATH" 2>/dev/null)
if [ "$PIDFILE" != "$$" ]
then
	echo "[-] Concurrent access detected with another instance"
	exit 1
fi

EXECUTE_EXIT_FUNCTION=1

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

function main_code(){	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= HEAP SCRIPT TO SCHEDULE ALL THE ACTIONS            ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"

	# Step 1 : Check if the user is root to have all the privileges
	"$UTIL_DIR/user_root.sh"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	# Step 2 : Change permissions, backup and send the data in an external space
	"$BAT_DIR/manage_permissions.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	# Step 3 : Keep the last version of the operating system
	"$BAT_DIR/upgrade_system.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	# Step 4 : Remove the old logs files
	"$BAT_DIR/clean_files.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	exit "$RETURN_CODE"
}
main_code > >(tee "$LOG_PATH") 2>&1
RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

##################################################################################
exit "$RETURN_CODE"
