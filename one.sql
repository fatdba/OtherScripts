	Example Scenario:
	Imagine you're managing multiple databases, and each database has its own secret (like a password) stored in a secret manager. Also, these secrets might be stored in different environments such as development, staging, and production.

	Code Explanation with Examples:
	The code snippet is like a preparation step before checking the secrets. Let's break it down:

	rds_secrets_list: This is an empty list where you'll store information about the potential secrets for each database.

	Loop through each database instance (let's call each database "DB1", "DB2", etc.).

	secrets_environments: Imagine secrets_environments is set to "dev,stage,prod".

	For the current database instance (let's say it's "DB1"):

	db_admin_secret_name_list: Start with an empty list to hold potential secret names.
	db_admin_secret_name: Create a list of possible secret names for "DB1":
	'/secret/DB1/rds-password'
	'/secret/DB1/rds-password-v2'
	Add these possible secret names to db_admin_secret_name_list.
	db_admin_secret_name_suffix: Set it as '/rds/DB1'.
	Loop through the environments ("dev", "stage", "prod"):
	For each environment, combine the environment name with the suffix to create more potential secret names, like '/dev/rds/DB1', '/stage/rds/DB1', and '/prod/rds/DB1'.
	Add these environment-specific secret names to db_admin_secret_name_list.
	Now, db_admin_secret_name_list contains all the possible secret names for "DB1" in different environments.

	Create a dictionary entry for "DB1" and add it to the rds_secrets_list:

	ScanID: The ID of the current scan.
	AccountID: The ID of the current account.
	DBInstanceID: The ID of the current database ("DB1").
	DatabaseName: The name of the current database ("DB1").
	DBAdminSecretName: The list of possible secret names.
	DBAdminSecretARN: An empty placeholder for the secret's Amazon Resource Name (ARN).
	DBAdminSecretPresent: An empty placeholder to indicate whether the secret is present.
	Repeat this process for each database instance ("DB2", "DB3", etc.), creating entries in rds_secrets_list for each.

	In Short:
	The code prepares a list (rds_secrets_list) that contains all the potential secret names for each database instance. It considers different environments and builds variations of secret names based on the database's attributes. Later, this list will be used to check whether these secrets exist and to track their attributes.
