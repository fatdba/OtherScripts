SELECT r.rolname, current_database(),'DATABASE',c.oid::regclass,'SEQUENCE',
array(select privs from unnest(ARRAY [
( CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END)]) foo(privs) where privs is not null) ,r.rolcanlogin
FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
and  c.relkind='S' and
has_table_privilege(r.rolname,c.oid,'SELECT,UPDATE')  
AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
and c.relowner <>  r.oid;
