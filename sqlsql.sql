def generate_csv_and_pdf_reports_for_the_drift_tables(secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    """
    Function to generate CSV and pdf reports from the tables in the drift reporting database.
    secrets_client: Parameter to connect to the Drift Reporting DB.
    table_names_list: List of all the drift tables to generate CSV and PDF reports from.
    scan_id: Represents the Scan ID for this current lambda invocation. Scan ID will be incremented with each invocation.
    """
    # ... (Previous code)

    # Looping Through Tables
    for each_table in table_names_list:
        print(each_table)
        # Get table data
        sql = f"""
        SELECT * FROM {each_table} WHERE scanid = {str(scan_id)}::varchar;
        """
        print("before_run_query_using_secrets")
        result = pgs.run_query_using_secrets(secrets_client, reporting_db_secret_arn, sql)
        print("after_run_query_using_secrets")
        print(result)
        print("printresult")
        result_list = [each._asdict() for each in result]

        # Check if result is empty
        if not result_list:
            # If the result is empty, create empty CSV and PDF reports
            header_list = ["No data available"]
            result_list = [{"No data available": ""}]
        else:
            # If the result is not empty, parse it as before
            header_list = [str(i) for i in result[0]._asdict().keys()]

        # ... (Rest of the code remains unchanged)
