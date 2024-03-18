#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m'
RED='\e[0;31m' .
echo -e "${GREEN}****************************************************************************${NC}"
echo -e "${GREEN}******* Tool   : EDB PostgreSQL Installer***********************************${NC}"
echo -e "${GREEN}******* Author : Prashant Dixit          ***********************************${NC}"
echo -e "${GREEN}******* Version:  1.3                    ***********************************${NC}"
echo -e "${GREEN}****************************************************************************${NC}"

echo "You are going to install EDB PostgreSQL of your choice"
echo ">>>>>>>Use format like "edb-as15-server.x86_64" for version 15.x ..."
echo ">>>>>>>Use format like "edb-as14-server.x86_64" for version 14.x... "
read -p "PostgreSQL_Version: " PostgreSQL_Version
echo " ......"
echo "Please provide the directory structure details"
echo ">>>>> Pass ---> 'as14' if you want to install PostgreSQL 14.x"
echo ">>>>> Pass ---> 'as15' if you want to install PostgreSQL 15.x"
read -p "DATABASE_BIN_DIR: " DATABASE_BIN_DIR

echo ">>>>> What PORT number you would like to use for your database ? My tool uses port 5432 "
#read -p "PORT: " PORT

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
yum -y install yum-utils
yum -y install pygpgme

echo -e "${RED}  -------> You might get warning "Another app is currently holding the yum lock waiting for it to exit..." ${NC}"
echo -e "${RED}  -------> ++ Kill the PID which is coming on the screen from a parallel screen ${NC}"
echo -e "${RED}  -------> ++ If you are lazy like me, JUST WAIT!! and it will automatcally goes in to SLEEP and message will go away ${NC}"

rpm --import 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/gpg.E71EB0829F1EF813.key'
curl -1sLf 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/config.rpm.txt?distro=el&codename=7' > /tmp/enterprisedb-enterpris
e.repo
yum-config-manager --add-repo '/tmp/enterprisedb-enterprise.repo'
yum -q makecache -y --disablerepo='*' --enablerepo='enterprisedb-enterprise'

# Here we are installing the required version of the postgresql software
yum -y install $PostgreSQL_Version
echo "********************************"
echo "$PostgreSQL_Version is Installed"
echo "********************************"

# Switch to the desired user
#sudo -u enterprisedb bash <<EOF

# Initialize the database cluster
sudo -u enterprisedb /usr/edb/$DATABASE_BIN_DIR/bin/initdb -D /var/lib/edb//$DATABASE_BIN_DIR/data

echo "EDB PostgreSQL installation and initialization completed."

# prepare the parameter file
echo "Lets create a custom $PostgreSQL_Version Parameter file for you ..."

DATA_DIR=/var/lib/edb/$DATABASE_BIN_DIR/data

# Check if the directory exists
if [ -d "$DATA_DIR" ]; then
  # Change to the application directory
  cd "$DATA_DIR"
  echo "Changed to directory: $DATA_DIR"
else
  echo "Directory does not exist: $DATA_DIR"
fi


sudo -u enterprisedb mv postgresql.conf postgresql.conf.ORIG

file_name="postgresql.conf"
touch "$file_name"

