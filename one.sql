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
    for each in parameter_list:
        sql += f"""
        alter table if exists {table_name} add column if not exists {each} varchar(500);
        """
    status_code, status = run_query(secrets_client, reporting_db_secret_arn, sql)
    if status_code == -1:
        # Handle the error here
        print("Error:", status)
    else:
        print("Success:", status)
