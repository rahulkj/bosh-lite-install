#!/bin/bash --login

. logMessages.sh

export EXECUTION_DIR=$PWD
export LOG_FILE=$EXECUTION_DIR/setup.log

export MYSQL_RELEASE_GIT_REPO=https://github.com/cloudfoundry/cf-mysql-release

execute() {
  clone_repo
  export_mysql_release
  install_service
  create_service_broker
}

clone_repo() {
	logTrace "Clone Required Git Repositories"
	if [ ! -d "$MYSQL_RELEASE_DIR" ]; then
		git clone $MYSQL_RELEASE_GIT_REPO $MYSQL_RELEASE_DIR &> $LOG_FILE 2>&1
	fi


	cd $MYSQL_RELEASE_DIR
	./update
}

export_mysql_release() {
	export MYSQL_LATEST_RELEASE_VERSION=`tail -2 $MYSQL_RELEASE_DIR/releases/index.yml | head -1 | cut -d':' -f2 | cut -d' ' -f2`

	if [[ -n ${MYSQL_LATEST_RELEASE_VERSION//[0-9]/} ]]; then
		export MYSQL_LATEST_RELEASE_VERSION=`echo $MYSQL_LATEST_RELEASE_VERSION | tr -d "'"`
	fi

	logInfo "Latest version of MySQL Service is: $MYSQL_LATEST_RELEASE_VERSION"
	export MYSQL_RELEASE=cf-mysql-$MYSQL_LATEST_RELEASE_VERSION.yml
	logInfo "Deploy MySQL release $MYSQL_RELEASE"

	echo "###### Validate the entered mysql version ######"
	if [ ! -f $MYSQL_RELEASE_DIR/releases/$MYSQL_RELEASE ]; then
		logError "Invalid MySQL version selected. Please correct and try again"
	fi
}

install_service() {
	cd $MYSQL_RELEASE_DIR
	bosh upload release releases/$MYSQL_RELEASE &> $LOG_FILE 2>&1
	./bosh-lite/make_manifest_spiff_mysql &> $LOG_FILE 2>&1
	echo "yes" | bosh deploy &> $LOG_FILE 2>&1
}

create_service_broker() {
	bosh run errand broker-registrar &> $LOG_FILE 2>&1
}

logTrace "Install MySQL Service Broker"
if [ $# -lt 1 ]; then
	echo "Usage: ./setup_mysql.sh <install-dir>"
	printf "\t %s \t\t %s \n" "install-dir:" "Specify the install directory"
	exit 1
fi

if [ ! -d $1 ]; then
	logError "Non-existant directory: $1"
fi

export BOSH_RELEASES_DIR=$1
export MYSQL_RELEASE_DIR=$BOSH_RELEASES_DIR/cf-mysql-release

execute
