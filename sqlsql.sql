SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    fdwname AS object_name,
    'FDW' AS privilege_type,
    ARRAY[CASE WHEN has_foreign_data_wrapper_privilege(r.rolname, fdwname, 'USAGE') THEN 'USAGE' ELSE NULL END] AS privileges,
    r.rolcanlogin AS can_login
FROM
    pg_catalog.pg_foreign_data_wrapper
JOIN
    pg_catalog.pg_roles r ON fdwowner = r.oid
WHERE
    has_foreign_data_wrapper_privilege(r.rolname, fdwname, 'USAGE')
    AND fdwowner <> r.oid;
