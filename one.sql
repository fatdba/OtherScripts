#Boto3 Modules
import boto3
import botocore
from botocore.exceptions import ClientError
#User Defined lambda layers
import postgres_utils as pgs
from postgres_utils import pg
from csv2pdf import convert
from PIL import ImageFont 
#General Python Modules
import logging 
from datetime import  datetime
import csv
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

#Get assume role credentials
def get_assume_role_session(sts_role):
    sts_client = boto3.client('sts')
    return sts_client.assume_role(
        RoleArn=sts_role,
        RoleSessionName="accountSelector"
    )['Credentials']

# Function to run a query in RDS 
def run_query(secrets_client, secret_arn, sql):
    try:
        # check if connection to RDS works
        dbconn = pgs.get_connection(pgs.get_secret_dict(secrets_client, secret_arn, "AWSCURRENT"))
        if dbconn:
            result = pgs.run_query_using_secrets(secrets_client, secret_arn, sql)
            status = "Successfully executed query"
            logger.info("%s" % (status))
            status_code = 0
        else:
            status = f"Unable to login to server with secret"
            logger.info("%s" % (status))
            status_code = -1
            result = []  # Set result to an empty list in case of failure
    except Exception as e:
        status = f"Query execution failed: {e}"
        logger.info("%s" % (status))
        status_code = -1
        result = []  # Set result to an empty list in case of failure

    if not result:
        result = []  # Set result to an empty list if it's None or empty
    
    return status_code, status, result

#updates the given table
def update_table(rds_list, parameter_list, table_name):
    secrets_client = boto3.client('secretsmanager')
    reporting_db_secret_arn = os.getenv("db_secret_arn")
    parameter_string = "("+", ".join(parameter_list)+")"
    sql = f"""select * from {table_name};"""
    sql1 = ''
    for each in rds_list:
        sql1 += f"""INSERT INTO {table_name} {parameter_string} VALUES {tuple(each.values())};"""
    sql1 = sql1+sql
    status_code,status=run_query(secrets_client,reporting_db_secret_arn,sql1)

#Creates or Alter table
def create_or_alter_table(parameter_list, table_name):
    """
    parameter_list: list of table column headers
    table_name: name of the table you are going to create
    """
    secrets_client = boto3.client('secretsmanager')
    reporting_db_secret_arn = os.getenv("db_secret_arn")
    sql = f"""
    create table if not exists {table_name} (Id int GENERATED ALWAYS AS IDENTITY, RecordedTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ScanId Varchar(10));
    """
    status_code, status = run_query(secrets_client, reporting_db_secret_arn, sql)  # Unpack only two values
    # sql = ''
    for each in parameter_list:
        sql += f"""
        alter table {table_name} add column if not exists {each} varchar(500);
        """
    status_code, status = run_query(secrets_client, reporting_db_secret_arn, sql)
        
