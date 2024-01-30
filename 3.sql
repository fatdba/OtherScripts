I have completed my analysis to obtain costing information for the logical replication approach, and the following highlights encompass each of the involved components:

In the scenario where the primary instance resides in the customer's on-premises data center, the costs will be associated with running RDS, including storage cost, licensing cost, instance size, instance type, IO types, etc.

No data replication costs will be incurred.

If we opt for the "db.m4.4xlarge" type for the RDS instance (16 vCPUs) with 64 GB memory, a single AZ, no RDS Proxy, and an on-demand instance, the monthly cost for Amazon RDS PostgreSQL instances will be $1,066.53. This is calculated as follows: 1 instance(s) x $1.461 hourly x (100% utilization/month) x 730 hours in a month = $1,066.53.

Assuming 100 GB storage with the general-purpose gp2 type, the monthly storage cost will be $11.50: 100 GB per month x $0.115 x 1 instance = $11.50 (Storage Cost).

It is assumed that the network configuration between on-premises and AWS infrastructure already exists, and no new networking components such as Transit Gateways, networking rules, or objects need to be created.

DMS-based logical replication setup is not considered, and native PostgreSQL replication methods will be used to avoid additional costs for replication instances, storage, and computation.
