[ERROR] AttributeError: 'Row' object has no attribute 'values'
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 928, in lambda_handler
    update_table(audit_role_privileges_userinfo_data, audit_role_privileges_userinfo_parameter_list, table_name='audit_role_privileges_userinfo')
  File "/var/task/lambda_function.py", line 60, in update_table
    sql1 += f"""INSERT INTO {table_name} {parameter_string} VALUES {tuple(each.values())};"""
