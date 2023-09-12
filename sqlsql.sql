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



SELECT r.rolname, catalog_name, schema_name, 'SCHEMA' AS level, 'DATABASE',
  ARRAY(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_schema_privilege(r.rolname, c.schema_name, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_schema_privilege(r.rolname, c.schema_name, 'USAGE') THEN 'USAGE' ELSE NULL END)
    ])) AS privs,
  r.rolcanlogin
FROM (
  SELECT s.schema_name, s.catalog_name, u.rolname, s.schema_owner
  FROM information_schema.schemata s
  JOIN pg_user u ON u.usename = current_user
  WHERE has_schema_privilege(u.rolname, s.schema_name, 'CREATE,USAGE')
    AND s.schema_name NOT LIKE 'pg_temp%'
    AND s.schema_owner <> u.rolname
) AS c
JOIN pg_roles r ON r.rolname = c.rolname;


ERROR:  column u.rolname does not exist
LINE 10:   SELECT s.schema_name, s.catalog_name, u.rolname, s.schema_...
                                                 ^
HINT:  Perhaps you meant to reference the column "u.usename".




  SELECT r.rolname, catalog_name, schema_name, 'SCHEMA' AS level, 'DATABASE',
  ARRAY(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_schema_privilege(r.rolname, c.schema_name, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_schema_privilege(r.rolname, c.schema_name, 'USAGE') THEN 'USAGE' ELSE NULL END)
    ])) AS privs,
  r.rolcanlogin
FROM (
  SELECT s.schema_name, s.catalog_name, current_user AS rolname, s.schema_owner
  FROM information_schema.schemata s
  WHERE has_schema_privilege(current_user, s.schema_name, 'CREATE,USAGE')
    AND s.schema_name NOT LIKE 'pg_temp%'
    AND s.schema_owner <> current_user
) AS c
JOIN pg_roles r ON r.rolname = c.rolname;



=========

SELECT
    r.rolname,
    current_database() AS catalog_name,
    n.nspname AS schema_name,
    'SCHEMA' AS level,
    'DATABASE' AS database_name,
    ARRAY(
        SELECT privs
        FROM unnest(ARRAY[
            (CASE WHEN has_schema_privilege(r.rolname, n.nspname, 'CREATE') THEN 'CREATE' ELSE NULL END),
            (CASE WHEN has_schema_privilege(r.rolname, n.nspname, 'USAGE') THEN 'USAGE' ELSE NULL END)
        ])) AS privs,
    r.rolcanlogin
FROM
    pg_namespace n
JOIN
    pg_roles r ON true
WHERE
    has_schema_privilege(r.rolname, n.nspname, 'CREATE,USAGE')
    AND n.nspname NOT LIKE 'pg_temp%'
    AND n.nspowner <> r.oid;


