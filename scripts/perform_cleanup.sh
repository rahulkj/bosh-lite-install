#!/bin/bash --login
. logMessages.sh

set +e
logTrace "Switching to bosh-lite"
cd $BOSH_RELEASES_DIR/bosh-lite

logInfo "Deleting vagrant box"
vagrant halt
vagrant destroy -f

logSuccess "Deleted your old vagrant box, and continuing setup"
