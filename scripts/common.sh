#!/bin/bash --login
export EXECUTION_DIR=$PWD
export LOG_FILE=$EXECUTION_DIR/setup.log

rm -rf $LOG_FILE

echo ">>>>>>>>>> Start time: $(date) <<<<<<<<<<<<" >> $LOG_FILE

export BOSH_DIRECTOR_URL=192.168.50.4:25555
export BOSH_USER=admin
export BOSH_PASSWORD=admin

export BOSH_LITE_REPO=https://github.com/cloudfoundry/bosh-lite.git
export CF_RELEASE_REPO=https://github.com/cloudfoundry/cf-release.git
export DIEGO_RELEASE_REPO=https://github.com/cloudfoundry-incubator/diego-release.git
export GARDEN_RELEASE_REPO=https://github.com/cloudfoundry-incubator/garden-linux-release.git
export ETCD_RELEASE_REPO=https://github.com/cloudfoundry-incubator/etcd-release.git

export STEMCELL_URL=https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent
export STEMCELL_TO_INSTALL=latest-bosh-lite-stemcell.tgz

export VAGRANT_VERSION=1.7.4
export BOSH_RUBY_VERSION=2.3.0

export RVM_DOWNLOAD_URL=https://get.rvm.io

export HOMEBREW_DOWNLOAD_URL=https://raw.github.com/Homebrew/homebrew/go/install

validate_input() {
	set -e
	./validation.sh $PROVIDER
}

prompt_password() {
	read -s -p "Enter Password: " PASSWORD
	if [ -z $PASSWORD ]; then
		logError "Please provide the sudo password"
	fi

	echo

	cmd=`$EXECUTION_DIR/login.sh $USER $PASSWORD`
	if [[ $cmd == *Sorry* ]]; then
		logError "Invalid password"
	else
		logSuccess "Password Validated"
	fi
}

install_required_tools() {
	set +e
	$EXECUTION_DIR/ruby_install.sh

	if [[ $OS = "Darwin" ]]; then
		set +e
		$EXECUTION_DIR/brew_install.sh

		INSTALLED_WGET=`which wget`
		if [ -z $INSTALLED_WGET ]; then
			logTrace " Installing wget "
			brew install wget >> $LOG_FILE 2>&1
		fi
	fi

	GO_INSTALLED=`which go`
	if [ -z $GO_INSTALLED ]; then
		logInfo "Go command not found, please install go"
		brew install go >> $LOG_FILE 2>&1
	fi


	BOSH_INSTALLED=`which bosh`
	if [ -z $BOSH_INSTALLED ]; then
		logError "Bosh command not found, please fire rvm gemset use bosh-lite"
	fi

	VAGRANT_INSTALLED=`which vagrant`
	if [ -z $VAGRANT_INSTALLED ]; then
		logError "You don't have vagrant Installed. I knew you would never read instructions. Install that first and then come back."
	fi

	PLUGIN_INSTALLED=false
	VMWARE_PLUGIN_INSTALLED=`vagrant plugin list`
	STRING_TO_LOOK_FOR="vagrant-vmware-fusion"
	if echo "$VMWARE_PLUGIN_INSTALLED" | grep -q "$STRING_TO_LOOK_FOR"; then
		PLUGIN_INSTALLED=true
	fi

	INSTALLED_SPIFF=`which spiff`
	if [ -z $INSTALLED_SPIFF ]; then
		go get github.com/cloudfoundry-incubator/spiff &> $LOG_FILE 2>&1
	fi
}

# <repo-dir> <repo-url> <switch_to_release> <bundle-required>
sync_repo() {
	if [ ! -d "$BOSH_RELEASES_DIR/$1" ]; then
		git clone $2 $BOSH_RELEASES_DIR/$1 >> $LOG_FILE 2>&1
	fi

	set -e
	switch_to_$3

	if [[ ! -f ./scripts/update ]]; then
		logTrace "Update $1 to sync the sub-modules"
		./scripts/update &> $LOG_FILE
	else
		git pull &> $LOG_FILE
	fi

	if [[ $4 == true ]]; then
		bundle install &> $LOG_FILE
	fi
}

