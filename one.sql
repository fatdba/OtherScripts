# Import block for the existing IAM role
data "external" "import_role" {
  program = ["echo", "import_role_id_here"]  # Replace "import_role_id_here" with the actual IAM role's ARN to import
}

# IAM roles and Policies
# Standard AWS trust policy allowing lambda to assume role
resource "aws_iam_role" "lambda_role" {
  count      = (local.create_execution_role == "true") ? 1 : 0
  name       = local.lambda_execution_role_name
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/pubcloud/AppTeamIAMBoundary"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Output the ARN of the imported role
output "imported_role_arn" {
  value = data.external.import_role.result
}
