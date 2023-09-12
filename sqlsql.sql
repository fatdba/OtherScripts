SELECT
  r.rolname,
  current_database() AS current_db,
  'DATABASE' AS object_type,
  c.oid::regclass AS object_name,
  'VIEW' AS object_kind,
  'VIEW OWNER' AS object_owner,
  ARRAY(
    SELECT privs
    FROM unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) AS privs
    WHERE
      (privs = 'SELECT' AND has_table_privilege(r.rolname, c.oid, 'SELECT')) OR
      (privs = 'INSERT' AND has_table_privilege(r.rolname, c.oid, 'INSERT')) OR
      (privs = 'UPDATE' AND has_table_privilege(r.rolname, c.oid, 'UPDATE')) OR
      (privs = 'DELETE' AND has_table_privilege(r.rolname, c.oid, 'DELETE')) OR
      (privs = 'TRUNCATE' AND has_table_privilege(r.rolname, c.oid, 'TRUNCATE')) OR
      (privs = 'REFERENCES' AND has_table_privilege(r.rolname, c.oid, 'REFERENCES')) OR
      (privs = 'TRIGGER' AND has_table_privilege(r.rolname, c.oid, 'TRIGGER'))
  ) AS object_privileges,
  r.rolcanlogin
FROM
  pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_roles r ON c.relowner = r.oid
WHERE
  n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
  AND c.relkind = 'v'
  AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE')
  AND c.relowner <> r.oid;
