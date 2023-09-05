# Loop through list of target accounts
for acct_id in acct_ids_dict.keys():
    # ...

    # Execute SQL query to gather audit_role_privileges data
    audit_roles_list = get_audit_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], audit_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'])
    
    # Execute SQL query to gather public_role_privileges data
    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=1)
    
    # Execute SQL query to gather users_roles_info data
    users_roles_info = get_users_roles_info(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'])
    
    # Process and store the users_roles_info data as needed
    
    # Check if users_roles_info data is available
    if users_roles_info:
        # Set a flag to indicate the presence of data
        flag = 3  # You can use a different flag value if needed

        # Define the parameter list based on the structure of users_roles_info
        parameter_list = users_roles_info[0].keys()
        
        # Create or update the users_roles_info table
        create_or_alter_table(parameter_list, table_name="users_roles_info")
        
        # Update the users_roles_info table with the collected data
        update_table(users_roles_info, parameter_list, table_name='users_roles_info')
