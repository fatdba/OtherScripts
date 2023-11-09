Error: Unexpected External Program Results
with module.edm_lambda["rds-drift-detection"].data.external.import_role
on .terraform/modules/edm_lambda/main.tf line 33, in data "external" "import_role":
  program = ["echo", "arn:aws:iam::219586591115:role/drift_detection"]  # Replace "import_role_id_here" with the actual IAM role's ARN to import
The data source received unexpected results after executing the program.

Program output must be a JSON encoded map of string keys and string values.
