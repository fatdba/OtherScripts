# ... (your existing code)

# Call the function to get the data
audit_role_privileges_userinfo_data = get_audit_role_privileges_userinfo(reporting_db_secrets_client, reporting_db_secret_arn)

# Define the parameter list for the table
audit_role_privileges_userinfo_parameter_list = ["user_role_id", "user_role_name", "other_role_id", "other_role_name"]

# Create or update the table
create_or_alter_table(audit_role_privileges_userinfo_parameter_list, table_name="audit_role_privileges_userinfo")

# Update the table with the retrieved data
for row in audit_role_privileges_userinfo_data:
    # Convert the row object to a list of values
    values = [row[column_name] for column_name in audit_role_privileges_userinfo_parameter_list]

    # Create the parameter string for the columns
    parameter_string = "(" + ", ".join(audit_role_privileges_userinfo_parameter_list) + ")"

    # Create the SQL statement for inserting the row
    sql1 = f"INSERT INTO audit_role_privileges_userinfo {parameter_string} VALUES {tuple(values)};"

    # Execute the SQL statement or perform the necessary database operation here
    # (e.g., execute SQL statement using a database cursor)

    # Print or log the SQL statement for debugging (optional)
    print("SQL Statement:", sql1)

# ... (the rest of your existing code)

# After processing the new table, update the table_names_list as needed
if flag == 2:
    table_names_list = ["public_role_privileges", "audit_role_privileges", "audit_role_privileges_userinfo", summary_table_name, "instances_info", "snapshots_info"]
elif flag == 1:
    table_names_list = ["audit_role_privileges", "audit_role_privileges_userinfo", summary_table_name, "instances_info", "snapshots_info"]
else:
    table_names_list = [summary_table_name, "instances_info", "snapshots_info"]
