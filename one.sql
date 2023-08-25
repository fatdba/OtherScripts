[ERROR] IndexError: list index out of range
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 892, in lambda_handler
    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
  File "/var/task/lambda_function.py", line 491, in generate_csv_and_pdf_reports_for_the_drift_tables
    header_list = [str(i) for i in result[0]._asdict().keys()]
