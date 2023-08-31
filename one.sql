SELECT
    m.member,
    r.rolname AS role_name,
    r.rolcanlogin AS can_login
FROM
    pg_roles r
JOIN
    pg_auth_members m ON r.oid = m.roleid
WHERE
    r.rolsuper IS TRUE;
