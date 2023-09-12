select r.rolname,catalog_name,schema_name,'SCHEMA' as level, 'DATABASE',array(select privs from unnest(ARRAY[
( CASE WHEN has_schema_privilege(r.rolname,schema_name,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_schema_privilege(r.rolname,schema_name,'USAGE') THEN 'USAGE' ELSE NULL END)])foo(privs) 
WHERE privs IS NOT NULL),r.rolcanlogin
from information_schema.schemata c
where has_schema_privilege(r.rolname,schema_name,'CREATE,USAGE') 
and c.schema_name not like 'pg_temp%'
and schema_owner <> r.rolname;


RROR:  missing FROM-clause entry for table "r"
LINE 1: select r.rolname,catalog_name,schema_name,'SCHEMA' as level,...
               ^
