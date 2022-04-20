#!/bin/bash

####################################################################################
#                   SHELL SCRIPT TO DO MAJOR DATABASE UPGRADE                      #
####################################################################################

###########
# Functions being used in the upgrade script
###########


#######################################
# Function to show usage of the script#
#######################################

show_usage()
{

echo -e "\n  ###################################################################################################"
echo -e "  ###  This script is for doing major upgrades of database                                        ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  Usage : /opt/app/oracle/scripts/FCDBA-IND/$0 [ arguments ]                         ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  Arguments include                                                                          ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  --help            : Gives help on this script                                              ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  --sid             : Provide the SID of the database which you want to upgrade              ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  --upgrade_version : Provide the version number of database to upgrade to                   ###"
echo -e "  ###                      Value should in format <DB Version>:<Patchset Version>                 ###"
echo -e "  ###                      Example: 11.2.0.3:A03db                                                ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###  --mode            : Provide the mode in which you want to run the script.                  ###"
echo -e "  ###                      We have 2 modes for this script                                        ###"
echo -e "  ###                      1) PRE_UPGRADE mode - Only downloads binary and keep it ready          ###"
echo -e "  ###                      2) UPGRADE mode - Includes PRE_UPGRADE mode and also bounces the DB.   ###"
echo -e "  ###                         UPGRADE mode requires downtime.                                     ###"
echo -e "  ###  --oh_download     : Option to download Oracle Home on just primary or both primary or      ###"
echo -e "  ###                      standby.                                                               ###"
echo -e "  ###                      Possible Options - primary/both                                        ###"
echo -e "  ###                                                                                             ###"
echo -e "  ###################################################################################################\n"
exit;

}

##############################
# Function to enable logging #
##############################
LOG()
{
    if [ "$LOGGING_OPTION" = "TERMINAL" ]
    then
        echo -e "$1"                                    ##No Logging
    elif [ "$LOGGING_OPTION" = "TERMINAL_TZ" ]
    then
        echo -e  `date -u` "--> $1"                     ##No Logging,with timestamp
    elif [ "$LOGGING_OPTION" = "LOGFILE" ]
    then
        echo -e "$1" >> $LOG_FILE                       ##Log Only, No output
    elif [ "$LOGGING_OPTION" = "LOGFILE_TZ" ]
    then
        echo -e  `date -u` "--> $1" >> $LOG_FILE        ## log only, no output, with timestamp
    elif [ "$LOGGING_OPTION" = "BOTH" ]
    then
        echo -e  "$1" | tee -a $LOG_FILE                ## show and log
    else
        echo -e  `date -u` "--> $1" | tee -a $LOG_FILE  ## show and log
    fi

    if [ $? -ne 0 ]
    then
        echo "error writing to $LOG_FILE"
        exit 1
    fi
}

###################################
GET_STANDBY_HOST_NAME()
###################################
{
        DB="$1"
        PRIM_C_NAME="$DB-orasvr.db.amazon.com"
        A_C_NAME="$DB-a-dg.db.amazon.com"
        B_C_NAME="$DB-b-dg.db.amazon.com"

        ping -c1 $PRIM_C_NAME  >/dev/null 2>&1
        IS_PRIM_VALID=`echo $?`
        ping -c1 $A_C_NAME >/dev/null 2>&1
        IS_A_VALID=`echo $?`
        ping -c1 $B_C_NAME >/dev/null 2>&1
        IS_B_VALID=`echo $?`
        
        if [ $IS_PRIM_VALID -ne 0 ] || [ $IS_A_VALID -ne 0 ] || [ $IS_B_VALID -ne 0 ]
        then
                STDBY_HOST_NAME="UNRESOLVED"
                LOG "Unable to find standby hostname -$STDBY_HOST_NAME"
                LOG "Exiting ..."
                exit;
        else
                PRIM_HOST_NAME=`ping -c1 $PRIM_C_NAME | head -1 | grep -o -E "[^ ]*.amazon.com"`
                A_HOST_NAME=`ping -c1 $A_C_NAME | head -1 | grep -o -E "[^ ]*.amazon.com"`
                B_HOST_NAME=`ping -c1 $B_C_NAME | head -1 | grep -o -E "[^ ]*.amazon.com"`
 
                if [ "$PRIM_HOST_NAME" = "$A_HOST_NAME" ]
                then
                        STDBY_HOST_NAME=$B_HOST_NAME
                        
                elif [ "$PRIM_HOST_NAME" = "$B_HOST_NAME" ]
                then
                        STDBY_HOST_NAME=$A_HOST_NAME

                fi
        fi
}

