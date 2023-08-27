[ERROR] ValueError: too many values to unpack (expected 2)
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 604, in lambda_handler
    create_or_alter_table(summary_table_parameter_list, summary_table_name)
  File "/var/task/lambda_function.py", line 77, in create_or_alter_table
    status_code, status = run_query(secrets_client, reporting_db_secret_arn, sql)
