#!/bin/bash
# Prompt for user inputs to pass user variables
#read -p "DB_HOST: " DB_HOST
GREEN='\033[0;32m'
NC='\033[0m'
RED='\e[0;31m'
echo -e "${GREEN}****************************************************************************${NC}"
echo -e "${GREEN}******* Tool   : EDB Database Restore Tool - 2          ********************${NC}"
echo -e "${GREEN}******* Desc   : Restore database backup in directory fmt ******************${NC}"
echo -e "${GREEN}******* Author : Prashant Dixit                         ********************${NC}"
echo -e "${GREEN}******* Version: 1.1                                    ********************${NC}"
echo -e "${GREEN}****************************************************************************${NC}"

read -p "DB_PORT: " DB_PORT
read -p "DB_NAME: " DB_NAME
read -p "BACKUP_DIR: " BACKUP_DIR
read -p "NUMBER_OF_PARALLEL_SLAVES: " NUMBER_OF_PARALLEL_SLAVES
read -p "DB_NAME_TOCREATE: " DB_NAME_TOCREATE
read -p "DB_USER_TOCREATE: " DB_USER_TOCREATE
read -p "rolename: " rolename



# Start time of the restore
echo "Restore Start Time ..."
start_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "..."
echo "..."



#creating the user
echo "Creating the empty user in the database before restoring"
#createdb -U "$DB_USER_TOCREATE" "$DB_NAME_TOCREATE"
createdb "$DB_NAME_TOCREATE"
echo "Database $DB_NAME is created sucessfully"
echo "..."
echo "..."



# Restore the database
echo "Restoring the database now..."



# Note: Before restoring, make sure the database you want to restore to exists.
pg_restore -p $DB_PORT -d $DB_NAME --jobs=$NUMBER_OF_PARALLEL_SLAVES --format=d --verbose $BACKUP_DIR



#if [ $? -ne 0 ]; then
#    echo "Failed to restore the database. Exiting..."
#    exit 1
#fi



echo "..."
echo "..."
echo "Database restored successfully!"
echo "..."
echo "..."



#create respective role for the user in the database
echo "Creating ROLE for the new database with name $DB_NAME .... :) "
psql -d postgres -c "Create role $rolename WITH CREATEDB SUPERUSER LOGIN"



echo "..."
echo "..."
echo "**** Dont' worry if you receive errors or warnings like 'database already exists' or 'role already exists'."
echo "**** This is because they are already there"
echo "..."
echo "..."



#Query database to show the new database
echo "New Database is created and restored, Here is the proof"
psql -d postgres -c "SELECT datname,pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false and datname='$DB_NAME'"
echo "..."
echo "..."



# End time of the restore
echo "Activity Timelines ..."
end_time=$(date +"%Y-%m-%d %H:%M:%S")
start_seconds=$(date -d "$start_time" +"%s")
end_seconds=$(date -d "$end_time" +"%s")
time_taken=$((end_seconds - start_seconds))
echo "Start Time: $start_time"
echo "End Time:   $end_time"
echo "Time Taken: $time_taken seconds"
echo "..."
echo "..."
