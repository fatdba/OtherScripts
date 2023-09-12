SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    l.lanname AS object_name,
    'LANGUAGE' AS privilege_type,
    ARRAY[CASE WHEN has_language_privilege(r.rolname, l.lanname, 'USAGE') THEN 'USAGE' ELSE NULL END] AS privileges,
    r.rolcanlogin AS can_login
FROM
    pg_catalog.pg_language l
JOIN
    pg_catalog.pg_roles r ON has_language_privilege(r.rolname, l.lanname, 'USAGE');