echo "listen_addresses = '*'" >> "$file_name"
echo "port = 5432" >> "$file_name"
echo "max_connections = 3000" >> "$file_name"
echo "shared_buffers = 10GB" >> "$file_name"
echo "temp_buffers = 1024" >> "$file_name"
echo "work_mem = 96MB" >> "$file_name"
echo "maintenance_work_mem = 1GB" >> "$file_name"
echo "effective_cache_size= 30GB" >> "$file_name"
echo "effective_io_concurrency = 500" >> "$file_name"
echo "max_parallel_maintenance_workers = 6" >> "$file_name"
echo "max_parallel_workers = 10" >> "$file_name"
echo "max_parallel_workers_per_gather = 6" >> "$file_name"
echo "max_worker_processes = 10" >> "$file_name"
echo "dynamic_shared_memory_type = posix" >> "$file_name"
echo "huge_pages = 'on'" >> "$file_name"
echo "idle_in_transaction_session_timeout = '30min'" >> "$file_name"
echo "max_stack_depth = '2MB'" >> "$file_name"
echo "shared_preload_libraries = 'pg_stat_statements'" >> "$file_name"
echo "pg_stat_statements.max = 10000" >> "$file_name"
echo "pg_stat_statements.track = all" >> "$file_name"
echo "jit = off" >> "$file_name"
echo "jit_above_cost = 50000" >> "$file_name"
echo "jit_inline_above_cost = 100000" >> "$file_name"
echo "jit_optimize_above_cost = 100000" >> "$file_name"
echo "bgwriter_delay = 50ms" >> "$file_name"
echo "bgwriter_lru_maxpages = 5000" >> "$file_name"
echo "bgwriter_lru_multiplier = 5" >> "$file_name"
echo "fsync = on" >> "$file_name"
echo "wal_buffers = 128MB" >> "$file_name"
echo "synchronous_commit = local" >> "$file_name"
echo "checkpoint_timeout = 15min" >> "$file_name"
echo "checkpoint_warning = 1min" >> "$file_name"
echo "min_wal_size = 30GB" >> "$file_name"
echo "checkpoint_completion_target = 0.9" >> "$file_name"
echo "random_page_cost = 1.1" >> "$file_name"
echo "wal_sync_method = 'fsync'" >> "$file_name"
echo "archive_mode = on" >> "$file_name"
echo "hot_standby = on" >> "$file_name"
echo "wal_level = replica" >> "$file_name"
echo "archive_timeout = 0" >> "$file_name"
echo "max_wal_senders = 7" >> "$file_name"
echo "wal_keep_size=20480MB" >> "$file_name"
echo "cpu_tuple_cost = 0.03" >> "$file_name"
echo "cpu_index_tuple_cost = 0.005" >> "$file_name"
echo "default_statistics_target = 30" >> "$file_name"
echo "from_collapse_limit = 8" >> "$file_name"
echo "join_collapse_limit = 8" >> "$file_name"
echo "log_destination = 'stderr'" >> "$file_name"
echo "logging_collector = on" >> "$file_name"
echo "log_directory = 'log'" >> "$file_name"
echo "log_rotation_size = 1GB" >> "$file_name"
echo "autovacuum=on" >> "$file_name"
echo "autovacuum_work_mem = 3GB" >> "$file_name"
echo "vacuum_cost_limit = 2000" >> "$file_name"
echo "autovacuum_max_workers = 20" >> "$file_name"
echo "autovacuum_naptime = 30s" >> "$file_name"
echo "autovacuum_vacuum_cost_delay = 10ms" >> "$file_name"
echo "autovacuum_vacuum_cost_limit = 10000" >> "$file_name"
echo "autovacuum_vacuum_threshold = 2000" >> "$file_name"
echo "autovacuum_analyze_threshold = 10000" >> "$file_name"
echo "autovacuum_vacuum_scale_factor = 0" >> "$file_name"
echo "autovacuum_analyze_scale_factor = 0.02" >> "$file_name"
echo "edb_dynatune = 100" >> "$file_name"
echo "edb_dynatune_profile = mixed" >> "$file_name"
echo "timed_statistics = on" >> "$file_name"
echo "log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h'" >> "$file_name"
echo "log_checkpoints = on" >> "$file_name"
echo "log_connections = on" >> "$file_name"
echo "log_min_duration_statement = 10000" >> "$file_name"
echo "wal_recycle = off" >> "$file_name"
echo "wal_init_zero = off" >> "$file_name"

#prepare the pg_hba conf files
mv pg_hba.conf pg_hba.conf.orig

hba_name="pg_hba.conf"
touch "$hba_name"

echo "# This is a automated pg_conf file generated by the tool. Please modify as per your need"
echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD" >> "$hba_name"
echo "local   all             all                                     trust" >> "$hba_name"
echo "host    all             all             127.0.0.1/32            trust" >> "$hba_name"
echo "host    all             all             ::1/128                 trust" >> "$hba_name"
echo "local   replication     all                                     trust" >> "$hba_name"
echo "host    replication     all             127.0.0.1/32            ident" >> "$hba_name"
echo "host    replication     all             ::1/128                 ident" >> "$hba_name"
echo "host    all     all     0.0.0.0/0       trust                        " >> "$hba_name"

chown enterprisedb:enterprisedb /var/lib/edb/$DATABASE_BIN_DIR/data/pg_hba.conf
chown enterprisedb:enterprisedb /var/lib/edb/$DATABASE_BIN_DIR/data/postgresql.conf

# Start database instance
cd /usr/edb/$DATABASE_BIN_DIR/bin
sudo -u enterprisedb /usr/edb/$DATABASE_BIN_DIR/bin/pg_ctl -D $DATA_DIR start

sudo -u enterprisedb /usr/edb/$DATABASE_BIN_DIR/bin/psql -d postgres -p 5432 -c "select version()"

echo ""
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "${GREEN}EDB PostgreSQL Version $PostgreSQL_Version has been installed and started successfully!!!!!!!${NC}"
echo -e "Happy Postgre-SSSSSSING ... "
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

exit
EOF
