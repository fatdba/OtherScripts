
[ERROR] ClientError: An error occurred (AccessDeniedException) when calling the GetSecretValue operation: User: arn:aws:sts::219586591115:assumed-role/drift_detection/drift_detection_suresh is not authorized to perform: secretsmanager:GetSecretValue on resource: arn:aws:secretsmanager:us-east-2:929661497517:secret:dev/rds/horizon-Ou4RpV because no resource-based policy allows the secretsmanager:GetSecretValue action
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 21, in lambda_handler
    get_secret_value_response = client.get_secret_value(
  File "/var/runtime/botocore/client.py", line 530, in _api_call
    return self._make_api_call(operation_name, kwargs)
  File "/var/runtime/botocore/client.py", line 960, in _make_api_call
    raise error_class(parsed_response, operation_name)

Looking at the CloudTrail logs for the "GetSecretValue" API call I can see that the role "LambdaCrossAccountFunctionRole" is returning a KMS access error "Access to KMS is not allowed". Due to cross-account privacy you can find the resources on the related case.
