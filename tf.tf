resource "aws_iam_policy" "s3_policy" {
  name        = "lambda-${var.function_name}-s3_policy"
  path        = "/"

  policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:*",
                    "s3-object-lambda:*"
                ],
                "Resource": "*"
            }
        ]
    }
    EOF

  lifecycle {
    prevent_destroy = true
  }
}
