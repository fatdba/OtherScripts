def run_query(secrets_client, secret_arn, sql):
    try:
        # ... (your existing code)
        
        result = pgs.run_query_using_secrets(secrets_client, secret_arn, sql)
        
        status = "Successfully executed query"
        status_code = 0
        
    except Exception as e:
        # ... (your existing code)
        
    return status_code, status, result
