def generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    # ... other code ...

    for table_name in table_names_list:
        # Retrieve data from the database
        result = pgs.run_query_using_secrets(reporting_db_secrets_client, reporting_db_secret_arn, f"SELECT * FROM {table_name}")

        if not result:
            # Handle the case where the result is empty (no rows returned)
            print(f"No data found for {table_name}")
            continue

        # Generate headers for the CSV and PDF reports
        header_list = [str(i) for i in result[0]._asdict().keys()]
        
        # ... rest of the code for generating reports ...
