import os

# Get the secret pattern from environment variable
secret_pattern = os.getenv("db_secret_pattern", "/secret/{}/rds-password")

rds_secrets_list = []
for each in rds_list:
    # Construct the secret name based on the secret pattern
    db_admin_secret_name = secret_pattern.format(each["DBInstanceID"])
    
    rds_secrets_list.append({
        "ScanID": scan_id,
        "AccountID": acct_id,
        "DBInstanceID": each["DBInstanceID"],
        "DatabaseName": each["DatabaseName"],
        "DBAdminSecretName": [db_admin_secret_name],  # Use the custom secret name
        "DBAdminSecretARN": "",
        "DBAdminSecretPresent": ""
    })
