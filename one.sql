{
  "errorMessage": "list index out of range",
  "errorType": "IndexError",
  "requestId": "080d7ca0-5da4-47cb-89ea-2e1c55d9caef",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 954, in lambda_handler\n    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)\n",
    "  File \"/var/task/lambda_function.py\", line 521, in generate_csv_and_pdf_reports_for_the_drift_tables\n    header_list = [str(i) for i in result[0]._asdict().keys()]\n"
  ]
}
