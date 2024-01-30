

Using DMS which uses replication instance & Replication tasks,


apprximate cost for this kind of setup
transit gateways
-----------------------------------------

paying for running RDS - storage cost, licnes cost and size of the instance, instance type, IO types etc. 
Data replication (data transfer cost) : No cost.



https://aws.amazon.com/rds/postgresql/pricing/

https://calculator.aws/#/createCalculator/RDSPostgreSQL

m4.10x large
single az
pricing model - ondemand or reserved (ondem) 
no need of an RDS proxy here.
storage : gp2 




Selected Instance:
db.m4.4xlarge
vCPU: 16
Memory: 64 GiB

1 instance(s) x 1.461 USD hourly x (100 / 100 Utilized/Month) x 730 hours in a month = 1066.5300 USD
Amazon RDS PostgreSQL instances cost (monthly): 1,066.53 USD


100 GB per month x 0.115 USD x 1 instances = 11.50 USD (Storage Cost)
Storage pricing (monthly): 11.50 USD

nothing new to pay in case of any existing configuration. 


DMS (addtiinal cost): 
pub-sub kinda arch


