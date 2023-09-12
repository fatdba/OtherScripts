SELECT
  r.rolname,
  current_database() AS current_db,
  'DATABASE' AS object_type,
  c.oid::regclass AS object_name,
  'SEQUENCE' AS object_kind,
  'SEQUENCE OWNER' AS object_owner,
  r.rolcanlogin
FROM
  pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_roles r ON c.relowner = r.oid
WHERE
  n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
  AND c.relkind = 'S'
  AND has_table_privilege(r.rolname, c.oid, 'SELECT, UPDATE')
  AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE')
  AND c.relowner = r.oid;
