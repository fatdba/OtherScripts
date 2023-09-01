import os
import boto3
import psycopg2
import pg8000
from datetime import datetime
from botocore.exceptions import ClientError
import logging

# Define your helper functions here (e.g., run_query, create_or_alter_table, update_table, etc.)

def lambda_handler(event, context):
    # ... (previous code) ...

    # Add the new SQL query to generate the "audit_role_privileges_users" report
    sql_users = """
    SELECT a.oid as user_role_id,
           a.rolname as user_role_name,
           b.roleid as other_role_id,
           c.rolname as other_role_name
    FROM pg_roles a
    INNER JOIN pg_auth_members b ON a.oid=b.member
    INNER JOIN pg_roles c ON b.roleid=c.oid;
    """
    
    # Execute the SQL query and retrieve the results
    result_users = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql_users)
    
    # Create the "audit_role_privileges_users" report
    users_report_list = []
    for row in result_users:
        users_report_list.append({
            "user_role_id": row.user_role_id,
            "user_role_name": row.user_role_name,
            "other_role_id": row.other_role_id,
            "other_role_name": row.other_role_name
        })

    # Update the table_names_list to include the new report
    if flag == 2:
        table_names_list = ["public_role_privileges", "audit_role_privileges", "audit_role_privileges_users", summary_table_name, "instances_info", "snapshots_info"]
    elif flag == 1:
        table_names_list = ["audit_role_privileges", "audit_role_privileges_users", summary_table_name, "instances_info", "snapshots_info"]
    else:
        table_names_list = [summary_table_name, "instances_info", "snapshots_info"]

    # ... (rest of the code to generate reports, update_table, and generate_csv_and_pdf_reports_for_the_drift_tables)