def parse_instances_info(rds_client, acct_id, acct_ids_dict, scan_id):
    """
    Function to get and parse the Instrance info from the target accounts
    rds_client: Boto3 rds assume role client method to get rds instances data from target account.
    acct_id: ID of the target Account.
    scan_id: Represents the Sacn ID for this current lambda invocation. And Scan ID will be incremented with each invocation.
    """
    rds_list = []
    rds_summary_list = []
    # List postgres rds instances in the account
    try:
        rds_instances = rds_client.describe_db_instances(
            Filters=[{
                    'Name': 'engine',
                    'Values': [
                        'postgres','aurora-postgresql'
                    ]}],
        )
    except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError) as client_error:
        error = f"""Exception Caught - Error = {client_error}"""
        #If any error with summary list refer Comment above the summary_table_parameter_list
        rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})

    # Variable to hold the list of rds instances
    instances=[]
    index = 0
    if rds_summary_list == [] and len(rds_instances['DBInstances']) > 0:
        while index < len(rds_instances['DBInstances']):
            try:
                # Check if instance is part of a cluster by checking if 'DBClusterIdentifier' key is in dictionary
                if 'DBClusterIdentifier' in rds_instances['DBInstances'][index]:
                    
                    # Use the dbclusteridentifier to get the db_cluster endpoint and port.
                    db_cluster = rds_client.describe_db_clusters(
                        DBClusterIdentifier=rds_instances['DBInstances'][index]['DBClusterIdentifier']
                    )
                    print("db_cluster: ", db_cluster)
                    dbinstanceid=str(rds_instances['DBInstances'][index]['DBClusterIdentifier'].rsplit('-',1)[0])
                    secret_host=db_cluster['DBClusters'][0]['Endpoint']
                    secret_port=db_cluster['DBClusters'][0]['Port']
                    MultiAZ = db_cluster['DBClusters'][0]['MultiAZ']
                    Engine = db_cluster['DBClusters'][0]['Engine']
                    EngineVersion = db_cluster['DBClusters'][0]['EngineVersion']
                    cluster_encrypted = db_cluster['DBClusters'][0]['StorageEncrypted']
                    DatabaseName = db_cluster['DBClusters'][0].get('DatabaseName', "NA")
                    BackupRetentionPeriod = db_cluster['DBClusters'][0]['BackupRetentionPeriod']
                    PubliclyAccessible = rds_instances['DBInstances'][index]["PubliclyAccessible"]
                    instance_encrypted = rds_instances['DBInstances'][index]['StorageEncrypted']
                    if Engine != "aurora-postgresql":
                        PerformanceInsightsEnabled = db_cluster['DBClusters'][0]['PerformanceInsightsEnabled']
                    else:
                        PerformanceInsightsEnabled = "NA"
                    
                else:
                    # print(rds_instances['DBInstances'][index])
                    logger.info ("Instance")
                    #create dictionary item in list for instance
                    dbinstanceid=rds_instances['DBInstances'][index]['DBInstanceIdentifier']
                    secret_host=rds_instances['DBInstances'][index]['Endpoint']['Address']
                    secret_port=rds_instances['DBInstances'][index]['Endpoint']['Port']
                    PubliclyAccessible = rds_instances['DBInstances'][index]["PubliclyAccessible"]
                    MultiAZ = rds_instances['DBInstances'][index]['MultiAZ']
                    Engine = rds_instances['DBInstances'][index]['Engine']
                    EngineVersion = rds_instances['DBInstances'][index]['EngineVersion']
                    instance_encrypted = rds_instances['DBInstances'][index]['StorageEncrypted']
                    DatabaseName = rds_instances['DBInstances'][index].get('DBName', "NA")
                    BackupRetentionPeriod = rds_instances['DBInstances'][index]['BackupRetentionPeriod']
                    PerformanceInsightsEnabled = rds_instances['DBInstances'][index]['PerformanceInsightsEnabled']
           
              
                if secret_host not in instances:
          
                    instances.append(secret_host)
                    if 'DBClusterIdentifier' in rds_instances['DBInstances'][index]:
                        rds_list.append(
                            {
                                "ScanId":scan_id,
                                'AccountID': acct_id,
                                'DBInstanceID': str(dbinstanceid),
                                'SecretHost': secret_host,
                                'SecretPort': str(secret_port),
                                'MultiAZ':str(MultiAZ),
                                'Engine':Engine,
                                'EngineVersion':str(EngineVersion),
                                'ClusterEncrypted':cluster_encrypted,
                                'DatabaseName':DatabaseName,
                                'BackupRetentionPeriod':BackupRetentionPeriod,
                                'PubliclyAccessible':PubliclyAccessible,
                                'InstanceEncrypted':instance_encrypted,
                                'PerformanceInsightsEnabled':PerformanceInsightsEnabled
                            }
                        )
                    else:
                        rds_list.append(
                            {
                                "ScanId":scan_id,
                                'AccountID': acct_id,
                                'DBInstanceID': dbinstanceid,
                                'SecretHost': secret_host,
                                'SecretPort': secret_port,
                                'MultiAZ':MultiAZ,
                                'Engine':Engine,
                                'EngineVersion':EngineVersion,
                                'ClusterEncrypted':'NA',
                                'DatabaseName':DatabaseName,
                                'BackupRetentionPeriod':BackupRetentionPeriod,
                                'PubliclyAccessible':PubliclyAccessible,
                                'InstanceEncrypted':instance_encrypted,
                                'PerformanceInsightsEnabled':PerformanceInsightsEnabled
                            }
                        )
                        
            except Exception as error:
                error = f"""Error while parsing the rds db response - {error}"""
                if 'DBClusterIdentifier' in rds_instances['DBInstances'][index]:
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": str(rds_instances['DBInstances'][index]['DBClusterIdentifier'].rsplit('-',1)[0]), "SecretARN":"NA", "Summary":error})
                else:
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_instances['DBInstances'][index]['DBInstanceIdentifier'], "SecretARN":"NA", "Summary":error})
                    
            index=index+1
        #create and update instances info table
        try:
            if rds_list:
                parameter_list = rds_list[0].keys()
                create_or_alter_table(parameter_list, table_name="instances_info")
                update_table(rds_list, parameter_list, table_name="instances_info")
        except Exception as error:
            error = f"""Error While creating or updaing the instances_info table - {error}"""
            #If any error with summary list refer Comment above the summary_table_parameter_list
            rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
    else:
        error = "There are No postgres or aurora-postgresql databases in this account"
        #If any error with summary list refer Comment above the summary_table_parameter_list
        rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
    return rds_list, rds_summary_list
    
