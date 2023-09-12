WITH elevated_perm_proc AS (
    SELECT
        row_number() OVER (ORDER BY p.oid) AS row_num,
        p.oid,
        nspname,
        proname,
        format_type(unnest(proargtypes)::oid, NULL) AS format_type
    FROM
        pg_proc p
    JOIN
        pg_namespace n ON p.pronamespace = n.oid
    JOIN
        pg_authid a ON a.oid = p.proowner
    WHERE
        prosecdef OR NOT proconfig IS NULL
),
func_with_elvated_priv AS (
    SELECT
        oid,
        nspname,
        proname,
        array_to_string(array_agg(format_type), ',') AS proc_param
    FROM
        elevated_perm_proc
    GROUP BY
        oid,
        nspname,
        proname
    UNION
    SELECT
        p.oid,
        nspname,
        proname,
        ' ' AS proc_param
    FROM
        pg_proc p
    JOIN
        pg_namespace n ON p.pronamespace = n.oid
    JOIN
        pg_authid a ON a.oid = p.proowner
    WHERE
        (prosecdef OR NOT proconfig IS NULL)
        AND p.oid NOT IN (SELECT oid FROM elevated_perm_proc)
),
func_with_elvated_priv1 AS (
    SELECT
        current_database() AS dbname,
        'DATABASE' AS level,
        nspname || '.' || proname || '(' || proc_param || ')' AS f
    FROM
        func_with_elvated_priv
    WHERE
        nspname NOT IN ('dbms_scheduler', 'dbms_session', 'pg_catalog', 'sys', 'utl_http')
)
INSERT INTO audit_role_privileges (rolname, dbname, level, object_name, object_type, privileges, canlogin)
SELECT
    r.rolname,
    func.*,
    'FUNCTION' AS object_type,
    'Elevated Privileges' AS privileges,
    r.rolcanlogin
FROM
    func_with_elvated_priv1 func
WHERE
    has_function_privilege(r.rolname, func.f, 'execute') = true;
