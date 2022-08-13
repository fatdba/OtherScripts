#! /bin/bash
# unset any variable which system may be using

echo -e '\E[36m'"*************************************************************************************" $prashantdixit $setis
echo -e '\E[36m'"Edited by (Version 2.1) : prashant Dixit ---> prashantdixit@fatdba.com" $prashantdixit $auth
echo -e '\E[36m'"DB + OS level monitoring for EDB PostgreSQL Database" $prashantdixit $auth
echo -e '\E[36m'"Date/Version : 07/27/2022  #2.1" $prashantdixit $date
echo -e '\E[36m'" " $prashantdixit $date
echo -e '\E[36m'"Usage : ./db_edb_OS_health_V2.1.sh" $prashantdixit $date
echo -e '\E[36m'"************************************************************************************" $prashantdixit $setis

unset prashantdixit 

while true; do


# Define Variable prashantdixit
prashantdixit=$(tput sgr0)

# Check hostname
echo -e '\E[32m'"Hostname :" $prashantdixit $HOSTNAME


# Check Logged In Users
who>/tmp/who
echo -e '\E[32m'"Logged In users :" $prashantdixit && cat /tmp/who

# Check System Uptime
tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
echo -e '\E[32m'"System Uptime Days/(HH:MM) :" $prashantdixit $tecuptime


# Check RAM and SWAP Usages
free -g | grep -v + > /tmp/ramcache
echo -e '\E[32m'"Ram Usages :" $prashantdixit
cat /tmp/ramcache | grep -v "Swap"
echo -e '\E[32m'"Swap Usages :" $prashantdixit
cat /tmp/ramcache | grep -v "Mem"

# Check Disk Usages
df -kh| grep 'Filesystem\|' > /tmp/diskusage
echo -e '\E[32m'"Disk Usages :" $prashantdixit
cat /tmp/diskusage

echo -e '\E[32m'"memory details :" $prashantdixit $memorydetails
vmstat -s |grep -E 'total memory|used memory|free memory|total swap|free swap|used swap'

echo -e '\E[32m'"VMStats results 5 iterations :" $prashantdixit $VMStatsRes
vmstat 1 5

echo -e '\E[32m'"IO Stats for all disk :" $prashantdixit $iostatsforalldisks
iostat -m -p

echo -e '\E[32m'"top head :" $prashantdixit $tophead
# TOP Head
top -bc -n 1 -b | head 

echo -e '\E[32m'"System Activity in last 3 Hours :" $prashantdixit $sysactivityinlast3hours
sar | head -n 20

DBNAME="postgres"
echo -e '\E[32m'"DB Size" $prashantdixit $xyz
psql -d $DBNAME -c "SELECT pg_database.datname as "database_name", pg_size_pretty(pg_database_size(pg_database.datname)) AS size_in_mb FROM pg_database ORDER
 by size_in_mb DESC;";

psql -d $DBNAME -c "select state, usename, count(*) from pg_stat_activity where pid <> pg_backend_pid() group by 1, 2 order by 2, 1;";

echo -e '\E[32m'"Blocking Stats" $prashantdixit $xyz
psql -d $DBNAME -c "  SELECT bl.pid AS blocked_pid,
         a.usename              AS blocked_user,
         ka.query               AS current_statement_in_blocking_process,
         now() - ka.query_start AS blocking_duration,
         kl.pid                 AS blocking_pid,
         ka.usename             AS blocking_user,
         a.query                AS blocked_statement,
         now() - a.query_start  AS blocked_duration
  FROM  pg_catalog.pg_locks         bl
   JOIN pg_catalog.pg_stat_activity a  ON a.pid = bl.pid
   JOIN pg_catalog.pg_locks         kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
   JOIN pg_catalog.pg_stat_activity ka ON ka.pid = kl.pid
  WHERE NOT bl.GRANTED;";

