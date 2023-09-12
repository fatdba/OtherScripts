SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    fdwname AS object_name,
    'FDW' AS privilege_type,
    'FDW OWNER' AS privilege_name,
    r.rolcanlogin AS can_login
FROM
    pg_catalog.pg_foreign_data_wrapper
WHERE
    has_foreign_data_wrapper_privilege(r.rolname, fdwname, 'USAGE')
    AND fdwowner = r.oid;
