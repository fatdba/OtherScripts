--database permissions

SELECT
    r.rolname,
    datname,
    ARRAY_AGG(
        CASE
            WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT'
            WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE'
            WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY'
            WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT'
            ELSE NULL
        END
    ) AS privileges,
    'DATABASE' AS level,
    r.rolcanlogin
FROM
    pg_database c
JOIN
    pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE
    datname = current_database()
GROUP BY
    r.rolname, datname, r.rolcanlogin;

          rolname          | datname  | privileges |  level   | rolcanlogin
---------------------------+----------+------------+----------+-------------
 pg_write_server_files     | postgres | {CONNECT}  | DATABASE | f
 pg_read_all_stats         | postgres | {CONNECT}  | DATABASE | f
 postgres                  | postgres | {CONNECT}  | DATABASE | t





--schema privileges 
SELECT
    r.rolname,
    current_database() AS catalog_name,
    n.nspname AS schema_name,
    'SCHEMA' AS level,
    'DATABASE' AS database_name,
    (
        SELECT ARRAY_AGG(priv)
        FROM (
            SELECT
                CASE WHEN has_schema_privilege(r.rolname, n.nspname, 'CREATE') THEN 'CREATE' END AS priv
            UNION
            SELECT
                CASE WHEN has_schema_privilege(r.rolname, n.nspname, 'USAGE') THEN 'USAGE' END AS priv
        ) AS privs
        WHERE priv IS NOT NULL
    ) AS privs,
    r.rolcanlogin
FROM
    pg_namespace n
JOIN
    pg_roles r ON true
WHERE
    has_schema_privilege(r.rolname, n.nspname, 'CREATE,USAGE')
    AND n.nspname NOT LIKE 'pg_temp%'
    AND n.nspowner <> r.oid;

          rolname          | catalog_name |    schema_name     | level  | database_name |     privs      | rolcanlogin
---------------------------+--------------+--------------------+--------+---------------+----------------+-------------
 pg_monitor                | postgres     | pg_catalog         | SCHEMA | DATABASE      | {USAGE}        | f
 pg_monitor                | postgres     | public             | SCHEMA | DATABASE      | {CREATE,USAGE} | f
 pg_monitor                | postgres     | information_schema | SCHEMA | DATABASE      | {USAGE}        | f
 pg_read_all_settings      | postgres     | pg_catalog         | SCHEMA | DATABASE      | {USAGE}        | f



--- schema privileges 1 
SELECT
    r.rolname,
    current_database() AS catalog_name,
    c.schema_name,
    'SCHEMA' AS level,
    'DATABASE' AS database_name,
    'SCHEMA OWNER' AS privilege,
    r.rolcanlogin
FROM
    information_schema.schemata c
JOIN
    pg_roles r ON c.schema_owner = r.rolname
WHERE
    has_schema_privilege(r.rolname, c.schema_name, 'CREATE,USAGE')
    AND c.schema_name NOT LIKE 'pg_temp%';

 rolname  | catalog_name |    schema_name     | level  | database_name |  privilege   | rolcanlogin
----------+--------------+--------------------+--------+---------------+--------------+-------------
 postgres | postgres     | pg_toast           | SCHEMA | DATABASE      | SCHEMA OWNER | t
 postgres | postgres     | pg_toast_temp_1    | SCHEMA | DATABASE      | SCHEMA OWNER | t



-- Table Owner Privileges 
SELECT
    r.rolname,
    current_database() AS catalog_name,
    'DATABASE' AS database_name,
    c.oid::regclass AS table_name,
    'TABLE' AS level,
    'TABLE OWNER' AS privilege,
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
    AND has_schema_privilege(r.rolname, n.oid, 'USAGE');

 rolname | catalog_name | database_name | table_name | level | privilege | rolcanlogin
---------+--------------+---------------+------------+-------+-----------+-------------
(0 rows)


-- Non Owner Privileges
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

rolname | catalog_name | database_name | table_name | level | privileges | rolcanlogin
---------+--------------+---------------+------------+-------+------------+-------------
(0 rows)



-- View privileges
SELECT
  r.rolname,
  current_database() AS current_db,
  'DATABASE' AS object_type,
  c.oid::regclass AS object_name,
  'VIEW' AS object_kind,
  'VIEW OWNER' AS object_owner,
  r.rolcanlogin
FROM
  pg_class c
JOIN
  pg_namespace n ON c.relnamespace = n.oid
JOIN
  pg_roles r ON c.relowner = r.oid
WHERE
  n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
  AND c.relkind = 'v'
  AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE');

