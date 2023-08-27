[ERROR] IndexError: list index out of range
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 582, in lambda_handler
    scan_id = str(result[0]._asdict()["nextval"])
