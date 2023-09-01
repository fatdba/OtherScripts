CloudWatch
Log groups
/aws/lambda/drift_detection_latest_prashant
2023/09/01/[$LATEST]e94f6062729a4e9b8b9a7fba5e15da2e


SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (16386, 'rds_superuser', 3373, 'pg_monitor');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (3373, 'pg_monitor', 3374, 'pg_read_all_settings');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (3373, 'pg_monitor', 3375, 'pg_read_all_stats');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (3373, 'pg_monitor', 3377, 'pg_stat_scan_tables');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (16386, 'rds_superuser', 4200, 'pg_signal_backend');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20515, 'fitb_admin', 16386, 'rds_superuser');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (16399, 'db_admin', 16386, 'rds_superuser');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (16386, 'rds_superuser', 16387, 'rds_replication');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20572, 'iam-bigid_user', 16388, 'rds_iam');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20567, 'iam-edm-pg_owner', 16388, 'rds_iam');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20565, 'iam-edm-pg_ro', 16388, 'rds_iam');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20563, 'iam-edm-pg_rw', 16388, 'rds_iam');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (16386, 'rds_superuser', 16389, 'rds_password');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20567, 'iam-edm-pg_owner', 20559, 'edmpg_db_owner');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20566, 'edm-pg_owner', 20559, 'edmpg_db_owner');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20515, 'fitb_admin', 20559, 'edmpg_db_owner');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20563, 'iam-edm-pg_rw', 20560, 'edmpg_db_rw');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20562, 'edm-pg_rw', 20560, 'edmpg_db_rw');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20515, 'fitb_admin', 20560, 'edmpg_db_rw');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20572, 'iam-bigid_user', 20561, 'edmpg_db_ro');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20571, 'bigid_user', 20561, 'edmpg_db_ro');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20565, 'iam-edm-pg_ro', 20561, 'edmpg_db_ro');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20564, 'edm-pg_ro', 20561, 'edmpg_db_ro');
SQL Statement: INSERT INTO audit_role_privileges_userinfo (user_role_id, user_role_name, other_role_id, other_role_name) VALUES (20515, 'fitb_admin', 20561, 'edmpg_db_ro');


flag: 2
['public_role_privileges', 'audit_role_privileges', 'audit_role_privileges_userinfo', 'connection_summary', 'instances_info', 'snapshots_info']

printresult
audit_role_privileges_userinfo
before_run_query_using_secrets
[INFO]	2023-09-01T22:46:07.195Z	4123b7ad-a9e1-4be8-9af5-36539c810ddb	DB name passed as parameter: None
[INFO]	2023-09-01T22:46:07.196Z	4123b7ad-a9e1-4be8-9af5-36539c810ddb	DB name being used: edmpg_db
[INFO]	2023-09-01T22:46:07.227Z	4123b7ad-a9e1-4be8-9af5-36539c810ddb	Successfully established SSL/TLS connection as user 'db_admin' with host: 'edm-pg-v2.cluster-cv88e32pyp96.us-east-2.rds.amazonaws.com'
[INFO]	2023-09-01T22:46:07.240Z	4123b7ad-a9e1-4be8-9af5-36539c810ddb	query_using_secrets: Successfully executed query in PostgreSQL DB using secret in arn:aws:secretsmanager:us-east-2:219586591115:secret:/secret/edm-pg/rds-password-dPyQM8.
after_run_query_using_secrets
[]
printresult
No data found for audit_role_privileges_userinfo
