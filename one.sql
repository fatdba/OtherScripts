{
  "errorMessage": "too many values to unpack (expected 2)",
  "errorType": "ValueError",
  "requestId": "c9ef3dd8-ff28-4729-8328-b06782b5fd57",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 601, in lambda_handler\n    create_or_alter_table(summary_table_parameter_list, summary_table_name)\n",
    "  File \"/var/task/lambda_function.py\", line 79, in create_or_alter_table\n    status_code,status=run_query(secrets_client,reporting_db_secret_arn,sql)\n"
  ]
}
