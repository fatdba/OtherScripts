# Convert the row tuple to a dictionary
row_dict = {column_name: value for column_name, value in zip(audit_role_privileges_userinfo_parameter_list, row)}

# Access elements using string keys
values = [row_dict[column_name] for column_name in audit_role_privileges_userinfo_parameter_list]
