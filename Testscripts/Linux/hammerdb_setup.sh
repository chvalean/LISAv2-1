#!/bin/bash

#######################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
#
#######################################################################

#######################################################################
#
# hammerdb_setup.sh
# Description:
#    Format existing additional storage (either NVMe or other disk types)
#    to be used as the storage for HammerDB under-test database.
#    Install MySQL server.
#    Configure mysql and move data folder the new disk.
#    This script must to be run on server VM.
#
# Supported Distros:
#    Ubuntu
#
#######################################################################

UTIL_FILE="./utils.sh"
schemaBuildURL="https://github.com/chvalean/LISAv2-1/raw/hammerdb-testcase/Tools/hammerdb_schemabuild.tcl"
schemaBuildName="hammerdb_schemabuild.tcl"

# Source utils.sh
. ${UTIL_FILE} || {
	echo "ERROR: unable to source utils.sh!"
	echo "TestAborted" > state.txt
	exit 0
}

# Source constants file and initialize most common variables
UtilsInit

function install_hammerdb () {
	export DEBIAN_FRONTEND="noninteractive"
	update_repos
	install_package "libmysqlclient-dev"
	check_exit_status "libmysqlclient-dev installation" "exit"

	wget -q $hammerURL/$hammerPKG
	chmod 755 ./$hammerPKG && ./$hammerPKG --mode silent

	wget -q $schemaBuildURL

	sed -i "s/127.0.0.1/${server}/g" $schemaBuildName
	sed -i "s/default_password/${sql_password}/g" $schemaBuildName

cd /usr/local/HammerDB-3.1/
./hammerdbcli <<!>> setup.output 2>&1
source /root/$schemaBuildName
!
	#check_exit_status "generate test DB status" "exit"
	echo "BASH SCRIPT AFTER BUILD.."
	sleep 5
}

LogMsg "Starting HammerDB setup"
install_hammerdb

SetTestStateCompleted
LogMsg "HammerDB installed and configured successfully"