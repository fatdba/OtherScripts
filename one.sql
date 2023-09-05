{
  "errorMessage": "'Row' object has no attribute 'values'",
  "errorType": "AttributeError",
  "requestId": "eff130e8-af60-45c0-abde-81686b823fc7",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 920, in lambda_handler\n    update_table(users_roles_info, parameter_list, table_name='users_roles_info')\n",
    "  File \"/var/task/lambda_function.py\", line 60, in update_table\n    sql1 += f\"\"\"INSERT INTO {table_name} {parameter_string} VALUES {tuple(each.values())};\"\"\"\n"
  ]
}
