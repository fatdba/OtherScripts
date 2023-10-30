The missing permission in your scenario is the permission to perform the iam:AttachRolePolicy action on the SCLaunchRole role. This action allows attaching an IAM policy to an IAM role. The error message explicitly states that the user or role with the ARN arn:aws:sts::589839611729:assumed-role/cloud-automation/vault-token-terraform-aws-589839611729-1698662801-wnRIb51XozoCoE is not authorized to perform this action on the SCLaunchRole role.

To resolve this issue, you need to grant the necessary permission for the user or role to attach policies to the SCLaunchRole role. You can do this by updating the policy associated with the user or role and ensuring it includes the required permissions for the iam:AttachRolePolicy action on the SCLaunchRole resource.

Here's an example of what the permission might look like in an IAM policy:

json
Copy code
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:AttachRolePolicy",
            "Resource": "arn:aws:iam::YOUR_ACCOUNT_ID:role/SCLaunchRole"
        }
    ]
}
Replace YOUR_ACCOUNT_ID with your AWS account ID. This policy statement allows the specified user or role to attach IAM policies to the SCLaunchRole role. Make sure to attach this policy to the user or role that is trying to perform this action
