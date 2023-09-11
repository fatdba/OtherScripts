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




-- Database permissions
			insert into audit_role_privileges (rolname,dbname,privileges,level,canlogin)
			SELECT r.rolname, datname, array(select privs from unnest(ARRAY[
			( CASE WHEN has_database_privilege(r.rolname,c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
			(CASE WHEN has_database_privilege(r.rolname,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
			(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
			(CASE WHEN has_database_privilege(r.rolname,c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)])foo(privs) 
			WHERE privs IS NOT NULL), 'DATABASE',r.rolcanlogin FROM pg_database c WHERE 
			has_database_privilege(r.rolname,c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname =current_database();
			
			
		
		
			-- Schema Privileges
			insert into audit_role_privileges (rolname,dbname,object_name,object_type,level,privileges,canlogin)
			select r.rolname,catalog_name,schema_name,'SCHEMA' as level, 'DATABASE',array(select privs from unnest(ARRAY[
			( CASE WHEN has_schema_privilege(r.rolname,schema_name,'CREATE') THEN 'CREATE' ELSE NULL END),
			(CASE WHEN has_schema_privilege(r.rolname,schema_name,'USAGE') THEN 'USAGE' ELSE NULL END)])foo(privs) 
			WHERE privs IS NOT NULL),r.rolcanlogin
			from information_schema.schemata c
			where has_schema_privilege(r.rolname,schema_name,'CREATE,USAGE') 
			and c.schema_name not like 'pg_temp%'
			and schema_owner <> r.rolname;
			
			insert into audit_role_privileges (rolname,dbname,object_name,object_type,level,privileges,canlogin)
			select r.rolname,catalog_name,schema_name,'SCHEMA' as level, 'DATABASE','SCHEMA OWNER',r.rolcanlogin
			from information_schema.schemata c
			where has_schema_privilege(r.rolname,schema_name,'CREATE,USAGE') 
			and c.schema_name not like 'pg_temp%'
			and schema_owner = r.rolname;
			
			
			-- Table privileges
			-- Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'TABLE', 'TABLE OWNER' ,
			r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid 
			where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
			c.relowner =  r.oid
			AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			;
			
			-- Non Owner privilges
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'TABLE', array(select privs from unnest(ARRAY [ 
			( CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) where privs is not null) ,
			r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid 
			where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
			has_table_privilege(r.rolname,c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') 
			AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			and c.relowner <>  r.oid
			;
			
			
			-- View privileges
			-- Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'VIEW','VIEW OWNER' ,
			r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
			and  c.relkind='v' AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			and c.relowner =  r.oid;
			
			-- Non Owner permissions
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT  r.rolname,current_database(),'DATABASE',c.oid::regclass,'VIEW',
			array(select privs from unnest(ARRAY [
			( CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) where privs is not null) ,
			r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
			and  c.relkind='v' and has_table_privilege(r.rolname,c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') 
			AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			and c.relowner <>  r.oid;
		
		
			-- Sequence privileges
			-- Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',c.oid::regclass,'SEQUENCE',
			'SEQUENCE OWNER' ,r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
			and  c.relkind='S' and
			has_table_privilege(r.rolname,c.oid,'SELECT,UPDATE')  
			AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			and c.relowner =  r.oid;
			
			-- Non Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',c.oid::regclass,'SEQUENCE',
			array(select privs from unnest(ARRAY [
			( CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
			(CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END)]) foo(privs) where privs is not null) ,r.rolcanlogin
			FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
			and  c.relkind='S' and
			has_table_privilege(r.rolname,c.oid,'SELECT,UPDATE')  
			AND has_schema_privilege(r.rolname,c.relnamespace,'USAGE')
			and c.relowner <>  r.oid;
			
		
						
			-- Foreign data wrapper privileges
			-- Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',fdwname,'FDW', 'FDW OWNER',r.rolcanlogin
			FROM pg_catalog.pg_foreign_data_wrapper 
			WHERE has_foreign_data_wrapper_privilege(r.rolname,fdwname,'USAGE')
			and fdwowner =  r.oid;
			

			-- Non Owner
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',fdwname,'FDW', ARRAY[
			(CASE WHEN has_foreign_data_wrapper_privilege(r.rolname,fdwname,'USAGE') THEN 'USAGE' ELSE NULL END)] ,r.rolcanlogin
			FROM pg_catalog.pg_foreign_data_wrapper 
			WHERE has_foreign_data_wrapper_privilege(r.rolname,fdwname,'USAGE')
			and fdwowner <>  r.oid;
			
			
			-- Language  privileges
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',l.lanname,'LANGUAGE',
			ARRAY[(CASE WHEN has_language_privilege(r.rolname,lanname,'USAGE') THEN 'USAGE' ELSE NULL END)] ,r.rolcanlogin
			FROM pg_catalog.pg_language l where has_language_privilege(r.rolname,lanname,'USAGE') 
			;
		
		
			-- Function privileges		
			-- Get functions with elevated permissions with security definer
			

			with elevated_perm_proc as
			(
			SELECT  row_number() over( order by p.oid),p.oid,nspname,proname,format_type(unnest(proargtypes)::oid,NULL)
			FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
			pg_authid a ON a.oid = p.proowner 
			WHERE prosecdef OR NOT proconfig IS NULL
			),

			func_with_elvated_priv as
			(
			select  oid,nspname,proname,array_to_string(array_agg(format_type),',') as proc_param
			from elevated_perm_proc
			group by oid,nspname,proname
			union
			select p.oid,nspname,proname,' ' as proc_param
			FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
			pg_authid a ON a.oid = p.proowner 
			WHERE (prosecdef OR NOT proconfig IS NULL)
			and p.oid not in
			(select oid from elevated_perm_proc )
			),
			func_with_elvated_priv1 as
			( select current_database() as dbname,'DATABASE' as level ,nspname||'.'||proname||'('||proc_param||')' as f
			from func_with_elvated_priv 
                        where nspname not in ('dbms_scheduler','dbms_session','pg_catalog','sys','utl_http')
			)
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, func.*,'FUNCTION','Elevated Privileges',r.rolcanlogin
			from func_with_elvated_priv1 func
			where has_function_privilege(r.rolname,func.f,'execute')=true;

			-- End function with elevated permissions
			
			--SELECT r.rolname, current_database(),'DATABASE',nspname||'.'||proname,'FUNCTION','Elevated Privileges',r.rolcanlogin
			--FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
			--pg_authid a ON a.oid = p.proowner WHERE prosecdef OR NOT proconfig IS NULL;
			
			insert into audit_role_privileges (rolname,dbname,level,object_name,object_type,privileges,canlogin)
			SELECT r.rolname, current_database(),'DATABASE',nspname||'.'||proname,'FUNCTION','FUNCTION OWNER',r.rolcanlogin
			FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
			and r.oid = p.proowner ;
			
