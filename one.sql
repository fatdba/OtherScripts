{
  "errorMessage": "tuple indices must be integers or slices, not str",
  "errorType": "TypeError",
  "requestId": "777f4a3c-0dc1-4720-bb8c-4bbbe7b8f42c",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 924, in lambda_handler\n    values = [row[column_name] for column_name in audit_role_privileges_userinfo_parameter_list]\n",
    "  File \"/var/task/lambda_function.py\", line 924, in <listcomp>\n    values = [row[column_name] for column_name in audit_role_privileges_userinfo_parameter_list]\n"
  ]
}
