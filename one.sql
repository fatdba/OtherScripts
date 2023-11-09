resource "aws_iam_role" "lambda_role" {
  # ... other role configuration ...
}

data "external" "import_role" {
  program = ["echo", "import_role_id_here"]  # Replace "import_role_id_here" with the actual IAM role's ARN to import
}

# Output the ARN of the imported role
output "imported_role_arn" {
  value = data.external.import_role.result
}
