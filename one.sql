Error: attaching policy with IAM Policy Attachment AmazonS3FullAccess: – AccessDenied: User: arn:aws:sts::589839611729:assumed-role/cloud-automation/vault-token-terraform-aws-589839611729-1698406852-jcVLzY5PTGEsgW is not authorized to perform: iam:AttachRolePolicy on resource: role SCLaunchRole with an explicit deny in a service control policy status code: 403, request id: 10a332ea-7f58-42f1-9a88-4cd41025868c
with module.edm_lambda["rds-drift-detection"].aws_iam_policy_attachment.s3_policy_attachment
on .terraform/modules/edm_lambda/main.tf line 215, in resource "aws_iam_policy_attachment" "s3_policy_attachment":
resource "aws_iam_policy_attachment" "s3_policy_attachment" {
