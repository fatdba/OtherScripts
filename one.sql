        users_roles_info = []
        
        # print("rds_list: ", rds_list)
        if audit_roles_list:
            flag = 1
            parameter_list = audit_roles_list[0].keys()
            #Creates or update audit role privileges table
            create_or_alter_table(parameter_list, table_name="audit_role_privileges")
            update_table(audit_roles_list, parameter_list, table_name='audit_role_privileges')
        if public_roles_list:
            flag = 2
            parameter_list = public_roles_list[0].keys()
            #Creates or update public role privileges table
            create_or_alter_table(parameter_list, table_name="public_role_privileges")
            update_table(public_roles_list, parameter_list, table_name='public_role_privileges')
        if users_roles_info:
            flag = 3 
            parameter_list = users_roles_info[0].keys()
            create_or_alter_table(parameter_list, table_name="users_roles_info")
            update_table(users_roles_info, parameter_list, table_name='users_roles_info')

    #updates summary table
    update_table(summary_list, summary_table_parameter_list, summary_table_name)
    if flag == 2:
        table_names_list = ["public_role_privileges", "audit_role_privileges",summary_table_name,"instances_info","snapshots_info"]
    elif flag == 1:
        table_names_list = ["audit_role_privileges",summary_table_name,"instances_info","snapshots_info"]
    else:
        table_names_list = [summary_table_name,"instances_info","snapshots_info"]
    #generate CSV and pdf files of the tables for each scan
    print("flag:", flag)
    print(table_names_list)
    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
