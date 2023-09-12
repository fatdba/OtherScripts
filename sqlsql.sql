SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'VIEW',
array(select privs from unnest(ARRAY [
( CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) where privs is not null) ,
r.rolcanlogin
FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
and  c.relkind='v' and has_table_privilege(r.rolname,c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') 
AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
and c.relowner <>  r.oid;