def parse_snapshots_info(rds_client, acct_id, acct_ids_dict, scan_id):
    """
    Function to get and parse the snapshots info from the target accounts
    rds_client: Boto3 rds assume role client method to get rds instances and it's snapshots data from target account.
    acct_id: ID of the target Account.
    scan_id: Represents the Sacn ID for this current lambda invocation. And Scan ID will be incremented with each invocation.
    """
    rds_snapshots_list = []
    rds_summary_list = []
    # List postgres rds instance snapshots in the account
    try:
        rds_instances = rds_client.describe_db_instances(
            Filters=[{
                    'Name': 'engine',
                    'Values': [
                        'postgres','aurora-postgresql'
                    ]}],
        )
    except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError) as client_error:
        error = f"""Error While getting the rds instances info for describing snapshots - {client_error}"""
        #If any error with summary list refer Comment above the summary_table_parameter_list
        rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
        return rds_snapshots_list, rds_summary_list

    index = 0
    if rds_summary_list == []:
        while index < len(rds_instances['DBInstances']):
            # Check if instance is part of a cluster by checking if 'DBClusterIdentifier' key is in dictionary
            if 'DBClusterIdentifier' in rds_instances['DBInstances'][index]:
                
                try:
                    #Start Reading RDS cluster snaphots
                    snapshots_response = rds_client.describe_db_cluster_snapshots(
                        DBClusterIdentifier=rds_instances['DBInstances'][index]['DBClusterIdentifier']
                    )
                except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError) as client_error:
                    error = f"""Error While describing snapshots - {client_error}"""
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": str(rds_instances['DBInstances'][index]['DBClusterIdentifier'].rsplit('-',1)[0]), "SecretARN":"NA", "Summary":error})
                try:
                    if snapshots_response["DBClusterSnapshots"]:
                        for each in snapshots_response["DBClusterSnapshots"]:
                            rds_snapshots_list.append({
                                "ScanId":scan_id,
                                "AccountID": acct_id,
                                "DBInstanceID": str(rds_instances['DBInstances'][index]['DBClusterIdentifier'].rsplit('-',1)[0]),
                                "DBClusterIdentifier":rds_instances['DBInstances'][index]['DBClusterIdentifier'],
                                "DBSnapshotIdentifier_Instance_or_Cluster":each["DBClusterSnapshotIdentifier"],
                                "DBSnapshotEncrypted_Instance_or_Cluster": each["StorageEncrypted"],
                                "DBSnapshotType_Instance_or_Cluster":each["SnapshotType"]
                            })
                except Exception as error:
                    error = f"""Error While parsing snapshots info - {error}"""
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": str(rds_instances['DBInstances'][index]['DBClusterIdentifier'].rsplit('-',1)[0]), "SecretARN":"NA", "Summary":error})
                
        
            else:
                dbinstanceid=rds_instances['DBInstances'][index]['DBInstanceIdentifier']
                
                try:
                    #Start Reading RDS Instance snaphots
                    snapshots_response = rds_client.describe_db_snapshots(
                        DBInstanceIdentifier=rds_instances['DBInstances'][index]['DBInstanceIdentifier']
                    )
                except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError) as client_error:
                    error = f"""Error While describing snapshots - {client_error}"""
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_instances['DBInstances'][index]['DBInstanceIdentifier'], "SecretARN":"NA", "Summary":error})
                try:
                    if snapshots_response["DBSnapshots"]:
                        for each in snapshots_response["DBSnapshots"]:
                            rds_snapshots_list.append({
                                "ScanId":scan_id,
                                "AccountID": acct_id,
                                "DBInstanceID": rds_instances['DBInstances'][index]['DBInstanceIdentifier'],
                                "DBClusterIdentifier":"NA",
                                "DBSnapshotIdentifier_Instance_or_Cluster":each["DBSnapshotIdentifier"],
                                "DBSnapshotEncrypted_Instance_or_Cluster": each["Encrypted"],
                                "DBSnapshotType_Instance_or_Cluster":each["SnapshotType"]  
                            })
                except Exception as error:
                    error = f"""Error While parsing snapshots info - {error}"""
                    #If any error with summary list refer Comment above the summary_table_parameter_list
                    rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": rds_instances['DBInstances'][index]['DBInstanceIdentifier'], "SecretARN":"NA", "Summary":error})
                
            index=index+1
        
        try:
            #create and update snapshots info table
            if rds_snapshots_list:
                parameter_list = rds_snapshots_list[0].keys()
                create_or_alter_table(parameter_list, table_name="snapshots_info")
                update_table(rds_snapshots_list, parameter_list, table_name="snapshots_info")
        except Exception as error:
            error = f"""Error While Creating or updaing the snapshots_info table - {error}"""
            #If any error with summary list refer Comment above the summary_table_parameter_list
            rds_summary_list.append({"ScanID":scan_id, "AccountID":acct_id, "AccountName":acct_ids_dict.get(acct_id), "RDSIdentifier": "NA", "SecretARN":"NA", "Summary":error})
            
    
    return rds_snapshots_list, rds_summary_list
    
