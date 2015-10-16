#!/bin/bash
. logMessages.sh

OS=`uname`

BREW_INSTALLED=`which brew`
if [ -z $BREW_INSTALLED ]; then
	logCustom 9 "ALERT: " "Homebrew not found. I knew you would never read the instructions. I have to install this for you now! Phew!!"
	if [ "$OS" == "Darwin" ]; then
		logInfo "Installing HomeBrew on Mac"
		logCustom 6 "INPUT: " "When prompted, enter your password"
		echo "" | ruby -e "$(curl -fsSL $HOMEBREW_DOWNLOAD_URL)"

		BREW_INSTALLED=`which brew`
		if [ -z $BREW_INSTALLED	]; then
			logError "Install Failed, please install brew manually"
			exit 1
		fi
		brew doctor >> $LOG_FILE 2>&1
		brew update >> $LOG_FILE 2>&1

	elif [ "$OS' == 'Ubuntu" ]; then
		logInfo Install Linuxbrew on Ubuntu
		echo $2 | sudo apt-get install build-essential curl git ruby texinfo libbz2-dev libcurl4-openssl-dev libexpat-dev libncurses-dev zlib1g-dev >> $LOG_FILE 2>&1
		git clone $LINUXBREW_GIT_REPO ~/.linuxbrew >> $LOG_FILE 2>&1
		export PATH='$HOME/.linuxbrew/bin:$PATH'
		export LD_LIBRARY_PATH='$HOME/.linuxbrew/lib:$LD_LIBRARY_PATH'
	fi
fi

GIT_INSTALLED=`which git`
if [ -z $GIT_INSTALLED ]; then
	brew install git git-flow
fi
