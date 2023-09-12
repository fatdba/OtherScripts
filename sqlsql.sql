SELECT r.rolname, datname, array(select privs from unnest(ARRAY[
( CASE WHEN has_database_privilege(r.rolname,c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)]) foo(privs) 
WHERE privs IS NOT NULL), 'DATABASE',r.rolcanlogin FROM pg_database c WHERE 
has_database_privilege(r.rolname,c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname =current_database();

ERROR:  missing FROM-clause entry for table "r"
LINE 1: SELECT r.rolname, datname, array(select privs from unnest(AR...

  WITH roles AS (
    SELECT rolname
    FROM pg_roles
    WHERE rolcanlogin = true
)
SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', r.rolcanlogin
FROM pg_database c
JOIN roles r ON true
WHERE has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP') AND datname = current_database();


RROR:  column r.rolcanlogin does not exist
LINE 15: ), 'DATABASE', r.rolcanlogin
                        ^
