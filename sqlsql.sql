
-- report name : database_permissions
-- provide a summary of database privileges for each role in the current PostgreSQL database. 
-- It lists the roles, the database they have privileges on, the types of privileges they have (CONNECT, CREATE, TEMPORARY), and whether they can log in.
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









-- report name : schema_privs_role
-- summary of schema privileges for each role and schema combination
-- showing which roles have 'CREATE' and 'USAGE' privileges on each schema in the current PostgreSQL database. 
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
	
	
	
	
	
	
	
-- report name : role_specific_privs
-- identify and list database roles (owners) that have specific privileges (CREATE and USAGE) on schemas in the current database.
-- includes information about the database, schema, and whether the role can log in. 
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
 
 
 
 
 
 
	
	
-- report name : role_priv_tables
-- identify and list the owners of tables in the database, along with their privileges. 
-- It checks whether a role has the privilege to use tables in certain schemas and excludes system schemas from consideration.
-- includes information about the database, table, and whether the role can log in.
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







	

-- report name : role_specific_privs_table
-- identify and list the roles that have specific privileges on tables in the database.
-- It checks for a set of privileges on tables in non-system schemas while excluding cases where the role owns the table. 
-- includes information about the database, table, and whether the role can log in.
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





	

-- report name : views_ownership_usage_privs
-- identify and list the roles that have the privilege to use (or access) views in the database.
-- checks for schema usage privilege on views in non-system schemas while excluding system schemas and includes information about the database, view, and whether the role can log in. 
-- The query specifically focuses on view ownership and usage privileges.
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







  
  
-- report name : view_privs_role
-- identify and list the roles that have specific privileges on views in the database.
-- checks for schema usage privilege on views in non-system schemas while excluding system schemas and includes information about the database, view, and whether the role can log in. 
-- constructs an array of view privileges for each role.
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







  
  
-- report name : sequence_ownership_usage_privs
-- identify and list the roles that have specific privileges (SELECT and UPDATE) on sequences in the database.
-- checks for schema usage privilege on sequences in non-system schemas while excluding system schemas and includes information about the database, sequence, and whether the role can log in. 
-- focuses on sequence ownership and usage privileges.
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








-- report name : roles_specific_privileges_sequences
-- identify and list the roles that have both SELECT and UPDATE privileges on sequences in the database. 
-- It filters out sequences in specific schemas, focuses on sequences, and includes information about the database, sequence, privileges, and whether the role can log in.
-- includes roles with both SELECT and UPDATE privileges on sequences.
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







	
	
	
-- report name : roles_privs_fdw
-- identify and list the roles that have the USAGE privilege on foreign data wrappers (FDWs) in the database.
-- focuses on FDW ownership and USAGE privileges. 
-- which roles have the authority to use FDWs in the database.
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





	
	
-- report name : roles_login_fdw
-- identify and list the roles that have the USAGE privilege on foreign data wrappers (FDWs) in the database. 
-- constructs an array of privileges for each role and excludes cases where the role owns the FDW.
-- which roles can use FDWs in the database and whether they can log in
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




	

	
-- file name : roles_privs_language
-- identify and list the roles that have the USAGE privilege on languages in the database. 
-- constructs an array of privileges for each role based on the USAGE privilege on specific languages. 
-- understand which roles can use particular languages for writing stored procedures and functions in the database and whether they can log in.
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
 
 
 
 
 
	
	
-- report name : function_privs_elevated
-- identify database roles that have the privilege to execute functions with elevated privileges in the database.
-- functions defined with specific security considerations and provides information about the role, the functions, and whether the role can log in.
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





	
	
	
-- report name : functions_ownership_roles
-- identify and list the database roles that own functions in the database
-- provides information about the roles, the functions they own, and whether the roles can log in
-- useful for understanding the ownership of functions within the database.
SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    n.nspname || '.' || p.proname AS object_name,
    'FUNCTION' AS privilege_type,
    'FUNCTION OWNER' AS privilege_name,\
    r.rolcanlogin AS can_login
FROM
    pg_proc p
JOIN
    pg_namespace n ON p.pronamespace = n.oid
JOIN
    pg_roles r ON r.oid = p.proowner;
	
	
 role_name | database_name | object_type |                       object_name                       | privilege_type | privilege_name | can_login
-----------+---------------+-------------+---------------------------------------------------------+----------------+----------------+-----------
 postgres  | postgres      | DATABASE    | pg_catalog.boolin                                       | FUNCTION       | FUNCTION OWNER | t
 postgres  | postgres      | DATABASE    | pg_catalog.boolout                                      | FUNCTION       | FUNCTION OWNER | t
