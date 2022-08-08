set termout off
set linesize 90
set pagesize 20
ttitle center 'PDHC1.4 -  A Quick Health Check' skip 2
btitle center '<span style="background-color:#38761d;color:#ffffff;border:1px solid black;">PART - 1</span>'
set markup html on spool on entmap off

spool DB_Detail_status.html
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(instance_name, 17) current_instance FROM v$instance;
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set linesize 400 pagesize 400
SET TERMOUT ON;


PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT----- Script: Healthcheck.sql (pdhc.sql)
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.3 (Date: 15-07-2022)
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Database under Observation                                  |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
select s.NAME,s.DB_UNIQUE_NAME AS UNQ_NAME,TO_CHAR(d.STARTUP_TIME, 'DD-MM-YY HH24:MI:SS') AS STARTTIME,s.OPEN_MODE,d.INSTANCE_ROLE, s.LOG_MODE,
to_char(s.current_scn) as SCN,s.DATABASE_ROLE,s.FLASHBACK_ON, d.VERSION,d.LOGINS from v$database s, v$instance d where s.name=UPPER(d.instance_name);


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Database under Observation                                  |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

WITH
rac AS (SELECT /*+  MATERIALIZE NO_MERGE  */ COUNT(*) instances, CASE COUNT(*) WHEN 1 THEN 'Single-instance' ELSE COUNT(*)||'-node RAC cluster' END db_type
FROM gv$instance),
mem AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) target FROM gv$system_parameter2 WHERE name = 'memory_target'),
sga AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) target FROM gv$system_parameter2 WHERE name = 'sga_target'),
pga AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) target FROM gv$system_parameter2 WHERE name = 'pga_aggregate_target'),
db_block AS (SELECT /*+  MATERIALIZE NO_MERGE  */ value bytes FROM v$system_parameter2 WHERE name = 'db_block_size'),
db AS (SELECT /*+  MATERIALIZE NO_MERGE  */ name, platform_name FROM v$database),
inst AS (SELECT /*+  MATERIALIZE NO_MERGE  */ host_name, version db_version FROM v$instance),
data AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(bytes) bytes, COUNT(*) files, COUNT(DISTINCT ts#) tablespaces FROM v$datafile),
temp AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(bytes) bytes FROM v$tempfile),
log AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(bytes) * MAX(members) bytes FROM v$log),
control AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(block_size * file_size_blks) bytes FROM v$controlfile),
 cell AS (SELECT /*+  MATERIALIZE NO_MERGE  */ COUNT(DISTINCT cell_name) cnt FROM v$cell_state),
core AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) cnt FROM gv$osstat WHERE stat_name = 'NUM_CPU_CORES'),
cpu AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) cnt FROM gv$osstat WHERE stat_name = 'NUM_CPUS'),
pmem AS (SELECT /*+  MATERIALIZE NO_MERGE  */ SUM(value) bytes FROM gv$osstat WHERE stat_name = 'PHYSICAL_MEMORY_BYTES')
SELECT /*+  NO_MERGE  */ /* 1a.1 */
       'Database name:' system_item, db.name system_value FROM db
 UNION ALL
SELECT 'Oracle Database version:', inst.db_version FROM inst
 UNION ALL
SELECT 'Database block size:', TRIM(TO_CHAR(db_block.bytes / POWER(2,10), '90'))||' KB' FROM db_block
 UNION ALL
SELECT 'Database size:', TRIM(TO_CHAR(ROUND((data.bytes + temp.bytes + log.bytes + control.bytes) / POWER(10,12), 3), '999,999,990.000'))||' TB'
  FROM db, data, temp, log, control
 UNION ALL
SELECT 'Datafiles:', data.files||' (on '||data.tablespaces||' tablespaces)' FROM data
 UNION ALL
SELECT 'Database configuration:', rac.db_type FROM rac
 UNION ALL
