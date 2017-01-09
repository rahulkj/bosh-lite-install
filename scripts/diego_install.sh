#!/bin/bash

. common.sh

execute_diego_deployment() {
	logTrace "Installing Diego"
	sync_repo diego-release $DIEGO_RELEASE_REPO diego_release
	sync_repo etcd-release $ETCD_RELEASE_REPO etcd_release
	sync_repo cflinuxfs2-rootfs-release $CF_LINUX_ROOTFS_RELEASE_REPO cflinuxfs2_rootfs_release
	sync_repo garden-runc-release $GARDEN_RUNC_RELEASE_REPO garden_runc_release

	export_release $CF_RELEASE_DIR/releases cf && export CF_RELEASE=$RELEASE
	export_release $ETCD_RELEASE_DIR/releases/etcd etcd && export ETCD_RELEASE=$RELEASE
	export_release $CF_LINUX_ROOTFS_RELEASE_DIR/releases/cflinuxfs2-rootfs cflinuxfs2-rootfs && export CF_LINUX_ROOTFS_RELEASE=$RELEASE
	export_release $GARDEN_RUNC_RELEASE_DIR/releases/garden-runc garden-runc && export GARDEN_RUNC_RELEASE=$RELEASE
	export_release $DIEGO_RELEASE_DIR/releases diego && export DIEGO_RELEASE=$RELEASE && export DIEGO_LATEST_RELEASE_VERSION=$RELEASE_VERSION

	switch_to_diego_release
	git checkout v$DIEGO_LATEST_RELEASE_VERSION &> $LOG_FILE 2>&1 && ./scripts/update &> $LOG_FILE 2>&1

	export DEPLOYED_RELEASE=`bosh deployments | grep diego/ | cut -d '|' -f3 | cut -d '/' -f2 | cut -d '+' -f1 | sort -u`

	export CONTINUE_INSTALL=true

	if [[ $CONTINUE_INSTALL = true ]]; then
		echo
		create_deployment_dir

		generate_diego_deployment_stub
		generate_cf_deployment_manifest
		generate_diego_deployment_manifest

		generate_and_upload_release $CF_RELEASE_DIR cf $CF_RELEASE
		generate_and_upload_release $ETCD_RELEASE_DIR etcd etcd/$ETCD_RELEASE
		generate_and_upload_release $GARDEN_RUNC_RELEASE_DIR garden-runc garden-runc/$GARDEN_RUNC_RELEASE
		generate_and_upload_release $CF_LINUX_ROOTFS_RELEASE_DIR cflinuxfs2-rootfs/$CF_LINUX_ROOTFS_RELEASE
		generate_and_upload_release $DIEGO_RELEASE_DIR diego $DIEGO_RELEASE

		bosh deployment $CF_RELEASE_DIR/bosh-lite/deployments/cf.yml &> $LOG_FILE 2>&1
		deploy_release $CF_RELEASE_DIR $CF_RELEASE_DIR/bosh-lite/deployments/cf.yml CF

		bosh deployment $DIEGO_RELEASE_DIR/bosh-lite/deployments/diego.yml &> $LOG_FILE 2>&1
		deploy_release $DIEGO_RELEASE_DIR $DIEGO_RELEASE_DIR/bosh-lite/deployments/diego.yml DIEGO

		switch_to_diego_release
		git checkout master
		logSuccess "Done installing $DIEGO_RELEASE"
	fi
}
