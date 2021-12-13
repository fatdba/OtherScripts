#!/usr/bin/env python
import cx_Oracle
import os, sys
from optparse import OptionParser

OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

rcodes = {0: 'OK', 1: 'WARNING', 2: 'CRITICAL', 3: 'UNKNOWN'}

rc = UNKNOWN

def qry( qstr ):
    cursor = conn.cursor()
    cursor.execute(qstr)
    #res=''.join(str(cursor.fetchone()))
    res=cursor.fetchone()
    cursor.close()
    return res

#Getting and checking command line arguments
parser = OptionParser()
parser.add_option("-w", "--warning", dest="warn", default=60,
                  help="set warning threshold percent (0..100)")
parser.add_option("-c", "--critical", dest="crit", default=90,
                  help="set critical threshold percent (0..100)")
parser.add_option("-e", "--event", dest="event",
                  help="name of wait event to monitor")
parser.add_option("-i", "--instance", dest="inst",
                  help="name of the instance to monitor")

(options, args) = parser.parse_args()
option_dict = vars(options)

inst=option_dict['inst']
event=option_dict['event']

if event is None:
    print "Please specify an event name with -e or --event"
    sys.exit(UNKNOWN)

try:
    warn=float(option_dict['warn'])
    crit=float(option_dict['crit'])
except:
    print "Warning and critical threshold should be numbers!"
    sys.exit(UNKNOWN)

if warn > crit:
    print "Warning threshold level should be lower than critical threshold!"
    sys.exit(UNKNOWN)
     

#Checking ORACLE_SID
if inst:
    os.environ["ORACLE_SID"] = inst
elif os.environ.has_key("ORACLE_SID"):
    inst = os.environ["ORACLE_SID"]
else:
    print "ORACLE_SID is not set, use the -i switch to set instance name!"
    sys.exit(UNKNOWN)


#Trying to connect
try:
    conn = cx_Oracle.Connection(mode = cx_Oracle.SYSDBA)
except:
    print "Could not connect to " + inst + ". Error message:"
    
    for err in sys.exc_info():
        print err
    
    exit(UNKNOWN) 

vers = conn.version

cursor = conn.cursor()
cursor.execute('SELECT instance_name FROM v$instance')
dbname=''.join(cursor.fetchone())
cursor.close()

print "Connected to Instance " + dbname + " Version: " + vers

#Check for AWR snapshots since instance startup, if there are less than 2 Snapshots after startup: skip check
qstartup = """select count(*) from dba_hist_snapshot
        where to_char(STARTUP_TIME, 'DD-MM-YYYY HH24:MI') = (
	        select to_char(STARTUP_TIME, 'DD-MM-YYYY HH24:MI') from v$instance)"""

snapcount = qry(qstartup)[0]
if snapcount < 2:
    print "Less than 2 snapshots, probably instance was restarted recently or AWR snapshots are disabled"
    sys.exit(UNKNOWN)

#Look for wait event in DBA_HIST_SYSTEM_EVENT
qwtime="""with old_snap as (
    select event_id, total_waits,TIME_WAITED_MICRO, snap_id
    from DBA_HIST_SYSTEM_EVENT
     where snap_id = (
      select snap_id from DBA_HIST_SNAPSHOT
      where end_interval_time= (
        select max(end_interval_time)
        from DBA_HIST_SNAPSHOT
        where end_interval_time not in (
          select max(end_interval_time) from DBA_HIST_SNAPSHOT)
        )
      )
      and dbid = (select dbid from v$database)
    )
    select (s1.TIME_WAITED_MICRO-s2.TIME_WAITED_MICRO)/1000/1000 total_wait
    from DBA_HIST_SYSTEM_EVENT s1, old_snap s2
    where s1.snap_id = (
      select snap_id from dba_hist_snapshot
      where end_interval_time= (
        select max(end_interval_time) from DBA_HIST_SNAPSHOT))
    and s1.event_id=s2.event_id
    and lower(s1.event_name)=lower('""" + event + """')
    and s1.dbid = (select dbid from v$database)"""

try:
    wtime = round(qry(qwtime)[0],2)
except:
    wtime = None

#Look for wait event in dba_hist_sys_time_model
if wtime is None:
    qwtime="""with old_snap as (
    select STAT_ID,VALUE from dba_hist_sys_time_model
     where snap_id = (
      select snap_id from DBA_HIST_SNAPSHOT
      where end_interval_time= (
        select max(end_interval_time)
        from DBA_HIST_SNAPSHOT
        where end_interval_time not in (
          select max(end_interval_time) from DBA_HIST_SNAPSHOT)
        )
      )
      and dbid = (select dbid from v$database)
    )
    select  (s1.VALUE-s2.VALUE)/1000/1000 ela_Waits 
    from dba_hist_sys_time_model s1, old_snap s2
    where s1.snap_id = (
      select snap_id from dba_hist_snapshot
      where end_interval_time= (
        select max(end_interval_time) from DBA_HIST_SNAPSHOT))
    and s1.STAT_ID=s2.STAT_ID
    and lower(s1.STAT_NAME)=lower('""" + event + """')
    and s1.dbid = (select dbid from v$database)"""

try:
    wtime = round(qry(qwtime)[0],2)
except:
    print "Wait Event " + event + " not found"
    sys.exit(UNKNOWN)


print "Wait time for " + event + ": " + str(wtime) + " sec"

#Getting elapsed time between last two Snapshots
qtim = """SELECT EXTRACT(DAY FROM end_interval_time - begin_interval_time) * 86400
     + EXTRACT( HOUR   FROM end_interval_time - begin_interval_time ) *  3600
     + EXTRACT( MINUTE FROM end_interval_time - begin_interval_time ) *    60
     + EXTRACT( SECOND FROM end_interval_time - begin_interval_time )
     from   DBA_HIST_SNAPSHOT
             where end_interval_time= (
          select max(end_interval_time) from DBA_HIST_SNAPSHOT)"""

ela=qry(qtim)[0]
print "Elapsed Time between the last 2 snapshots: " + str(round(ela)) + " sec"

#DB Time between last two Snapshots
qdbtim = """with old_snap as (
      select value, stat_id, stat_name from dba_hist_sys_time_model
      where snap_id = (
        select snap_id from DBA_HIST_SNAPSHOT
        where end_interval_time= (
          select max(end_interval_time)
          from DBA_HIST_SNAPSHOT
          where end_interval_time not in (
            select max(end_interval_time) from DBA_HIST_SNAPSHOT)
            )
          )
      and stat_name = 'DB time')
      select (s1.value-s2.value)/1000/1000 dbtime
      from dba_hist_sys_time_model s1, old_snap s2
      where s1.snap_id = (
        select snap_id from dba_hist_snapshot
        where end_interval_time= (
          select max(end_interval_time) from DBA_HIST_SNAPSHOT))
        and s1.stat_id=s2.stat_id
        and s1.stat_name = 'DB time'"""

dbtime = float(qry(qdbtim)[0])
print "DB Time between the last 2 snapshots: " + str(round(dbtime,3)) + " sec"

#if dbtime is less than half of elapsed time, then elapsed time will be considered 
if dbtime * 2 > ela:
    time = dbtime
else:
    time = ela

waitperc = round(wtime / time *100, 2)

if waitperc < warn:
    rc = OK

if waitperc >= warn:
    rc = WARNING

if waitperc > crit:
    rc = CRITICAL

print "WaitCheck - " + rcodes[rc] + "! " + event + " wait percentage: " + str(waitperc)

sys.exit(rc)