SELECT 'Database memory:',
CASE WHEN mem.target > 0 THEN 'MEMORY '||TRIM(TO_CHAR(ROUND(mem.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN sga.target > 0 THEN 'SGA '   ||TRIM(TO_CHAR(ROUND(sga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN pga.target > 0 THEN 'PGA '   ||TRIM(TO_CHAR(ROUND(pga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN mem.target > 0 THEN 'AMM' ELSE CASE WHEN sga.target > 0 THEN 'ASMM' ELSE 'MANUAL' END END
  FROM mem, sga, pga
 UNION ALL
 SELECT 'Hardware:', CASE WHEN cell.cnt > 0 THEN 'Engineered System '||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%5675%' THEN 'X2-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2690%' THEN 'X3-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2697%' THEN 'X4-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2699%' THEN 'X5-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8870%' THEN 'X3-8 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8895%' THEN 'X4-8 or X5-8 ' END||
 'with '||cell.cnt||' storage servers'
 ELSE 'Unknown' END FROM cell
  UNION ALL
SELECT 'Processor:', 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' FROM DUAL
 UNION ALL
SELECT 'Physical CPUs:', core.cnt||' cores'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, core
 UNION ALL
SELECT 'Oracle CPUs:', cpu.cnt||' CPUs (threads)'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, cpu
 UNION ALL
SELECT 'Physical RAM:', TRIM(TO_CHAR(ROUND(pmem.bytes / POWER(2,30), 1), '999,990.0'))||' GB'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM
 rac, pmem
 UNION ALL
SELECT 'Operating system:', db.platform_name FROM db;



prompt**=====================================================================================================**
prompt**                                **Check Database component status**
prompt**=====================================================================================================**

set line 200;
set pagesize 9999;
col COMP_ID format a15;
col COMP_NAME format a35;

select COMP_ID,COMP_NAME,STATUS, VERSION, modified from dba_registry;



prompt**=====================================================================================================**
prompt**                                :       Contents of DB Registry History  :
prompt**=====================================================================================================**

SET LINESIZE 200
COLUMN action_time FORMAT A20
COLUMN action FORMAT A20
COLUMN namespace FORMAT A20
COLUMN version FORMAT A10
COLUMN comments FORMAT A30
COLUMN bundle_series FORMAT A10

SELECT TO_CHAR(action_time, 'DD-MON-YYYY HH24:MI:SS') AS action_time,
       action,
       namespace,
       version,
       id,
       comments,
       bundle_series
FROM   sys.registry$history
ORDER by action_time;




prompt**=================================================================================================================================**
prompt**                                            **   LISTENER Status   **
prompt**=================================================================================================================================**

show parameter listener

PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Standby Gap                                                 |
PROMPT | This is a RAC aware script                                             |
PROMPT | Description: This script identifies gap in STBY replication if any     |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
select to_char(sysdate,'mm-dd-yyyy hh24:mi:ss') "Current Time" from dual;
SELECT DB_NAME, APPLIED_TIME, LOG_ARCHIVED-LOG_APPLIED LOG_GAP ,
(case when ((APPLIED_TIME is not null and (LOG_ARCHIVED-LOG_APPLIED) is null) or
(APPLIED_TIME is null and (LOG_ARCHIVED-LOG_APPLIED) is not null) or
((LOG_ARCHIVED-LOG_APPLIED) > 5))
then 'Error! Log Gap is '
else 'OK!'
end) Status
FROM
(
SELECT INSTANCE_NAME DB_NAME
FROM GV$INSTANCE
where INST_ID = 1
),
(
SELECT MAX(SEQUENCE#) LOG_ARCHIVED
FROM V$ARCHIVED_LOG WHERE DEST_ID=1 AND ARCHIVED='YES' and THREAD#=1
),
(
SELECT MAX(SEQUENCE#) LOG_APPLIED
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' and THREAD#=1
),
(
SELECT TO_CHAR(MAX(COMPLETION_TIME),'DD-MON/HH24:MI') APPLIED_TIME
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' and THREAD#=1
)
UNION
SELECT DB_NAME, APPLIED_TIME, LOG_ARCHIVED-LOG_APPLIED LOG_GAP,
(case when ((APPLIED_TIME is not null and (LOG_ARCHIVED-LOG_APPLIED) is null) or
(APPLIED_TIME is null and (LOG_ARCHIVED-LOG_APPLIED) is not null) or
((LOG_ARCHIVED-LOG_APPLIED) > 5))
then 'Error! Log Gap is '
else 'OK!'
end) Status
from (
SELECT INSTANCE_NAME DB_NAME
FROM GV$INSTANCE
where INST_ID = 2
),
(
SELECT MAX(SEQUENCE#) LOG_ARCHIVED
FROM V$ARCHIVED_LOG WHERE DEST_ID=1 AND ARCHIVED='YES' and THREAD#=2
),
(
SELECT MAX(SEQUENCE#) LOG_APPLIED
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' and THREAD#=2
),
(
SELECT TO_CHAR(MAX(COMPLETION_TIME),'DD-MON/HH24:MI') APPLIED_TIME
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' and THREAD#=2
);


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : RMAN BACKUP DETAILS FOR LAST 7 DAY                          |
PROMPT | This is a RAC aware script                                             |
PROMPT | Description: This section shows details on RMAN backups                |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

col cf for 9,999
col df for 9,999
col elapsed_seconds heading "ELAPSED|SECONDS"
col i0 for 9,999
col i1 for 9,999
col l for 9,999
col output_mbytes for 9,999,999 heading "OUTPUT|MBYTES"
col session_recid for 999999 heading "SESSION|RECID"
col session_stamp for 99999999999 heading "SESSION|STAMP"
col status for a10 trunc
col time_taken_display for a10 heading "TIME|TAKEN"
col output_instance for 9999 heading "OUT|INST"
select
  j.session_recid, j.session_stamp,
  to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
  to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
  (j.output_bytes/1024/1024) output_mbytes, j.status, j.input_type,
  decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday',
                                     3, 'Tuesday', 4, 'Wednesday',
                                     5, 'Thursday', 6, 'Friday',
                                     7, 'Saturday') dow,
  j.elapsed_seconds, j.time_taken_display,
  x.cf, x.df, x.i0, x.i1, x.l,
  ro.inst_id output_instance
from V$RMAN_BACKUP_JOB_DETAILS j
  left outer join (select
                     d.session_recid, d.session_stamp,
                     sum(case when d.controlfile_included = 'YES' then d.pieces else 0 end) CF,
                     sum(case when d.controlfile_included = 'NO'
                               and d.backup_type||d.incremental_level = 'D' then d.pieces else 0 end) DF,
                     sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
                     sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
                     sum(case when d.backup_type = 'L' then d.pieces else 0 end) L
                   from
                     V$BACKUP_SET_DETAILS d
                     join V$BACKUP_SET s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
                   where s.input_file_scan_only = 'NO'
                   group by d.session_recid, d.session_stamp) x
    on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
  left outer join (select o.session_recid, o.session_stamp, min(inst_id) inst_id
                   from GV$RMAN_OUTPUT o
                   group by o.session_recid, o.session_stamp)
    ro on ro.session_recid = j.session_recid and ro.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-8
order by j.start_time;


PROMPT +------------------------------------------------------------------------+
PROMPT | FRA Usage details                                                      |
PROMPT | Desc: FRA Usage                                                   |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
SELECT NAME,
       (SPACE_LIMIT / 1024 / 1024 / 1024) SPACE_LIMIT_GB,
         ((SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE) / 1024 / 1024 / 1024) AS SPACE_AVAILABLE_GB,
       ROUND((SPACE_USED - SPACE_RECLAIMABLE) / SPACE_LIMIT * 100, 1) AS PERCENT_FULL
  FROM V$RECOVERY_FILE_DEST;
select * from v$flash_recovery_area_usage;


PROMPT +------------------------------------------------------------------------+
PROMPT | Tablespace stats    |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
SELECT /* + RULE */  df.tablespace_name "Tablespace",
       df.bytes / (1024 * 1024) "Size (Mb)",
       SUM(fs.bytes) / (1024 * 1024) "Free (Mb)",
       Nvl(Round(SUM(fs.bytes) * 100 / df.bytes),1) "% Free",
       Round((df.bytes - SUM(fs.bytes)) * 100 / df.bytes) "% Used"
  FROM dba_free_space fs,
       (SELECT tablespace_name,SUM(bytes) bytes
          FROM dba_data_files
         GROUP BY tablespace_name) df
 WHERE fs.tablespace_name (+)  = df.tablespace_name
 GROUP BY df.tablespace_name,df.bytes
UNION ALL
SELECT /* + RULE */ df.tablespace_name tspace,
       fs.bytes / (1024 * 1024),
       SUM(df.bytes_free) / (1024 * 1024),
       Nvl(Round((SUM(fs.bytes) - df.bytes_used) * 100 / fs.bytes), 1),
       Round((SUM(fs.bytes) - df.bytes_free) * 100 / fs.bytes)
  FROM dba_temp_files fs,
       (SELECT tablespace_name,bytes_free,bytes_used
          FROM v$temp_space_header
         GROUP BY tablespace_name,bytes_free,bytes_used) df
 WHERE fs.tablespace_name (+)  = df.tablespace_name
 GROUP BY df.tablespace_name,fs.bytes,df.bytes_free,df.bytes_used
 ORDER BY 4 DESC;

PROMPT +------------------------------------------------------------------------+
PROMPT | ASM Usage stats                                                        |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
SET VERIFY    off
COLUMN group_name             FORMAT a20           HEAD 'Disk Group|Name'
COLUMN sector_size            FORMAT 99,999        HEAD 'Sector|Size'
COLUMN block_size             FORMAT 99,999        HEAD 'Block|Size'
COLUMN allocation_unit_size   FORMAT 999,999,999   HEAD 'Allocation|Unit Size'
COLUMN state                  FORMAT a11           HEAD 'State'
COLUMN type                   FORMAT a6            HEAD 'Type'
COLUMN total_mb               FORMAT 999,999,999   HEAD 'Total Size (MB)'
COLUMN used_mb                FORMAT 999,999,999   HEAD 'Used Size (MB)'
COLUMN pct_used               FORMAT 999.99        HEAD 'Pct. Used'

break on report on disk_group_name skip 1
compute sum label "Grand Total: " of total_mb used_mb on report

SELECT
    name                                     group_name
  , sector_size                              sector_size
  , block_size                               block_size
  , allocation_unit_size                     allocation_unit_size
  , state                                    state
  , type                                     type
  , total_mb                                 total_mb
  , (total_mb - free_mb)                     used_mb
  , ROUND((1- (free_mb / total_mb))*100, 2)  pct_used
FROM
    v$asm_diskgroup
ORDER BY
    name
/

prompt**====================================================================================================================================**
prompt**                                **  Check SGA Utilization and Other Memory Allocation      **
prompt**====================================================================================================================================**
col COMPONENT format a26
select component,
current_size/1024/1024 "CURRENT_MB",
min_size/1024/1024 "MIN_MB",
user_specified_size/1024/1024 "USER_SPEC_MB",
last_oper_type "TYPE"
from v$sga_dynamic_components
/

SELECT ROUND (used.bytes / 1024 / 1024 / 1024, 2) sga_used_mb,
       ROUND (free.bytes / 1024 / 1024 / 1024, 2) sga_free_mb,
       ROUND (tot.bytes / 1024 / 1024 / 1024, 2)  sga_total_mb
  FROM (SELECT SUM (bytes) bytes
          FROM v$sgastat
         WHERE name != 'free memory') used,
       (SELECT SUM (bytes) bytes
          FROM v$sgastat
         WHERE name = 'free memory') free,
       (SELECT SUM (bytes) bytes FROM v$sgastat) tot;

PROMPT +------------------------------------------------------------------------+
PROMPT | Running Jobs                                                           |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
SELECT
       *
  FROM dba_jobs_running
 ORDER BY
       job;

--PROMPT +------------------------------------------------------------------------+
--PROMPT | DR Standby database status                                                          |
--PROMPT | Instance : &current_instance                                           |
--PROMPT +------------------------------------------------------------------------|
--Col APPLIED_TIME format a20
-- Col destination format a20
--Col Status format a20
--SELECT DB_NAME,destination,  APPLIED_TIME, LOG_APPLIED,LOG_ARCHIVED,
--(
--  CASE
--    WHEN ((APPLIED_TIME            IS NOT NULL    AND (LOG_ARCHIVED-LOG_APPLIED) IS NULL)
--  OR (APPLIED_TIME               IS NULL    AND (LOG_ARCHIVED-LOG_APPLIED) IS NOT NULL)
--  OR ((LOG_ARCHIVED-LOG_APPLIED)  > 1))
--  THEN 'Error! Log Gap is '
--    ELSE 'OK!'
--  END) Status,
-- LOG_ARCHIVED-LOG_APPLIED LOG_GAP
--FROM
--( SELECT INSTANCE_NAME DB_NAME FROM GV$INSTANCE WHERE INST_ID = 1 ),
-- (SELECT MAX(SEQUENCE#) LOG_ARCHIVED   FROM V$ARCHIVED_LOG    WHERE DEST_ID=1 ),
-- (select applied_seq# as LOG_APPLIED,destination as destination  from v$archive_dest_status WHERE DEST_ID=3 ),
--(SELECT TO_CHAR(MAX(COMPLETION_TIME),'DD-MON/HH24:MI') APPLIED_TIME  FROM V$ARCHIVED_LOG  WHERE DEST_ID=1 );



prompt**===================================================================================================================================**
prompt**                            **  SYSAUX tablespace occupant information.  **
prompt**===================================================================================================================================**


select occupant_desc, space_usage_kbytes/1024 MB from v$sysaux_occupants where space_usage_kbytes > 0 order by space_usage_kbytes;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : LONG OPS                                                    |
PROMPT | This is RAC aware script                                               |
PROMPT | Description: This view displays the status of various operations that  |
PROMPT | run for longer than 6 seconds (in absolute time). These operations     |
PROMPT | currently include many backup and recovery functions, statistics gather|
prompt | , and query execution, and more operations are added for every OracleRE|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set lines 120
cle bre
col sid form 99999
col start_time head "Start|Time" form a12 trunc
col opname head "Operation" form a12 trunc
col target head "Object" form a30 trunc
col totalwork head "Total|Work" form 9999999999 trunc
col Sofar head "Sofar" form 9999999999 trunc
col elamin head "Elapsed|Time|(Mins)" form 99999999 trunc
col tre head "Time|Remain|(Mins)" form 999999999 trunc

select sid,serial#,to_char(start_time,'dd-mon:hh24:mi') start_time,
          opname,target,totalwork,sofar,(elapsed_Seconds/60) elamin,
          time_remaining tre
 from v$session_longops
 where totalwork <> SOFAR
 order by 9 desc;
/


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : IN-FLIGHT TRANSACTION                                       |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: This output gives a glimpse of what all running/waiting in DB    |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set linesize 400 pagesize 400
select x.inst_id,x.sid
,x.serial#
,x.username
,x.sql_id
,plan_hash_value
,sqlarea.DISK_READS
,sqlarea.BUFFER_GETS
,sqlarea.ROWS_PROCESSED
,x.event
,x.osuser
,x.status
,x.BLOCKING_SESSION_STATUS
,x.BLOCKING_INSTANCE
,x.BLOCKING_SESSION
,x.process
,x.machine
,x.OSUSER
,x.program
,x.module
,x.action
,TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime
,x.LAST_CALL_ET
--,x.BLOCKING_SESSION_STATUS
,x.SECONDS_IN_WAIT
,x.state
,sql_text,
ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
 || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
 || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09'))    RUNNING_SINCE
from   gv$sqlarea sqlarea
,gv$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    sql_text not like '%select x.inst_id,x.sid ,x.serial# ,x.username ,x.sql_id ,plan_hash_value ,sqlarea.DISK_READS%'
and    x.status='ACTIVE'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by RUNNING_SINCE desc;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Archive generation per hour basis                           |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: This will give an idea about any spike in redo activity or DMLs  |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
set linesize 140
set pagesize 1000
col ARCHIVED format a8
col ins    format 99  heading "DB"
col member format a80
col status format a12
col archive_date format a20
col member format a60
col type   format a10
col group#  format 99999999
col min_archive_interval format a20
col max_archive_interval format a20
col h00 heading "H00" format  a3
col h01 heading "H01" format  a3
col h02 heading "H02" format  a3
col h03 heading "H03" format  a3
col h04 heading "H04" format  a3
col h05 heading "H05" format  a3
col h06 heading "H06" format  a3
col h07 heading "H07" format  a3
col h08 heading "H08" format  a3
col h09 heading "H09" format  a3
col h10 heading "H10" format  a3
col h11 heading "H11" format  a3
col h12 heading "H12" format  a3
col h13 heading "H13" format  a3
col h14 heading "H14" format  a3
col h15 heading "H15" format  a3
col h16 heading "H16" format  a3
col h17 heading "H17" format  a3
col h18 heading "H18" format  a3
col h19 heading "H19" format  a3
col h20 heading "H20" format  a3
col h21 heading "H21" format  a3
col h22 heading "H22" format  a3
col h23 heading "H23" format  a3
col total format a6
col date format a10

select * from v$logfile order by group#;
select * from v$log order by SEQUENCE#;

select max( sequence#) last_sequence, max(completion_time) completion_time, max(block_size) block_size from v$archived_log ;

SELECT instance ins,
       log_date "DATE" ,
       lpad(to_char(NVL( COUNT( * ) , 0 )),6,' ') Total,
       lpad(to_char(NVL( SUM( decode( log_hour , '00' , 1 ) ) , 0 )),3,' ') h00 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '01' , 1 ) ) , 0 )),3,' ') h01 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '02' , 1 ) ) , 0 )),3,' ') h02 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '03' , 1 ) ) , 0 )),3,' ') h03 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '04' , 1 ) ) , 0 )),3,' ') h04 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '05' , 1 ) ) , 0 )),3,' ') h05 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '06' , 1 ) ) , 0 )),3,' ') h06 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '07' , 1 ) ) , 0 )),3,' ') h07 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '08' , 1 ) ) , 0 )),3,' ') h08 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '09' , 1 ) ) , 0 )),3,' ') h09 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '10' , 1 ) ) , 0 )),3,' ') h10 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '11' , 1 ) ) , 0 )),3,' ') h11 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '12' , 1 ) ) , 0 )),3,' ') h12 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '13' , 1 ) ) , 0 )),3,' ') h13 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '14' , 1 ) ) , 0 )),3,' ') h14 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '15' , 1 ) ) , 0 )),3,' ') h15 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '16' , 1 ) ) , 0 )),3,' ') h16 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '17' , 1 ) ) , 0 )),3,' ') h17 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '18' , 1 ) ) , 0 )),3,' ') h18 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '19' , 1 ) ) , 0 )),3,' ') h19 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '20' , 1 ) ) , 0 )),3,' ') h20 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '21' , 1 ) ) , 0 )),3,' ') h21 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '22' , 1 ) ) , 0 )),3,' ') h22 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '23' , 1 ) ) , 0 )),3,' ') h23
