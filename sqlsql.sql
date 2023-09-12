WITH Privileges AS (
    SELECT
        r.rolname AS role_name,
        current_database() AS database_name,
        'DATABASE' AS object_type,
        c.oid::regclass AS object_name,
        'SEQUENCE' AS privilege_type,
        CASE WHEN has_table_privilege(r.rolname, c.oid, 'SELECT') THEN 'SELECT' ELSE NULL END AS select_priv,
        CASE WHEN has_table_privilege(r.rolname, c.oid, 'UPDATE') THEN 'UPDATE' ELSE NULL END AS update_priv,
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
        AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE')
)
SELECT
    role_name,
    database_name,
    object_type,
    object_name,
    privilege_type,
    ARRAY_REMOVE(ARRAY[select_priv, update_priv], NULL) AS privileges,
    can_login
FROM
    Privileges
WHERE
    ARRAY[select_priv, update_priv] IS NOT NULL;
