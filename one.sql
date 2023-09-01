def get_audit_role_privileges_userinfo(secrets_client, secret_arn):
    sql = """
    select a.oid as user_role_id
    , a.rolname as user_role_name
    , b.roleid as other_role_id
    , c.rolname as other_role_name
    from pg_roles a
    inner join pg_auth_members b on a.oid=b.member
    inner join pg_roles c on b.roleid=c.oid;
    """
    result = pgs.run_query_using_secrets(secrets_client, secret_arn, sql)
    return result




# Call the function to get the data
audit_role_privileges_userinfo_data = get_audit_role_privileges_userinfo(reporting_db_secrets_client, reporting_db_secret_arn)

# Define the parameter list for the table
audit_role_privileges_userinfo_parameter_list = ["user_role_id", "user_role_name", "other_role_id", "other_role_name"]

# Create or update the table
create_or_alter_table(audit_role_privileges_userinfo_parameter_list, table_name="audit_role_privileges_userinfo")

# Update the table with the retrieved data
update_table(audit_role_privileges_userinfo_data, audit_role_privileges_userinfo_parameter_list, table_name='audit_role_privileges_userinfo')