echo -e '\E[32m'"more blocking related stats"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT blocked_locks.pid AS blocked_pid,
blocked_activity.usename AS blocked_user,
now() - blocked_activity.query_start
AS blocked_duration,
blocking_locks.pid AS blocking_pid,
blocking_activity.usename AS blocking_user,
now() - blocking_activity.query_start
AS blocking_duration,
blocked_activity.query AS blocked_statement,
blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks AS blocked_locks
JOIN pg_catalog.pg_stat_activity AS blocked_activity
ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks AS blocking_locks
ON blocking_locks.locktype = blocked_locks.locktype
AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity AS blocking_activity
ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;";

echo -e '\E[32m'"Dead Tuples count in Tables"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT schemaname,relname,n_live_tup,n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup desc limit 30;";
#psql -d $DBNAME -c "select count(*), ostate from eoc.cworderinstance group by ostate;";

psql -d $DBNAME -c "select query,now()-xact_start as duration from pg_stat_activity where query like 'autovacuum:%';";

echo -e '\E[32m'"Queries running for more than 1 second"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT
 pid,
 now() - pg_stat_activity.query_start AS duration,
 query,
 state
 FROM pg_stat_activity
 WHERE state not in ( 'idle', 'idle in transaction') and (now() - pg_stat_activity.query_start) > interval '1 seconds'
 and query not like 'autovacuum:%'
 order by duration desc;";


echo -e '\E[32m'"connection type and count"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT count(*),
       state
FROM pg_stat_activity
GROUP BY 2;";


echo -e '\E[32m'"'Auto-Vacuum Sessions running more than 2 mins'"  $prashantdixit $xyz
psql -d $DBNAME -c "select pid,client_addr,now() - pg_stat_activity.query_start as duration,query,state from pg_stat_activity where state = 'active' 
and query like 'autovacuum%' and query_start < now() - '2 minutes'::interval order by 3 desc;";


echo -e '\E[32m'"Last Vaccum and Analyze Date"  $prashantdixit $xyz
psql -d $DBNAME -c "select relname,last_vacuum, last_autovacuum, last_analyze, last_autoanalyze from pg_stat_user_tables;";


echo -e '\E[32m'"Table Size based sorting"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT
nspname,
relname,
pg_size_pretty(pg_relation_size(C.oid)) AS "size"
FROM pg_class C
LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(C.oid) DESC
LIMIT 20;"

psql -d $DBNAME -c "SELECT
nspname,
relname,
relkind as "type",
pg_size_pretty(pg_table_size(C.oid)) AS size,
pg_size_pretty(pg_indexes_size(C.oid)) AS idxsize,
pg_size_pretty(pg_total_relation_size(C.oid)) as "total"
FROM pg_class C
LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
WHERE nspname NOT IN ('pg_catalog', 'information_schema') AND
nspname !~ '^pg_toast' AND
relkind IN ('r','i')
ORDER BY pg_total_relation_size(C.oid) DESC
LIMIT 20;";


echo -e '\E[32m'"Temp File Usage" $prashantdixit $xyz
psql -d $DBNAME -c "SELECT datname,temp_files,temp_bytes FROM pg_stat_database;";

echo -e '\E[32m'"table index usage rates (should not be less than 0.99)"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT relname,
  CASE WHEN (seq_scan + idx_scan) != 0
    THEN 100.0 * idx_scan / (seq_scan + idx_scan)
    ELSE 0
  END AS percent_of_times_index_used,
  n_live_tup AS rows_in_table
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;";


echo -e '\E[32m'"Top 10 Objects in DB"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT N.nspname ,relname AS "relation",pg_size_pretty (pg_total_relation_size (C .oid)) AS "total_size" 
FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C .relnamespace) WHERE nspname NOT IN ('pg_catalog','information_schema')
-- AND C .relkind <> 'i'
-- AND C.relname not like '%_seq'
AND C.relname in (select kcu.table_name
from information_schema.table_constraints tco
join information_schema.key_column_usage kcu
on kcu.constraint_name = tco.constraint_name
and kcu.constraint_schema = tco.constraint_schema
and kcu.constraint_name = tco.constraint_name
where tco.constraint_type = 'PRIMARY KEY')
AND nspname !~ '^pg_toast'
and N.nspname not like '_edb%'
ORDER BY
pg_total_relation_size (C .oid) DESC limit 25;";

