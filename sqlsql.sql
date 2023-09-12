SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'TABLE', 'TABLE OWNER' ,
r.rolcanlogin
FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid 
where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
c.relowner =  r.oid
AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
;

SELECT
    r.rolname,
    current_database() AS catalog_name,
    'DATABASE' AS database_name,
    c.oid::regclass AS table_name,
    'TABLE' AS level,
    'TABLE OWNER' AS privilege,
    r.rolcanlogin
FROM
    pg_class c
JOIN
    pg_roles r ON c.relowner = r.oid
JOIN
    pg_namespace n ON c.relnamespace = n.oid
WHERE
    n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
    AND c.relkind = 'r'
    AND has_schema_privilege(r.rolname, n.oid, 'USAGE');
