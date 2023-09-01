# Modify the table_names_list based on the value of 'flag'
if flag == 2:
    table_names_list = ["public_role_privileges", "audit_role_privileges", "audit_role_privileges_userinfo", summary_table_name, "instances_info", "snapshots_info"]
elif flag == 1:
    table_names_list = ["audit_role_privileges", "audit_role_privileges_userinfo", summary_table_name, "instances_info", "snapshots_info"]
else:
    table_names_list = ["audit_role_privileges_userinfo", summary_table_name, "instances_info", "snapshots_info"]

# Call the function to get the data
audit_role_privileges_userinfo_data = get_audit_role_privileges_userinfo(reporting_db_secrets_client, reporting_db_secret_arn)

# Define the parameter list for the table
audit_role_privileges_userinfo_parameter_list = ["user_role_id", "user_role_name", "other_role_id", "other_role_name"]

# Create or update the table
create_or_alter_table(audit_role_privileges_userinfo_parameter_list, table_name="audit_role_privileges_userinfo")

# Update the table with the retrieved data
update_table(audit_role_privileges_userinfo_data, audit_role_privileges_userinfo_parameter_list, table_name='audit_role_privileges_userinfo')