FROM   (
        SELECT thread# INSTANCE ,
               TO_CHAR( first_time , 'YYYY-MM-DD' ) log_date ,
               TO_CHAR( first_time , 'hh24' ) log_hour
        FROM   v$log_history
       )
GROUP  BY
       instance,log_date
ORDER  BY
       log_date ;

select trunc(min(completion_time - first_time))||'  Day  '||
       to_char(trunc(sysdate,'dd') + min(completion_time - first_time),'hh24:mm:ss')||chr(10) min_archive_interval,
       trunc(max(completion_time - first_time))||'  Day  '||
       to_char(trunc(sysdate,'dd') + max(completion_time - first_time),'hh24:mm:ss')||chr(10) max_archive_interval
from gv$archived_log
where sequence# <> ( select max(sequence#) from gv$archived_log ) ;

set feedback on





PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : SESSION DETAILS                                             |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Shows details about all sessions and their states active, inactiv|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set linesize 400 pagesize 400
select resource_name, current_utilization, max_utilization, limit_value, inst_id
    from gv$resource_limit
    where resource_name in ('sessions', 'processes');


select count(s.status) INACTIVE_SESSIONS
from gv$session s, gv$process p
where
p.addr=s.paddr and
s.status='INACTIVE';


select count(s.status) "INACTIVE SESSIONS > 3HOURS "
from gv$session s, gv$process p
where
p.addr=s.paddr and
s.last_call_et > 10800 and
s.status='INACTIVE';



select count(s.status) ACTIVE_SESSIONS
from gv$session s, gv$process p
where
p.addr=s.paddr and
s.status='ACTIVE';


select s.program,count(s.program) Inactive_Sessions_from_1Hour
from gv$session s,gv$process p
where     p.addr=s.paddr  AND
s.status='INACTIVE'
and s.last_call_et > (10800)
group by s.program
order by 2 desc;


set linesize 400 pagesize 400
col INST_ID for 99
col spid for a10
set linesize 150
col PROGRAM for a10
col action format a10
col logon_time format a16
col module format a13
col cli_process format a7
col cli_mach for a15
col status format a10
col username format a10
col last_call_et_Hrs for 9999.99
col sql_hash_value for 9999999999999
col username for a10
set linesize 152
set pagesize 80
col "Last SQL" for a60
col elapsed_time for 999999999999

