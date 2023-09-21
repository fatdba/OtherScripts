def get_account_ids():
    #Returns List of Account Id's based on the environment in environment variables.
    error = ""
    sts_org_arn = "arn:aws:iam::009973789139:role/list-org-accounts"
    acct_ids = []
    acct_ids_dict = {}
    try:
        print("before_accountids_getenv")
        if os.getenv("account_ids") != "" and "," in os.getenv("account_ids"):
            acct_ids.extend(os.getenv("account_ids").split(","))
        elif os.getenv("account_ids") != "" and "," not in os.getenv("account_ids"):
            acct_ids.append(os.getenv("account_ids"))
        print("after_acountids_getenv")
        environment = os.getenv("environment").lower()
        print("before_assumerole")
        credentials = get_assume_role_session(sts_org_arn)
        print("before_boto3_client")
        org_client = boto3.client(
            'organizations',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )
        response = org_client.list_accounts(MaxResults=20)
        print("printing org response")
        print(response)
