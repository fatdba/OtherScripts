if flag == 3:
    table_names_list = ["public_role_privileges", "audit_role_privileges", "users_roles_info", summary_table_name, "instances_info", "snapshots_info"]
elif flag == 2:
    table_names_list = ["public_role_privileges", "audit_role_privileges", summary_table_name, "instances_info", "snapshots_info"]
elif flag == 1:
    table_names_list = ["audit_role_privileges", summary_table_name, "instances_info", "snapshots_info"]
else:
    table_names_list = [summary_table_name, "instances_info", "snapshots_info"]
