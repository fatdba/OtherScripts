-bash-4.2$ aws s3 ls s3://edm-saas-dev-arrxi
Traceback (most recent call last):
  File "/usr/bin/aws", line 19, in <module>
    import awscli.clidriver
  File "/usr/lib/python2.7/site-packages/awscli/clidriver.py", line 17, in <module>
    import botocore.session
ImportError: No module named botocore.session
