SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    c.oid::regclass AS object_name,
    'SEQUENCE' AS privilege_type,
    ARRAY(
        SELECT unnest(ARRAY[
            CASE WHEN has_table_privilege(r.rolname, c.oid, 'SELECT') THEN 'SELECT' ELSE NULL END,
            CASE WHEN has_table_privilege(r.rolname, c.oid, 'UPDATE') THEN 'UPDATE' ELSE NULL END
        ]) AS privs
        WHERE privs IS NOT NULL
    ) AS privileges,
    r.rolcanlogin AS can_login
FROM
    pg_class c
JOIN
    pg_namespace n ON c.relnamespace = n.oid
JOIN
    pg_roles r ON r.oid = c.relowner
WHERE
    n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
    AND c.relkind = 'S'
    AND has_table_privilege(r.rolname, c.oid, 'SELECT,UPDATE')
    AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE');
