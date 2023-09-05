{
  "errorMessage": "'Row' object has no attribute 'keys'",
  "errorType": "AttributeError",
  "requestId": "9bfc0f65-5993-4bfa-8eba-447fb62bd7d2",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 917, in lambda_handler\n    parameter_list = users_roles_info[0].keys()\n"
  ]
}

        if users_roles_info:
            flag = 3 
            parameter_list = users_roles_info[0].keys()
            create_or_alter_table(parameter_list, table_name="users_roles_info")
            update_table(users_roles_info, parameter_list, table_name='users_roles_info')
