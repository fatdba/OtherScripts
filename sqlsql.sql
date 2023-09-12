SELECT
  r.rolname,
  current_database() AS current_db,
  'DATABASE' AS object_type,
  c.oid::regclass AS object_name,
  'VIEW' AS object_kind,
  'VIEW OWNER' AS object_owner,
  r.rolcanlogin
FROM
  pg_class c
JOIN
  pg_namespace n ON c.relnamespace = n.oid
JOIN
  pg_roles r ON c.relowner = r.oid
WHERE
  n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
  AND c.relkind = 'v'
  AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE');
