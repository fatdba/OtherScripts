def lambda_handler(event, context):
    #SQL query for dropping the tables

    # reporting_db_secrets_client = boto3.client('secretsmanager')
    # reporting_db_secret_arn = os.getenv("db_secret_arn")
    # sql = f"""
    # DROP TABLE IF EXISTS instances_info;
    # DROP TABLE IF EXISTS snapshots_info;
    # DROP TABLE IF EXISTS audit_role_privileges;
    # DROP TABLE IF EXISTS connection_summary;
    # DROP TABLE IF EXISTS public_role_privileges;
    # DROP SEQUENCE IF EXISTS scan_sequence;
    # """
    # status_code,status=run_query(reporting_db_secrets_client,reporting_db_secret_arn,sql)
    
    flag = 0
    
    # Call the connect_and_authenticate function with appropriate params 
    conn = connect_and_authenticate(secret_dict, port, dbname, use_ssl, host)
    
    # if conn is not None:
        
    #Secret client and db secret arn to connect to drift reporting DB
    reporting_db_secrets_client = boto3.client('secretsmanager')
    reporting_db_secret_arn = os.getenv("db_secret_arn")

    #SQL query for creating the sequence if not exists
    sql = f"""
    CREATE SEQUENCE IF NOT EXISTS scan_sequence
    start with 1
    increment by 1
    minvalue 1
    maxvalue 1000
    cycle;
    """
    status_code,status=run_query(reporting_db_secrets_client,reporting_db_secret_arn,sql)
    
    #SQL query to get present scan ID and increment Scan ID sequence by 1.
    sql = f"""
    SELECT nextval('scan_sequence');
    """
    result = pgs.run_query_using_secrets(reporting_db_secrets_client, reporting_db_secret_arn, sql)
    print("result: ", result)
    scan_id = str(result[0]._asdict()["nextval"])
    
    #table name
    summary_table_name = "connection_summary"
    
    #variable to store the All the actions done by this lambda. 
    summary_list = []
    
    #list contains the column header names for the connection_summary table.
    #To create new column, Add new column name at the end of the list.
    #If this list updated then while adding the updating to summary_list the this new column must be added
    summary_table_parameter_list = ["ScanID", "AccountID", "AccountName", "RDSIdentifier", "SecretARN", "Summary"]
    
    #Creates connection_summary table.
    create_or_alter_table(summary_table_parameter_list, summary_table_name)

    #Get list of account ID's based on environment
    acct_ids_dict, error = get_account_ids()
    # acct_ids = ["728226656595"]
    if error != "":
        #If any error with summary list refer Comment above the summary_table_parameter_list
        summary_list.append({"ScanID":scan_id, "AccountID":"ALL", "AccountName":"ALL", "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
    print(len(acct_ids_dict))

    #loop through list of target accounts
    for acct_id in acct_ids_dict.keys():
        # Cross account assume role
        try:
            #Formulating the role arn to assume
            master_role_arn_to_assume = "arn:aws:iam::{}:role/edm/{}".format(acct_id, "LambdaCrossAccountFunctionRole")
            #Getting the assume role credentials on target account
            org_sts_token = get_assume_role_session(master_role_arn_to_assume)
            #If any error with summary list refer Comment above the summary_table_parameter_list
            summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":"Assume role connection successful"})
        except ClientError as client_error:
            #If any error with summary list refer Comment above the summary_table_parameter_list
            summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":"Error Assuming the role on target account"})
            logger.info("Exception Caught - Error = %s" %( client_error))
            print("exception4 $$$$$$$")
            continue
    
        #create rds service client using the assumed role credentials
        rds_client = boto3.client('rds',
            aws_access_key_id=org_sts_token['AccessKeyId'],
            aws_secret_access_key=org_sts_token['SecretAccessKey'],
            aws_session_token=org_sts_token['SessionToken']
        )
        
        # describe and parse rds instances response from target account
        rds_list, rds_summary_list = parse_instances_info(rds_client, acct_id, acct_ids_dict, scan_id)
        if rds_summary_list:
            summary_list.extend(rds_summary_list)
        
        # describe and parse rds snapshots response from target account
        rds_snapshots_list, rds_summary_list = parse_snapshots_info(rds_client, acct_id, acct_ids_dict, scan_id)
        if rds_summary_list:
            summary_list.extend(rds_summary_list)
        
        
        #create secrets service client using the assumed role credentials
        secrets_client = boto3.client('secretsmanager',
            aws_access_key_id=org_sts_token['AccessKeyId'],
            aws_secret_access_key=org_sts_token['SecretAccessKey'],
            aws_session_token=org_sts_token['SessionToken']
        )
        #get secret names list of dictionaries
        secret_names, error = get_secrets_list(secrets_client)
        if error != "":
            summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
        # End getting the secret name and the arn to a list
        
        # Added by Prashant on 08-29-2023 
        # The section is to parameterize the secret pattern for non-master accounts.
        # Approch is to use the environment variable to customize the secret pattern.
        # Get the secret pattern from environment variable
        secret_pattern = os.getenv("db_secret_pattern", "/secret/{}/rds-password")
        
        rds_secrets_list = []
        for each in rds_list:
            # Construct the secret name based on the secret pattern
            db_admin_secret_name = secret_pattern.format(each["DBInstanceID"])

            rds_secrets_list.append({
                "ScanID": scan_id,
                "AccountID": acct_id,
                "DBInstanceID": each["DBInstanceID"],
                "DatabaseName": each["DatabaseName"],
                "DBAdminSecretName": [db_admin_secret_name],  # Use the custom secret name
                "DBAdminSecretARN": "",
                "DBAdminSecretPresent": ""
            })
        
        index=0
        while index < len(rds_secrets_list):
            for k in rds_secrets_list[index]['DBAdminSecretName']:
                if k in secret_names.keys():
                    rds_secrets_list[index]['DBAdminSecretARN'] = secret_names.get(k)
                    break
            if rds_secrets_list[index]['DBAdminSecretARN'] == "":
                summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_secrets_list[index]['DBInstanceID'], "SecretARN":"NA", "Summary":"No Secret found for the RDS in secret manager"})
            else:
                summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_secrets_list[index]['DBInstanceID'], "SecretARN":rds_secrets_list[index]['DBAdminSecretARN'], "Summary":"Secret Found for the rds in secret manager"})
            index = index +1 
         
    
        # Loop through the list of RDS instances and check rds_admin secret is present
        index=0
        now = datetime.now()
        audit_roles_list = []
        public_roles_list = []
        while index < len(rds_secrets_list):
            
            if rds_secrets_list[index]['DBAdminSecretARN'] != "":
                #test_db_admin_secret
                sql = f"""
                select now();
                """
                print(rds_secrets_list[index]['DBAdminSecretARN'])
                status_code,status=run_query(secrets_client,rds_secrets_list[index]['DBAdminSecretARN'],sql)
                print(status_code, status)
                
                # if query execution was unsuccessfull updates summary table with db admin secret didn't work
                if status_code < 0:
                    rds_secrets_list[index]['DBAdminSecretPresent'] = "FALSE"
                    summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_secrets_list[index]['DBInstanceID'], "SecretARN":rds_secrets_list[index]['DBAdminSecretARN'], "Summary":"Unable to connect to the target Db with Secret"})
                
                #If query execution successfull runs the CIS sql scripts on target db for drifts.
                else:
                    print("connection successful")
                    summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_secrets_list[index]['DBInstanceID'], "SecretARN":rds_secrets_list[index]['DBAdminSecretARN'], "Summary":"Successfully Connected to db with Secret"})
                    rds_secrets_list[index]['DBAdminSecretPresent'] = "TRUE"
                    sql = f"""
                    select rolname,'ALL','ALL','ALL','ALL','SUPERUSER','SERVER',rolcanlogin from pg_roles where rolsuper is true;
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    audit_roles_list = get_audit_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], audit_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'])
                    
                    sql = f"""
                    select rolname,'ALL','ALL','ALL','ALL','CREATE DATABASE','SERVER',rolcanlogin from pg_roles where rolcreatedb is true and rolsuper is false;
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    audit_roles_list = get_audit_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], audit_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'])
                    
                    sql = f"""
                    select rolname,'ALL','ALL','ALL','ALL','REPLICATION','SERVER',rolcanlogin from pg_roles where rolreplication is true and rolsuper is false;
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    audit_roles_list = get_audit_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], audit_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'])
                    
                    sql = f"""
                    select rolname,'ALL','ALL','ALL','ALL','CREATE ROLE','SERVER',rolcanlogin from pg_roles where rolcreaterole is true and rolsuper is false;
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    audit_roles_list = get_audit_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], audit_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'])
                    
                    sql = f"""
                    SELECT 'public', spcname, ARRAY[
                    (CASE WHEN has_tablespace_privilege('public',spcname,'CREATE') 
                    THEN 'CREATE' ELSE NULL END)],
                    'TABLESPACE','f'
                    FROM pg_tablespace WHERE has_tablespace_privilege('public',spcname,'CREATE');
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=1)
                    # empty tablespace not applicable
                    if result:
                        print("result_type1: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT 'public', datname, array(select privs from unnest(ARRAY[
                	( CASE WHEN has_database_privilege('public',c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
                	(CASE WHEN has_database_privilege('public',c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
                	(CASE WHEN has_database_privilege('public',c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
                	(CASE WHEN has_database_privilege('public',c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)])foo(privs) 
                	WHERE privs IS NOT NULL), 'DATABASE','f' FROM pg_database c WHERE 
                	has_database_privilege('public',c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname =current_database();
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=2)
                    if result:
                        print("result_type2: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    select 'public',catalog_name,schema_name,'SCHEMA' as level, 'DATABASE',array(select privs from unnest(ARRAY[
                	( CASE WHEN has_schema_privilege('public',schema_name,'CREATE') THEN 'CREATE' ELSE NULL END),
                	(CASE WHEN has_schema_privilege('public',schema_name,'USAGE') THEN 'USAGE' ELSE NULL END)])foo(privs) 
                	WHERE privs IS NOT NULL),'f'
                	from information_schema.schemata c
                	where has_schema_privilege('public',schema_name,'CREATE,USAGE') 
                	and c.schema_name not like 'pg_temp%'
                	and schema_owner <> 'public';
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=3)
                    if result:
                        print("result_type3: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT  'public',current_database(),'DATABASE',n.nspname||'.'||c.oid::regclass,'TABLE', array(select privs from unnest(ARRAY [ 
                	(CASE WHEN has_table_privilege('public',c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) where privs is not null) ,
                	'f'
                	FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid 
                	where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
                	has_table_privilege('public',c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') 
                	AND has_schema_privilege('public',c.relnamespace,'USAGE');
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=4)
                    if result:
                        print("result_type4: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT  'public',current_database(),'DATABASE',n.nspname||'.'||c.oid::regclass,'VIEW',
                	array(select privs from unnest(ARRAY [
                	( CASE WHEN has_table_privilege('public',c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) where privs is not null) ,
                	'f'
                	FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
                	and  c.relkind='v' and has_table_privilege('public',c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') 
                	AND has_schema_privilege('public',c.relnamespace,'USAGE');
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=5)
                    if result:
                        print("result_type5: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT 'public', current_database(),'DATABASE',c.oid::regclass,'SEQUENCE',
                	array(select privs from unnest(ARRAY [
                	( CASE WHEN has_table_privilege('public',c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
                	(CASE WHEN has_table_privilege('public',c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END)]) foo(privs) where privs is not null) ,'f'
                	FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') 
                	and  c.relkind='S' and
                	has_table_privilege('public',c.oid,'SELECT,UPDATE')  AND has_schema_privilege('public',c.relnamespace,'USAGE');
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=6)
                    if result:
                        print("result_type6: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT 'public', current_database(),'DATABASE',fdwname,'FDW', ARRAY[
                	(CASE WHEN has_foreign_data_wrapper_privilege('public',fdwname,'USAGE') THEN 'USAGE' ELSE NULL END)] ,'f'
                	FROM pg_catalog.pg_foreign_data_wrapper WHERE has_foreign_data_wrapper_privilege('public',fdwname,'USAGE');
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=7)
                    if result:
                        print("result_type7: ", type(result[0]))
                        print("result: ", result[0]._asdict())
                    
                    sql = f"""
                    SELECT 'public', current_database(),'DATABASE',l.lanname,'LANGUAGE',
                	ARRAY[(CASE WHEN has_language_privilege('public',lanname,'USAGE') THEN 'USAGE' ELSE NULL END)] ,'f'
                	FROM pg_catalog.pg_language l where has_language_privilege('public',lanname,'USAGE') ;
                    """
                    result = pgs.run_query_using_secrets(secrets_client, rds_secrets_list[index]['DBAdminSecretARN'], sql)
                    public_roles_list = get_public_roles_list(scan_id, acct_id, rds_secrets_list[index]['DBInstanceID'], public_roles_list, result, dbname=rds_secrets_list[index]['DatabaseName'], query_number=8)
                    if result:
                        print("result_type8: ", type(result[0]))
                        print("result: ", result[0]._asdict())
            else:
                logger.info("DBAdminSecretName is not present in secret manager for the DB: %s" %(rds_secrets_list[index]["DBInstanceID"]))
        
            index = index + 1
        
        # print("rds_list: ", rds_list)
        if audit_roles_list:
            flag = 1
            parameter_list = audit_roles_list[0].keys()
            #Creates or update audit role privileges table
            create_or_alter_table(parameter_list, table_name="audit_role_privileges")
            update_table(audit_roles_list, parameter_list, table_name='audit_role_privileges')
        if public_roles_list:
            flag = 2
            parameter_list = public_roles_list[0].keys()
            #Creates or update public role privileges table
            create_or_alter_table(parameter_list, table_name="public_role_privileges")
            update_table(public_roles_list, parameter_list, table_name='public_role_privileges')
