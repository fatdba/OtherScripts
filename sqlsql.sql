SELECT
    r.rolname,
    current_database() AS catalog_name,
    'DATABASE' AS database_name,
    c.oid::regclass AS table_name,
    'TABLE' AS level,
    ARRAY(
        SELECT privs
        FROM unnest(ARRAY[
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'SELECT') THEN 'SELECT' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'INSERT') THEN 'INSERT' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'UPDATE') THEN 'UPDATE' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'DELETE') THEN 'DELETE' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
            (CASE WHEN has_table_privilege(r.rolname, c.oid, 'TRIGGER') THEN 'TRIGGER' ELSE NULL END)
        ]) AS privs
        WHERE privs IS NOT NULL
    ) AS privileges,
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
    AND has_table_privilege(r.rolname, c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
    AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE')
    AND c.relowner <> r.oid;
