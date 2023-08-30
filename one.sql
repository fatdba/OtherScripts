logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get assume role credentials
def get_assume_role_session(sts_role):
    sts_client = boto3.client('sts')
    return sts_client.assume_role(
        RoleArn=sts_role,
        RoleSessionName="accountSelector"
    )['Credentials']

def connect_and_authenticate(secret_dict, port, dbname, use_ssl, host):
    if host == None:
        host = secret_dict['host']
    if dbname == None:
        dbname = secret_dict['dbname'] if 'dbname' in secret_dict else "postgres"

    # Try to obtain a connection to the db
    logger.info(f"Attempting login with |{secret_dict['password']}|")  # Use for TESTING ONLY!
    try:
        if use_ssl:
            logger.info("Attempting login with SSL")
            # Setting sslmode='verify-full' will verify the server's certificate and check the server's host name
            conn = pgdb.connect(host, user=secret_dict['username'], password=secret_dict['password'], database=dbname, port=port,
                                connect_timeout=5, sslrootcert='/etc/pki/tls/cert.pem', sslmode='verify-full')
        else:
            logger.info("Attempting login without SSL")
            conn = pgdb.connect(host, user=secret_dict['username'], password=secret_dict['password'], database=dbname, port=port,
                                connect_timeout=5, sslmode='disable')
        logger.info("Successfully established %s connection as user '%s' with host: '%s'" % ("SSL/TLS" if use_ssl else "non SSL/TLS", secret_dict['username'], secret_dict['host']))
        return conn
    except pg.InternalError as e:
        logger.info("pgdb.connect exception: %s" % e)
        if "server does not support SSL, but SSL was required" in e.args[0]:
            logger.error("Unable to establish SSL/TLS handshake, SSL/TLS is not enabled on the host: %s" % secret_dict['host'])
        elif re.search('server common name ".+" does not match host name ".+"', e.args[0]):
            logger.error("Hostname verification failed when estlablishing SSL/TLS Handshake with host: %s" % secret_dict['host'])
        elif re.search('no pg_hba.conf entry for host ".+", SSL off', e.args[0]):
            logger.error("Unable to establish SSL/TLS handshake, SSL/TLS is enforced on the host: %s" % secret_dict['host'])
        return None

# Function to run a query in RDS 
def run_query(secrets_client, secret_arn, sql):
    try:
        # Your code for running the query goes here
        pass
    except Exception as e:
        logger.error("An error occurred while running the query: %s" % e)
