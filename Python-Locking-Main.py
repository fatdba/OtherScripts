import cx_Oracle

# Database connection details
db_username = "system"
db_password = "xxx"
db_host = "xxx.xxx.com"
db_port = "1521"
db_service = "xx"

bold_start = "\033[1m"
color_green = "\033[32m"
reset_format = "\033[0m"

def print_colored(text, color_code):
    colored_text = "{}{}{}".format(color_code, text, reset_format)
    print(colored_text)

# Define the SQL statements
sql_statements = [
'''
SELECT rpad(instance_name, 17) current_instance, status, STARTUP_TIME, HOST_NAME, version, DATABASE_STATUS FROM v$instance
''',
"""
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS'
""",
"""
SELECT
    OUTPUT || CHR(10) || RPAD('-', LENGTH(OUTPUT) - LENGTH(REPLACE(OUTPUT, CHR(10), '')), '-') AS OUTPUT
FROM (
    SELECT
    'INST_ID -->  '||x.INST_ID || CHR(10) ||
    'Serial ID -->  '||x.sid || CHR(10) ||
    'Serial Num -->  '||x.serial# || CHR(10) ||
    'User Name -->  '||x.username || CHR(10) ||
    'Session Status -->  '||x.status || CHR(10) ||
    'Program -->  '||x.program || CHR(10) ||
    'Module -->  '||x.Module || CHR(10) ||
    'Action -->  '||x.action || CHR(10) ||
    'Machine -->  '||x.machine || CHR(10) ||
    'OS_USER -->  '||x.OSUSER || CHR(10) ||
    'Process -->  '||x.process || CHR(10) ||
    'State -->  '||x.State || CHR(10) ||
    'EVENT -->  '||x.event || CHR(10) ||
    'SECONDS_IN_WAIT -->  '||x.SECONDS_IN_WAIT || CHR(10) ||
    'LAST_CALL_ET -->  '||x.LAST_CALL_ET || CHR(10) ||
    'SQL_PROFILE --> '||SQL_PROFILE || CHR(10) ||
    'ROWS_PROCESSED --> '||ROWS_PROCESSED || CHR(10) ||
    'BLOCKING_SESSION_STATUS --> '||BLOCKING_SESSION_STATUS || CHR(10) ||
    'BLOCKING_INSTANCE --> '||BLOCKING_INSTANCE || CHR(10) ||
    'BLOCKING_SESSION --> '||BLOCKING_SESSION || CHR(10) ||
    'FINAL_BLOCKING_SESSION_STATUS --> '||FINAL_BLOCKING_SESSION_STATUS || CHR(10) ||
    'SQL_ID -->  '||x.sql_id || CHR(10) ||
    'SQL_TEXT -->  '||SQL_TEXT || CHR(10) ||
    'Logon Time -->  '||TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24MISS') || CHR(10) ||
    'RunTime -->  '||ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
    || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
    || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09')) || CHR(10) AS OUTPUT,
    x.LAST_CALL_ET AS RUNT
    FROM   gv$sqlarea sqlarea
    ,gv$session x
    WHERE  x.sql_hash_value = sqlarea.hash_value
    AND    x.sql_address    = sqlarea.address
    AND    x.status='ACTIVE'
    AND x.event like '%row lock contention%'
    AND SQL_TEXT not like '%SELECT     OUTPUT || CHR(10)%'
    AND x.USERNAME IS NOT NULL
    AND x.SQL_ADDRESS    = sqlarea.ADDRESS
    AND x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
)
ORDER BY RUNT DESC
""",
"""
with lk as (select blocking_instance||'.'||blocking_session blocker, inst_id||'.'||sid waiter
 from gv$session where blocking_instance is not null and blocking_session is not null and username is not null)
 select lpad(' ',2*(level-1))||waiter lock_tree from
 (select * from lk
 union all
 select distinct 'root', blocker from lk
 where blocker not in (select waiter from lk))
 connect by prior waiter=blocker start with blocker='root'
""",
"""
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
,DECODE (l.lmode,0, 'None',1, 'Null',2, 'Row Share',3, 'Row Excl.'
,4, 'Share',5, 'S/Row Excl.',6, 'Exclusive'
,LTRIM (TO_CHAR (lmode, '990'))) lock_mode
,ctime
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
ORDER BY id1, id2, ctime DESC
""",
"""
select l1.sid, ' IS BLOCKING ', l2.sid
from gv$lock l1, gv$lock l2 where l1.block =1 and l2.request > 0
and l1.id1=l2.id1
and l1.id2=l2.id2
""",
"""
select s2.inst_id,s1.username || '@' || s1.machine
 || ' ( SID=' || s1.sid || ' )  is blocking '
 || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
  from gv$lock l1, gv$session s1, gv$lock l2, gv$session s2
  where s1.sid=l1.sid and s2.sid=l2.sid and s1.inst_id=l1.inst_id and s2.inst_id=l2.inst_id
  and l1.BLOCK=1 and l2.request > 0
  and l1.id1 = l2.id1
  and l2.id2 = l2.id2
order by s1.inst_id
""",
"""
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
      where request > 0 OR block =1
""",
"""
select  sn.USERNAME,
        m.SID,
        sn.SERIAL#,
        m.TYPE,
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive') lock_type,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive') lock_requested,
        m.ID1,
        m.ID2,
        t.SQL_TEXT
from    v$session sn,
        v$lock m ,
        v$sqltext t
where   t.ADDRESS = sn.SQL_ADDRESS
and     t.HASH_VALUE = sn.SQL_HASH_VALUE
and     ((sn.SID = m.SID and m.REQUEST != 0)
or      (sn.SID = m.SID and m.REQUEST = 0 and LMODE != 4 and (ID1, ID2) in
        (select s.ID1, s.ID2
         from   gv$lock S
         where  REQUEST != 0
         and    s.ID1 = m.ID1
         and    s.ID2 = m.ID2)))
order by sn.USERNAME, sn.SID, t.PIECE
"""
]

banner = """
=========================================================
      Locking Stats Report
        Author: Prashant Dixit 
        Version : 1.0
       Date : 2023-August-11
========================================================
"""
print_colored(banner, color_green)

try:
    # Establishing a database connection
    dsn = cx_Oracle.makedsn(db_host, db_port, service_name=db_service)
    connection = cx_Oracle.connect(user=db_username, password=db_password, dsn=dsn)

    # Executing each SQL statement
    cursor = connection.cursor()
    for idx, statement in enumerate(sql_statements):
        statement = statement.strip()
        if statement:
            try:
                cursor.execute(statement)

                if statement.upper().startswith("SELECT"):
                    result = cursor.fetchall()
                    if result:
                        column_names = [desc[0] for desc in cursor.description]
                        print_colored("Column Headers: " + ", ".join(column_names), color_green)
                        print("Results:")

                        for row in result:
                            print("Row:")
                            for col_name, col_value in zip(column_names, row):
                                print("{}: {}".format(col_name, col_value))
                            print("\n")

                    else:
                        print("No results.")

                    # Add a newline after the output of the first two SQL statements
                    #if idx == 1:
                     #   print("\n")

                #print("\n" * 1)  # Add a gap of one  lines

            except Exception as e:
                print("Error executing statement:", statement)
                print("Error details:", str(e))

    connection.commit()
    print("SQL statements execution completed.")

except Exception as e:
    connection.rollback()
    print("An error occurred:", str(e))

finally:
    if connection:
        connection.close()
