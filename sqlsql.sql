SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'VIEW','VIEW OWNER' ,
r.rolcanlogin
FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
and  c.relkind='v' AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
and c.relowner =  r.oid;
