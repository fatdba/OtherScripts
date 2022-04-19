#!/bin/bash

function UpperCase {
local str=$(echo $1 |tr "a-z" "A-Z")
echo "$str"
}


function validate_user {
if [[ "$USER" == "oracle" ]];then
return 0
else
echo
echo "ERROR : This script should be executed by \"oracle\". Exiting..."
echo
exit
fi
}

## Checks for pmon and gives a nod if no DBs are running
function pmon_check {
if [[ $(ps -aef|grep -i ora_pmon|grep -v grep|wc -l) -eq 0 ]]; then
echo
echo -e "${green}You are good to go ahead with the maintenance. If there are any error messages, you can page-scos-dba@, for assistance ${normal}"
else
echo
echo -e "${red}WARNING: DB(s) still appear to be running. Please page-scos-dba@, for assistance${normal}"
fi
exit
}

## Tries 10 times to take an outage on the job_id passed.
function take_outage {
job_id=$1
out_count=0
try_cnt=1
while [[ out_count -eq 0 && try_cnt -le 10 ]]
do
## echo "Trying to take outage for job id : $job_id, iteration : $try_cnt"
job_out=$(/apollo/env/DBEngDatabase/echelon/bin/outage.pl --job_id=$job_id --description='HW Maintenance' --mode=TAKE --notify-level=1 --duration=360 2>&1 )
out_count=$(echo $job_out | grep "Outage taken" | grep -v grep | wc -l)
if [[ out_count -gt 0 ]]; then
return
else 
try_cnt=$((try_cnt+1))
fi
done
echo "${red}ERROR : Cannot take outage in 10 attempts. Please DONOT proceed with the maintenance, and page-scos-dba@ for assistance. ${normal} "
exit
}


# Verify if the argument passed to this function is a standby
function verify_standby {
SID=$1
oraenvamzn ${SID} 1>/dev/null 2>&1
if [[ $? -ne 0 || "$ORACLE_SID" -ne "$SID" ]]; then
echo
echo  "${red}ERROR : Couldn't set the environment using \"oraenvamzn ${SID}\". Make sure $SID is present in /etc/oratab. Please page-scos-dba@ for assistance. ${normaL}"
echo
exit;
fi

tempfile=$(/bin/mktemp)

sqlplus '/ as sysdba' <<EOF 1>$tempfile 2>&1
set lines 1024
select lower(name)||':'||database_role from v\$database;
exit
EOF
grep "ORA-" $tempfile 1>/dev/null 2>&1

if [ $? -eq 0 ]; then
echo
echo "${red}ERROR : Couldn't connect to \"$SID\" on this host. Please *DONOT* proceed with maintenance, and page-scos-dba@ for assistance ${normal}"
echo
exit
fi

grep "${SID}:PRIMARY" $tempfile 1>/dev/null 2>&1

if [ $? -eq 0 ]; then
echo
echo -e "${red}ERROR : This host has PRIMARY instance of \"$SID\". Please DONOT proceed with the maintenance and move the tt back to DBA queue ${normal}"
echo
exit
fi

grep "${SID}:PHYSICAL STANDBY" $tempfile 1>/dev/null 2>&1

if [ $? -ne 0 ]; then
echo -e "${red}ERROR : This doesn't seem to be STANDBY instance of $SID. Please DONOT proceed with the maintenance and move the tt back to DBA queue ${normal}"
exit
fi
}

green=$(tput setaf 2)
red=$(tput setaf 1)
normal=$(tput sgr0)

## Verify if the script is run by oracle, if not exit.
validate_user
source /apollo/env/DBEngDatabase/admin/bin/.oraenvamzn

echo
echo -n "Please enter your Email Alias : "
read alias
echo -n "Please enter the TT number (e.g : 0029613380) : "
read tt_num
##echo "${alias}@ is working on https://tt.amazon.com/${tt_num}" | mail -s "HW Maintenance on $(hostname)" nnaveen@amazon.com -c sreekanc@amazon.com
subject="HW Maintenance on $(hostname)"
from='no-reply@amazon.com'
to_list="nnaveen@amazon.com,sreekanc@amazon.com"
##to_list="scos-dba-core@amazon.com,fba-dba@amazon.com"
cc_list="${alias}@amazon.com"
##cc_list="${alias}@amazon.com"
body="${alias}@ is working on https://tt.amazon.com/${tt_num}"

##MAIL_TXT="Subject: HW Maintenance on $(hostname)\nFrom: sreekanc@amazon.com\nTo: nnaveen@amazon.com\nCc:${alias}@amazon.com,${alias}@amazon.com\n\n${alias}@ is working on https://tt.amazon.com/${tt_num}"  
MAIL_TXT="Subject: $subject\nFrom: $from\nTo: $to_list\nCc:$cc_list\n\n$body"  
echo -e $MAIL_TXT | /usr/sbin/sendmail -t

## Check if oratab is present and readable
if [ ! -r /etc/oratab ]; then
pmon_check
fi

## No SID entries found in /etc/oratab. Check pmon and exit
DBs=$(cat /etc/oratab|egrep -v "^(DEFAULT|test|newhome|#|\*)" | wc -l)
if [ $DBs -eq 0 ];then
pmon_check
fi

##echo
echo "Checking if the host has only Standby databases running on it ... "

for SID in `cat /etc/oratab|egrep -v "^(DEFAULT|test|#|\*)" | cut -d':' -f1`
do
	verify_standby $SID
done 

echo "Taking outages...."

for sid in `cat /etc/oratab|egrep -v "^(DEFAULT|test|newhome|#|\*)" | cut -d':' -f1`
do
SID=$(UpperCase $sid)
OUT=$(/apollo/env/DBAutoToolkit/bin/odin-sqlplus -S -m com.amazon.dbaccess.oracle.credential.eng1ro.db_monitoring_user eng1ro <<EOF 2>&1 
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT JOB_ID FROM MONITORING.DBSYS_AGENT_JOBS_V1 WHERE UPPER(TARGET_NAME)='${SID}' AND ( AGENT_NAME IN ( 'FSFMonitor', 'StandbyMonitor', 'RemoteStandbyMonitor' ) OR UPPER(AGENT_NAME) LIKE '%STANDBY%' ) ;
EXIT;
EOF)

if [[ $? -eq 0 ]]; then
RV=$(echo $OUT | grep "ORA-" | grep -v grep | wc -l)
else
RV=1
fi

if [[ $RV -ne 0 ]]; then
echo $OUT
echo "${red} Something is not right. Please *DONOT* proceed with maintenance, and page-scos-dba@ for assistance ${normal}"
exit
fi

if [ -z "$OUT" ]; then
  echo "${red} No rows returned from database. Something is not right. Please *DONOT* proceed with maintenance, and page-scos-dba@ for assistance ${normal}"
  exit 0
else

for job_id in $OUT
do
	take_outage $job_id
done
fi
done

echo "Shutting down Standby database(s). It can take up to a minute or two. Please wait .. "
for SID in `cat /etc/oratab|egrep -v "^(DEFAULT|test|newhome|#|\*)" | cut -d':' -f1`
do
## echo "Stopping $SID... "
/opt/amazon/oracle/admin/bin/oracle-control stop $SID  1>/dev/null 2>&1
/opt/amazon/oracle/admin/bin/oracle-control stop_dg_listeners $SID  1>/dev/null 2>&1
sleep 5
done

pmon_check

