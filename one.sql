Error: attaching policy with IAM Policy Attachment AmazonS3FullAccess: – AccessDenied: User: arn:aws:sts::589839611729:assumed-role/cloud-automation/vault-token-terraform-aws-589839611729-1698662801-wnRIb51XozoCoE is not authorized to perform: iam:AttachRolePolicy on resource: role SCLaunchRole with an explicit deny in a service control policy status code: 403, request id: a575183b-0cbc-4cf1-b29e-e89be830edad
with module.edm_lambda["rds-drift-detection"].aws_iam_policy_attachment.managed_s3_policy_attachment
on .terraform/modules/edm_lambda/main.tf line 207, in resource "aws_iam_policy_attachment" "managed_s3_policy_attachment":
resource "aws_iam_policy_attachment" "managed_s3_policy_attachment" {


Error: attaching policy with IAM Policy Attachment AmazonS3FullAccess: – AccessDenied: User: arn:aws:sts::589839611729:assumed-role/cloud-automation/vault-token-terraform-aws-589839611729-1698662801-wnRIb51XozoCoE is not authorized to perform: iam:AttachRolePolicy on resource: role SCLaunchRole with an explicit deny in a service control policy status code: 403, request id: c6fc4262-d786-4331-aad2-e7be9bf26348
with module.edm_lambda["rds-drift-detection"].aws_iam_policy_attachment.s3_policy_attachment
on .terraform/modules/edm_lambda/main.tf line 215, in resource "aws_iam_policy_attachment" "s3_policy_attachment":
resource "aws_iam_policy_attachment" "s3_policy_attachment" {
