def connect_and_authenticate(secret_dict, port, dbname, use_ssl, host):
    """Attempt to connect and authenticate to a PostgreSQL instance
 
    This helper function tries to connect to the database using connectivity info passed in.
    If successful, it returns the connection, else None
 
    Args:
        - secret_dict (dict): The Secret Dictionary
        - port (int): The databse port to connect to
        - dbname (str): Name of the database
        - use_ssl (bool): Flag indicating whether connection should use SSL/TLS
 
    Returns:
        Connection: The pymongo.database.Database object if successful. None otherwise
 
    Raises:
        KeyError: If the secret json does not contain the expected keys

    """
    if host == None:
        host=secret_dict['host']
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
