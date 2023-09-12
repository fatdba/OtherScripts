select r.rolname,catalog_name,schema_name,'SCHEMA' as level, 'DATABASE','SCHEMA OWNER',r.rolcanlogin
from information_schema.schemata c
where has_schema_privilege(r.rolname,schema_name,'CREATE,USAGE') 
and c.schema_name not like 'pg_temp%'
and schema_owner = r.rolname;


SELECT
    r.rolname,
    current_database() AS catalog_name,
    c.schema_name,
    'SCHEMA' AS level,
    'DATABASE' AS database_name,
    'SCHEMA OWNER' AS privilege,
    r.rolcanlogin
FROM
    information_schema.schemata c
JOIN
    pg_roles r ON c.schema_owner = r.rolname
WHERE
    has_schema_privilege(r.rolname, c.schema_name, 'CREATE,USAGE')
    AND c.schema_name NOT LIKE 'pg_temp%';
