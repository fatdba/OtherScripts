select r.rolname,catalog_name,schema_name,'SCHEMA' as level, 'DATABASE','SCHEMA OWNER',r.rolcanlogin
from information_schema.schemata c
where has_schema_privilege(r.rolname,schema_name,'CREATE,USAGE') 
and c.schema_name not like 'pg_temp%'
and schema_owner = r.rolname;
