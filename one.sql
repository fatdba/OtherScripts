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
