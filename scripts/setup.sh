#!/bin/bash --login
export EXECUTION_DIR=$PWD
export LOG_FILE=$EXECUTION_DIR/setup.log

. logMessages.sh

echo ">>>>>>>>>> Start time: $(date) <<<<<<<<<<<<"

clear
unset HISTFILE

logTrace "Install Open Source CloudFoundry"
if [[ $# -lt 2 || $# -gt 3 ]]; then
	echo "Usage: ./setup.sh <provider> <install-dir> <options>"
	printf "\t %s \t\t %s \n\t\t\t\t %s \n" "provider:" "Enter 1 for Virtual Box" "Enter 2 for VMWare Fusion"
	printf "\t %s \t\t %s \n" "install-dir:" "Specify the install directory"
	printf "\t %s \t\t\t %s \n" "-f" "Clean install"
	exit 1
fi

if [ ! -d $2 ]; then
	logError "Non-existant directory: $2"
fi

export PROVIDER=$1
export BOSH_RELEASES_DIR=$2

if [[ $3 = "-f" ]]; then
	export FORCE_DELETE="-f"
fi

export SELECTION=0

while [[ $SELECTION -ne 1 && $SELECTION -ne 2 ]]; do
	echo "Select the option:"
	printf " %s \t %s \n" "1:" "CF-RELEASE"
	printf " %s \t %s \n" "2:" "DIEGO-RELEASE"
	read -p "What's it you wish to install? " SELECTION
	echo
done

export OS=`uname`

export BOSH_LITE_DIR=$BOSH_RELEASES_DIR/bosh-lite
export CF_RELEASE_DIR=$BOSH_RELEASES_DIR/cf-release
export DIEGO_RELEASE_DIR=$BOSH_RELEASES_DIR/diego-release
export GARDEN_RELEASE_DIR=$BOSH_RELEASES_DIR/garden-linux-release
export ETCD_RELEASE_DIR=$BOSH_RELEASES_DIR/etcd-release
export CF_LINUX_ROOTFS_RELEASE_DIR=$BOSH_RELEASES_DIR/cflinuxfs2-rootfs-release

export RETAKE_SNAPSHOT=false

. common.sh
. cf_install.sh
. diego_install.sh
. logMessages.sh

pre_install

if [[ $SELECTION = 1 ]]; then
	execute_cf_deployment
elif [[ $SELECTION = 2 ]]; then
	execute_diego_deployment
fi

post_install_activities

logInfo ">>>>>>>>>> End time: $(date) <<<<<<<<<<<<"

logSuccess "Congratulations: Open Source CloudFoundry setup complete!"
