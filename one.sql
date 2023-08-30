# ... (previous code)
#updates summary table
update_table(summary_list, summary_table_parameter_list, summary_table_name)
if flag == 2:
    table_names_list = ["public_role_privileges", "audit_role_privileges", summary_table_name, "instances_info", "snapshots_info"]
elif flag == 1:
    table_names_list = ["audit_role_privileges", summary_table_name, "instances_info", "snapshots_info"]
else:
    table_names_list = [summary_table_name, "instances_info", "snapshots_info"]
#generate CSV and pdf files of the tables for each scan
print("flag:", flag)
print(table_names_list)
generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
