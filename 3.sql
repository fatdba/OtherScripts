1. SQL Query to Select all from user_roles_table where scan_id is max
	2. Get all_user_roles from above sql query
	3. Filter out users with sensitive permissions from all_user_roles and
		save to users_with_sensitive_permissions list
	4. for each user in users_with_sensitive_permissions_list
		if user['has_createrole_perm']:
			execute this sql query
			ALTER ROLE user['user_role_name'] NOCREATEROLE;

		if user['has_createdb_perm']:
			execute this sql query
			ALTER ROLE user['user_role_name'] NOCREATEDB;

		execute this sql query
		ALTER ROLE user['user_role_name'] NOSUPERUSER;
