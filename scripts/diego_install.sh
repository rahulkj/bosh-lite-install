#!/bin/bash

. common.sh

execute_diego_deployment() {
	logTrace "Installing Diego"
	sync_repo diego-release $DIEGO_RELEASE_REPO diego_release

	export_release $CF_RELEASE_DIR/releases cf && export CF_RELEASE=$RELEASE
	export_release $DIEGO_RELEASE_DIR/releases diego && export DIEGO_RELEASE=$RELEASE && export DIEGO_LATEST_RELEASE_VERSION=$RELEASE_VERSION

	switch_to_diego_release
	git checkout v$DIEGO_LATEST_RELEASE_VERSION && ./scripts/update

	export DEPLOYED_RELEASE=`bosh deployments | grep diego/ | cut -d '|' -f3 | cut -d '/' -f2 | cut -d '+' -f1 | sort -u`

	export CONTINUE_INSTALL=true

	if [[ $CONTINUE_INSTALL = true ]]; then
		echo
		create_deployment_dir

		generate_diego_deployment_stub
		generate_diego_deployment_manifest

		generate_and_upload_release $CF_RELEASE_DIR cf $CF_RELEASE
		bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release
		bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release
		bosh upload release https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-rootfs-release
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