def get_secrets_list(secrets_client):
    # This section of code will read the list of secrets in sceret manager
    secrets=[]
    secret_names={}
    error=""
    # List secrets in the account. 10 secrets are returned for each call
    # loop as long as the dictionary in the result contains the 'NextToken' key
    try:
        secret_list = secrets_client.list_secrets()
        while ('NextToken' in secret_list) :
            secrets =  secrets + secret_list['SecretList']
            secret_list = secrets_client.list_secrets(NextToken=secret_list['NextToken'])        
        secrets =  secrets + secret_list['SecretList']
        # End listing secrets
        
        # Get the secret name and the arn to a list
        index=0
        secret_count = len(secrets)
        while index < secret_count:
                secret_names.update({secrets[index]['Name']: secrets[index]['ARN']})
                index=index+1
    except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError) as client_error:
        error = f"""Error getting Secrets = {client_error}"""
        # logger.info("Exception Caught - Error = %s" %( error))

    return secret_names, error

def get_account_ids():
    #Returns List of Account Id's based on the environment in environment variables.
    error = ""
    sts_org_arn = "arn:aws:iam::009973789139:role/list-org-accounts"
    acct_ids = []
    acct_ids_dict = {}
    try:
        if os.getenv("account_ids") != "" and "," in os.getenv("account_ids"):
            acct_ids.extend(os.getenv("account_ids").split(","))
        elif os.getenv("account_ids") != "" and "," not in os.getenv("account_ids"):
            acct_ids.append(os.getenv("account_ids"))
        environment = os.getenv("environment").lower()
        credentials = get_assume_role_session(sts_org_arn)
        org_client = boto3.client(
            'organizations',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )
        response = org_client.list_accounts(MaxResults=20)
        # print(response)
        for each in response.get("Accounts"):
            if environment+"-" in each.get("Name").lower() or "-"+environment in each.get("Name").lower() or each.get("Id") in acct_ids:
            # if each.get("Id") in acct_ids:
                acct_ids_dict.update({str(each.get("Id")):each.get("Name")})
        while 'NextToken' in response:
            response = org_client.list_accounts(
                NextToken = response.get("NextToken"),
                MaxResults=20
            )
            for each in response.get("Accounts"):
                if environment+"-" in each.get("Name").lower() or "-"+environment in each.get("Name").lower() or each.get("Id") in acct_ids:
                # if each.get("Id") in acct_ids:
                    acct_ids_dict.update({str(each.get("Id")):each.get("Name")})
    except (botocore.exceptions.BotoCoreError,boto3.exceptions.Boto3Error,botocore.exceptions.ClientError,Exception) as client_error:
        error = f"""Exception Caught - Error = {client_error}"""
    # tag_response = org_client.list_tags_for_resource(
    #     ResourceId=each.get("Id")
    # )
    # print(tag_response)
    
    return acct_ids_dict, error

