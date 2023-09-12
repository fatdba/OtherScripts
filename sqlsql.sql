SELECT r.rolname, datname, array(select privs from unnest(ARRAY[
( CASE WHEN has_database_privilege(r.rolname,c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)]) foo(privs) 
WHERE privs IS NOT NULL), 'DATABASE',r.rolcanlogin FROM pg_database c WHERE 
has_database_privilege(r.rolname,c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname =current_database();

ERROR:  missing FROM-clause entry for table "r"
LINE 1: SELECT r.rolname, datname, array(select privs from unnest(AR...

  WITH roles AS (
    SELECT rolname
    FROM pg_roles
    WHERE rolcanlogin = true
)
SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', r.rolcanlogin
FROM pg_database c
JOIN roles r ON true
WHERE has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP') AND datname = current_database();


RROR:  column r.rolcanlogin does not exist
LINE 15: ), 'DATABASE', r.rolcanlogin
                        ^



SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', (
    SELECT rolcanlogin
    FROM pg_roles
    WHERE rolname = r.rolname
)) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();


ERROR:  syntax error at or near ")"
LINE 14: )) AS result
          ^

SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', (
    SELECT rolcanlogin
    FROM pg_roles
    WHERE rolname = r.rolname
)) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();





SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.rolname AND rolcanlogin) THEN 'true' ELSE 'false' END) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();

ERROR:  syntax error at or near ")"
LINE 10: ...name AND rolcanlogin) THEN 'true' ELSE 'false' END) AS resul...
                                                              ^






SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', CASE WHEN r2.rolcanlogin IS NOT NULL THEN 'true' ELSE 'false' END) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
LEFT JOIN pg_roles r2 ON r.rolname = r2.rolname
WHERE datname = current_database();






ostgres-# WHERE datname = current_database();
ERROR:  syntax error at or near ")"
LINE 10: ...lcanlogin IS NOT NULL THEN 'true' ELSE 'false' END) AS resul...
                                                              ^




SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', (
    SELECT CASE WHEN rolcanlogin THEN 'true' ELSE 'false' END
    FROM pg_roles
    WHERE rolname = r.rolname
)) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();








SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', (
    SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = r.rolname
        AND rolcanlogin
    ) THEN 'true' ELSE 'false' END
)) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();

ERROR:  syntax error at or near ")"
LINE 17: )) AS result
          ^


SELECT r.rolname, datname, array(
    SELECT privs
    FROM unnest(ARRAY[
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CONNECT') THEN 'CONNECT' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'CREATE') THEN 'CREATE' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
        (CASE WHEN has_database_privilege(r.rolname, c.oid, 'TEMP') THEN 'CONNECT' ELSE NULL END)
    ]) AS foo(privs)
    WHERE privs IS NOT NULL
), 'DATABASE', (
    SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = r.rolname
        AND rolcanlogin
    ) THEN 'true' ELSE 'false' END
)) AS result
FROM pg_database c
JOIN pg_roles r ON has_database_privilege(r.rolname, c.oid, 'CONNECT,CREATE,TEMPORARY,TEMP')
WHERE datname = current_database();
