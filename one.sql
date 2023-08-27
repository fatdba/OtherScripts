# Function to run a query in RDS 
def run_query(secrets_client, secret_arn, sql):
    try:
        # check if connection to RDS works
        dbconn = pgs.get_connection(pgs.get_secret_dict(secrets_client, secret_arn, "AWSCURRENT"))
        if dbconn:
            pgs.run_query_using_secrets(secrets_client, secret_arn, sql)
        else:
            status = f"Unable to login to server with secret "
            logger.info("%s" % (status)) 
            status_code = -1
            return status_code, status
        status = f"Successfully executed query"
        logger.info("%s" % (status)) 
        status_code = 0
    except Exception as e:
        pass
        status = f"Query execution failed: {e} "
        logger.info("%s" % (status)) 
        status_code = -1

    return status_code, status
