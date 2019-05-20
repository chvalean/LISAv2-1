#!/bin/bash

#######################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
#
#######################################################################

#######################################################################
#
# mysql_setup.sh
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

# generic array name for RAID setup
deviceName="/dev/md0"
# for NVMe case we'll use the first disk
namespace="nvme0n1"

UTIL_FILE="./utils.sh"

# Source utils.sh
. ${UTIL_FILE} || {
	echo "ERROR: unable to source utils.sh!"
	echo "TestAborted" > state.txt
	exit 0
}

# Source constants file and initialize most common variables
UtilsInit

function setup_mysql_server () {
	export DEBIAN_FRONTEND="noninteractive"
	debconf-set-selections <<< "mysql-server mysql-server/root_password password ${sql_password}"
	debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${sql_password}"

	update_repos
	install_package "mysql-server"
	check_exit_status "mysql-server installation" "exit"

	sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
	mysql -u root -p${sql_password} -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${sql_password}'; FLUSH PRIVILEGES;"

	# Stop the service and disable apparmor for mysqld
	service mysql stop
	ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
	apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld

	# Move sql data folder to a separate disk
	mkdir -p $mountDir/mysql
	cp -rap /var/lib/mysql/* $mountDir/mysql
	mv /var/lib/mysql /var/lib/mysql_backup
	chown -R mysql:mysql $mountDir/mysql
	ln -s $mountDir/mysql /var/lib/mysql
	chown -R mysql:mysql /var/lib/mysql

	service mysql start
	check_exit_status "mysql-server status" "exit"
	sleep 5
}

LogMsg "Starting storage configuration for DB files setup"
if [[ ${disk_type} == "nvme" ]]; then
	pushd /mnt
	mountDir="/mnt/$namespace"
	if [[ -d "$mountDir" ]];then
		rm -rf $mountDir
	fi
	Format_Mount_NVME "$namespace" "$filesystem"
	popd
elif [[ ${disk_type} == "raid" ]]; then
	# Setup RAID on traditional disk types
	mountDir="/mnt/data"
	create_raid_and_mount "$deviceName" "$mountDir" "$filesystem"
fi

mount -l | grep "$mountDir"
check_exit_status "Disk setup $disk_type status" "exit"

LogMsg "Starting MySQL server setup"
setup_mysql_server

SetTestStateCompleted
LogMsg "MySQL server installed and configured successfully"