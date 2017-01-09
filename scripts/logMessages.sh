logError () {
	logCustom 1 "ERROR: " "$1"

	if [[ ! -z "$2" ]]; then
		logInfo "$2"
	fi

	echo ">>>>>>>>>> End time: $(date) <<<<<<<<<<<<"
	echo ">>>>>>>>>> End time: $(date) <<<<<<<<<<<<" &> $LOG_FILE 2>&1
	exit 1
}

logSuccess () {
	logCustom 2 "SUCCESS: " "$1"
}

logInfo () {
	logCustom 6 "INFO: " "$1"
}

logTrace () {
	logCustom 11 "TRACE: " "$1"
}

logCustom () {
	tput setaf $1
	echo $2 "$3"
	echo $2 "$3" &> $LOG_FILE 2>&1
	tput sgr 0
}
