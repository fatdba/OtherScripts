{
  "errorMessage": "list index out of range",
  "errorType": "IndexError",
  "requestId": "ad6856f0-840b-4787-a194-64e794d14c14",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 895, in lambda_handler\n    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)\n",
    "  File \"/var/task/lambda_function.py\", line 495, in generate_csv_and_pdf_reports_for_the_drift_tables\n    Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]\n"
  ]
}