def get_audit_roles_list(scan_id, acct_id, rds_identifier, audit_roles_list, result, dbname):
    #Parse the sqlquery output and add to the list as dict for updating the audit roles table.
    for each in result:
        each_dict = each._asdict()
        audit_roles_list.append({
            'ScanId':scan_id,
            'AccountID': acct_id,
            'DbIdentifier': rds_identifier,
            'rolname':each_dict.get("rolname"),
            'tablespacename':each_dict.get("tablespacename", "ALL"),
            'dbname':dbname,
            'object_name':each_dict.get("object_name", "ALL"),
            'object_type':each_dict.get("object_type", "ALL"),
            'privileges':each_dict.get("_5", "NA"),
            'level':each_dict.get("_6", "NA"),
            'canlogin':each_dict.get("rolcanlogin", "NA")
        })
    return audit_roles_list

def get_public_roles_list(scan_id, acct_id, rds_identifier, public_roles_list, result, dbname, query_number):
    #Parse the sqlquery output and add to the list as dict for updating the audit roles table.
    for each in result:
        each_dict = each._asdict()
        if len(each_dict.keys()) == 5:
            public_roles_list.append({
                'ScanId':scan_id,
                'AccountID': acct_id,
                'DbIdentifier': rds_identifier,
                'dbname':dbname,
                'catalog_name': "NA",
                'schema_name': "NA",
                'level': "NA",
                'rolname':each_dict.get("_0"),
                'datname':each_dict.get("datname"),
                'privileges':",".join(each_dict.get("array", "NA")),
                'lanname':"NA"
            })
        elif len(each_dict.keys()) > 5:
            if "lanname" in each_dict.keys():
                public_roles_list.append({
                    'ScanId':scan_id,
                    'AccountID': acct_id,
                    'DbIdentifier': rds_identifier,
                    'dbname':dbname,
                    'catalog_name': "NA",
                    'schema_name': "NA",
                    'level': "NA",
                    'rolname':each_dict.get("_0"),
                    'datname':"NA",
                    'privileges':",".join(each_dict.get("array", "NA")),
                    'lanname': each_dict.get("lanname")
                })
            elif 'catalog_name' in each_dict.keys():
                public_roles_list.append({
                    'ScanId':scan_id,
                    'AccountID': acct_id,
                    'DbIdentifier': rds_identifier,
                    'dbname':dbname,
                    'catalog_name': each_dict.get("catalog_name"),
                    'schema_name': each_dict.get("schema_name"),
                    'level': each_dict.get("level"),
                    'rolname':each_dict.get("_0"),
                    'datname':"NA",
                    'privileges':",".join(each_dict.get("array", "NA")),
                    'lanname':"NA"
                })
            
    return public_roles_list

