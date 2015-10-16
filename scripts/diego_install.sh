#!/bin/bash

. common.sh

execute_diego_deployment() {
	logTrace "Installing Diego"
	sync_repo diego-release $DIEGO_RELEASE_REPO diego_release
	sync_repo garden-linux-release $GARDEN_RELEASE_REPO garden_linux_release true
	sync_repo etcd-release $ETCD_RELEASE_REPO etcd_release true

	export_release $CF_RELEASE_DIR/releases cf && export CF_RELEASE=$RELEASE
	export_release $DIEGO_RELEASE_DIR/releases diego && export DIEGO_RELEASE=$RELEASE && export DIEGO_LATEST_RELEASE_VERSION=$RELEASE_VERSION
	export_release $GARDEN_RELEASE_DIR/releases/garden-linux garden-linux && export GARDEN_LINUX_RELEASE=$RELEASE
	export_release $ETCD_RELEASE_DIR/releases/etcd etcd && export ETCD_RELEASE=$RELEASE

	export DEPLOYED_RELEASE=`bosh deployments | grep diego/ | cut -d '|' -f3 | cut -d '/' -f2 | cut -d '+' -f1 | sort -u`

	if [[ $DEPLOYED_RELEASE != '' ]]; then
		validate_deployed_release $DEPLOYED_RELEASE $DIEGO_LATEST_RELEASE_VERSION true
	else
		export CONTINUE_INSTALL=true
	fi

	if [[ $CONTINUE_INSTALL = true ]]; then
		echo
		create_deployment_dir

		generate_diego_deployment_stub
		generate_diego_deployment_manifest

		generate_and_upload_release $CF_RELEASE_DIR cf $CF_RELEASE
		generate_and_upload_release $GARDEN_RELEASE_DIR garden-linux garden-linux/$GARDEN_LINUX_RELEASE
		generate_and_upload_release $ETCD_RELEASE_DIR etcd etcd/$ETCD_RELEASE
		generate_and_upload_release $DIEGO_RELEASE_DIR diego $DIEGO_RELEASE

		bosh deployment $CF_RELEASE_DIR/bosh-lite/deployments/cf.yml &> $LOG_FILE 2>&1
		deploy_release $CF_RELEASE_DIR $CF_RELEASE_DIR/bosh-lite/deployments/cf.yml CF

		bosh deployment $DIEGO_RELEASE_DIR/bosh-lite/deployments/diego.yml &> $LOG_FILE 2>&1
		deploy_release $DIEGO_RELEASE_DIR $DIEGO_RELEASE_DIR/bosh-lite/deployments/diego.yml DIEGO

		logSuccess "Done installing $DIEGO_RELEASE"
	fi
}