select p.spid, s.sid,s.serial#,s.last_call_et/3600 last_call_et_3Hrs ,s.status,s.action,s.module,s.program,t.disk_reads,lpad(t.sql_text,30) "Last SQL"
from gv$session s, gv$sqlarea t,gv$process p
where s.sql_address =t.address and
s.sql_hash_value =t.hash_value and
p.addr=s.paddr and
s.status='INACTIVE'
and s.last_call_et > (10800)
order by last_call_et;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Sequence exhaustion for more than 90 percent                |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Shows details about all sequences used more than 90 percent      |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

SELECT
       ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) percent_used, /* latest change */
       s.*
from dba_sequences s
where
   s.sequence_owner not in ('ANONYMOUS','APEX_030200','APEX_040000','APEX_SSO','APPQOSSYS','CTXSYS','DBSNMP','DIP','EXFSYS','FLOWS_FILES','MDSYS','OLAPSYS','
ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS','OUTLN','OWBSYS')
and s.sequence_owner not in ('SI_INFORMTN_SCHEMA','SQLTXADMIN','SQLTXPLAIN','SYS','SYSMAN','SYSTEM','TRCANLZR','WMSYS','XDB','XS$NULL','PERFSTAT','STDBYPERF'
,'MGDSYS','OJVMSYS')
and s.max_value > 0
and ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) > 90
order by
ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) DESC, /* latest change */
s.sequence_owner, s.sequence_name;




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : ORA errors reported in alert log of databases, SYSDATE-1    |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Shows all alert log ora errors and log files with locations      |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

select TO_CHAR(A.ORIGINATING_TIMESTAMP, 'dd.mm.yyyy hh24:mi:ss') MESSAGE_TIME
,inst_id, message_text
,host_id
,inst_id
,adr_home
from v$DIAG_ALERT_EXT A
where A.ORIGINATING_TIMESTAMP > sysdate-1
and component_id='rdbms'
and message_text like '%ORA-%'
order by 1 desc;





PROMPT +##############################################################################################################################################
PROMPT +##############################################################################################################################################
PROMPT +#############################################################################################################################################
PROMPT +################################################################## PART - 2 ##################################################################
PROMPT +##############################################################################################################################################
PROMPT +##############################################################################################################################################
ttitle center 'PDHC1.4 -  A Quick Health Check --- PART 2' skip 2
btitle center '<span style="background-color:#c90421;color:#ffffff;border:1px solid black;">PART - 2</span>'


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Current waits and counts                                    |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: This script shows what all sessions waits currently   their count|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

select event, state, inst_id, count(*) from gv$session_wait group by event, state, inst_id order by 4 desc;