def generate_csv_and_pdf_reports_for_the_drift_tables(secrets_client, reporting_db_secret_arn, table_names_list, scan_id):
    """
    Function to gnereate CSV and pdf reports from the tables in drift reporting database
    secrets_client: Parameter to connect to Drift Reporting DB
    table_names_list: list of the all the drift tables to generate CSV and PDf reports from.
    scan_id: Represents the Sacn ID for this current lambda invocation. And Scan ID will be incremented with each invocation.
    """
    #Creates S3 bucket if not exist for storing the CSV and PDF reports of drift DB
    s3_resource = boto3.resource('s3')
    s3_bucket_name = 'edm-db-drift-detection-reports-'+os.getenv('environment')
    bucket = s3_resource.Bucket(s3_bucket_name)
    if bucket.creation_date:
        print("s3 bucket: "+s3_bucket_name+' Exists')
    else:
        response = bucket.create(CreateBucketConfiguration={'LocationConstraint': 'us-east-2'})
    s3_client = boto3.client('s3')

    #using font lib for calculating Sizes for pdf files
    font = ImageFont.load_default()

    #Looping Through Tables
    for each_table in table_names_list:
        print(each_table)
        #get table data
        sql = f"""
        select*from {each_table} where scanid = {str(scan_id)}::varchar;
        """
        result = pgs.run_query_using_secrets(secrets_client, reporting_db_secret_arn, sql)
        result_list = [each._asdict() for each in result]

        #Parse Db table data and create CSV and PDF files
        if result:
            header_list = [str(i) for i in result[0]._asdict().keys()]
            Column_sizes = [font.getsize(str(i)) for i in header_list]
        else:
            logging.warning("No rows returned in the query result.")
        Column_sizes = [font.getsize(str(i)) for i in result[0]._asdict().keys()]

        file_name = str(each_table)+'_scan_'+str(scan_id)+'.csv'
        file_path = "/tmp/"+file_name

        pdf_file_name = str(each_table)+'_scan_'+str(scan_id)+'.pdf'
        pdf_file_path = "/tmp/"+pdf_file_name
        file_exists = os.path.exists(file_path)
        if not file_exists:
            #Creates CSV files
            with open(file_path,"w") as file:
                writer_object = csv.writer(file)
                writer_object.writerow(header_list)
                for each in result_list:
                    writer_object.writerow([str(j) for j in each.values()])
                    #calculating the column sizes for putting table data into pdf
                    index = 0
                    for i in each.values():
                        if Column_sizes[index][0] < font.getsize(str(i))[0]:
                            Column_sizes[index] = font.getsize(str(i))
                        index += 1
                file.close()
        else:
            #Updates CSV files
            with open(file_path,"a+") as file:
                writer_object = csv.writer(file)
                for each in result_list:
                    writer_object.writerow([str(j) for j in each.values()])
                    #calculating the column sizes for putting table data into pdf
                    index = 0
                    for i in each.values():
                        if Column_sizes[index][0] < font.getsize(str(i))[0]:
                            Column_sizes[index] = font.getsize(str(i))
                        index += 1
                file.close()
        file_exists = os.path.exists(file_path)
        #calculating max cel height height and total width of the page
        total_width = 0
        max_column_hieght = 0
        for each in Column_sizes:
            total_width += each[0]
            if max_column_hieght < each[1]:
                max_column_hieght = each[1]
        if file_exists:
            #Converts CSV file to PDF file
            convert(file_path, pdf_file_path, align='L', line_height=max_column_hieght, Column_sizes=Column_sizes, total_width=total_width+50)
            
            #Uploading CSV and PDF files to the S3 Bucket
            s3_client.upload_file(file_path, s3_bucket_name, 'csv_files/{}'.format(file_name))
            s3_client.upload_file(pdf_file_path, s3_bucket_name, 'pdf_files/{}'.format(pdf_file_name))
    

def lambda_handler(event, context):
    #SQL query for dropping the tables
    print('insidehandler')

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
    status_code, status, result = run_query(reporting_db_secrets_client, reporting_db_secret_arn, sql)
    print("result: ", result) #You can now safely access the result variable
    scan_id = str(result[0]._asdict()["nextval"])
    #SQL query to get present scan ID and increment Scan ID sequence by 1.
    sql = f"""
    SELECT nextval('scan_sequence');
    """
    status_code, status = run_query(reporting_db_secrets_client, reporting_db_secret_arn, sql)
    print("result: ", result)
    print("status:", status)
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
        
        # loop through RDS instances and
        # Loop through secrets and check if dbadmin secrets are in secret_list
        #rds_secrets_list contains list of matched secrets for the rds in target account
        rds_secrets_list = []
        for each in rds_list:
            # secret for db_admin we need to look for
            secrets_environments = os.getenv("secrets_environments").split(",")
            db_admin_secret_name_list = []
            db_admin_secret_name=['/secret/'+each["DBInstanceID"]+'/rds-password','/secret/'+each["DBInstanceID"]+'/rds-password-v2']
            db_admin_secret_name_list.extend(db_admin_secret_name)
            db_admin_secret_name_suffix='/rds/'+each["DBInstanceID"]
            for i in secrets_environments:
                db_admin_secret_name_list.append(i+db_admin_secret_name_suffix)
            rds_secrets_list.append({
                "ScanID":scan_id,
                "AccountID":acct_id,
                "DBInstanceID":each["DBInstanceID"],
                "DatabaseName":each["DatabaseName"],
                "DBAdminSecretName":db_admin_secret_name_list,
                "DBAdminSecretARN":"",
                "DBAdminSecretPresent":""
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

    #updates summary table
    update_table(summary_list, summary_table_parameter_list, summary_table_name)
    if flag == 2:
        table_names_list = ["public_role_privileges", "audit_role_privileges",summary_table_name,"instances_info","snapshots_info"]
    elif flag == 1:
        table_names_list = ["audit_role_privileges",summary_table_name,"instances_info","snapshots_info"]
    else:
        table_names_list = [summary_table_name,"instances_info","snapshots_info"]
    #generate CSV and pdf files of the tables for each scan
    print("flag:", flag)
    print(table_names_list)
    generate_csv_and_pdf_reports_for_the_drift_tables(reporting_db_secrets_client, reporting_db_secret_arn, table_names_list, scan_id)
