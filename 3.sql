                    select a.oid as user_role_id
                    , a.rolname as user_role_name
                    , a.rolcanlogin as role_can_login
                    , b.roleid as other_role_id
                    , c.rolname as other_role_name
                    , a.rolreplication as has_replication_perm
                    , a.rolcreaterole as has_createrole_perm
                    , a.rolcreatedb as has_createdb_perm
                    from pg_roles a
                    inner join pg_auth_members b on a.oid=b.member
                    inner join pg_roles c on b.roleid=c.oid
                    WHERE
                    a.rolsuper = true
                    OR a.rolreplication = true
                    OR a.rolcreaterole = true
                    OR a.rolcreatedb = true;