##################################################
# Function to get input arguments for the script #
##################################################
GET_INPUTS()
{

SID="NO"
MODE="NO"
RELINK="NO"
UPGRD="NO"
OH="NO"


while [ $# -gt 0 ]
do
        ARG=$1
        ARG_TYPE=`echo $ARG | awk -F "=" '{print $1}' | sed "s/ //g"`
        if [ $ARG_TYPE = "--sid" ] && [ $SID != "YES" ]
        then
            ORACLE_SID=`echo $1 | awk -F "=" '{print $2}' | sed "s/ //g"`
            SID="YES";
        elif [ $ARG_TYPE = "--mode" ] && [ $MODE != "YES" ]
        then
            MODE_TYPE=`echo $1 | awk -F "=" '{print $2}' | sed "s/ //g"`
            MODE="YES";
        elif [ $ARG_TYPE = "--oh_download" ] && [ $OH != "YES" ]
        then
            OH_DOWNLOAD=`echo $1 | awk -F "=" '{print $2}' | sed "s/ //g"`
            OH="YES";
        elif [ $ARG_TYPE = "--upgrade_version" ] && [ $UPGRD != "YES" ]
        then
            UPGRD_VERSION=`echo $1 | awk -F "=" '{print $2}' | sed "s/ //g"`
            DB_UPGRD_VERSION=`echo $UPGRD_VERSION | awk -F ":" '{print $1}'`
            PATCH_VERSION=`echo $UPGRD_VERSION | awk -F ":" '{print $2}'`
            PATCH_RELEASE=`echo ${DB_UPGRD_VERSION} | sed "s/\.//g"`
            UPGRD="YES";
        else
            show_usage
        fi
        shift
done

if [ "$SID" = "NO" ] || [ "$MODE" = "NO" ] || [ "$UPGRD" = "NO" ]
then
    show_usage
fi

if [ "$OH" = "NO" ]
then
    OH_DOWNLOAD="primary"
fi

if [ "$OH_DOWNLOAD" != "primary" ] && [ "$OH_DOWNLOAD" != "both" ]
then
    show_usage
fi

LOG "Checking role of database - \c"

DB_ROLE=`sqlplus -s "/as sysdba" << EOF
set heading off verify off feedback off;
select database_role from v\\$database;
exit;
EOF`

DB_ROLE=`echo $DB_ROLE | sed "s/ //g"`

echo -e "$DB_ROLE"
LOG ""

LOG "Checking type of database - \c"

DB_TYPE=`sqlplus -s fleet/fleet@fcdba << EOF
set heading off verify off feedback off;
select database_type from fc_database_schemas where DATABASE = upper('$ORACLE_SID');
exit;
EOF`

DB_TYPE=`echo $DB_TYPE | sed "s/ //g"`

echo -e "$DB_TYPE"
LOG ""


}


VALIDATE_INPUTS()
{

## Check the mode in which script needs to be run

if [ "$MODE_TYPE" != "PRE_UPGRADE" ]
then
    if [ "$MODE_TYPE" != "UPGRADE" ]
    then
        LOG "Please provide the correct mode for script to run."
        LOG "Valid modes are PRE_UPGRADE / UPGRADE"
        LOG "Exiting ...\n"
        exit;
    else
        LOG "Script is running in UPGRADE mode. This needs database shutdown at later stage"
    fi
else
    LOG "Script is running in PRE_UPGRADE mode. This does not need downtime"
fi

## Check what should be FTP location

HOST_LOC=`hostname | awk -F "." '{print $2}'`
if [ $HOST_LOC = "vdc" ]
then
        FTP_LOCATION="iad"
else
        HOST_LOC=`expr substr $HOST_LOC 1 3`
        FTP_LOCATION=$HOST_LOC
fi

LOG ""

if [ "$FTP_LOCATION" != "iad" ]
then
    if [ "$FTP_LOCATION" != "sea" ]
    then
        if [ "$FTP_LOCATION" != "dub" ]
        then
            if [ "$FTP_LOCATION" != "pek" ]
            then 
                LOG "Unable to determine the FTP location. Taking iad as default FTP location"
                FTP_LOCATION="iad"
                LOG "Taking FTP_LOCATION as iad" 
                LOG ""
            else
                LOG "FTP location is PEK"
            fi
        else
            LOG "FTP Location is DUB"
        fi
    else
        LOG "FTP location is SEA"
    fi
else
    LOG "FTP location is IAD"
fi

## Check if SID exists

SID_EXISTS=`grep $ORACLE_SID /etc/oratab | grep -v "#" | wc -l` 
SID_EXISTS=`expr $SID_EXISTS + 0`

if [ $SID_EXISTS -eq 0 ]
then
    LOG ""
    LOG "SID $ORACLE_SID does not exists on this host. Please provide valid SID"
    LOG "Exiting ..."
    LOG ""
    exit;
else
    LOG ""
    LOG "Upgrading SID $ORACLE_SID"
    LOG ""
fi

## Check if Oracle Home is running in desired patch set

CURRENT_PATCH_VERSION=`basename $ORACLE_HOME` 
CURRENT_RELEASE=`echo $ORACLE_HOME | awk -F "/" '{print $6}' | sed "s/ //g"`

if [ "$CURRENT_RELEASE" = "$PATCH_RELEASE" ]
then
    LOG ""
    LOG "Current database version is $CURRENT_RELEASE $CURRENT_PATCH_VERSION"
    LOG "Required database version is $DB_UPGRD_VERSION $PATCH_VERSION" 
    LOG "Database upgrade not required. Please go for patch set upgrade"
    LOG "Exiting..." 
    LOG ""
    exit;
else
    LOG ""
    LOG "Current database version is $CURRENT_RELEASE $CURRENT_PATCH_VERSION"
    LOG "Required database version is $DB_UPGRD_VERSION $PATCH_VERSION" 
    COMPARE_VERSION
    LOG "Proceeding with upgrade"
    LOG ""
fi


# Check if more than 1 databases are running under same Oracle Home

RUNNING_INSTANCES=`ps -eaf | grep pmon | grep -v grep | wc -l`
RUNNING_INSTANCES=`expr $RUNNING_INSTANCES + 0`

if [ "$MODE_TYPE" = "UPGRADE" ]
then
    if [ $RUNNING_INSTANCES -gt 1 ]
    then
        LOG "More than 1 databases running on this host"
        LOG "Checking if they are under same Oracle Home or different"
        
        INSTANCES_UNDER_HOME=`cat /etc/oratab | grep $CURRENT_RELEASE | grep -v grep | grep -v "#" | wc -l`
        INSTANCES_UNDER_HOME=`expr $INSTANCES_UNDER_HOME + 0`
        
        if [ $INSTANCES_UNDER_HOME -gt 1 ]
        then
            LOG "More than 1 databases running under $CURRENT_RELEASE Oracle Home"
            LOG "This script can be used only when 1 database is running under a Oracle Home"
            LOG "Existing ..."
            exit;
        fi
    
    fi

fi

}



SET_LOGGING()
{

    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID >> /dev/null
    
    if [ ! -f /opt/app/oracle/admin/${ORACLE_SID}/${PATCH_RELEASE}_upgrade ]
    then
      mv /opt/app/oracle/admin/${ORACLE_SID}/${PATCH_RELEASE}_upgrade /opt/app/oracle/admin/${ORACLE_SID}/${PATCH_RELEASE}_upgrade_${TIMESTAMP} 2> /dev/null
    fi
    
    mkdir -p /opt/app/oracle/admin/${ORACLE_SID}/${PATCH_RELEASE}_upgrade
    LOG_DIR="/opt/app/oracle/admin/${ORACLE_SID}/${PATCH_RELEASE}_upgrade"
    LOG_FILE="$LOG_DIR/upgrade.log"
    
    LOG ""
    LOG "Log file Directory - $LOG_DIR"
    LOG "Log file           - $LOG_FILE"
    LOG ""

}



########################################################
# Function to download the binary and extract the same #
########################################################

DOWNLOAD()
{

cd ~ ; . ./.oraenvamzn
oraenvamzn $ORACLE_SID >> /dev/null

LOG ""
LOG "\t\t##################################################"
LOG "\t\t####   Software download for primary server   ####"
LOG "\t\t##################################################"

NEW_OH="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"

if [ -s "$NEW_OH" ]
then
    LOG ""
    LOG "ORACLE_HOME already exist - $NEW_OH"
    DOWNLOAD="NO"
    sleep 3;
else
    LOG ""
    LOG "ORACLE_HOME - $NEW_OH - does not exists"
    LOG ""
    LOG "Proceeding to install new Oracle Home - $NEW_OH"
    DOWNLOAD="YES"
    sleep 3;
fi


if [ "$DOWNLOAD" = "YES" ]
then
        
        ## Check the disk space

        DISK_SIZE=`df /opt/app/oracle | grep -v Filesystem | awk '{print $2}'`
        DISK_SIZE=`expr $DISK_SIZE + 0`
        TEN_PCT=`expr $DISK_SIZE / 10`
        THRESHOLD_SIZE=`expr $DISK_SIZE - $TEN_PCT`
        AVALABLE_SIZE=`df /opt/app/oracle | grep -v Filesystem | awk '{print $3}'`
        AVALABLE_SIZE=`expr $AVALABLE_SIZE + 0`
        AFTER_SIZE=`expr $AVALABLE_SIZE + 4000000`

        if [ $AFTER_SIZE -ge $THRESHOLD_SIZE ]
        then
                LOG ""
                LOG "Cannot download and extract binaries. Space available on the disk /opt/app/oracle is not sufficient"
                LOG "Current Disk size                     - "`expr $DISK_SIZE / 1024 / 1024`"G"
                LOG "Space Used                            - "`expr $AVALABLE_SIZE / 1024 / 1024`"G"
                LOG "Space required for new Oracle Home    - 3.5G"
                LOG "Space after install                   - "`expr $AFTER_SIZE / 1024 / 1024`"G"
                LOG ""
                LOG "Space available after installation will be more then 90% of total disk space. This can cause a sev 2 ticket. Please free up some space and run this script again."
                LOG "Exiting ..."
                exit;
        else
                LOG ""
                LOG "Current Disk size                     - "`expr $DISK_SIZE / 1024 / 1024`"G"
                LOG "Space Used                            - "`expr $AVALABLE_SIZE / 1024 / 1024`"G"
                LOG "Space required for new Oracle Home    - 3.5G"
                LOG "Space after install                   - "`expr $AFTER_SIZE / 1024 / 1024`"G"
                LOG ""
                LOG "Space is sufficient. Proceeding with Oracle Home installation"
                sleep 5;
        fi

        ## Check the space in dump directory

        DUMP_SIZE=`df -k /dumps-01/ | grep -v Filesystem  | awk '{print $3}'`
        DUMP_SIZE=`expr $DUMP_SIZE + 0`
        DUMP_SIZE_AFTR=`expr $DUMP_SIZE + 2000000`
        DUMP_TOTAL=`df -k /dumps-01/ | grep -v Filesystem  | awk '{print $2}'`
        DUMP_TOTAL=`expr $DUMP_TOTAL + 0`
        DUMP_TEN=`expr $DUMP_TOTAL / 10`
        DUMP_THRESHOLD=`expr $DUMP_TOTAL - $DUMP_TEN`
        if [ $DUMP_SIZE_AFTR -ge $DUMP_THRESHOLD ]
        then
                LOG ""
                LOG "Space left in /dumps-01 location is very less to download the patch set. Please free up some space in this location"
                LOG ""
                LOG "$PATCH_RELEASE $PATCH_VERSION dump required atleast 1.5G to download. If the /dump-01 location is more than 90% full, you will get a sev 2"
                LOG "Exiting ..."
                LOG ""
                exit;
        fi

        ## Download and install ORACLE_HOME

        LOG ""
        LOG "Downloading required ORACLE_HOME version - ${PATCH_RELEASE}/$PATCH_VERSION\n\n"
        sleep 3;
        mkdir -p /dumps-01/databases/PATCH_SET
        rm -rf /dumps-01/databases/PATCH_SET/*
        cd /dumps-01/databases/PATCH_SET

        if [ "$FTP_LOCATION" = "pek" ]
        then
                wget dbeng-downloads-pek.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/$PATCH_RELEASE/server/$PATCH_RELEASE$PATCH_VERSION.tar.gz
        elif [ "$FTP_LOCATION" = "dub" ]
        then
                wget dbeng-downloads-dub.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/$PATCH_RELEASE/server/$PATCH_RELEASE$PATCH_VERSION.tar.gz
        elif [ "$FTP_LOCATION" = "iad" ]
        then
                wget dbeng-downloads-iad.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/$PATCH_RELEASE/server/$PATCH_RELEASE$PATCH_VERSION.tar.gz
        elif [ "$FTP_LOCATION" = "sea" ]
        then
                wget dbeng-downloads-sea.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/$PATCH_RELEASE/server/$PATCH_RELEASE$PATCH_VERSION.tar.gz
        else
                wget dbeng-downloads-iad.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/$PATCH_RELEASE/server/$PATCH_RELEASE$PATCH_VERSION.tar.gz
        fi

        LOG ""
        LOG "Download completed"
        LOG ""
        LOG "Extracting the files"
        tar xvfz /dumps-01/databases/PATCH_SET/$PATCH_RELEASE$PATCH_VERSION.tar.gz -C /opt/app/oracle/product/ > /dev/null
        LOG ""
        LOG "Extraction completed"
        
        LOG ""
        LOG "Checking if new Oracle Home is correct"
        
        NR_SCRIPTS=`ls $NEW_OH/rdbms/admin/*sql |wc -l`
        if [ $NR_SCRIPTS -ge 949 ]
        then
            LOG ""
            LOG "Oracle Home looks ok"
        else
            LOG ""
            LOG "***WARNING: Oracle home doesn't look ok, probably a tar failure***"
            LOG "Please download again. Exiting ..."
            LOG ""
            exit;
        fi
        
        LOG ""
        LOG "Relinking new ORACLE_HOME"
        
        ORACLE_HOME="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"
        LD_LIBRARY_PATH="${ORACLE_HOME}/lib"
        SHLIB_PATH="${ORACLE_HOME}/lib"
        
        $ORACLE_HOME/bin/relink all
        
        LOG ""
        LOG "Relink of new ORACLE_HOME completed"
        
        cd ~ ; . ./.oraenvamzn 
        oraenvamzn $ORACLE_SID >> /dev/null
        
fi

LOG ""
LOG "Creating symlink for init file and password file in new OH"

ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/init${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/spfile${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
ln -s /opt/app/oracle/admin/${ORACLE_SID}/orapw/orapw${ORACLE_SID} ${NEW_OH}/dbs 2>/dev/null

if [ "$OH_DOWNLOAD" = "both" ] && [ "$DB_TYPE" = "production" ]
then
    
    LOG ""
    LOG "\t\t##################################################"
    LOG "\t\t####   Software download for standby server   ####"
    LOG "\t\t##################################################"
    
    GET_STANDBY_HOST_NAME $ORACLE_SID
    
    LOG ""
    LOG "Checking if Oracle Home exists on standby - $STDBY_HOST_NAME"
    
    if $SSH $STDBY_HOST_NAME 'ls "'$NEW_OH'" 2> /dev/null 1> /dev/null' 
    then
        STDBY_DOWNLOAD="NO"
    else
        STDBY_DOWNLOAD="YES"
    fi
    
    if [ "$STDBY_DOWNLOAD" = "NO" ]
    then
        LOG "ORACLE_HOME - $NEW_OH - exists on standby server" 
        LOG "Skipping Oracle Home download for standby"
    else
        LOG "ORACLE_HOME - $NEW_OH - does not exists on standby server"
        LOG ""
        LOG "Proceeding to install new Oracle Home - $NEW_OH"
        
        cat >> /tmp/oh_download_${TIMESTAMP}.sh << EOF
#! /bin/bash        

##############################
# Function to enable logging #
##############################
STANDBY_LOG()
{
    if [ "\$LOGGING_OPTION" = "TERMINAL" ]
    then
        echo -e "\$1"                                    ##No Logging
    elif [ "\$LOGGING_OPTION" = "TERMINAL_TZ" ]
    then
        echo -e  \`date -u\` "--> \$1"                     ##No Logging,with timestamp
    elif [ "\$LOGGING_OPTION" = "LOGFILE" ]
    then
        echo -e "\$1" >> \$LOG_FILE                       ##Log Only, No output
    elif [ "\$LOGGING_OPTION" = "LOGFILE_TZ" ]
    then
        echo -e  \`date -u\` "--> \$1" >> \$LOG_FILE        ## log only, no output, with timestamp
    elif [ "\$LOGGING_OPTION" = "BOTH" ]
    then
        echo -e  "\$1" | tee -a \$LOG_FILE                ## show and log
    else
        echo -e  \`date -u\` "--> \$1" | tee -a \$LOG_FILE  ## show and log
    fi

    if [ \$? -ne 0 ]
    then
        echo "error writing to \$LOG_FILE"
        exit 1
    fi
}

## Check the disk space

PATCH_RELEASE="$PATCH_RELEASE"
PATCH_VERSION="$PATCH_VERSION"
FTP_LOCATION="$FTP_LOCATION"
DB_UPGRD_VERSION="$DB_UPGRD_VERSION"
ORACLE_SID="$ORACLE_SID"
LOGGING_OPTION="$LOGGING_OPTION"
LOG_FILE="/tmp/oh_download.log"

STDBY_LOG_FILE=/tmp/standby_download.log

NEW_OH="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"

DISK_SIZE=\`df /opt/app/oracle | grep -v Filesystem | awk '{print \$2}'\`
DISK_SIZE=\`expr \$DISK_SIZE + 0\`
TEN_PCT=\`expr \$DISK_SIZE / 10\`
THRESHOLD_SIZE=\`expr \$DISK_SIZE - \$TEN_PCT\`
AVALABLE_SIZE=\`df /opt/app/oracle | grep -v Filesystem | awk '{print \$3}'\`
AVALABLE_SIZE=\`expr \$AVALABLE_SIZE + 0\`
AFTER_SIZE=\`expr \$AVALABLE_SIZE + 4000000\`

if [ \$AFTER_SIZE -ge \$THRESHOLD_SIZE ]
then
        STANDBY_LOG ""
        STANDBY_LOG "Cannot download and extract binaries. Space available on the disk /opt/app/oracle is not sufficient"
        STANDBY_LOG "Current Disk size                     - "\`expr \$DISK_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG "Space Used                            - "\`expr \$AVALABLE_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG "Space required for new Oracle Home    - 3.5G"
        STANDBY_LOG "Space after install                   - "\`expr \$AFTER_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG ""
        STANDBY_LOG "Space available after installation will be more then 90% of total disk space. This can cause a sev 2 ticket. Please free up some space and run this script again."
        STANDBY_LOG "Exiting ..."
        exit;
else
        STANDBY_LOG ""
        STANDBY_LOG "Current Disk size                     - "\`expr \$DISK_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG "Space Used                            - "\`expr \$AVALABLE_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG "Space required for new Oracle Home    - 3.5G"
        STANDBY_LOG "Space after install                   - "\`expr \$AFTER_SIZE / 1024 / 1024\`"G"
        STANDBY_LOG ""
        STANDBY_LOG "Space is sufficient. Proceeding with Oracle Home installation"
        sleep 5;
fi

## Check the space in dump directory

DUMP_SIZE=\`df -k /dumps-01/ | grep -v Filesystem  | awk '{print \$3}'\`
DUMP_SIZE=\`expr \$DUMP_SIZE + 0\`
DUMP_SIZE_AFTR=\`expr \$DUMP_SIZE + 2000000\`
DUMP_TOTAL=\`df -k /dumps-01/ | grep -v Filesystem  | awk '{print \$2}'\`
DUMP_TOTAL=\`expr \$DUMP_TOTAL + 0\`
DUMP_TEN=\`expr \$DUMP_TOTAL / 10\`
DUMP_THRESHOLD=\`expr \$DUMP_TOTAL - \$DUMP_TEN\`

if [ \$DUMP_SIZE_AFTR -ge \$DUMP_THRESHOLD ]
then
        STANDBY_LOG ""
        STANDBY_LOG "Space left in /dumps-01 location is very less to download the patch set. Please free up some space in this location"
        STANDBY_LOG ""
        STANDBY_LOG "\$PATCH_RELEASE \$PATCH_VERSION dump required atleast 1.5G to download. If the /dump-01 location is more than 90% full, you will get a sev 2"
        STANDBY_LOG "Exiting ..."
        STANDBY_LOG ""
        exit;
fi

## Download and install ORACLE_HOME

STANDBY_LOG ""
STANDBY_LOG "Downloading required ORACLE_HOME version - \${PATCH_RELEASE}/\$PATCH_VERSION"
STANDBY_LOG ""
STANDBY_LOG ""

sleep 3;
mkdir -p /dumps-01/databases/PATCH_SET
rm -rf /dumps-01/databases/PATCH_SET/*
cd /dumps-01/databases/PATCH_SET

if [ "\$FTP_LOCATION" = "pek" ]
then
        wget -q dbeng-downloads-pek.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/\$PATCH_RELEASE/server/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz
elif [ "\$FTP_LOCATION" = "dub" ]
then
        wget -q dbeng-downloads-dub.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/\$PATCH_RELEASE/server/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz
elif [ "\$FTP_LOCATION" = "iad" ]
then
        wget -q dbeng-downloads-iad.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/\$PATCH_RELEASE/server/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz
elif [ "\$FTP_LOCATION" = "sea" ]
then
        wget -q dbeng-downloads-sea.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/\$PATCH_RELEASE/server/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz
else
        wget -q dbeng-downloads-iad.aka.amazon.com/skip-authentication/downloads/golden-images/linux-x86-64/\$PATCH_RELEASE/server/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz
fi

STANDBY_LOG ""
STANDBY_LOG "Download completed"
STANDBY_LOG ""
STANDBY_LOG "Extracting the files"
tar xvfz /dumps-01/databases/PATCH_SET/\$PATCH_RELEASE\$PATCH_VERSION.tar.gz -C /opt/app/oracle/product/ > /dev/null
STANDBY_LOG ""
STANDBY_LOG "Extraction completed"

STANDBY_LOG ""
STANDBY_LOG "Checking if new Oracle Home is correct"

NR_SCRIPTS=\`ls \$NEW_OH/rdbms/admin/*sql |wc -l\`
if [ \$NR_SCRIPTS -ge 949 ]
then
    STANDBY_LOG ""
    STANDBY_LOG "Oracle Home looks ok"
else
    STANDBY_LOG ""
    STANDBY_LOG "***WARNING: Oracle home doesn't look ok, probably a tar failure***"
    STANDBY_LOG "Please download again. Exiting ..."
    STANDBY_LOG ""
    exit;
fi

STANDBY_LOG ""
STANDBY_LOG "Relinking new ORACLE_HOME"

ORACLE_HOME="$NEW_OH"
LD_LIBRARY_PATH="\${ORACLE_HOME}/lib"
SHLIB_PATH="\${ORACLE_HOME}/lib"

STANDBY_LOG "New Oracle Home is - \$ORACLE_HOME"

\$ORACLE_HOME/bin/relink all

STANDBY_LOG ""
STANDBY_LOG "Relink of new ORACLE_HOME completed"

cd ~ ; . ./.oraenvamzn 
oraenvamzn \$ORACLE_SID >> /dev/null

EOF
    $SCP /tmp/oh_download_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/oh_download.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/oh_download.sh"    

    fi
    
    cat >> /tmp/oh_init_symlink_${TIMESTAMP}.sh << EOF
#! /bin/bash

echo -e ""
echo -e "Creating symlink for init file and password file in new OH"

ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/init${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/spfile${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
ln -s /opt/app/oracle/admin/${ORACLE_SID}/orapw/orapw${ORACLE_SID} ${NEW_OH}/dbs 2>/dev/null

EOF

    $SCP /tmp/oh_init_symlink_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/oh_init_symlink.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/oh_init_symlink.sh"    

fi
    
}

COMPARE_VERSION()
{

    CURR_PART1=`echo $CURRENT_RELEASE | awk -F "." '{print $1}'`
    CURR_PART2=`echo $CURRENT_RELEASE | awk -F "." '{print $2}'`
    CURR_PART3=`echo $CURRENT_RELEASE | awk -F "." '{print $3}'`
    CURR_PART4=`echo $CURRENT_RELEASE | awk -F "." '{print $4}'`
    
    REQ_PART1=`echo $DB_UPGRD_VERSION | awk -F "." '{print $1}'`
    REQ_PART2=`echo $DB_UPGRD_VERSION | awk -F "." '{print $2}'`
    REQ_PART3=`echo $DB_UPGRD_VERSION | awk -F "." '{print $3}'`
    REQ_PART4=`echo $DB_UPGRD_VERSION | awk -F "." '{print $4}'`
    
    
    CURR_PATCH_VER=`echo $CURRENT_PATCH_VERSION | cut -c 2-3`
    CURR_PATCH_VER=`expr $CURR_PATCH_VER + 0`
    REQ_PATCH_VER=`echo $PATCH_VERSION | cut -c 2-3`
    REQ_PATCH_VER=`expr $REQ_PATCH_VER + 0`
    
    if [ "$CURRENT_RELEASE" = "$DB_UPGRD_VERSION" ]
    then
        LOG "Upgrade version is same as current version"
        LOG "Upgrade version : $DB_UPGRD_VERSION"
        LOG "Current version : $CURRENT_RELEASE"
        LOG "This script is for doing major upgrade. Please use patchset upgrade script for doing patchset upgrades"
        LOG "Exiting ..."
        exit;
    fi
      
    if [ $CURR_PART1 -eq $REQ_PART1 ]
    then
        if [ $CURR_PART2 -eq $REQ_PART2 ]
        then
            if [ $CURR_PART3 -eq $REQ_PART3 ]
            then
                if [ $CURR_PART4 -eq $REQ_PART4 ] || [ $REQ_PART4 -lt $CURR_PART4 ]
                then
                    LOG "Required upgrade version is equal or smaller than current version. Upgrade cannot run"
                    LOG "Exiting ..."
                    exit 1;
                fi
            elif [ $REQ_PART3 -lt $CURR_PART3 ]
            then
                LOG "Required upgrade version is smaller than current version. Upgrade cannot run"
                LOG "Exiting ..."
                exit 1;
            fi
        elif [ $REQ_PART2 -lt $CURR_PART2 ]
        then
            LOG "Required upgrade version is smaller than current version. Upgrade cannot run"
            LOG "Exiting ..."
            exit 1;
        fi
    elif [ $REQ_PART1 -lt $CURR_PART1 ]
    then
        LOG "Required upgrade version is smaller than current version. Upgrade cannot run"
        LOG "Exiting ..."
        exit 1;
    fi
    
}

                    
##############################################
# Function to check current database version #
##############################################

CHECK_DB_VERSION ()
{

    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID > /dev/null 2>&1
    
    if [ "$DB_ROLE" = "PRIMARY" ]
    then
        databaseVersion=`sqlplus -s '/ as sysdba' <<EOF
        set echo off ;
        set feedback off;
        set heading off;
        set verify off;
        select substr(version,1,instr(version,'.',-1)-1) from dba_registry where comp_name = 'Oracle Database Catalog Views' and status='VALID';
        exit 0;
EOF`
    elif [ "$DB_ROLE" = "PHYSICALSTANDBY" ]
    then
        databaseVersion=`sqlplus -s '/ as sysdba' <<EOF
        set echo off ;
        set feedback off;
        set heading off;
        set verify off;
        select substr(banner,instr(banner,' ',1,6)+1,8) from v\\$version where rownum = 1;
        exit 0;
EOF`

    fi

    if [ $? -ne 0 ]; then
        echo -e "DONE" | tee -a $LOG_FILE
        # sqlplus failed for some reason
        LOG ""
        LOG "Unable to determine Oracle version"
        LOG "$databaseVersion"
        LOG ""
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        echo -e "DONE" | tee -a $LOG_FILE
        databaseVersion=`echo $databaseVersion | sed "s/ //g"`
        LOG "Current Database version is: $databaseVersion"
    fi

    return;

}

##########################################
# Function to check current oratab entry #
##########################################

CHECK_ORATAB_VERSION()
{

    oratabVersion="`awk -F: -v sid=$ORACLE_SID '{ if ( $1 == sid ) { print $2 }}' /etc/oratab|cut -f6 -d/`";
    echo -e "DONE" | tee -a $LOG_FILE
    LOG "Version in /etc/oratab: $oratabVersion"
    LOG ""
    return;

}

###################################
# Function to check Linux Release #
###################################

CHECK_RHEL5()
{

    echo -e "DONE" | tee -a $LOG_FILE
    if [ "`grep 'release 5' /etc/redhat-release`" ]; then
        LOG "OS Release is RHEL 5"
    else
        LOG "OS release is not RHEL5"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    fi

    return;

}

####################################
# Function to check OS bit version #
####################################

CHECK64BIT()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    if [ "`uname -i`" = "x86_64" ]; then
        LOG "Linux is running on 64 bit"
    else
        LOG "This is not a 64-bit OS"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    fi

    return;

}

##############################
# Function to check timezone #
##############################

CHECK_TIMEZONE()
{

    timezone="`sqlplus -s '/as sysdba' <<EOF
    set echo off
    set feedback off
    set heading off
    select version from v\\$timezone_file;
    exit;
    EOF`"

    echo -e "DONE" | tee -a $LOG_FILE

    if [ $timezone -ne 4 ] && [ $timezone -ne 14 ] ; then
       LOG "Timezone version is not 4"
       LOG "Please upgrade Timezone version to 4 and then try the upgrade"
       LOG "Exiting ..."
       LOG ""
       exit 1;
    else
       LOG "Database is running on correct timezone"
    fi

    return;

}

###########################################################
# Function to check status of previous backup of database #
###########################################################

LAST_BACKUP_CHECK()
{

    BKP_STATUS=`sqlplus -s '/as sysdba' <<EOF
    set echo off;
    set feedback off;
    set heading off;
    select round(max(round(sysdate-full_time,2))) || ':' || round(max(round(sysdate-incr_time,2)))
    from    (   select  max(b.completion_time) full_time,a.name 
                from    v\\$datafile a ,v\\$backup_datafile b
                where   a.file#=b.file# 
                and     incremental_level=0 group by a.name 
            ) a, 
            (   select  max(b.completion_time) incr_time,a.name 
                from    v\\$datafile a ,v\\$backup_datafile b 
                where   a.file#=b.file# 
                and     incremental_level>0 group by a.name 
            ) b 
    where   a.name=b.name;
    exit;
EOF`

    FULL_BKP_DAYS=`echo $BKP_STATUS | awk -F ":" '{print $1}'`
    FULL_BKP_DAYS=`expr $FULL_BKP_DAYS + 0`
    INC_BKP_DAYS=`echo $BKP_STATUS | awk -F ":" '{print $2}'`
    INC_BKP_DAYS=`expr $INC_BKP_DAYS + 0`

    echo -e "DONE" | tee -a $LOG_FILE

    if [ $FULL_BKP_DAYS -gt 6 ]
    then
        LOG "Last full backup of database is $FULL_BKP_DAYS old"
        LOG "Full backup of database is older than 6 days. Please take a full backup of database before upgrade"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        LOG "Last full backup of database is $FULL_BKP_DAYS old"
    fi
    
    if [ $INC_BKP_DAYS -gt 2 ]
    then
        LOG "Last full backup of database is $INC_BKP_DAYS old"
        LOG "Incremental backup of database is older than 2 days. Looks like some issue with backups. Please take backup of database before upgrade"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        LOG "Last incremental backup of database is $INC_BKP_DAYS old"
    fi

    return;

}



##################################################################
# Function to check adequate space in Shared pool before upgrade #
##################################################################

CHECK_SP()
{

    # Checking current shared pool size

    shared_pool_current="`sqlplus -s '/as sysdba' <<EOF
    set echo off
    set feedback off
    set heading off
    select 'SHARED_POOL_CURRENT: '|| VALUE/1024/1024 from v\\$parameter where NAME= 'shared_pool_size';
    exit;
    EOF`"

    spc="`echo $shared_pool_current | awk '/SHARED_POOL_CURRENT:/ {print $2}'`"

    echo -e "DONE" | tee -a $LOG_FILE

    LOG "Current Shared Pool Size is $spc MB"

    # Checking current buffer cache size

    buffer_cache_current="`sqlplus -s '/as sysdba' <<EOF
    set echo off
    set feedback off
    set heading off
    select 'BUFFER_CACHE_CURRENT: '||bytes/1024/1024 from v\\$sgainfo where name='Buffer Cache Size';
    exit;
    EOF`"

    bcc="`echo $buffer_cache_current | awk '/BUFFER_CACHE_CURRENT:/ {print $2}'`"

    # Checking current processes parameter value

    processes_current="`sqlplus -s '/as sysdba' <<EOF
    set echo off
    set feedback off
    set heading off
    select 'PROCESSES_CURRENT: '|| VALUE from v\\$parameter where NAME='processes';
    exit;
    EOF`"

    pc="`echo $processes_current | awk '/PROCESSES_CURRENT:/ {print $2}'`"


    shared_pool_req=`echo \(80 + \(15 \* \($bcc/256\) \) + \(5 \* \($pc/100\) \) \)|bc`;

    LOG "Shared pool required for upgrade is : $shared_pool_req MB"


    if [ $spc > $shared_pool_req ]; then
        LOG "Current Shared Pool Size is more than required Shared Pool Size"
    else
        LOG "Current Shared Pool Size is less than required Shared Pool Size. Set shared pool size to minimum $shared_pool_req size before proceeding with upgrade"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    fi


}

#########################################
# Function to check for Journal Entries #
#########################################

JOURNAL_ENTRIES()
{

    journal_entries="`sqlplus -s '/as sysdba' <<EOF
        set echo off ;
        set feedback off ;
        set heading off;
        select  COUNT(*)
        from    (   select  a.name iname, 
                            b.obj#, 
                            'SYS_JOURNAL_'||b.obj# jname
                    from    sys.obj$ a, sys.ind$ b
                    where   a.obj# = b.obj#
                    and     bitand(b.flags, 512)=512
                ) i_info,
                (   select  name jname, 
                            obj#, 
                            'SYS_IOT_TOP_'||obj# iotname
                    from    sys.obj$
                    where   name like 'SYS_JOURNAL_%'
                ) j_info,
                (   select  name iotname, obj#
                    from    sys.obj$
                    where   name like 'SYS_IOT_TOP_%'
                ) iot_info
        where   j_info.jname = i_info.jname (+)
        and     j_info.iotname = iot_info.iotname (+); 
        exit; 
    EOF`"

    journal_entries=`expr $journal_entries + 0`

    echo -e "DONE" | tee -a $LOG_FILE

    if [ $journal_entries -ne 0 ]; then
        LOG "Database has $journal_entries journal entries. Please check. Journal Clean Up must be done before database upgrade"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        LOG "Database does not have Journal Entries"
    fi

    return;

}

##################################
# Function to check AWR settings #
##################################
AWR_CHECK()
{

    AWR_RECORD=`sqlplus -s '/ as sysdba' <<EOF
    set heading off;
    set verify off;
    set feedback off;
    select count(1) from dba_hist_wr_control;
    exit;
EOF`

    echo -e "DONE" | tee -a $LOG_FILE

    AWR_RECORD=`echo $AWR_RECORD | sed "s/ //g"`
    AWR_RECORD=`expr $AWR_RECORD + 0`
    
    if [ $AWR_RECORD -gt 1 ]
    then
        LOG "Multiple records found for AWR setting. Doing Cleanup.."
        sqlplus -s '/ as sysdba' << EOF
        delete from dba_hist_wr_control where dbid not in (select dbid from v\$database);
        commit;
        exit;
EOF
        LOG "Cleanup Done"
    else
        LOG "AWR setting found correct"
    fi
    
    return;

}


##################################
# Function to check SYSAUX Space #
##################################
SYSAUX_CHECK()
{

    SPACE=`sqlplus -s '/ as sysdba' << EOF
        set feedback off verify off heading off;
        select round(sum(bytes/1024/1024/1024)) from   dba_data_files  where  tablespace_name = 'SYSAUX';
        exit;
EOF`

    echo -e "DONE" | tee -a $LOG_FILE
    
    SPACE=`echo $SPACE | sed "s/ //g"`
    SPACE=`expr $SPACE + 0`
    
    if [ $SPACE -lt 5 ]
    then
        LOG "Current space in SYSAUX is $SPACE GB - Insufficient"
        LOG "Space in SYSAUX tablespace is less than 5GB. Consider adding space to SYSAUX before doing upgrade"
        LOG "Exiting ..."
        exit 1;
    else
        LOG "Current space in SYSAUX is $SPACE GB - Sufficient"
    fi

}


##########################################################
# Function to check size of Incremental statistics table #
##########################################################
STATS_TABLE_CHECK()
{

    STATS_TAB_COUNT=`sqlplus -S '/ as sysdba' << EOF
    set feedback off verify off heading off;
    select count(1) from  dba_segments where segment_name in ('WRI$_OPTSTAT_SYNOPSIS$','WRI$_OPTSTAT_SYNOPSIS_HEAD$') group by segment_name having sum(bytes/1024/1024) > 512;
    exit;
EOF`

    echo -e "DONE" | tee -a $LOG_FILE

    STATS_TAB_COUNT=`echo $STATS_TAB_COUNT | sed "s/ //g"`
    STATS_TAB_COUNT=`expr $STATS_TAB_COUNT + 0`
    
    if [ $STATS_TAB_COUNT -ne 0 ]
    then
        LOG "Stats table size is bigger. Need to delete extraneous data"
        
        sqlplus -S '/ as sysdba' << EOF
        set feedback off verify off heading off;
        truncate table sys.wri\$_optstat_synopsis$;
        truncate table sys.wri\$_optstat_synopsis_head$;
EOF
        LOG "Data deleted from WRI$_OPTSTAT_SYNOPSIS$ and WRI$_OPTSTAT_SYNOPSIS_HEAD$ table"
    else
        LOG "Stats table size is not bigger"
    fi

}
        

######################################################
# Function to check health of data dictionary tables #
######################################################
DATA_DICT_HEALTH()
{

    sqlplus -S '/ as sysdba' << EOF >> $LOG_DIR/data_dict_health-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.txt
    set long 20000 feed off term off 
    -- clean up old check
    exec dbms_hm.drop_schema();
    -- run new check
    exec dbms_hm.run_check('Dictionary Integrity Check','PreUpgradeCheck'); 
    -- get sid for spool file name
    col instance new_value sid noprint
    select instance_name instance from v\$instance;
    -- run report
    set term on
    spool PreUpgradeCheck_&sid..spool
    select dbms_hm.get_run_report('PreUpgradeCheck') from dual;
    spool off
    prompt Report output saved in PreUpgradeCheck_&sid..spool
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG "Log - $LOG_DIR/data_dict_health-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.txt"

}


#####################################################
# Function to check physical corruption in database #
#####################################################
CHECK_CORRUPTION()
{
    
    DATA_CORR=`sqlplus -S '/ as sysdba' << EOF
    set feedback off verify off heading off;
    select count(1) from v\\$database_block_corruption;
    exit;
EOF`
    
    DATA_CORR=`echo $DATA_CORR | sed "s/ //g"`
    DATA_CORR=`expr $DATA_CORR + 0`
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    if [ $DATA_CORR -eq 0 ]
    then
        LOG "No physical corruption found in database"
    else
        LOG "Physical Corruption found in database"
        sqlplus -S '/ as sysdba' << EOF
        set feedback off verify off heading off;
        select * from v\$database_block_corruption;
        exit;
EOF

    fi

}


#####################################################
# Function to increase column width for object_name #
#####################################################
COL_WIDTH()
{

    sqlplus -s '/ as sysdba' << EOF
    set feedback off verify off heading off;
    alter table admin.DB_AUDITED_DDL_OPERATIONS modify object_name varchar2(1024);
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG "Column width for object_name increased to 1024 bytes in admin.DB_AUDITED_DDL_OPERATIONS table"

}


##############################################
# Function to check guaranteed restore point #
##############################################
RESTORE_POINT_CHECK()
{

    RESTORE_POINT=`sqlplus -s '/ as sysdba' << EOF
    set feedback off verify off heading off;
    select count(1) from v\\$restore_point where GUARANTEE_FLASHBACK_DATABASE ='YES';
    exit;
EOF`
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    RESTORE_POINT=`echo $RESTORE_POINT | sed "s/ //g"`
    RESTORE_POINT=`expr $RESTORE_POINT + 0`
    
    if [ $RESTORE_POINT -ne 0 ]
    then
        LOG "Looks like guaranteed restore point is setup in database. Please clear the restore point before upgrade"
        LOG "Exiting ..."
        exit 1;
    else
        LOG "No guaranteed restore point set in database"
    fi

}

    



#####################################
# Function to do pre upgrade checks #
#####################################

PRE_UPGRADE_CHECK()
{

    UPGRADE_ORACLE_HOME="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"
    
    UTILITY_SCRIPT_VERSION=`echo $PATCH_RELEASE | cut -c 1-3`

    sqlplus -s '/ as sysdba' << EOF
    set heading off;
    set verify off;
    set feedback off;
    exec DBMS_STATS.GATHER_DICTIONARY_STATS;
    exec dbms_stats.GATHER_DICTIONARY_STATS(options => 'GATHER STALE');
EOF

    echo -e "DONE" | tee -a $LOG_FILE

    spoolFile="$LOG_DIR/utlu${UTILITY_SCRIPT_VERSION}i-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log";

    LOG "Running utlu${UTILITY_SCRIPT_VERSION}i.sql to check if any warnings need to be addressed before upgrade"

    sqlplus -s '/ as sysdba' << EOF >> /dev/null
    set termout off;
    set heading off;
    set verify off;
    spool $spoolFile
    @$UPGRADE_ORACLE_HOME/rdbms/admin/utlu${UTILITY_SCRIPT_VERSION}i.sql
    spool off
    exit
EOF

    if [ ! -f $spoolFile ]; then
        LOG "Unable to spool output from sqlplus script: $UPGRADE_ORACLE_HOME/rdbms/admin/utlu${UTILITY_SCRIPT_VERSION}i.sql"
        exit 1;
    fi

    LOG "Warnings encountered and needs to be addressed before Upgrade"
    LOG "Log file - $spoolFile"
    LOG ""
    LOG ""

}

##########################################
# Function to do pre upgrade validations #
##########################################
PRE_UPGRADE_VALIDATION()
{

    LOG ""
    LOG "Checking if DB is already running on $PATCH_VERSION ................................................... \c"

    CHECK_DB_VERSION
    
    sleep 3
    
    LOG ""
    LOG "Checking version in /etc/oratab .............................................................. \c"

    CHECK_ORATAB_VERSION
    
    sleep 3
    
    LOG "Comparing upgrade version with /etc/oratab and database ...................................... DONE"

    if [ "${oratabVersion}" = "$DB_UPGRD_VERSION" ]; then
        LOG ""
        LOG "/etc/oratab shows $ORACLE_SID has already running on $DB_UPGRD_VERSION"
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        LOG "$ORACLE_SID database version in /etc/oratab is different than upgrade version"
    fi
    
    if [ "${oratabVersion}" != "${databaseVersion}" ]; then
        LOG ""
        LOG "\n/etc/oratab shows a different version than what the database shows. Exiting..."
        LOG ""
        exit 1;
    else
        LOG "$ORACLE_SID database version in /etc/oratab is same as database version"
    fi
    
    if [ "$databaseVersion" = "$DB_UPGRD_VERSION" ]; then
        LOG ""
        LOG "\nDB is already running on $DB_UPGRD_VERSION. Exiting..."
        LOG "Exiting ..."
        LOG ""
        exit 1;
    else
        LOG "$ORACLE_SID database version in database is different than upgrade version"
    fi
    
    # Checking if server is RHEL 5
    
    LOG ""
    LOG "Checking OS release version .................................................................. \c"
    
    CHECK_RHEL5
    
    sleep 3
    
    LOG ""
    LOG "Checking 64-bit version of Linux ............................................................. \c"
    
    CHECK64BIT
    
    sleep 3
    
    LOG ""
    LOG "Checking timezone of database. Database must be on timezone 4 before upgrade ................. \c"
    
    CHECK_TIMEZONE
    
    sleep 3
    
    LOG ""
    LOG "Checking if last backup of database is successful ............................................ \c"
    
    LAST_BACKUP_CHECK
    
    sleep 3
    
    LOG ""
    LOG "Checking if shared pool has adequate space for the upgrade to proceed ........................ \c"
    
    CHECK_SP
    
    if [ "$DB_ROLE" = "PRIMARY" ]
    then
    
        sleep 3
        
        LOG ""
        LOG "Checking if database has journal entries ..................................................... \c"
        
        JOURNAL_ENTRIES
        
        sleep 3
        
        LOG ""
        LOG "Checking AWR setting ......................................................................... \c"
    
        AWR_CHECK
        
        sleep 3
        
        LOG ""
        LOG "Checking if SYSAUX has sufficient space ...................................................... \c"
        
        SYSAUX_CHECK
        
        sleep 3
        
        LOG ""
        LOG "Checking if incremental statistics tables are too large (SR 3-4303224981, bug 10406267) ...... \c"
    
        STATS_TABLE_CHECK
    
    fi
    
    sleep 3
    
    LOG ""
    LOG "Checking Data Dictionary health .............................................................. \c"
    
    DATA_DICT_HEALTH
    
    if [ $ORACLE_SID = "fcdba" ]
    then
        sleep 3
        
        LOG ""
        LOG "Checking for XDB installation ............................................................ DONE"
        LOG "XDB installation exists. Refer to following document for steps specific to XDB"
        LOG "https://w.amazon.com/index.php/DBAutomation11202upgradeto11203#Check_for_XDB_cruft"
        LOG ""
    fi
    
    if [ "$DB_ROLE" = "PRIMARY" ]
    then
    
        sleep 3
        
        LOG ""
        LOG "Increasing the width of object_name in admin.DB_AUDITED_DDL_OPERATIONS ....................... \c"
        
        COL_WIDTH

    fi
        
    sleep 3
    
    LOG ""
    LOG "Checking existence of guaranteed restore point in database ................................... \c"
    
    RESTORE_POINT_CHECK
    
    if [ "$DB_ROLE" = "PRIMARY" ]
    then
    
        sleep 3
        
        LOG ""
        LOG "Running pre-upgrade script to perform validations ............................................ \c"
        
        PRE_UPGRADE_CHECK
    
    fi

}

########################################
# Function to do Check Carnaval outage #
########################################
CHECK_CARNAVAL_OUTAGE()
{

    OSID=`echo $ORACLE_SID | tr [:lower:] [:upper:]`
    MONITOR_SUPPRESS=`/apollo/env/FCDatabases/bin/carnaval.rb --name=FCDB.Oracle.InstanceMonitor.${OSID} --verbose | grep suppression | awk '{print $3}' | sed "s/ //g"`
    MONITOR_SUPPRESS=`echo $MONITOR_SUPPRESS | tr "[:lower:]" "[:upper:]"`
    SUPPRESS_DURATION=`/apollo/env/FCDatabases/bin/carnaval.rb --name=FCDB.Oracle.InstanceMonitor.${OSID} --verbose | grep duration | awk '{print $3}' | sed "s/ //g"`
    SUPPRESS_DURATION=`expr $SUPPRESS_DURATION + 0`

    echo -e "DONE" | tee -a $LOG_FILE
    
        if [ "$MONITOR_SUPPRESS" = "TRUE" ] && [ $SUPPRESS_DURATION -gt 200 ]
        then
            LOG "Instance Monitor for $OSID is suppressed for more than 3 hours"
        else
            LOG "Monitor for $OSID is not suppressed or duration is less than 3 hours"
            LOG "Please suppress instance monitor for at least 200 mins duration"
            LOG "Exiting ..."
            LOG ""
            exit;
        fi

}

##############################
# Function to do disable FSF #
##############################
DISABLE_FSF()
{

    OBSERVER_HOST=`sqlplus -s '/ as sysdba' <<EOF
    set feedback off verify off heading off;
    spool $LOG_DIR/observer_host.log
    select FS_FAILOVER_OBSERVER_HOST from v\\$database;
    exit
EOF`

    OBSERVER_HOST=`echo $OBSERVER_HOST | sed "s/ //g"`

    dgmgrl << EOF >>/dev/null
connect /
disable fast_start failover force;
disable configuration;
exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG "Observer host name - $OBSERVER_HOST"
    
}

#########################################
# Function to do backup and remove cron #
#########################################
REMOVE_CRON()
{
    
    crontab -l > $LOG_DIR/crontab_${ORACLE_SID}.save 2>/dev/null
    
    crontab -r << EOF >/dev/null 2>/dev/null
    SYS
EOF
    
    echo -e "DONE" | tee -a $LOG_FILE

}

###################################
# Function to do shutdown standby #
###################################
SHUTDOWN_STANDBY()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    GET_STANDBY_HOST_NAME $ORACLE_SID
    
    LOG ""
    LOG "Shutting down standby listeners"
    LOG ""
    LOG "========================================================================================="
    $SSH $STDBY_HOST_NAME "/opt/amazon/oracle/admin/bin/oracle-control stop_listeners ${ORACLE_SID}" | tee -a $LOG_FILE
    $SSH $STDBY_HOST_NAME "/opt/amazon/oracle/admin/bin/oracle-control stop_dg_listeners ${ORACLE_SID}" | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    LSNR_COUNT=`$SSH $STDBY_HOST_NAME "ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | wc -l"`
    
    if [ $LSNR_COUNT -ne 0 ]
    then
        LOG "Standby listener shutdown was not successful. Going for kill"
        $SSH $STDBY_HOST_NAME "ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | awk '{print $2}' | xargs kill -9"
        
        LSNR_COUNT=`$SSH $STDBY_HOST_NAME "ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | wc -l"`
        
        if [ $LSNR_COUNT -ne 0 ]
        then
            LOG "Standby listener shutdown was not successful. Unable to kill process"
            LOG "Exiting ..."
            exit;
        else
            LOG "Standby listener shutdown completed successfully"
        fi
    else
        LOG "Standby listener shutdown completed successfully"
    fi
    

    LOG ""
    LOG "Shutting down standby database"
    LOG ""
    LOG "========================================================================================="
    $SSH $STDBY_HOST_NAME "/opt/amazon/oracle/admin/bin/oracle-control stop ${ORACLE_SID}" | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    STDBY_PMON_COUNT=`$SSH $STDBY_HOST_NAME "ps -eaf | grep pmon | grep $ORACLE_SID | grep -v grep | wc -l"`
    
    if [ $STDBY_PMON_COUNT -ne 0 ]
    then
        LOG "Standby database shutdown was not successful. Please check"
        LOG "Exiting ..."
        exit;
    else
        LOG "Standby database shutdown completed successfully"
    fi
    
    HP_TOT=`$SSH $STDBY_HOST_NAME "grep HugePages_Total /proc/meminfo" | awk '{print $2}'`
    HP_FREE=`$SSH $STDBY_HOST_NAME "grep HugePages_Free /proc/meminfo" | awk '{print $2}'`
    
    HP_TOT=`expr $HP_TOT + 0`
    HP_FREE=`expr $HP_FREE + 0`
    
    if [ $HP_FREE -eq $HP_TOT ] 
    then
        LOG "Hugepages are freed after standby shutdown"
    else
        LOG ""
        LOG "Hugepages are not freed after standby shutdown"
        LOG "*** WARNING: you need to run ipcs -a and free hugepages ***"
    fi
    
}


#############################################
# Function to run Amazon Pre-Upgrade script #
#############################################
AMZN_PRE_UPGRADE()
{

    sqlplus -s "/as sysdba" << EOF >> $LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    @$NEW_OH/rdbms/admin/amzn_pre_${PATCH_RELEASE}.sql
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}_2.log
    @$NEW_OH/rdbms/admin/amzn_pre_${PATCH_RELEASE}.sql
    exit;
EOF

    ORA_ERROR=`cat $LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}_2.log | grep ORA- | grep 00600 | wc -l`
    ORA_ERROR=`expr $ORA_ERROR + 0`
    
    if [ $ORA_ERROR -ne 0 ]
    then
        LOG "Some ORA-00600 errors reported in Amazon Pre-Upgrade script"
        LOG "Please check the errors in following log files. Exiting ..."
        LOG "$LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log"
        LOG "$LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}-2.log"
        exit ;
    else
        LOG "Amazon Pre-Upgrade script ran successfully"
        LOG "Log file - $LOG_DIR/amzn-pre-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log"
    fi

}


#########################################
# Function to shutdown primary database #
#########################################
SHUTDOWN_PRIMARY()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Checking if Carnaval outage is taken ............................................................. \c"
    CHECK_CARNAVAL_OUTAGE
    
    LOG ""
    LOG "Shutting down primary listeners"
    LOG ""
    LOG "========================================================================================="
    /opt/amazon/oracle/admin/bin/oracle-control stop_listeners ${ORACLE_SID} | tee -a $LOG_FILE
    /opt/amazon/oracle/admin/bin/oracle-control stop_dg_listeners ${ORACLE_SID} | tee -a $LOG_FILE
    sleep 3;
    LOG "========================================================================================="
    LOG ""
    
    LSNR_COUNT=`ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | wc -l`
    
    if [ $LSNR_COUNT -ne 0 ]
    then
        LOG "Primary listener shutdown was not successful. Going for kill"
        ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | awk '{print $2}' | xargs kill -9
        
        LSNR_COUNT=`ps -eaf | grep tns | grep -v grep  | grep $ORACLE_SID | wc -l`
        
        if [ $LSNR_COUNT -ne 0 ]
        then
            LOG "Primary listener shutdown was not successful. Unable to kill process"
            LOG "Exiting ..."
            exit;
        else
            LOG "Primary listener shutdown completed successfully"
        fi
    else
        LOG "Primary listener shutdown completed successfully"
    fi
    

    LOG ""
    LOG "Shutting down primary database"
    LOG ""
    LOG "========================================================================================="
    /opt/amazon/oracle/admin/bin/oracle-control stop ${ORACLE_SID} | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    PRIM_PMON_COUNT=`ps -eaf | grep pmon | grep $ORACLE_SID | grep -v grep | wc -l`
    
    if [ $PRIM_PMON_COUNT -ne 0 ]
    then
        LOG "Primary database shutdown was not successful. Please check"
        LOG "Exiting ..."
        exit;
    else
        LOG "Primary database shutdown completed successfully"
    fi
    
    HP_TOT=`grep HugePages_Total /proc/meminfo | awk '{print $2}'`
    HP_FREE=`grep HugePages_Free /proc/meminfo | awk '{print $2}'`
    
    HP_TOT=`expr $HP_TOT + 0`
    HP_FREE=`expr $HP_FREE + 0`
    
    if [ $HP_FREE -eq $HP_TOT ] 
    then
        LOG "Hugepages are freed after primary shutdown"
    else
        LOG ""
        LOG "Hugepages are not freed after primary shutdown"
        LOG "*** WARNING: you need to run ipcs -a and free hugepages ***"
    fi
    
    LOG "Recording the last known good pre-upgrade logs - /arch-01/databases/${ORACLE_SID}/pre-upgrade_first_marker"
    
    ls -ltr /arch-01/databases/${ORACLE_SID} | tail >  /arch-01/databases/${ORACLE_SID}/pre-upgrade_first_marker
    
    
    LOG ""
    LOG "Bouncing primary database again"
    LOG ""
    LOG "Starting primary database"
    LOG ""
    
    sqlplus -s "/as sysdba" << EOF | tee -a $LOG_FILE
    startup restrict;
    exit;
EOF

    LOG ""
    LOG "Shutting down primary database"
    LOG ""
    
    sqlplus -s "/as sysdba" << EOF | tee -a $LOG_FILE
    alter system checkpoint;
    alter system switch logfile;
    alter system archive log all;
    shutdown immediate;
    exit;
EOF


    LOG ""
    LOG "Noting the last log sequence # archived - /arch-01/databases/${ORACLE_SID}/pre-upgrade_second_marker"
    
    ls -ltr /arch-01/databases/${ORACLE_SID} | tail >  /arch-01/databases/${ORACLE_SID}/pre-upgrade_second_marker

    HP_TOT=`grep HugePages_Total /proc/meminfo | awk '{print $2}'`
    HP_FREE=`grep HugePages_Free /proc/meminfo | awk '{print $2}'`
    
    HP_TOT=`expr $HP_TOT + 0`
    HP_FREE=`expr $HP_FREE + 0`
    
    if [ $HP_FREE -eq $HP_TOT ] 
    then
        LOG "Hugepages are freed after primary shutdown"
    else
        LOG ""
        LOG "Hugepages are not freed after primary shutdown"
        LOG "*** WARNING: you need to run ipcs -a and free hugepages ***"
    fi
    

}
 

#################################################
# Function to change /etc/oratab to new version #
#################################################
CHANGE_ORATAB()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    TIMEZONE=`grep $ORACLE_SID /etc/oratab | tail -1 | awk -F ":" '{print $4}' | sed "s/ //g"`
    sed "s/^$ORACLE_SID/#$ORACLE_SID/g" /etc/oratab > /tmp/oratab_${TIMESTAMP}
    echo -e "$ORACLE_SID:/opt/app/oracle/product/$DB_UPGRD_VERSION/$PATCH_VERSION:Y:$TIMEZONE" >> /tmp/oratab_${TIMESTAMP}
    cat /tmp/oratab_${TIMESTAMP} > /etc/oratab
    
    LOG ""
    cat /etc/oratab | tee -a $LOG_FILE
    LOG ""
   
}


###############################################################
# Function to generate new init file, spfile and listener.ora #
###############################################################
GENERATE_NEW_INIT()
{
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID >> /dev/null

    /apollo/env/FCDBOraInitConfig/bin/fcdb_ora_init_builder.py --use_oratab --create_spfile --stanza_path=/apollo/env/FCDBOraInitConfig/etc/oracle_stanzas 1>>$LOG_FILE 2>>$LOG_FILE

}


################################################################
# Function to take backups of controlfile and online redo logs #
################################################################
BACKUP_B4_UPGRADE()
{

    LOG "Taking backup of control file and online redo log file before upgrade"
    
    mkdir -p /ctl-01/backups/${ORACLE_SID} 
    mkdir -p /ctl-02/backups/${ORACLE_SID}
    mkdir -p /redo-01-a/backups/${ORACLE_SID}
    mkdir -p /redo-02-a/backups/${ORACLE_SID}
    mkdir -p /redo-03-a/backups/${ORACLE_SID}
    mkdir -p /redo-04-a/backups/${ORACLE_SID}
    
    cp /ctl-01/databases/${ORACLE_SID}/control.ctl /ctl-01/backups/${ORACLE_SID}/control.ctl
    cp /ctl-02/databases/${ORACLE_SID}/control.ctl /ctl-02/backups/${ORACLE_SID}/control.ctl
    
    cp /redo-01-a/databases/${ORACLE_SID}/* /redo-01-a/backups/${ORACLE_SID}/
    cp /redo-02-a/databases/${ORACLE_SID}/* /redo-02-a/backups/${ORACLE_SID}/
    cp /redo-03-a/databases/${ORACLE_SID}/* /redo-03-a/backups/${ORACLE_SID}/
    cp /redo-04-a/databases/${ORACLE_SID}/* /redo-04-a/backups/${ORACLE_SID}/
    
    LOG "Controlfile backup taken at - /ctl-0[1-2]/backups/${ORACLE_SID}"
    LOG "Redolog backup taken at     - /redo-0[1-4]-a/backups/${ORACLE_SID}"
    
}

########################################
# Function to upgrade primary database #
########################################
UPGRADE_PRIMARY()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID >> /dev/null
    
    LOG ""
    BACKUP_B4_UPGRADE
    
    LOG ""
    LOG "Doing startup upgrade for primary"
    LOG ""
    
    sqlplus -s '/ as sysdba' << EOF
    startup upgrade;
    exit;
EOF
    
    LOG ""
    LOG "Starting catupgrd now. You can check the upgrade logs at - $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log"
    LOG ""
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    set echo on pagesize 60 linesize 80
    @?/rdbms/admin/catupgrd.sql
    exit;
EOF

    LOG "catupgrd.sql completed. Starting database in restricted mode and compiling invalid objects"
    LOG ""
    
    sqlplus '/ as sysdba' << EOF >> /dev/null
    startup restrict;
    @?/rdbms/admin/utlrp.sql
    exit;
EOF

    LOG "Invalid objects compiled. Running remaining dbms_stats procedures"
    LOG ""
    
    sqlplus '/ as sysdba' << EOF >> /dev/null
    @?/rdbms/admin/dbmsstat.sql
    @?/rdbms/admin/prvtstas.plb
    @?/rdbms/admin/prvtstai.plb
    @?/rdbms/admin/prvtstat.plb
    exit;
EOF

    LOG "Remaining dbms_stats procedures completed. Checking for errors"
    LOG ""
    
    ERROR_COUNT=`grep -i "ora-"  $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log | grep -iv "DOC>" | grep -iv "rem"  | grep -v "\-\-" | grep ^ORA- | wc -l`
    ERROR_COUNT=`expr $ERROR_COUNT + 0`

    if [ $ERROR_COUNT -ne 0 ]
    then
        LOG "Error found in upgrade log - $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log"
        LOG ""
        grep -i "ora-"  $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log | grep -iv "DOC>" | grep -iv "rem"  | grep -v "\-\-" | grep ^ORA-
        grep -i "ora-"  $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log | grep -iv "DOC>" | grep -iv "rem"  | grep -v "\-\-" | grep ^ORA- >> $LOG_FILE
        LOG ""
        LOG "Please check logs in details"
        LOG ""
        LOG "At this stage, do you want to proceed further with upgrade ? [y/n]: \c"
        read PROCEED_FURTHER
        CONT_UPGRADE="T"
        while [ "$CONT_UPGRADE" = "T" ]
        do
            if [ "$PROCEED_FURTHER" = "y" ] || [ "$PROCEED_FURTHER" = "Y" ]
            then
                LOG ""
                LOG "Proceeding further with upgrade script"
                LOG ""
                CONT_UPGRADE="Y"
            elif [ "$PROCEED_FURTHER" = "n" ] || [ "$PROCEED_FURTHER" = "N" ]
            then
                LOG ""
                LOG "User choose to exit the script"
                LOG ""
                LOG "Exiting ..."
                LOG ""
                CONT_UPGRADE="N"
                exit;
            else
                LOG ""
                LOG "Please provide correct inputs. Do you want to proceed further with upgrade ? [y/n]: \c"
                read PROCEED_FURTHER
            fi
        done
    else
        LOG "Upgrade completed successfully. No error found on log file - $LOG_DIR/catupgrade-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log"
    fi
    
    LOG "Here is the database components status after upgrade"
    LOG ""
    LOG "========================================================================================="
    sqlplus -s '/ as sysdba' << EOF | tee -a $LOG_DIR/utlu${UTILITY_SCRIPT_VERSION}s-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log $LOG_FILE
    @?/rdbms/admin/utlu${UTILITY_SCRIPT_VERSION}s.sql
    exit;
EOF
    LOG "========================================================================================="
    
}


########################################
# Function to run post-upgrade scripts #
########################################
POST_UPGRADE()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Running catuppst script ............................. \c"
    
    sqlplus -s '/ as sysdba' << EOF >> $LOG_DIR/catuppst-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    startup restrict;  
    @?/rdbms/admin/catuppst.sql
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE

    LOG ""
    LOG "Compiling invalid objects ........................... \c"
    
    sqlplus '/ as sysdba' << EOF >> /dev/null
    @?/rdbms/admin/utlrp.sql
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE

    LOG ""
    LOG "Checking all packages and classes are valid ......... \c"
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/invalid_obj-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    SELECT count(*) FROM dba_invalid_objects;
    SELECT distinct object_name FROM dba_invalid_objects;
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE

    LOG ""
    LOG "Checking if all indexes are usable .................. \c"
       
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/index-check-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    select status, count(*) from dba_indexes group by status;
    select status, count(*) from dba_ind_partitions group by status;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Running amazon post-upgrade script .................. \c"
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/amzn_post-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    @?/rdbms/admin/amzn_post_${PATCH_RELEASE}.sql
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Running PSU catbundle ............................... \c"
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/psu-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    @?/rdbms/admin/catbundle.sql psu apply
    @?/rdbms/admin/utlrp
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
}


########################################
# Function to restart primary database #
########################################
RESTART_PRIMARY()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Shutting down primary database"
    LOG ""
    LOG "========================================================================================="
    /opt/amazon/oracle/admin/bin/oracle-control stop ${ORACLE_SID} | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    LOG "Starting up primary database"
    LOG ""
    LOG "========================================================================================="
    /opt/amazon/oracle/admin/bin/oracle-control start ${ORACLE_SID} | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    LOG "Primary database upgrade is complete. Database is now available for use"
}


###########################################
# Function to run misc post-upgrade steps #
###########################################
MISC_POST_UPGRADE()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Gather fixed object stats. This will take some time ........ \c"
    
    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/amzn_post_part2-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    exec dbms_stats.gather_fixed_objects_stats;
    exec dbms_stats.delete_table_stats('SYS','X\$KRBMRST');
    exec dbms_stats.delete_table_stats('SYS','X\$KSFQP');
    exec dbms_stats.delete_table_stats('SYS','X\$KCCRSR');
    exec dbms_stats.lock_table_stats('SYS','X\$KRBMRST');
    exec dbms_stats.lock_table_stats('SYS','X\$KSFQP');
    exec dbms_stats.lock_table_stats('SYS','X\$KCCRSR');
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Increase cache size for sys.audses ......................... \c"

    sqlplus -s '/ as sysdba' << EOF >> /dev/null
    alter sequence sys.audses\$  cache 10000;
    exit
EOF
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Lock MGDSYS account ........................................ \c"
    
    sqlplus -s '/ as sysdba' << EOF >> /dev/null
    alter user mgdsys account lock;
    exit
EOF

    echo -e "DONE" | tee -a $LOG_FILE

    LOG ""
    LOG "Enable cron jobs and restart monitoring .................... \c"
    
    crontab -r << EOF >/dev/null 2>/dev/null
    SYS
EOF
    crontab $LOG_DIR/crontab_${ORACLE_SID}.save 2>/dev/null

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Verify replication, AQ, and jobs are running correctly ..... \c"
    
    PROC_COUNT=`ps -eaf|grep -e cjq -e ora_j | wc -l`
    
    echo -e "DONE" | tee -a $LOG_FILE
        
    if [ $PROC_COUNT -eq 0 ]
    then
        LOG "replication, AQ, and jobs are not running fine. Please check"
    fi
    
    LOG ""
    LOG "Update dbeng user management packages ...................... \c"

    sqlplus '/ as sysdba' << EOF >> $LOG_DIR/db_eng-${ORACLE_SID}-${TIMESTAMP}-${PATCH_RELEASE}.log
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/manage_admin_user.pkg
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/manage_dml_user.pkg
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/kill_blocking_sessions.proc
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/disallowed_datafile_names.tab
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/db_audit_datafile_add.trg
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/log_space_stats.proc
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/create-man_arch_ro-user.sql
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/dbtools_run_as.proc
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/manage_admin_job.pkg
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/create-common-admin-sox-objects.sql
    @/apollo/env/DBAutoToolkit/LegacyUnownedOracleScripts/common/latest_common_all.sql
    exit;
EOF

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Creating required symlinks for dump directories ............ \c"
    
    UNIQ_NAME=`sqlplus -s "/as sysdba" << EOF
    set feedback off verify off heading off;
    select value from v\\$parameter where name = 'db_unique_name';
EOF`

    UNIQ_NAME=`echo $UNIQ_NAME | sed "s/ //g"`
    mv /dumps-01/database/${ORACLE_SID}/bdump /dumps-01/database/${ORACLE_SID}/bdump_old 2>/dev/null
    mv /dumps-01/database/${ORACLE_SID}/udump /dumps-01/database/${ORACLE_SID}/udump_old 2>/dev/null
    mv /opt/app/oracle/admin/${ORACLE_SID}/udump /opt/app/oracle/admin/${ORACLE_SID}/udump_old 2>/dev/null
    mv /opt/app/oracle/admin/${ORACLE_SID}/bdump /opt/app/oracle/admin/${ORACLE_SID}/bdump_old 2>/dev/null
    mv /opt/app/oracle/admin/${ORACLE_SID}/cdump /opt/app/oracle/admin/${ORACLE_SID}/cdump_old 2>/dev/null
    mv /opt/app/oracle/admin/${ORACLE_SID}/adump /opt/app/oracle/admin/${ORACLE_SID}/adump_old 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /dumps-01/database/${ORACLE_SID}/bdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /dumps-01/database/${ORACLE_SID}/udump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /opt/app/oracle/admin/${ORACLE_SID}/udump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /opt/app/oracle/admin/${ORACLE_SID}/bdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /opt/app/oracle/admin/${ORACLE_SID}/cdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/${UNIQ_NAME}/${ORACLE_SID}/trace /opt/app/oracle/admin/${ORACLE_SID}/adump 2>/dev/null

    echo -e "DONE" | tee -a $LOG_FILE    

}

VALIDATE_STANDBY_OH()
{
    
    cat >> /tmp/validate_standby_oh_${TIMESTAMP}.sh << EOF
#! /bin/bash

PATCH_RELEASE="$PATCH_RELEASE"
PATCH_VERSION="$PATCH_VERSION"
DB_UPGRD_VERSION="$DB_UPGRD_VERSION"
ORACLE_SID="$ORACLE_SID"
LOG_FILE="/tmp/validate_standby_oh.log"

STDBY_LOG_FILE=/tmp/validate_standby_oh.log

NEW_OH="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"

NR_SCRIPTS=\`ls \$NEW_OH/rdbms/admin/*sql |wc -l\`
if [ \$NR_SCRIPTS -ge 949 ]
then
    echo -e "CORRECT"
else
    echo -e "WRONG"
    exit;
fi

EOF

    $SCP /tmp/validate_standby_oh_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/validate_standby_oh.sh
    STANDBY_OH_STATUS=`$SSH $STDBY_HOST_NAME  "sh /tmp/validate_standby_oh.sh"`
    
    if [ "$STANDBY_OH_STATUS" != "CORRECT" ]
    then
        LOG ""
        LOG "***WARNING: Oracle home doesn't look ok on standby side, probably a tar failure***"
        LOG "Please download again. Exiting ..."
        LOG ""
        exit;
    else
        LOG ""
        LOG "Oracle Home looks ok on standby"
    fi
    
}

CREATE_INIT_SYMLINK()
{

cat >> /tmp/oh_init_symlink_${TIMESTAMP}.sh << EOF
#! /bin/bash

PATCH_RELEASE="$PATCH_RELEASE"
PATCH_VERSION="$PATCH_VERSION"
DB_UPGRD_VERSION="$DB_UPGRD_VERSION"
ORACLE_SID="$ORACLE_SID"
LOG_FILE="/tmp/validate_standby_oh.log"

STDBY_LOG_FILE=/tmp/oh_init_symlink.log

NEW_OH="/opt/app/oracle/product/${DB_UPGRD_VERSION}/${PATCH_VERSION}"

    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID >> /dev/null
    
    echo -e ""
    echo -e "Creating symlink for init file and password file in new OH"

    ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/init${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
    ln -s /opt/app/oracle/admin/${ORACLE_SID}/pfile/spfile${ORACLE_SID}.ora ${NEW_OH}/dbs 2>/dev/null
    ln -s /opt/app/oracle/admin/${ORACLE_SID}/orapw/orapw${ORACLE_SID} ${NEW_OH}/dbs 2>/dev/null

EOF


    $SCP /tmp/oh_init_symlink_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/oh_init_symlink.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/oh_init_symlink.sh" 
    
}


NO_START_FILE()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    NO_START_STATUS="$1"
    
    if [ "$NO_START_STATUS" = "PUT" ]
    then
        $SSH $STDBY_HOST_NAME  "date > /opt/app/oracle/fc-dba-tools.nostart"
        $SSH $STDBY_HOST_NAME  "date > /opt/app/oracle/fc-dba-adg.nostart"
        
        LOG "No.start file is in place now"
        
    fi
    
    if [ "$NO_START_STATUS" = "REMOVE" ]
    then
        $SSH $STDBY_HOST_NAME  "rm /opt/app/oracle/fc-dba-tools.nostart"
        $SSH $STDBY_HOST_NAME  "rm /opt/app/oracle/fc-dba-adg.nostart"
        
        LOG "No.start file removed"
        
    fi
    
}
    
CHANGE_STANDBY_ORATAB()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    cat > /tmp/change_oratab_${TIMESTAMP}.sh << EOF
#! /bin/bash

TIMESTAMP=$TIMESTAMP
PATCH_RELEASE="$PATCH_RELEASE"
PATCH_VERSION="$PATCH_VERSION"
DB_UPGRD_VERSION="$DB_UPGRD_VERSION"
ORACLE_SID="$ORACLE_SID"
LOGGING_OPTION="$LOGGING_OPTION"
LOG_FILE="/tmp/change_oratab_${TIMESTAMP}.log"


##############################
# Function to enable logging #
##############################
STANDBY_LOG()
{
    if [ "\$LOGGING_OPTION" = "TERMINAL" ]
    then
        echo -e "\$1"                                    ##No Logging
    elif [ "\$LOGGING_OPTION" = "TERMINAL_TZ" ]
    then
        echo -e  \`date -u\` "--> \$1"                     ##No Logging,with timestamp
    elif [ "\$LOGGING_OPTION" = "LOGFILE" ]
    then
        echo -e "\$1" >> \$LOG_FILE                       ##Log Only, No output
    elif [ "\$LOGGING_OPTION" = "LOGFILE_TZ" ]
    then
        echo -e  \`date -u\` "--> \$1" >> \$LOG_FILE        ## log only, no output, with timestamp
    elif [ "\$LOGGING_OPTION" = "BOTH" ]
    then
        echo -e  "\$1" | tee -a \$LOG_FILE                ## show and log
    else
        echo -e  \`date -u\` "--> \$1" | tee -a \$LOG_FILE  ## show and log
    fi

    if [ \$? -ne 0 ]
    then
        echo "error writing to \$LOG_FILE"
        exit 1
    fi
}

    TIMEZONE=\`grep \$ORACLE_SID /etc/oratab | tail -1 | awk -F ":" '{print \$4}' | sed "s/ //g"\`
    sed "s/^\$ORACLE_SID/\#\$ORACLE_SID/g" /etc/oratab > /tmp/oratab_\${TIMESTAMP}
    echo -e "\$ORACLE_SID:/opt/app/oracle/product/\$DB_UPGRD_VERSION/\$PATCH_VERSION:Y:\$TIMEZONE" >> /tmp/oratab_\${TIMESTAMP}
    cat /tmp/oratab_\${TIMESTAMP} > /etc/oratab
    
    STANDBY_LOG ""
    cat /etc/oratab | tee -a \$LOG_FILE
    STANDBY_LOG ""

EOF

    $SCP /tmp/change_oratab_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/change_oratab.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/change_oratab.sh"
    
}


##########################################################################
# Function to generate new init file, spfile and listener.ora on standby #
##########################################################################
GENERATE_NEW_INIT_STANDBY()
{
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    cat > /tmp/generate_init_${TIMESTAMP}.sh << EOF
#! /bin/bash

ORACLE_SID="$ORACLE_SID"
LOG_FILE="/tmp/generate_init_${TIMESTAMP}.log"

cd ~ ; . ./.oraenvamzn
oraenvamzn $ORACLE_SID >> /dev/null

/apollo/env/FCDBOraInitConfig/bin/fcdb_ora_init_builder.py --use_oratab --create_spfile --stanza_path=/apollo/env/FCDBOraInitConfig/etc/oracle_stanzas 1>>\$LOG_FILE 2>>\$LOG_FILE
EOF

    $SCP /tmp/generate_init_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/generate_init.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/generate_init.sh"

}


######################################
# Function to start standby database #
######################################
START_STANDBY_DB()
{
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG ""
    LOG "Starting standby database"
    LOG ""
    LOG "========================================================================================="
    $SSH $STDBY_HOST_NAME "/opt/amazon/oracle/admin/bin/oracle-control start ${ORACLE_SID}" | tee -a $LOG_FILE
    LOG "========================================================================================="
    LOG ""
    
    LOG "Creating required symlinks for dump directories on standby ........................................ \c"
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    cat > /tmp/generate_symlink_${TIMESTAMP}.sh << EOF
#! /bin/bash

    cd ~ ; . ./.oraenvamzn
    oraenvamzn $ORACLE_SID >> /dev/null

    UNIQ_NAME=\`sqlplus -s "/as sysdba" << EOF
    set feedback off verify off heading off;
    select value from v\\\\\$parameter where name = 'db_unique_name';
EOF\`

    UNIQ_NAME=\`echo \$UNIQ_NAME | sed "s/ //g"\`
    mv /dumps-01/database/\${ORACLE_SID}/bdump /dumps-01/database/\${ORACLE_SID}/bdump_old 2>/dev/null
    mv /dumps-01/database/\${ORACLE_SID}/udump /dumps-01/database/\${ORACLE_SID}/udump_old 2>/dev/null
    mv /opt/app/oracle/admin/\${ORACLE_SID}/udump /opt/app/oracle/admin/\${ORACLE_SID}/udump_old 2>/dev/null
    mv /opt/app/oracle/admin/\${ORACLE_SID}/bdump /opt/app/oracle/admin/\${ORACLE_SID}/bdump_old 2>/dev/null
    mv /opt/app/oracle/admin/\${ORACLE_SID}/cdump /opt/app/oracle/admin/\${ORACLE_SID}/cdump_old 2>/dev/null
    mv /opt/app/oracle/admin/\${ORACLE_SID}/adump /opt/app/oracle/admin/\${ORACLE_SID}/adump_old 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /dumps-01/database/\${ORACLE_SID}/bdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /dumps-01/database/\${ORACLE_SID}/udump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /opt/app/oracle/admin/\${ORACLE_SID}/udump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /opt/app/oracle/admin/\${ORACLE_SID}/bdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /opt/app/oracle/admin/\${ORACLE_SID}/cdump 2>/dev/null
    ln -s /dumps-01/diag/rdbms/\${UNIQ_NAME}/\${ORACLE_SID}/trace /opt/app/oracle/admin/\${ORACLE_SID}/adump 2>/dev/null

EOF

    $SCP /tmp/generate_symlink_${TIMESTAMP}.sh $STDBY_HOST_NAME:/tmp/generate_symlink.sh
    $SSH $STDBY_HOST_NAME "sh /tmp/generate_symlink.sh"
    
}


########################################
# Function to upgrade standby database #
########################################
UPGRADE_STANDBY()
{
    
    echo -e "DONE" | tee -a $LOG_FILE
    
    sleep 3
    
    LOG ""
    LOG "Validating new OH on standby side ................................................................. \c"
    
    VALIDATE_STANDBY_OH
    
    sleep 3
    
    LOG ""
    LOG "Creating symlink for init file and password file in new OH on standby ............................. \c"
    
    CREATE_INIT_SYMLINK
    
    sleep 3
    
    LOG ""
    LOG "Putting no.start file in place to prevent READONLY open ........................................... \c"
    
    NO_START_FILE PUT
    
    sleep 3
    
    LOG ""
    LOG "Changing Oracle Home in /etc/oratab on standby to $DB_UPGRD_VERSION ........................................ \c"
    
    CHANGE_STANDBY_ORATAB
    
    sleep 3
    
    LOG ""
    LOG "Generate new init file, spfile and listener.ora file on standby ................................... \c"

    GENERATE_NEW_INIT_STANDBY
    
    sleep 3
    
    LOG ""
    LOG "Start standby database in new oracle home ......................................................... \c"

    START_STANDBY_DB
    
}

#############################################
# Function to enable DG broker configuration#
#############################################
ENABLE_DG_BROKER()
{

    echo -e "DONE" | tee -a $LOG_FILE
    
    LOG "Enabling DG Broker. This will take time"

    sleep 10
    
    dgmgrl << EOF >> $LOG_FILE
    connect /
    enable configuration;
    exit;
EOF

    LOG "DG Broker configuration enabled. Waiting for 10 sec"
    
    sleep 10;
    
    LOG ""
    LOG "========================================================================================="
    LOG ""
    dgmgrl << EOF | tee -a $LOG_FILE
    connect /
    show configuration verbose;
    exit;
EOF
    sleep 1;
    
    LOG ""
    LOG "========================================================================================="
    LOG ""
    
    LOG "Enabling fast-start failover. Waiting for 10 sec"

    sleep 10;
    
    LOG ""
    LOG "========================================================================================="
    LOG ""
    dgmgrl << EOF | tee -a $LOG_FILE
    connect /
    enable fast_start failover;
    exit;
EOF
    LOG ""
    LOG "========================================================================================="
    LOG ""
    LOG "Fast-start failover enabled. Getting the final Status"
    
    sleep 10;
    
    LOG ""
    LOG "========================================================================================="
    LOG ""
    
    dgmgrl << EOF | tee -a $LOG_FILE
    connect /
    show configuration verbose;
    exit;
EOF
    LOG ""
    LOG "========================================================================================="
    LOG ""
    

}



################################################################################
#                               main ()                                        #
################################################################################

LOGGING_OPTION="BOTH"
TIMESTAMP=`date +%d%m%y%H%M%S`
SSH="ssh -q -o  BatchMode=yes -o ConnectTimeout=10  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"
SCP="scp -q -o  BatchMode=yes -o ConnectTimeout=10  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"

if [ $# -lt 2 ]
then
    show_usage
fi

LOG ""
LOG ""
LOG "\t\t############################################################"
LOG "\t\t####     SHELL SCRIPT FOR MAJOR DATABASE UPGRADE        ####"
LOG "\t\t############################################################"
LOG ""

LOG ""
LOG "Please make sure you are running this script in screen. If not please exit and run this in screen"
LOG "Y to countinue, N to exit [Y/N] : \c"
read START_INPUT

LOG ""

if [ "$START_INPUT" != "Y" ] && [ "$START_INPUT" != "y" ]
then
    LOG ""
    LOG "\nExiting ..."
    LOG ""
  exit;
fi

GET_INPUTS $@
VALIDATE_INPUTS
SET_LOGGING
DOWNLOAD

sleep 3

LOG ""
LOG "\t\t##############################################"
LOG "\t\t#### STARTING DATABASE PRE UPGRADE CHECKS ####"
LOG "\t\t##############################################"
LOG ""

PRE_UPGRADE_VALIDATION

if [ "$MODE_TYPE" = "UPGRADE" ]
then

    CONT="T"
    while [ $CONT = "T" ]
    do
        LOG ""
        LOG ""
        LOG ""
        LOG "You are running the script in UPGRADE mode"
        LOG "Please check the above warnings throughly and make sure all the critical warnings are resolved before proceeding"
        LOG ""
        LOG "Do you want to proceed [Y/N] : \c"
        read CONT;

        if [ "$CONT" = "Y" ] || [ "$CONT" = "y" ]
        then
            LOG ""
            LOG "Proceeding with the upgrade now"
        elif [ "$CONT" = "N" ] || [ "$CONT" = "n" ]
        then
            LOG ""
            LOG "Exiting ..."
            LOG ""
            exit;
        else
            CONT="T"
        fi
  done
  
    LOG ""
    LOG "\t\t#########################################"
    LOG "\t\t#### STARTING DATABASE UPGRADE Steps ####"
    LOG "\t\t#########################################"
    LOG ""
    
    if [ "$DB_TYPE" = "production" ]
    then
        sleep 3
    
        LOG ""
        LOG "Checking if Carnaval outage is taken ......................................................... \c"
        
        CHECK_CARNAVAL_OUTAGE
        
        sleep 3
        
        LOG ""
        LOG "Disabling FSF ................................................................................ \c"
        
        DISABLE_FSF
        
    fi
    
    sleep 3
    
    LOG ""
    LOG "Backing up and removing crontab .............................................................. \c"
        
    REMOVE_CRON
    
    if [ "$DB_TYPE" = "production" ]
    then
    
        sleep 3
    
        LOG ""
        LOG "Shutting down standby database ............................................................... \c"
    
        SHUTDOWN_STANDBY
        
    fi
    
    sleep 3
    
    LOG ""
    LOG "Running Amazon Pre-Upgrade script ................................................................ \c"
    
    AMZN_PRE_UPGRADE
    
    sleep 3
    
    LOG ""
    LOG "Shutting down primary database ................................................................... \c"
    
    SHUTDOWN_PRIMARY
    
    sleep 3
    
    LOG ""
    LOG "Changing Oracle Home in /etc/oratab to $DB_UPGRD_VERSION ................................................... \c"
    
    CHANGE_ORATAB
    
    sleep 3
    
    LOG ""
    LOG "Generate new init file, spfile and listener.ora file .............................................. \c"
    
    GENERATE_NEW_INIT
    
    sleep 3
    
    LOG ""
    LOG "Starting to upgrade database to $DB_UPGRD_VERSION .......................................................... \c"
    
    UPGRADE_PRIMARY
    
    sleep 3
    
    LOG ""
    LOG "Starting to post-upgrade scripts .................................................................. \c"
    
    POST_UPGRADE
    
    sleep 3
    
    LOG ""
    LOG "Restarting primary database ....................................................................... \c"
    
    RESTART_PRIMARY
    
    sleep 3
    
    LOG ""
    LOG "Running additional post-upgrade steps ............................................................. \c"
    
    MISC_POST_UPGRADE
    
    LOG ""
    LOG ""
    LOG "\t\t#################################################################"
    LOG "\t\t####     $ORACLE_SID PRIMARY DATABASE UPGRADE IS COMPLETE        "
    LOG "\t\t#################################################################"
    LOG ""

    LOG ""
    LOG "Do you want to continue upgrading standby database for $ORACLE_SID"
    LOG "Y to countinue, N to exit [Y/N] : \c"
    read STDBY_UPGRADE_CONTINUE
    
    LOG ""
    
    if [ "$STDBY_UPGRADE_CONTINUE" != 'Y' ] && [ "$STDBY_UPGRADE_CONTINUE" != 'y' ]
    then
        LOG ""
        LOG "\nExiting ..."
        LOG ""
      exit;
    fi
    
    LOG ""
    LOG "\t\t#################################################"
    LOG "\t\t#### STARTING STANDBY DATABASE UPGRADE Steps ####"
    LOG "\t\t#################################################"
    LOG ""
    
    sleep 3
    
    LOG ""
    LOG "Starting standby database upgrade ................................................................. \c"
    
    UPGRADE_STANDBY
    
    LOG ""
    LOG ""
    LOG "\t\t#################################################################"
    LOG "\t\t####     $ORACLE_SID STANDBY DATABASE UPGRADE IS COMPLETE        "
    LOG "\t\t#################################################################"
    LOG ""
    
    sleep 3
    
    LOG ""
    LOG "Enabling broker configuration and fast-start failover ............................................. \c"
    
    ENABLE_DG_BROKER
    
    sleep 3
    
    LOG ""
    LOG "Remove no.start file to open standby in READONLY ................................................. \c"
    
    NO_START_FILE REMOVE
    
    LOG ""
    LOG ""
    LOG "\t\t#########################################################"
    LOG "\t\t####     $ORACLE_SID DATABASE UPGRADE IS COMPLETE        "
    LOG "\t\t#########################################################"
    LOG ""

fi
