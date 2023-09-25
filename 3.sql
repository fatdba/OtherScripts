Error: creating IAM Role (drift_detection): EntityAlreadyExists: Role with name drift_detection already exists. status code: 409, request id: 9e9f2c32-ce57-443c-b219-78ff6984c183
with module.edm_lambda["drift-detection-test-new"].aws_iam_role.lambda_role[0]
on .terraform/modules/edm_lambda/main.tf line 33, in resource "aws_iam_role" "lambda_role":
resource "aws_iam_role" "lambda_role" {
