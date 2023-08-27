[ERROR] ValueError: not enough values to unpack (expected 3, got 2)
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 584, in lambda_handler
    status_code,status,result=run_query(reporting_db_secrets_client,reporting_db_secret_arn,sql)
