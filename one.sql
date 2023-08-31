SELECT
    superuser_roles.rolname AS superuser_role,
    superuser_roles.rolcanlogin,
    'ALL' AS placeholder1,
    'ALL' AS placeholder2,
    'ALL' AS placeholder3,
    'ALL' AS placeholder4,
    'SUPERUSER' AS placeholder5,
    'SERVER' AS placeholder6,
    assigned_users.other_role_id,
    assigned_users.other_role_name
FROM (
    SELECT
        a.oid AS superuser_role_id,
        a.rolname,
        a.rolcanlogin
    FROM
        pg_roles a
    WHERE
        a.rolsuper IS TRUE
) AS superuser_roles
JOIN (
    SELECT
        a.oid AS user_role_id,
        a.rolname AS user_role_name,
        b.roleid AS other_role_id,
        c.rolname AS other_role_name
    FROM
        pg_roles a
    INNER JOIN
        pg_auth_members b ON a.oid = b.member
    INNER JOIN
        pg_roles c ON b.roleid = c.oid
) AS assigned_users ON superuser_roles.superuser_role_id = assigned_users.other_role_id;