echo -e '\E[32m'"Bloating Sessions"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT
  current_database(), schemaname, tablename, /*reltuples::bigint, relpages::bigint, otta,*/
  ROUND((CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages::FLOAT/otta END)::NUMERIC,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE (bs*(sml.relpages-otta)/1024/1024)::BIGINT END AS wastedbytes,
  iname, /*ituples::bigint, ipages::bigint, iotta,*/
  ROUND((CASE WHEN iotta=0 OR ipages=0 THEN 0.0 ELSE ipages::FLOAT/iotta END)::NUMERIC,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE (bs*(ipages-iotta)/1024/1024) END AS wastedibytes FROM (
  SELECT
    schemaname, tablename, cc.reltuples, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::FLOAT)) AS otta,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::FLOAT)),0) AS iotta -- very rough approximation, assumes all cols
  FROM (
    SELECT
      ma,bs,schemaname,tablename,
      (datawidth+(hdr+ma-(CASE WHEN hdr%ma=0 THEN ma ELSE hdr%ma END)))::NUMERIC AS datahdr,
      (maxfracsum*(nullhdr+ma-(CASE WHEN nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        schemaname, tablename, hdr, ma, bs,
        SUM((1-null_frac)*avg_width) AS datawidth,
        MAX(null_frac) AS maxfracsum,
        hdr+(
          SELECT 1+COUNT(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
        ) AS nullhdr
      FROM pg_stats s, (
        SELECT
          (SELECT current_setting('block_size')::NUMERIC) AS bs,
          CASE WHEN SUBSTRING(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  JOIN pg_class cc ON cc.relname = rs.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml
ORDER BY wastedbytes DESC LIMIT 25;";

echo -e '\E[32m'"Number of DMLs on tables"  $prashantdixit $xyz
psql -d $DBNAME -c "SELECT relname,n_tup_ins as "inserts",n_tup_upd as "updates",n_tup_del as "deletes", n_live_tup as "live_tuples", 
n_dead_tup as "dead_tuples" FROM pg_stat_user_tables order by dead_tuples desc limit 10;";


echo -e '\E[32m'"Active Sessions Running for more than 5 Minutes"  $prashantdixit $xyz
psql -d $DBNAME -c "select pid,client_addr, now() - pg_stat_activity.query_start as duration,query,state from pg_stat_activity where state = 'active' 
and query not like 'autovacuum%' and query_start < now() - '5 minutes'::interval order by 3 desc;";

echo -e '\E[32m'"Idle Sessions running more than 5 Minutes"  $prashantdixit $xyz
psql -d $DBNAME -c "select pid,client_addr,now() - pg_stat_activity.query_start as duration,query,state from pg_stat_activity where state = 'active' 
and query not like 'autovacuum%' and query_start < now() - '5 minutes'::interval order by 3 desc;";


echo -e '\E[32m'"Idle In Transaction Sessions running more than 5 Minutes:"  $prashantdixit $xyz
psql -d $DBNAME -c "select pid,client_addr,now() - pg_stat_activity.query_start as duration,query, state from pg_stat_activity 
where state = 'idle in transaction' and query not like 'autovacuum%' and query_start < now() - '5 minutes'::interval order by 3 desc;";

echo -e '\E[32m'"Session Details Running For More Than 10 Minutes"  $prashantdixit $xyz
psql -d $DBNAME -c "select pid,usename,client_addr,now() - pg_stat_activity.query_start as duration,query,state from pg_stat_activity 
where  query_start < now() - '10 minutes'::interval order by 3 desc;";


# Unset Variables
unset prashantdixit 


echo "===============================================================================================================================================
===";
sleep 30;
done;

