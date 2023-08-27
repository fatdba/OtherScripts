Test Event Name
test-prashant

Response
{
  "errorMessage": "list index out of range",
  "errorType": "IndexError",
  "requestId": "81e0972a-1833-4d6b-bf15-368e9ab7214f",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 896, in lambda_handler\n    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)\n",
    "  File \"/var/task/lambda_function.py\", line 496, in generate_csv_and_pdf_reports_for_the_drift_tables\n    Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]\n"
  ]
}

Function Logs
LS connection as user 'db_admin' with host: 'michaeltestc-db-v2.cluster-c9fzyhbqneoo.us-east-2.rds.amazonaws.com'
ERROR]	2023-08-27T13:44:21.977Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	query_using_secrets: Execption encountered executing query ERROR:  column "Exception Caught - Error = argument of type 'NoneType' is not i" does not exist
LINE 1: ..., Summary) VALUES ('6', 'ALL', 'ALL', 'NA', 'NA', "Exception...
                                                             ^
.
[INFO]	2023-08-27T13:44:21.978Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	Query execution failed: query_using_secrets: Execption encountered executing query ERROR:  column "Exception Caught - Error = argument of type 'NoneType' is not i" does not exist
LINE 1: ..., Summary) VALUES ('6', 'ALL', 'ALL', 'NA', 'NA', "Exception...
                                                             ^
. 
flag: 0
['connection_summary', 'instances_info', 'snapshots_info']
s3 bucket: edm-db-drift-detection-reports-sandbox Exists
connection_summary
[INFO]	2023-08-27T13:44:22.158Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	DB name passed as parameter: None
[INFO]	2023-08-27T13:44:22.158Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	DB name being used: michaeltestcdb_db
[INFO]	2023-08-27T13:44:22.196Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	Successfully established SSL/TLS connection as user 'db_admin' with host: 'michaeltestc-db-v2.cluster-c9fzyhbqneoo.us-east-2.rds.amazonaws.com'
[INFO]	2023-08-27T13:44:22.203Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	query_using_secrets: Successfully executed query in PostgreSQL DB using secret in arn:aws:secretsmanager:us-east-2:589839611729:secret:/secret/michaeltestc-db/rds-password-gok7XS.
[WARNING]	2023-08-27T13:44:22.203Z	81e0972a-1833-4d6b-bf15-368e9ab7214f	No rows returned in the query result.
[ERROR] IndexError: list index out of range
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 896, in lambda_handler
    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
  File "/var/task/lambda_function.py", line 496, in generate_csv_and_pdf_reports_for_the_drift_tables
    Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]END RequestId: 81e0972a-1833-4d6b-bf15-368e9ab7214f
REPORT RequestId: 81e0972a-1833-4d6b-bf15-368e9ab7214f	Duration: 1014.55 ms	Billed Duration: 1015 ms	Memory Size: 10240 MB	Max Memory Used: 136 MB	Init Duration: 1153.87 ms

Request ID
81e0972a-1833-4d6b-bf15-368e9ab7214f
