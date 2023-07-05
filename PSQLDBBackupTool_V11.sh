#!/bin/bash
# Prompt for user inputs to pass user variables
#read -p "DB_HOST: " DB_HOST
GREEN='\033[0;32m'
NC='\033[0m'
RED='\e[0;31m'
echo -e "${GREEN}****************************************************************************${NC}"
echo -e "${GREEN}******* Tool   : EDB Database Backup Tool - 2     **************************${NC}"
echo -e "${GREEN}******* Desc   : Takes backup in Directory Format **************************${NC}"
echo -e "${GREEN}******* Author : Prashant Dixit                   **************************${NC}"
echo -e "${GREEN}******* Version:  1.1                             **************************${NC}"
echo -e "${GREEN}****************************************************************************${NC}"

read -p "DB_PORT: " DB_PORT
read -p "DB_NAME: " DB_NAME
read -p "BACKUP_DIR: " BACKUP_DIR
read -p "NUMBER_OF_PARALLEL_SLAVES: " NUMBER_OF_PARALLEL_SLAVES


echo "..."
echo "..."
# start time of the backup
echo "Backup Started ..."
start_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "..."
echo "..."



# Backup the database
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$TIMESTAMP.backup"
echo "..."
echo "..."
echo "Taking backup of the database..."
pg_dump -p $DB_PORT -Fc --format=directory --jobs=$NUMBER_OF_PARALLEL_SLAVES $DB_NAME -f $BACKUP_FILE



if [ $? -ne 0 ]; then
    echo "Failed to take the backup. Exiting..."
    exit 1
fi


echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "${GREEN} Database "$DB_NAME" Backup has been sucessfully completed, you're safe!!!!!!!${NC}"
echo -e "${GREEN} Backup Location : ------->  $BACKUP_FILE ${NC}"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "..."
echo "..."
# end time of the backup
echo "Backup Completed ..."
end_time=$(date +"%Y-%m-%d %H:%M:%S")
start_seconds=$(date -d "$start_time" +"%s")
end_seconds=$(date -d "$end_time" +"%s")
time_taken=$((end_seconds - start_seconds))
echo "Start Time: $start_time"
echo "End Time:   $end_time"
echo "Time Taken: $time_taken seconds"
directory="$BACKUP_DIR"
latest_file=$(ls -t "$directory" | head -n1)
file_size=$(stat -c "%s" "${directory}/${latest_file}")
echo "Latest backup file: $latest_file"
echo "Size of the latest backup file: $file_size bytes"
echo "..."
echo "..."
