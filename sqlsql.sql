Response
{
  "errorMessage": "'function' object has no attribute 'append'",
  "errorType": "AttributeError",
  "requestId": "19ebab27-4206-4a48-a692-21baf1ba6412",
  "stackTrace": [
    "  File \"/var/task/lambda_function.py\", line 1150, in lambda_handler\n    role_priv_tables_list = get_role_priv_tables_list(scan_id, acct_id, role_priv_tables_list, result)\n",
    "  File \"/var/task/lambda_function.py\", line 493, in get_role_priv_tables_list\n    role_priv_tables_list.append({\n"
  ]
}