update_repos() {
	set -e
	logTrace "Clone Required Git Repositories"
	if [ ! -d $BOSH_LITE_DIR ]; then
		git clone $BOSH_LITE_REPO $BOSH_LITE_DIR >> $LOG_FILE 2>&1
	fi

	if [[ $FORCE_DELETE = "-f" ]]; then
		$EXECUTION_DIR/perform_cleanup.sh
		rm -rf $BOSH_LITE_DIR/$STEMCELL_TO_INSTALL
	fi

	if [ ! -d $CF_RELEASE_DIR ]; then
		git clone $CF_RELEASE_REPO $CF_RELEASE_DIR >> $LOG_FILE 2>&1
		rm -rf Gemfile.lock
	fi

	switch_to_bosh_lite

	set -e
	logTrace "Pull latest changes (if any) for bosh-lite"
	git pull >> $LOG_FILE 2>&1

	switch_to_cf_release

	set -e
	logTrace "Update cf-release to sync the sub-modules"
	./scripts/update &> $LOG_FILE
}

switch_to_bosh_lite() {
	set +e
	logTrace "Switching to bosh-lite"
	cd $BOSH_LITE_DIR
}

switch_to_cf_release() {
	set +e
	logTrace "Switching to cf-release"
	cd $CF_RELEASE_DIR
}

switch_to_diego_release() {
	set +e
	logTrace "Switching to diego-release"
	cd $DIEGO_RELEASE_DIR
}

switch_to_garden_linux_release() {
	set +e
	logTrace "Switching to garden-linux-release"
	cd $GARDEN_RELEASE_DIR
}

switch_to_etcd_release() {
	set +e
	logTrace "Switching to etcd-release"
	cd $ETCD_RELEASE_DIR
}

create_deployment_dir() {
	set +e
	logTrace "Create deployment directory"
	mkdir -p $BOSH_RELEASES_DIR/deployments/bosh-lite
}

generate_diego_deployment_stub() {
	set +e
	logTrace "Generating Diego deployment stub"
	switch_to_diego_release
	./scripts/print-director-stub > $BOSH_RELEASES_DIR/deployments/bosh-lite/director.yml >> $LOG_FILE 2>&1
}

generate_diego_deployment_manifest() {
	set -e
	logTrace "Generating cf release manifest"

	switch_to_cf_release
	./scripts/generate-bosh-lite-dev-manifest >> $LOG_FILE 2>&1

	switch_to_diego_release
	./scripts/generate-bosh-lite-manifests >> $LOG_FILE 2>&1
}

generate_and_upload_release() {
	cd $1
	rm -rf Gemfile.lock
	logCustom 9 "ALERT: " "Upload $2-release $3 "
	bosh -n upload release --skip-if-exists releases/$3 >> $LOG_FILE 2>&1
}

deploy_release() {
	cd $1

	set +e
	bosh deployment $2 &> $LOG_FILE 2>&1

	set +e
	logCustom 9 "ALERT: " "Deploy $3 to BOSH-LITE (THIS WOULD TAKE SOME TIME) "
	bosh -n deploy &> $LOG_FILE 2>&1
}

validate_deployed_release() {
	set -e
	export CONTINUE_INSTALL=true

	logInfo "Deployed version $1 and new version $2"
	if [[ $1 != '' ]]; then
		if [[ "$1" = "$2" ]]; then
			logInfo "You're already on the current version, skipping deployment"
			export CONTINUE_INSTALL=false
		else
			logInfo "New CF release available, undeploying the older version"
			# Check if Diego Release
			if [[ $3 = true ]]; then
				bosh -n delete deployment cf-warden-diego --force &> $LOG_FILE 2>&1
				bosh -n delete release diego --force &> $LOG_FILE 2>&1
				bosh -n delete release garden-linux --force &> $LOG_FILE 2>&1
				bosh -n delete release etcd --force &> $LOG_FILE 2>&1
			fi
			bosh -n delete deployment cf-warden --force &> $LOG_FILE 2>&1
			bosh -n delete release cf --force &> $LOG_FILE 2>&1
		fi
	fi
}

