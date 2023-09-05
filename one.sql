    # Execute SQL query to gather users roles information
    users_roles_info = get_users_roles_info(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'])
    