set numwidth 10
column event format a25 tru
select inst_id, event, time_waited, total_waits, total_timeouts
from (select inst_id, event, time_waited, total_waits, total_timeouts
from gv$system_event where event not in ('rdbms ipc message','smon timer',
'pmon timer', 'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
order by time_waited desc)
where rownum < 11
order by time_waited desc;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Load Profile of any database                                |
PROMPT | This is not RAC aware script                                           |
PROMPT | Description: This section contains same stats what you will see anytime|
PROMPT | in AWR of database. Few of the imp sections are                        |
PROMPT | DB Block Changes Per Txn, Average Active Sessions, Executions Per Sec  |
PROMPT | User Calls Per Sec, Physical Writes Per Sec, Physical Reads Per Txn etc|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

SELECT
    metric_name, inst_id
  , ROUND(value,2) w_metric_value
  , metric_unit
FROM
    gv$sysmetric
WHERE
    metric_name IN (
                                'Average Active Sessions'
                        , 'Average Synchronous Single-Block Read Latency'
                        , 'CPU Usage Per Sec'
                        , 'Background CPU Usage Per Sec'
                        , 'DB Block Changes Per Txn'
                        , 'Executions Per Sec'
                        , 'Host CPU Usage Per Sec'
                        , 'I/O Megabytes per Second'
                        , 'I/O Requests per Second'
                        , 'Logical Reads Per Txn'
                        , 'Logons Per Sec'
                        , 'Network Traffic Volume Per Sec'
                        , 'Physical Reads Per Sec'
                        , 'Physical Reads Per Txn'
                        , 'Physical Writes Per Sec'
                        , 'Redo Generated Per Sec'
                        , 'Redo Generated Per Txn'
                        , 'Response Time Per Txn'
                        , 'SQL Service Response Time'
                        , 'Total Parse Count Per Txn'
                        , 'User Calls Per Sec'
                        , 'User Transaction Per Sec'
)
AND group_id = 2 -- get last 60 sec metrics
ORDER BY
    metric_name, inst_id
/




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Undo usage report                                           |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: This shows details about all undo rollback segments, best for 01555|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

SET LINESIZE 200

COLUMN username FORMAT A15

SELECT s.inst_id,
       s.username,
       s.sid,
       s.serial#,
       t.used_ublk,
       t.used_urec,
       rs.segment_name,
       r.rssize,
       r.status
FROM   gv$transaction t,
       gv$session s,
       gv$rollstat r,
       dba_rollback_segs rs
WHERE  s.saddr = t.ses_addr
AND    s.inst_id = t.inst_id
AND    t.xidusn = r.usn
AND    t.inst_id = r.inst_id
AND    rs.segment_id = t.xidusn
ORDER BY t.used_ublk DESC;


SET SERVEROUTPUT ON
SET LINES 600
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI:SS';

DECLARE
    v_analyse_start_time    DATE := SYSDATE - 7;
    v_analyse_end_time      DATE := SYSDATE;
    v_cur_dt                DATE;
    v_undo_info_ret         BOOLEAN;
    v_cur_undo_mb           NUMBER;
    v_undo_tbs_name         VARCHAR2(100);
    v_undo_tbs_size         NUMBER;
    v_undo_autoext          BOOLEAN;
    v_undo_retention        NUMBER(20);
    v_undo_guarantee        BOOLEAN;
    v_instance_number       NUMBER;
    v_undo_advisor_advice   VARCHAR2(100);
    v_undo_health_ret       NUMBER;
    v_problem               VARCHAR2(1000);
    v_recommendation        VARCHAR2(1000);
    v_rationale             VARCHAR2(1000);
    v_retention             NUMBER;
    v_utbsize               NUMBER;
    v_best_retention        NUMBER;
    v_longest_query         NUMBER;
    v_required_retention    NUMBER;
BEGIN
    select sysdate into v_cur_dt from dual;
    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('- Undo Analysis started at : ' || v_cur_dt || ' -');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');

    v_undo_info_ret := DBMS_UNDO_ADV.UNDO_INFO(v_undo_tbs_name, v_undo_tbs_size, v_undo_autoext, v_undo_retention, v_undo_guarantee);
    select sum(bytes)/1024/1024 into v_cur_undo_mb from dba_data_files where tablespace_name = v_undo_tbs_name;

    DBMS_OUTPUT.PUT_LINE('NOTE:The following analysis is based upon the database workload during the period -');
    DBMS_OUTPUT.PUT_LINE('Begin Time : ' || v_analyse_start_time);
    DBMS_OUTPUT.PUT_LINE('End Time   : ' || v_analyse_end_time);

    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Current Undo Configuration');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace',55) || ' : ' || v_undo_tbs_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace size (datafile size now) ',55) || ' : ' || v_cur_undo_mb || 'M');
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace size (consider autoextend) ',55) || ' : ' || v_undo_tbs_size || 'M');
    IF V_UNDO_AUTOEXT THEN
        DBMS_OUTPUT.PUT_LINE(RPAD('AUTOEXTEND for undo tablespace is',55) || ' : ON');
    ELSE
        DBMS_OUTPUT.PUT_LINE(RPAD('AUTOEXTEND for undo tablespace is',55) || ' : OFF');
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo retention',55) || ' : ' || v_undo_retention);

    IF v_undo_guarantee THEN
        DBMS_OUTPUT.PUT_LINE(RPAD('UNDO GUARANTEE is set to',55) || ' : TRUE');
    ELSE
        dbms_output.put_line(RPAD('UNDO GUARANTEE is set to',55) || ' : FALSE');
    END IF;
    DBMS_OUTPUT.PUT_LINE(CHR(9));

    SELECT instance_number INTO v_instance_number FROM V$INSTANCE;

    DBMS_OUTPUT.PUT_LINE('Undo Advisor Summary');
    DBMS_OUTPUT.PUT_LINE('---------------------------');

    v_undo_advisor_advice := dbms_undo_adv.undo_advisor(v_analyse_start_time, v_analyse_end_time, v_instance_number);
    DBMS_OUTPUT.PUT_LINE(v_undo_advisor_advice);

    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Undo Space Recommendation');
    DBMS_OUTPUT.PUT_LINE('-------------------------');

    v_undo_health_ret := dbms_undo_adv.undo_health(v_analyse_start_time, v_analyse_end_time, v_problem, v_recommendation, v_rationale, v_retention, v_utbsize
);
    IF v_undo_health_ret > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Minimum Recommendation           : ' || v_recommendation);
        DBMS_OUTPUT.PUT_LINE('Rationale                        : ' || v_rationale);
        DBMS_OUTPUT.PUT_LINE('Recommended Undo Tablespace Size : ' || v_utbsize || 'M');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Allocated undo space is sufficient for the current workload.');
    END IF;

    SELECT dbms_undo_adv.best_possible_retention(v_analyse_start_time, v_analyse_end_time) into v_best_retention FROM dual;
    SELECT dbms_undo_adv.longest_query(v_analyse_start_time, v_analyse_end_time) into v_longest_query FROM dual;
    SELECT dbms_undo_adv.required_retention(v_analyse_start_time, v_analyse_end_time) into v_required_retention FROM dual;

    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Retention Recommendation');
    DBMS_OUTPUT.PUT_LINE('------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('The best possible retention with current configuration is ',60) || ' : ' || v_best_retention || ' Seconds');
    DBMS_OUTPUT.PUT_LINE(RPAD('The longest running query ran for ',60) || ' : ' || v_longest_query || ' Seconds');
    DBMS_OUTPUT.PUT_LINE(RPAD('The undo retention required to avoid errors is ',60) || ' : ' || v_required_retention || ' Seconds');

END;
/




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Who is doing what with TEMP segments or tablespace          |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Look for cols usage_mb and sql_id and sql_text and username      |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
SELECT sysdate "TIME_STAMP", vsu.username, vs.sid, vp.spid, vs.sql_id, vst.sql_text, vsu.tablespace,
       sum_blocks*dt.block_size/1024/1024 usage_mb
   FROM
   (
           SELECT username, sqladdr, sqlhash, sql_id, tablespace, session_addr,
-- sum(blocks)*8192/1024/1024 "USAGE_MB",
                sum(blocks) sum_blocks
           FROM gv$sort_usage
           HAVING SUM(blocks)> 1000
           GROUP BY username, sqladdr, sqlhash, sql_id, tablespace, session_addr
   ) "VSU",
   gv$sqltext vst,
   gv$session vs,
   gv$process vp,
   dba_tablespaces dt
WHERE vs.sql_id = vst.sql_id
-- AND vsu.sqladdr = vst.address
-- AND vsu.sqlhash = vst.hash_value
   AND vsu.session_addr = vs.saddr
   AND vs.paddr = vp.addr
   AND vst.piece = 0
   AND dt.tablespace_name = vsu.tablespace
order by usage_mb;



SET TERMOUT OFF;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(instance_name, 17) current_instance FROM v$instance;
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set linesize 400 pagesize 400
SET TERMOUT ON;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Temp or Sort segment usage                                  |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Queies consuming huge sort area from last 2 hrs and more than 5GB|    |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
select sql_id,max(TEMP_SPACE_ALLOCATED)/(1024*1024*1024) gig
from DBA_HIST_ACTIVE_SESS_HISTORY
where
sample_time > sysdate - (120/1440) and
TEMP_SPACE_ALLOCATED > (5*1024*1024*1024)
group by sql_id order by gig desc;


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Sesions Waiting                                             |
PROMPT | Desc: The entries that are shown at the top are the sessions that have |
PROMPT | waited the longest amount of time that are waiting for non-idle wait   |
PROMPT | events (event column).
PROMPT | This is RAC aware script                                               |
PROMPT +------------------------------------------------------------------------+


set numwidth 15
set heading on
column state format a7 tru
column event format a25 tru
column last_sql format a40 tru
select sw.inst_id, sa.sql_id,sw.sid, sw.state, sw.event, sw.seconds_in_wait seconds,
sw.p1, sw.p2, sw.p3, sa.sql_text last_sql
from gv$session_wait sw, gv$session s, gv$sqlarea sa
where sw.event not in
('rdbms ipc message','smon timer','pmon timer',
'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
and sw.seconds_in_wait > 0
and (sw.inst_id = s.inst_id and sw.sid = s.sid)
and (s.inst_id = sa.inst_id and s.sql_address = sa.address)
order by seconds desc;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top 5 SQL statements in the past one hour                   |
PROMPT | This is RAC aware script                                               |
PROMPT | Description: Overall top SQLs on the basis on time waited in DB        |
PROMPT | This is sorted on the basis of the time each one of them spend in DB   |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

select * from (
select active_session_history.sql_id,
 dba_users.username,
 sqlarea.sql_text,
sum(active_session_history.wait_time +
active_session_history.time_waited) ttl_wait_time
from gv$active_session_history active_session_history,
gv$sqlarea sqlarea,
 dba_users
where
active_session_history.sample_time between sysdate -  1/24  and sysdate
  and active_session_history.sql_id = sqlarea.sql_id
and active_session_history.user_id = dba_users.user_id
 group by active_session_history.sql_id,sqlarea.sql_text, dba_users.username
 order by 4 desc )
where rownum < 6;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top10 SQL statements present in cache (elapsed time)        |
PROMPT | This is RAC aware script                                               |
PROMPT | Description: Overall top SQLs on the basis on elapsed time spend in DB |
PROMPT | Look out for ways to reduce elapsed time, check if its waiting on some-|
PROMPT | thing or other issues behind the high run time of query.
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

select rownum as rank, a.*
from (
select elapsed_Time/1000000 elapsed_time,
executions, inst_id,
elapsed_Time / (1000000 * decode(executions,0,1, executions) ) etime_per_exec,
buffer_gets,
disk_reads,
cpu_time
hash_value, sql_id,
sql_text
from  gv$sqlarea
where elapsed_time/1000000 > 5
order by etime_per_exec desc) a
where rownum < 11
/




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top 5  SQL statements present in cache (PIOs or Disk Reads) |
PROMPT | This output is sorted on the basis of TOTAL DISK READS                 |
PROMPT | This is RAC aware script                                               |
PROMPT | Description: Overall top SQLs on the basis on Physical Reads or D-Reads|
PROMPT | Most probably queries coming under this section are suffering from Full|
PROMPT | Table Scans (FTS) or DB File Scattered Read (User IO) Waits. Look for  |
PROMPT | options if Index can help. Run SQL Tuning Advisories or do manual check|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

select rownum as rank, a.*
from (
select disk_reads, inst_id,
executions,
disk_reads / decode(executions,0,1, executions) reads_per_exec,
hash_value,
sql_id,
sql_text
from  gv$sqlarea
where disk_reads > 10000
order by reads_per_exec desc) a
where rownum < 11
/


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top 10 SQL statements present in cache (LIOs or BufferReads)|
PROMPT | Sorted on the basis of TOTAL BUFFER GETS                               |
PROMPT | This is RAC aware script                                               |
PROMPT | Description: Overall top SQLs on the basis on Memmory Reads or L-Reads |
PROMPT | Most probably queries coming under this section are the ones doing FTS |
PROMPT | and might be waiting for any latch/Mutex to gain access on block. Pleas|
PROMPT | check the value of column 'gets_per_exec' that means average memory    |
PROMPT | reads per execution.                                                   |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+


select rownum as rank, a.*
from (
select buffer_gets,  inst_id,
executions,
buffer_gets/ decode(executions,0,1, executions) gets_per_exec,
hash_value,
sql_id,
sql_text
from  gv$sqlarea
where buffer_gets > 50000
order by gets_per_exec desc) a
where rownum < 11
/

PROMPT +----------------------------------------------------------------------------------------------+
PROMPT | Report   : SQLs with the highest concurrency waits (possible latch / mutex-related)          |
PROMPT | This is RAC aware script                                                                     |
PROMPT | Description: Queries sorted basis on concurrency events i.e. Latching or Mutex waits         |
PROMPT | look out for Conc Time (ms) and  SQL Conc Time% columns.
PROMPT | Instance : &current_instance                                                                 |
PROMPT +----------------------------------------------------------------------------------------------+


column sql_text format a40 heading "SQL Text"
column con_time_ms format 99,999,999 heading "Conc Time (ms)"
column con_time_pct format 999.99 heading "SQL Conc | Time%"
column pct_of_con_time format 999.99 heading "% Tot | ConcTime"

WITH sql_conc_waits AS
    (SELECT sql_id, SUBSTR (sql_text, 1, 80) sql_text, sql_id, inst_id,
            concurrency_wait_time / 1000 con_time_ms,
            elapsed_time,
            ROUND (concurrency_wait_Time * 100 /
                elapsed_time, 2) con_time_pct,
            ROUND (concurrency_wait_Time * 100 /
                SUM (concurrency_wait_Time) OVER (), 2) pct_of_con_time,
            RANK () OVER (ORDER BY concurrency_wait_Time DESC)
       FROM gv$sql
      WHERE elapsed_time> 0)
SELECT sql_text, con_time_ms, con_time_pct, inst_id,
       pct_of_con_time
FROM sql_conc_waits
WHERE rownum <= 10
;



PROMPT +---------------------------------------------------------------------------------------+
PROMPT | Report   : Current CPU Intensive statements (current 15)                              |
PROMPT | This is RAC aware script                                                              |
PROMPT | Instance : &current_instance                                                          |
PROMPT | Description: This gives you expensive SQLs which are in run right now and consuming   |
PROMPT | huge CPU seconds. Check column CPU_USAGE_SECONDS and investigate using SQLID          |
PROMPT +---------------------------------------------------------------------------------------+

set pages 1000
set lines 1000
col OSPID for a06
col SID for 99999
col SERIAL# for 999999
col SQL_ID for a14
col USERNAME for a15
col PROGRAM for a20
col MODULE for a18
col OSUSER for a10
col MACHINE for a25
select * from (
select p.spid "ospid",
(se.SID),ss.serial#,ss.inst_id,ss.SQL_ID,ss.username,ss.program,ss.module,ss.osuser,ss.MACHINE,ss.status,
se.VALUE/100 cpu_usage_seconds
from
gv$session ss,
gv$sesstat se,
gv$statname sn,
gv$process p
where
se.STATISTIC# = sn.STATISTIC#
and
NAME like '%CPU used by this session%'
and
se.SID = ss.SID
and ss.username !='SYS' and
ss.status='ACTIVE'
and ss.username is not null
and ss.paddr=p.addr and value > 0
order by se.VALUE desc)
where rownum <16;


PROMPT +---------------------------------------------------------------------------------------+
PROMPT | Report   : Top 10 CPU itensive queries based on total cpu seconds spend               |
PROMPT | This is RAC aware script                                                              |
PROMPT | Instance : &current_instance                                                          |
PROMPT +---------------------------------------------------------------------------------------+

col SQL_TEXT for a99
select rownum as rank, a.*
from (
select cpu_time/1000000 cpu_time, inst_id,
executions,
buffer_gets,
disk_reads,
cpu_time
hash_value,
sql_id,
sql_text
from  gv$sqlarea
where cpu_time/1000000 > 5
order by cpu_time desc) a
where rownum < 11
/


PROMPT +---------------------------------------------------------------------------------------+
PROMPT | Report   : Top 10 CPU itensive queries based on total cpu seconds spend per execution |
PROMPT | This is RAC aware script                                                              |
PROMPT | Instance : &current_instance                                                          |
PROMPT +---------------------------------------------------------------------------------------+

select rownum as rank, a.*
from (
select cpu_time/1000000 cpu_time, inst_id,
executions,
cpu_time / (1000000 * decode(executions,0,1, executions)) ctime_per_exec,
buffer_gets,
disk_reads,
cpu_time
hash_value,
sql_id,
sql_text
from  gv$sqlarea
where cpu_time/1000000 > 5
order by ctime_per_exec desc) a
where rownum < 11
/






PROMPT +----------------------------------------------------------------------------------------------+
PROMPT | Report   : IO wait breakdown in the datbase during runtime of this script                    |
PROMPT | This is RAC aware script                                                                     |
PROMPT | Desc: Look for last three cols, TOTAL_WAITS, TIME_WAITED_SECONDS and PCT. Rank matters here  |
PROMPT | Instance : &current_instance                                                                 |
PROMPT +----------------------------------------------------------------------------------------------+

column wait_type format a35
column lock_name format a12
column time_waited_seconds format 999,999.99
column pct format 99.99
set linesize 400 pagesize 400

WITH system_event AS
    (SELECT CASE
              WHEN event LIKE  'direct path% temp' THEN
                 'direct path read / write temp'
              WHEN event LIKE 'direct path%' THEN
                 'direct path read / write non-temp'
              WHEN wait_class = 'User I / O' THEN
                  event
              ELSE wait_class
              END AS wait_type, e. *
            FROM gv$system_event e)
SELECT wait_type, SUM (total_waits) total_waits,
       ROUND (SUM (time_waited_micro) / 1000000, 2) time_waited_seconds,
       ROUND (SUM (time_waited_micro)
             * 100
             / SUM (SUM (time_waited_micro)) OVER (), 2)
          pct
FROM (SELECT wait_type, event, total_waits, time_waited_micro
      FROM system_event e
      UNION
      SELECT 'CPU', stat_name, NULL, VALUE
      FROM gv$sys_time_model
      WHERE stat_name IN ('background cpu time', 'CPU DB')) l
WHERE wait_type <> 'Idle'
GROUP BY wait_type
ORDER BY 4 DESC
/




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Table Level Locking session details                         |
PROMPT | This is RAC aware script and will show all instances of TM Level RLCon |
PROMPT | Desc: This output shows what all active sessions waiting on TM Content.|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set linesize 400 pagesize 400
select x.inst_id,x.sid
,x.serial#
,x.username
,x.sql_id
,x.event
,x.osuser
,x.status
,x.process
,x.machine
,x.OSUSER
,x.program
,x.module
,x.action
,TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime
,x.LAST_CALL_ET
,x.SECONDS_IN_WAIT
,x.state
,sql_text,
ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
 || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
 || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09'))    RUNT
from   gv$sqlarea sqlarea
,gv$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    x.status='ACTIVE'
and x.event like '%TM - contention%'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by runt desc;




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Row Level Locking session details                           |                  |
PROMPT | This is RAC aware script and will show all instances of TX Level RLCon |
PROMPT | Desc: This output shows what all active sessions waiting on TX Content.|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set linesize 400 pagesize 400
select x.inst_id,x.sid
,x.serial#
,x.username
,x.sql_id
,x.event
,x.osuser
,x.status
,x.process
,x.machine
,x.OSUSER
,x.program
,x.module
,x.action
,TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime
,x.LAST_CALL_ET
,x.SECONDS_IN_WAIT
,x.state
,sql_text,
ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
 || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
 || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09'))    RUNT
from   gv$sqlarea sqlarea
,gv$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    x.status='ACTIVE'
and x.event like '%row lock contention%'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by runt desc;


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Blocking Tree                                               |
PROMPT | This output helps a DBA to identify all parent lockers in a pedigree   |
PROMPT | Desc: Creates a ASCII tree or graph to show parent and child lockers   |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col LOCK_TREE for a10
with lk as (select blocking_instance||'.'||blocking_session blocker, inst_id||'.'||sid waiter
 from gv$session where blocking_instance is not null and blocking_session is not null and username is not null)
 select lpad(' ',2*(level-1))||waiter lock_tree from
 (select * from lk
 union all
 select distinct 'root', blocker from lk
 where blocker not in (select waiter from lk))
 connect by prior waiter=blocker start with blocker='root';





PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : TX Row Lock Contention Details                              |
PROMPT | This report or result shows some extra and  imp piece of data          |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col LOCK_MODE for a10
col OBJECT_NAME for a30
col SID_SERIAL for a19
col OSUSER for a9
col USER_STATUS for a14

SELECT DECODE (l.BLOCK, 0, 'Waiting', 'Blocking ->') user_status
,CHR (39) || s.SID || ',' || s.serial# || CHR (39) sid_serial
,(SELECT instance_name FROM gv$instance WHERE inst_id = l.inst_id)
conn_instance
,s.SID
,s.PROGRAM
,s.inst_id
,s.osuser
,s.machine
,DECODE (l.TYPE,'RT', 'Redo Log Buffer','TD', 'Dictionary'
,'TM', 'DML','TS', 'Temp Segments','TX', 'Transaction'
,'UL', 'User','RW', 'Row Wait',l.TYPE) lock_type
--,id1
--,id2
,DECODE (l.lmode,0, 'None',1, 'Null',2, 'Row Share',3, 'Row Excl.'
,4, 'Share',5, 'S/Row Excl.',6, 'Exclusive'
,LTRIM (TO_CHAR (lmode, '990'))) lock_mode
,ctime
--,DECODE(l.BLOCK, 0, 'Not Blocking', 1, 'Blocking', 2, 'Global') lock_status
,object_name
FROM
   gv$lock l
JOIN
   gv$session s
ON (l.inst_id = s.inst_id
AND l.SID = s.SID)
JOIN gv$locked_object o
ON (o.inst_id = s.inst_id
AND s.SID = o.session_id)
JOIN dba_objects d
ON (d.object_id = o.object_id)
WHERE (l.id1, l.id2, l.TYPE) IN (SELECT id1, id2, TYPE
FROM gv$lock
WHERE request > 0)
ORDER BY id1, id2, ctime DESC;





PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : What is blocking what .....                                 |
PROMPT | This is that old and popular simple output that everybody knows        |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
select l1.sid, ' IS BLOCKING ', l2.sid
from gv$lock l1, gv$lock l2 where l1.block =1 and l2.request > 0
and l1.id1=l2.id1
and l1.id2=l2.id2;




PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Some more on locking                                        |
PROMPT | Little more formatted data that abive output                           |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col BLOCKING_STATUS for a120
select s2.inst_id,s1.username || '@' || s1.machine
 || ' ( SID=' || s1.sid || ' )  is blocking '
 || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
  from gv$lock l1, gv$session s1, gv$lock l2, gv$session s2
  where s1.sid=l1.sid and s2.sid=l2.sid and s1.inst_id=l1.inst_id and s2.inst_id=l2.inst_id
  and l1.BLOCK=1 and l2.request > 0
  and l1.id1 = l2.id1
  and l2.id2 = l2.id2
order by s1.inst_id;


PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : More on locks to read and analyze                           |
PROMPT | Thidata you can use for your deep drill down                         |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col BLOCKER for a8
col WAITER for a10
col LMODE for a14
col REQUEST for a15

SELECT sid,
                                TYPE,
                                DECODE( block, 0, 'NO', 'YES' ) BLOCKER,
        DECODE( request, 0, 'NO', 'YES' ) WAITER,
        decode(LMODE,1,'    ',2,'RS',3,'RX',4,'S',5,'SRX',6,'X','NONE') lmode,
                                 decode(REQUEST,1,'    ',2,'RS',3,'RX',4,'S',5,'SRX',6,'X','NONE') request,
                                TRUNC(CTIME/60) MIN ,
                                ID1,
                                ID2,
        block
                        FROM  gv$lock
      where request > 0 OR block =1;








PROMPT +---------------------------------------------------------------------------------------+
PROMPT | Report   : Database Objects Experienced the Most Number of Waits in the Past One Hour |
PROMPT | This is RAC aware script                                                              |
PROMPT | Description: Look for EVENT its getting and last column TTL_WAIT_TIME, time waited   |
PROMPT | Instance : &current_instance                                                          |
PROMPT +---------------------------------------------------------------------------------------+

col event format a40
col object_name format a40

select * from
(
  select dba_objects.object_name,
 dba_objects.object_type,
active_session_history.event,
 sum(active_session_history.wait_time +
  active_session_history.time_waited) ttl_wait_time
from gv$active_session_history active_session_history,
    dba_objects
 where
active_session_history.sample_time between sysdate - 1/24 and sysdate
and active_session_history.current_obj# = dba_objects.object_id
 group by dba_objects.object_name, dba_objects.object_type, active_session_history.event
 order by 4 desc)
where rownum < 6;



PROMPT +----------------------------------------------------------------------------------------------+
PROMPT | Report   : RAC Lost blocks report plus GC specific events                                    |
PROMPT | This is RAC aware script                                                                     |
PROMPT | Desc: This shows all RAC specific metrics like block lost, blocks served and recieved        |
PROMPT | Instance : &current_instance                                                                 |
PROMPT +----------------------------------------------------------------------------------------------+

col name format a30

SELECT name, SUM (VALUE) value
FROM gv$sysstat
WHERE name LIKE 'gc% lost'
      OR name LIKE 'gc% received'
      OR name LIKE 'gc% served'
GROUP BY name
ORDER BY name;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Wait Chains in RAC systems                                  |
PROMPT | Desc: This will show you the top 100 wait chain processes at any given |
PROMPT | point.You should look for number of waiters and blocking process       |
PROMPT | This is RAC aware script and only works with 11g and up versions       |
PROMPT +------------------------------------------------------------------------+

set pages 1000
set lines 120
column w_proc format a50 tru
column instance format a20 tru
column inst format a28 tru
column wait_event format a50 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column Seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
SELECT *
FROM (SELECT 'Current Process: '||osid W_PROC, 'SID '||i.instance_name INSTANCE,
'INST #: '||instance INST,'Blocking Process: '||decode(blocker_osid,null,'<none>',blocker_osid)||
' from Instance '||blocker_instance BLOCKER_PROC,'Number of waiters: '||num_waiters waiters,
'Wait Event: ' ||wait_event_text wait_event, 'P1: '||p1 p1, 'P2: '||p2 p2, 'P3: '||p3 p3,
'Seconds in Wait: '||in_wait_secs Seconds, 'Seconds Since Last Wait: '||time_since_last_wait_secs sincelw,
'Wait Chain: '||chain_id ||': '||chain_signature chain_signature,'Blocking Wait Chain: '||decode(blocker_chain_id,null,
'<none>',blocker_chain_id) blocker_chain
FROM v$wait_chains wc,
v$instance i
WHERE wc.instance = i.instance_number (+)
AND ( num_waiters > 0
OR ( blocker_osid IS NOT NULL
AND in_wait_secs > 10 ) )
ORDER BY chain_id,
num_waiters DESC)
WHERE ROWNUM < 101;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Latch statistics 1                                          |
PROMPT | This is RAC aware script                                               |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+


select inst_id, name latch_name,
round((gets-misses)/decode(gets,0,1,gets),3) hit_ratio,
round(sleeps/decode(misses,0,1,misses),3) "SLEEPS/MISS"
from gv$latch
where round((gets-misses)/decode(gets,0,1,gets),3) < .99
and gets != 0
order by round((gets-misses)/decode(gets,0,1,gets),3);



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Latch status                                                |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Please look for cols WAIT_TIME_SECONDS and WAIT_TIME             |
PROMPT |     Critical if both of the numbers are high                           |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

col NAME for a50
select v.*
from
  (select
      name, inst_id,
      gets,
      misses,
      round(misses*100/(gets+1), 3) misses_gets_pct,
      spin_gets,
      sleep1,
      wait_time,
      round(wait_time/1000000) wait_time_seconds,
   rank () over
     (order by wait_time desc) as misses_rank
   from
      gv$latch
   where gets + misses + sleep1 + wait_time > 0
   order by
      wait_time desc
  ) v
where
   misses_rank <= 10;





PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : No Willing to wait mode latch stats                         |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: This section is for those latches who requests in immediate_gets |
PROMPT | mode. Look for SLEEPSMISS column which is last one in results                  |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
select inst_id, name latch_name,
round((immediate_gets/(immediate_gets+immediate_misses)), 3) hit_ratio,
round(sleeps/decode(immediate_misses,0,1,immediate_misses),3) "SLEEPS/MISS"
from gv$latch
where round((immediate_gets/(immediate_gets+immediate_misses)), 3) < .99
and immediate_gets + immediate_misses > 0
order by round((immediate_gets/(immediate_gets+immediate_misses)), 3);






PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : SQL with 100 or more unshared child cursors                 |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Results coming here with more than 500 childs can lead to high   |
PROMPT | hard parsing situations which could lead to Library cache latching issu|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

WITH
not_shared AS (
SELECT /*+  MATERIALIZE NO_MERGE  */ /* 2a.135 */
       sql_id, COUNT(*) child_cursors,
       RANK() OVER (ORDER BY COUNT(*) DESC NULLS LAST) AS sql_rank
  FROM gv$sql_shared_cursor
 GROUP BY
       sql_id
HAVING COUNT(*) > 99
)
SELECT /*+  NO_MERGE  */ /* 2a.135 */
       ns.sql_rank,
       ns.child_cursors,
       ns.sql_id,
       (SELECT s.sql_text FROM gv$sql s WHERE s.sql_id = ns.sql_id AND ROWNUM = 1) sql_text
  FROM not_shared ns
 ORDER BY
       ns.sql_rank,
       ns.child_cursors DESC,
       ns.sql_id;





PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Sesions Waiting                                             |
PROMPT | Desc: The entries that are shown at the top are the sessions that have |
PROMPT | waited the longest amount of time that are waiting for non-idle wait   |
PROMPT | events (event column).
PROMPT | This is RAC aware script                                               |
PROMPT +------------------------------------------------------------------------+


set numwidth 15
set heading on
column state format a7 tru
column event format a25 tru
column last_sql format a40 tru
select sw.inst_id, sa.sql_id,sw.sid, sw.state, sw.event, sw.seconds_in_wait seconds,
sw.p1, sw.p2, sw.p3, sa.sql_text last_sql
from gv$session_wait sw, gv$session s, gv$sqlarea sa
where sw.event not in
('rdbms ipc message','smon timer','pmon timer',
'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
and sw.seconds_in_wait > 0
and (sw.inst_id = s.inst_id and sw.sid = s.sid)
and (s.inst_id = sa.inst_id and s.sql_address = sa.address)
order by seconds desc;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Lists all locked objects for whole RAC.                     |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Remember to always look for X type locks, SS, SX, S, SSX are fine|
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

SET LINESIZE 500
SET PAGESIZE 1000
SET VERIFY OFF

COLUMN owner FORMAT A20
COLUMN username FORMAT A20
COLUMN object_owner FORMAT A20
COLUMN object_name FORMAT A30
COLUMN locked_mode FORMAT A15

SELECT b.inst_id,
       b.session_id AS sid,
       NVL(b.oracle_username, '(oracle)') AS username,
       a.owner AS object_owner,
       a.object_name,
       Decode(b.locked_mode, 0, 'None',
                             1, 'Null (NULL)',
                             2, 'Row-S (SS)',
                             3, 'Row-X (SX)',
                             4, 'Share (S)',
                             5, 'S/Row-X (SSX)',
                             6, 'Exclusive (X)',
                             b.locked_mode) locked_mode,
       b.os_user_name
FROM   dba_objects a,
       gv$locked_object b
WHERE  a.object_id = b.object_id
ORDER BY 1, 2, 3, 4;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top object waits in the database.    |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Shows Object name along with count, sqlid, and total time waited |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

col event       format a26      head 'Wait Event'       trunc
col mod         format a26      head 'Module'           trunc
col sqlid       format a13      head 'SQL Id'
col oname       format a38      head 'Object Name'
col sname       format a30      head 'SubObject Name'
col otyp        format a10      head 'Object Typ'       trunc
col cnt         format 999999   head 'Wait Cnt'
col twait       format 9999999999       head 'Tot Time|Waited'

select   o.owner||'.'||o.object_name            oname
        ,o.object_type                          otyp
        ,o.subobject_name                       sname
        ,h.event                                event
        ,h.wcount                               cnt
        ,h.twait                                twait
        ,h.sql_id                               sqlid
        ,h.module                               mod
from    (select current_obj#,sql_id,module,event,count(*) wcount,sum(time_waited+wait_time) twait
         from gv$active_session_history
         where event not in (
                       'queue messages'
                      ,'rdbms ipc message'
                      ,'rdbms ipc reply'
                      ,'pmon timer'
                      ,'smon timer'
                      ,'jobq slave wait'
                      ,'wait for unread message on broadcast channel'
                      ,'wakeup time manager')
         and event not like 'SQL*Net%'
         and event not like 'Backup%'
         group by current_obj#,sql_id,module,event
         order by twait desc)     h
        ,dba_objects              o
where    h.current_obj#         = o.object_id
and      rownum                 < 31
;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : list of all custom SQL Profiles in DB                       |
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Shows details of all SQL profiles already there in the database  |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

select name, created, status,sql_text as SQLTXT from dba_sql_profiles order by created desc;



PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : who is using most pga currently over 2MB
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: PGA Usage                |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

col sid         format 99999
col module      format a60
col kb          format 999,999,999
col qc          format a5
col hhmmss      format a10
col sql_id      format a13

break on hhmmss on qc skip 1 on sid

select   to_char(sample_time,'HH24:MI:SS')      hhmmss
        ,decode(qc_session_id,null,'n/a',qc_session_id)         qc
        ,inst_id,SESSION_ID                             sid
        ,PGA_ALLOCATED/1024                     kb
        ,sql_id                                 sql_id
        ,decode(module,null,'<'||program||'>',module) module
from     gv$active_session_history
where    PGA_ALLOCATED > 2*1024*1024
and      sample_time > sysdate-3/60/1440
order by sample_time, qc_session_id, SESSION_ID
/

PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Top 10 objects in database.
PROMPT | This is RAC aware script                                               |
PROMPT | Desc: Database Usage                |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

col segment_name format a30
col owner format a20
col tablespace_name format a30
select * from (select owner,segment_name,SEGMENT_TYPE,TABLESPACE_NAME,round(sum(BYTES)/(1024*1024*1024)) size_in_GB
from dba_segments group by owner,segment_name,SEGMENT_TYPE,TABLESPACE_NAME order by 5 desc ) where rownum<=10;



PROMPT +------------------------------------------------------------------------+
PROMPT | Indexes larger than their Table                                        |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
WITH
tables AS (
SELECT
       owner,
       segment_name,
       SUM(bytes) bytes
  FROM dba_segments
 WHERE 'Y' = 'Y'
   AND segment_type LIKE 'TABLE%'
GROUP BY
       owner,
       segment_name
),
indexes AS (
SELECT
       owner,
       segment_name,
       SUM(bytes) bytes
  FROM dba_segments
 WHERE 'Y' = 'Y'
   AND segment_type LIKE 'INDEX%'
GROUP BY
       owner,
       segment_name
),
idx_tbl AS (
SELECT
       d.table_owner,
       d.table_name,
       d.owner,
       d.index_name,
       SUM(i.bytes) bytes
  FROM indexes i,
       dba_indexes d
WHERE i.owner = d.owner
   AND i.segment_name = d.index_name
GROUP BY
       d.table_owner,
       d.table_name,
       d.owner,
       d.index_name
),
total AS (
SELECT
       t.owner table_owner,
       t.segment_name table_name,
       t.bytes t_bytes,
       i.owner index_owner,
       i.index_name,
       i.bytes i_bytes
  FROM tables t,
       idx_tbl i
WHERE t.owner = i.table_owner
   AND t.segment_name = i.table_name
   AND i.bytes > t.bytes
   AND t.bytes > POWER(10,7)
)
SELECT table_owner,
       table_name,
       ROUND(t_bytes / POWER(10,9), 3) table_gb,
       index_owner,
       index_name,
       ROUND(i_bytes / POWER(10,9), 3) index_gb,
       ROUND((i_bytes - t_bytes) / POWER(10,9), 3) dif_gb,
       ROUND(100 * (i_bytes - t_bytes) / t_bytes, 1) dif_perc
  FROM total
ORDER BY
      table_owner,
       table_name,
       index_owner,
       index_name;


PROMPT +------------------------------------------------------------------------+
PROMPT | Tables with Stale Stats |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|

SELECT s.owner, s.table_name, s.num_rows, s.last_analyzed, s.stattype_locked
  FROM dba_tab_statistics s,
       dba_tables t
 WHERE s.object_type = 'TABLE'
   AND s.owner NOT IN ('ANONYMOUS','APEX_030200','APEX_040000','APEX_SSO','APPQOSSYS','CTXSYS','DBSNMP','DIP','EXFSYS','FLOWS_FILES','MDSYS','OLAPSYS','ORACL
E_OCM','ORDDATA','ORDPLUGINS','ORDSYS','OUTLN','OWBSYS')
   AND s.owner NOT IN ('SI_INFORMTN_SCHEMA','SQLTXADMIN','SQLTXPLAIN','SYS','SYSMAN','SYSTEM','TRCANLZR','WMSYS','XDB','XS$NULL','PERFSTAT','STDBYPERF','MGDS
YS','OJVMSYS')
   AND s.stale_stats = 'YES'
   AND s.table_name NOT LIKE 'BIN%'
   AND NOT (s.table_name LIKE '%TEMP' OR s.table_name LIKE '%\_TEMP\_%' ESCAPE '\')
   AND t.owner = s.owner
   AND t.table_name = s.table_name
   AND t.temporary = 'N'
   AND NOT EXISTS (
SELECT NULL
  FROM dba_external_tables e
 WHERE e.owner = s.owner
   AND e.table_name = s.table_name
)
 ORDER BY
       s.owner, s.table_name;


PROMPT +------------------------------------------------------------------------+
PROMPT | INVALID Objects                                                        |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------|
SELECT *
  FROM dba_objects
 WHERE status = 'INVALID'
 ORDER BY
       owner,
       object_name;


spool off
exit

