#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m'
RED='\e[0;31m'
echo -e "${GREEN}****************************************************************************${NC}"
echo -e "${GREEN}******* Tool   : EDB PGBouncer Installer ***********************************${NC}"
echo -e "${GREEN}******* Author : Prashant Dixit          ***********************************${NC}"
echo -e "${GREEN}******* Version:  1.2                    ***********************************${NC}"
echo -e "${GREEN}****************************************************************************${NC}"

echo "You are going to install EDB specific PGBouncer"
echo ">>>>>>>Use format like edb-pgbouncer117 for version 1.17"
echo ">>>>>>>Use format like edb-pgbouncer118 for version 1.18... "
read -p "PGBouncer_Version: " PGBouncer_Version
echo "Provide the application directory"
echo "If pgbouncer version is 1.18 then pass 'pgbouncer1.18.0.0'"
echo "If pgbouncer version is 1.17 then pass 'pgbouncer1.17'"
read -p "app_version: " app_version
base_dir=/etc/edb
app_dir="${base_dir}/${app_version}"

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi


# Steps to prepare EDB Repository
echo "***************************************************"
echo "*************Preparing EDB Repo********************"
echo "***************************************************"
curl -1sLf 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/setup.rpm.sh' | sudo -E bash
yum install yum-utils pygpgme
rpm --import 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/gpg.E71EB0829F1EF813.key'
curl -1sLf 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/config.rpm.txt?distro=el&codename=7' > /tmp/enterprisedb-enterpris
e.repo
yum-config-manager --add-repo '/tmp/enterprisedb-enterprise.repo'
yum -q makecache -y --disablerepo='*' --enablerepo='enterprisedb-enterprise'

# Here we are installing the required version of the bouncer software
yum -y install $PGBouncer_Version
echo "********************************"
echo "$PGBouncer_Version is Installed"
echo "********************************"

# Check if the directory exists
if [ -d "$app_dir" ]; then
  # Change to the application directory
  cd "$app_dir"
  echo "Changed to directory: $app_dir"
else
  echo "Directory does not exist: $app_dir"
fi

echo "Lets create a custom PGBouncer Parameter file for you ..."
echo "Give some relevant name to your parameter file i.e. eoc2, ecm2, camunda1 etc."
read -p "name: " name
#vi $app_dir/edbpgbouncer_$name.ini
#echo "Time to set few custom PGBouncer Parameters"
#read -p "app_version: " app_version

file_name="edb-pgbouncer-$name.ini"
touch "$file_name"

echo "[databases]" >> "$file_name"
echo "eoc = host=00.00.00.00 port=5444 user=eoc dbname=eoc" >> "$file_name"
echo "" >> "$file_name"
echo "[users]" >> "$file_name"
echo "[pgbouncer]" >> "$file_name"
echo "logfile = /var/log/edb/$app_version/edb-pgbouncer-$name.log" >> "$file_name"
echo "pidfile = /var/run/edb/$app_version/edb-pgbouncer-$name.pid" >> "$file_name"
echo "listen_addr = *" >> "$file_name"
echo "listen_port = 6432" >> "$file_name"
echo "unix_socket_dir = /var/run/edb/bouncer_2_sock" >> "$file_name"
echo "auth_type = trust" >> "$file_name"
echo "auth_file = $app_dir/userlist.txt" >> "$file_name"
echo "auth_query = SELECT * FROM pgbouncer.get_auth($1)" >> "$file_name"
echo "admin_users = enterprisedb, postgres" >> "$file_name"
echo "stats_users = enterprisedb, postgres" >> "$file_name"
echo "server_reset_query = DISCARD ALL" >> "$file_name"
echo "pool_mode = transaction" >> "$file_name"
echo "ignore_startup_parameters = extra_float_digits" >> "$file_name"
echo "max_client_conn = 1200" >> "$file_name"
echo "default_pool_size = 1000" >> "$file_name"
echo "min_pool_size = 500" >> "$file_name"
echo "reserve_pool_size = 50" >> "$file_name"
echo "reserve_pool_timeout = 3" >> "$file_name"
echo "max_user_connections = 500" >> "$file_name"
echo "query_timeout = 0" >> "$file_name"
echo "query_wait_timeout = 420" >> "$file_name"
echo "so_reuseport = 1" >> "$file_name"

echo "**************************************************************************************************"
echo "New parameter file $file_name created with content."
echo "**************************************************************************************************"

# Switch to the desired user
sudo -u enterprisedb -i <<EOF

#start Pgboucer
echo ""
echo "****I am now going to start your PGbouncer ... :)*****"
/usr/edb/$app_version/bin/pgbouncer -d -q  $app_dir/$file_name

exit
EOF

echo ""
output=$(ps -ef | grep bounc)
echo "$output"

echo ""
echo ""
echo -e "${RED}**NOTE** ${NC}"
echo -e "${RED}  -------> Please kill this instance if you want to modify your PGBouncer with some custom values${NC}"
echo -e "${RED}  -------> Once you are done with your changes, restart the PGBouncer using below command ${NC}"
echo -e "${RED}  -------> /usr/edb/pgbouncer<bouncer_location>/bin/pgbouncer -d -q /etc/edb/pgbouncer<bouncer_loc>/edb-pgbouncer-<inifilename>.ini ${NC}"
echo ""
echo "**************************************************************************************************"
echo "Let me print last 10 lines from the PGBouncer Log File ..."
echo "**************************************************************************************************"

log_file="/var/log/edb/$app_version/edb-pgbouncer-$name.log"
lines_to_print=10
tail -n "$lines_to_print" "$log_file"

echo ""
echo ""
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "${GREEN}PgBouncer has been installed and started successfully!!!!!!!${NC}"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo ""
echo ""
