SELECT r.rolname, datname, array(select privs from unnest(ARRAY[
( CASE WHEN has_database_privilege(r.rolname,c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)]) foo(privs) 
WHERE privs IS NOT NULL), 'DATABASE',r.rolcanlogin FROM pg_database c WHERE 
has_database_privilege(r.rolname,c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname =current_database();

ERROR:  missing FROM-clause entry for table "r"
LINE 1: SELECT r.rolname, datname, array(select privs from unnest(AR...