rolname | current_db | object_type | object_name | object_kind | object_owner | rolcanlogin
---------+------------+-------------+-------------+-------------+--------------+-------------
(0 rows)





-- non owner permissions
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

 rolname | current_db | object_type | object_name | object_kind | object_owner | object_privileges | rolcanlogin
---------+------------+-------------+-------------+-------------+--------------+-------------------+-------------
(0 rows)





-- sequence privileges
SELECT
  r.rolname,
  current_database() AS current_db,
  'DATABASE' AS object_type,
  c.oid::regclass AS object_name,
  'SEQUENCE' AS object_kind,
  'SEQUENCE OWNER' AS object_owner,
  r.rolcanlogin
FROM
  pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_roles r ON c.relowner = r.oid
WHERE
  n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
  AND c.relkind = 'S'
  AND has_table_privilege(r.rolname, c.oid, 'SELECT, UPDATE')
  AND has_schema_privilege(r.rolname, c.relnamespace, 'USAGE')
  AND c.relowner = r.oid;

 rolname | current_db | object_type | object_name | object_kind | object_owner | rolcanlogin
---------+------------+-------------+-------------+-------------+--------------+-------------
(0 rows)





-- sequence with no privs
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

role_name | database_name | object_type | object_name | privilege_type | privileges | can_login
-----------+---------------+-------------+-------------+----------------+------------+-----------
(0 rows)






-- foreign data wrappers owner privs
SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    fdwname AS object_name,
    'FDW' AS privilege_type,
    'FDW OWNER' AS privilege_name,
    r.rolcanlogin AS can_login
FROM
    pg_catalog.pg_foreign_data_wrapper fdw
JOIN
    pg_catalog.pg_roles r ON fdw.fdwowner = r.oid
WHERE
    has_foreign_data_wrapper_privilege(r.rolname, fdwname, 'USAGE');

 role_name | database_name | object_type | object_name | privilege_type | privilege_name | can_login
-----------+---------------+-------------+-------------+----------------+----------------+-----------
(0 rows)





-- FDW Non Owner
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
 role_name | database_name | object_type | object_name | privilege_type | privileges | can_login
-----------+---------------+-------------+-------------+----------------+------------+-----------
(0 rows)




-- Language privs
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
        role_name         | database_name | object_type | object_name | privilege_type | privileges | can_login
---------------------------+---------------+-------------+-------------+----------------+------------+-----------
 postgres                  | postgres      | DATABASE    | internal    | LANGUAGE       | {USAGE}    | t
 postgres                  | postgres      | DATABASE    | c           | LANGUAGE       | {USAGE}    | t
 postgres                  | postgres      | DATABASE    | sql         | LANGUAGE       | {USAGE}    | t


-- Get function privileges with elevated permissions with sexurity identifiers.
WITH elevated_perm_procs AS (
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
func_with_elevated_privileges AS (
    SELECT
        oid,
        nspname,
        proname,
        array_to_string(array_agg(format_type), ',') AS proc_param
    FROM
        elevated_perm_procs
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
        AND p.oid NOT IN (SELECT oid FROM elevated_perm_procs)
),
func_with_elevated_privileges_and_db AS (
    SELECT
        current_database() AS dbname,
        'DATABASE' AS level,
        nspname || '.' || proname || '(' || proc_param || ')' AS f
    FROM
        func_with_elevated_privileges
    WHERE
        nspname NOT IN ('dbms_scheduler', 'dbms_session', 'pg_catalog', 'sys', 'utl_http')
)
SELECT
    r.rolname,
    func.*,
    'FUNCTION' AS object_type,
    'Elevated Privileges' AS privileges,
    r.rolcanlogin
FROM
    func_with_elevated_privileges_and_db func
JOIN
    pg_roles r ON has_function_privilege(r.rolname, func.f, 'execute') = true;

 rolname | dbname | level | f | object_type | privileges | rolcanlogin
---------+--------+-------+---+-------------+------------+-------------
(0 rows)




-- End functions with elevated permissions
SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    n.nspname || '.' || p.proname AS object_name,
    'FUNCTION' AS privilege_type,
    'FUNCTION OWNER' AS privilege_name,
    r.rolcanlogin AS can_login
FROM
    pg_proc p
JOIN
    pg_namespace n ON p.pronamespace = n.oid
JOIN
    pg_roles r ON r.oid = p.proowner;

 role_name | database_name | object_type | object_name | privilege_type | privileges | rolcanlogin
---------+--------+-------+---+-------------+------------+-------------
