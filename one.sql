Error: Invalid function argument
on .terraform/modules/edm_lambda/main.tf line 63, in output "imported_role_arn":
  value = jsondecode(data.external.import_role.result)["arn"]
data.external.import_role.result is map of string with 1 element
Invalid value for "str" parameter: string required.
