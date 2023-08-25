Test Event Name
test

Response
{
  "errorMessage": "list index out of range",
  "errorType": "IndexError",
  "requestId": "669a39d6-c3e6-4955-a304-65cc801f3dc6",
  "stackTrace": [
    "  File \"/var/task/drift_detection/lambda_function.py\", line 805, in lambda_handler\n    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)\n",
    "  File \"/var/task/drift_detection/lambda_function.py\", line 430, in generate_csv_and_pdf_reports_for_the_drift_tables\n    header_list = [str(i) for i in result[0]._asdict().keys()]\n"
  ]
}

Function Logs
4-65cc801f3dc6	DB name passed as parameter: None
[INFO]	2023-08-25T02:37:17.061Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	DB name being used: michaeltestcdb_db
[INFO]	2023-08-25T02:37:17.097Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	Successfully established SSL/TLS connection as user 'db_admin' with host: 'michaeltestc-db-v2.cluster-c9fzyhbqneoo.us-east-2.rds.amazonaws.com'
[INFO]	2023-08-25T02:37:17.116Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	Printing Output
[INFO]	2023-08-25T02:37:17.116Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	[Row(id=1, recordedtime=datetime.datetime(2023, 7, 19, 13, 16, 36, 265378), scanid='1', accountid='ALL', rdsidentifier='NA', secretarn='NA', summary='Exception Caught - Error = An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:sts::589839611729:assumed-role/drift_detection_test/edm-rds-drift-detection is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::009973789139:role/list-org-accounts'), Row(id=2, recordedtime=datetime.datetime(2023, 7, 19, 13, 16, 36, 265378), scanid='1', accountid='472131731879', rdsidentifier='NA', secretarn='NA', summary='Assume role connection successful'), Row(id=3, recordedtime=datetime.datetime(2023, 7, 19, 13, 16, 36, 265378), scanid='1', accountid='472131731879', rdsidentifier='billytest9-db', secretarn='arn:aws:secretsmanager:us-east-2:472131731879:secret:/secret/billytest9-db/rds-password-Udxcnh', summary='Secret Found for the rds in secret manager'), Row(id=4, recordedtime=datetime.datetime(2023, 7, 19, 13, 16, 36, 265378), scanid='1', accountid='472131731879', rdsidentifier='billytest9-db', secretarn='arn:aws:secretsmanager:us-east-2:472131731879:secret:/secret/billytest9-db/rds-password-Udxcnh', summary='Successfully Connected to db with Secret'), Row(id=5, recordedtime=datetime.datetime(2023, 8, 25, 2, 37, 17, 98552), scanid='2', accountid='ALL', rdsidentifier='NA', secretarn='NA', summary='Exception Caught - Error = An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:sts::589839611729:assumed-role/drift_detection_test/edm-rds-drift-detection is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::009973789139:role/list-org-accounts')]
[INFO]	2023-08-25T02:37:17.120Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	query_using_secrets: Successfully executed query in PostgreSQL DB using secret in arn:aws:secretsmanager:us-east-2:589839611729:secret:/secret/michaeltestc-db/rds-password-gok7XS.
[INFO]	2023-08-25T02:37:17.121Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	Successfully executed query
s3 bucket: edm-db-drift-detection-reports-sandbox Exists
[INFO]	2023-08-25T02:37:17.347Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	DB name passed as parameter: None
[INFO]	2023-08-25T02:37:17.349Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	DB name being used: michaeltestcdb_db
[INFO]	2023-08-25T02:37:17.384Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	Successfully established SSL/TLS connection as user 'db_admin' with host: 'michaeltestc-db-v2.cluster-c9fzyhbqneoo.us-east-2.rds.amazonaws.com'
[INFO]	2023-08-25T02:37:17.399Z	669a39d6-c3e6-4955-a304-65cc801f3dc6	query_using_secrets: Successfully executed query in PostgreSQL DB using secret in arn:aws:secretsmanager:us-east-2:589839611729:secret:/secret/michaeltestc-db/rds-password-gok7XS.
[ERROR] IndexError: list index out of range
Traceback (most recent call last):
  File "/var/task/drift_detection/lambda_function.py", line 805, in lambda_handler
    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
  File "/var/task/drift_detection/lambda_function.py", line 430, in generate_csv_and_pdf_reports_for_the_drift_tables
    header_list = [str(i) for i in result[0]._asdict().keys()]END RequestId: 669a39d6-c3e6-4955-a304-65cc801f3dc6
REPORT RequestId: 669a39d6-c3e6-4955-a304-65cc801f3dc6	Duration: 1198.73 ms	Billed Duration: 1199 ms	Memory Size: 10240 MB	Max Memory Used: 137 MB	Init Duration: 1336.07 ms	
XRAY TraceId: 1-64e813da-56e6f7c244e8e04c0dd7c134	SegmentId: 60a94ba9371a8619	Sampled: true

Request ID
669a39d6-c3e6-4955-a304-65cc801f3dc6
