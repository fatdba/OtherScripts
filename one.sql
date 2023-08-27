# ...
sql = f"""
SELECT nextval('scan_sequence');
"""
status_code, status = run_query(reporting_db_secrets_client, reporting_db_secret_arn, sql)
print("result: ", result)
scan_id = str(result[0]._asdict()["nextval"])
# ...
