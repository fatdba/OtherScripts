SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'TABLE', 'TABLE OWNER' ,
r.rolcanlogin
FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid 
where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
c.relowner =  r.oid
AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
;