vagrant_up() {
	switch_to_bosh_lite

	set -e
	logTrace "Vagrant up"
	if [ $PROVIDER -eq 1 ]; then
		if [ $PLUGIN_INSTALLED == true ]; then
			logInfo "Found VMWare Fusion plugin, uninstalling it"
			vagrant plugin uninstall vagrant-vmware-fusion
		fi

		vagrant box update
		vagrant up --provider=virtualbox >> $LOG_FILE 2>&1
	else
		if [ $PLUGIN_INSTALLED == true ]; then
			logInfo "Vagrant Plugin already installed"
		else
			vagrant plugin install vagrant-vmware-fusion >> $LOG_FILE 2>&1
			vagrant plugin license vagrant-vmware-fusion $EXECUTION_DIR/license.lic >> $LOG_FILE 2>&1

			vagrant plugin install vagrant-multiprovider-snap >> $LOG_FILE 2>&1
		fi

		vagrant up --provider=vmware_fusion >> $LOG_FILE 2>&1
	fi

	logTrace "Target BOSH to BOSH director"
	bosh target $BOSH_DIRECTOR_URL

	logTrace "Setup bosh target and login"
	bosh login $BOSH_USER $BOSH_PASSWORD

	logTrace "Set the routing tables"
	echo $PASSWORD | sudo -S bin/add-route >> $LOG_FILE 2>&1

}

download_and_upload_stemcell() {
	switch_to_bosh_lite

	set -e
	logTrace "Download latest warden stemcell"
	logTrace "Downloading... warden"
	wget --progress=bar:force $STEMCELL_URL -O $STEMCELL_TO_INSTALL -o $LOG_FILE 2>&1

	set +e
	logTrace "Upload stemcell"
	bosh upload stemcell --skip-if-exists $BOSH_LITE_DIR/$STEMCELL_TO_INSTALL >> $LOG_FILE 2>&1

	set -e
	STEM_CELL_NAME=$( bosh stemcells | grep -o "bosh-warden-[^[:space:]]*" )
	logTrace "Uploaded stemcell $STEM_CELL_NAME"
}

# <releases-dir> <release-name>
export_release() {
	set -e

	export RELEASE_VERSION=`tail -2 $1/index.yml | head -1 | cut -d':' -f2 | cut -d' ' -f2`

	if [[ -n ${RELEASE_VERSION//[0-9]/} ]]; then
		export RELEASE_VERSION=`echo $RELEASE_VERSION | tr -d "'"`
	fi

	logInfo "Latest version of $2 is: $RELEASE_VERSION"
	export RELEASE=$2-$RELEASE_VERSION.yml
	logInfo "Deploy $2 release $RELEASE"

	logTrace "Validate the entered $2 version"
	if [ ! -f $1/$RELEASE ]; then
		logError "Invalid $2 version selected. Please correct and try again"
	fi
}

pre_install() {
	validate_input
	prompt_password
	install_required_tools
	update_repos
	vagrant_up
	download_and_upload_stemcell
}

setup_dev_environment() {
	cd $EXECUTION_DIR && $EXECUTION_DIR/setup_cf_commandline.sh
}

post_install_activities() {
  logTrace "Creating Org/Space"
	setup_dev_environment

	if [[ $SELECTION = 2 ]]; then
		cf enable-feature-flag diego_docker
	fi

	switch_to_bosh_lite

	IS_VAGRANT_SNAPSHOT_PLUGIN_AVAILABLE=`vagrant plugin list | grep vagrant-multiprovider-snap`
	if [[ ! -z $IS_VAGRANT_SNAPSHOT_PLUGIN_AVAILABLE ]]; then
		logTrace "Taking snapshot of the VM"
		vagrant snap delete --name=original
		vagrant suspend && vagrant snap take --name=original
	fi

	vagrant up && ./bin/add-route

	set +e
	logTrace "Executing BOSH VMS to ensure all VMS are running"
	BOSH_VMS_INSTALLED_SUCCESSFULLY=`bosh vms | grep -o failing`
	echo "Output of bosh vms is $BOSH_VMS_INSTALLED_SUCCESSFULLY"
	if [[ ! -z $BOSH_VMS_INSTALLED_SUCCESSFULLY ]]; then
		logInfo "Not all BOSH VMs are up. Please check bosh logs for more info. This is false/positive"
	fi
}
