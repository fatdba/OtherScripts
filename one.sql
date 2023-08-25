  "errorMessage": "list index out of range",
  "errorType": "IndexError",
  "requestId": "cbd216f7-ede3-47e7-ad4a-8e00ea343a4a",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 896, in lambda_handler\n    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)\n",
    "  File \"/var/task/lambda_function.py\", line 496, in generate_csv_and_pdf_reports_for_the_drift_tables\n    Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]\n"
  ]
}
