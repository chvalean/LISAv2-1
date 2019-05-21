#!/bin/tclsh
puts "SETTING CONFIGURATION"
global complete
proc wait_to_complete {} {
global complete
set complete [vucomplete]
if {!$complete} {after 5000 wait_to_complete} else { exit }
}
dbset db mysql
diset connection mysql_host 127.0.0.1
diset connection mysql_port 3306
diset tpcc mysql_pass default_password
diset tpcc mysql_count_ware 800
diset tpcc mysql_partition true
diset tpcc mysql_num_vu 64
diset tpcc mysql_storage_engine innodb
buildschema
wait_to_complete