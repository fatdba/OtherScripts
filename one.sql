[ERROR] ValueError: too many values to unpack (expected 2)
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 586, in lambda_handler
    status_code, status = run_query(reporting_db_secrets_client, reporting_db_secret_arn, sql)
