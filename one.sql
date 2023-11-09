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
