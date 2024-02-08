Telstra Hendrix :
-------------------
What is the ask here ? The expectations, the plan and the overall objective. 
 Based on my comprehension from the emails, it appears that a test system with EOC ECM with DXP 22.4 already installed with EDB 11.x and planning to upgrade it to EOCECM DXP 22.4 with DB on 15.x. 

The plan is to request the customer to share a backup dump (database) from their 21.1 system, which will subsequently be attempted to be restored on the test setup featuring EOC ECM 22.4.


The focus is on EDB migration or upgrade. 
running DXP 21.1 with EDB 11.7, targeting DXP 22.4 with EDB 15.5.


Is the application installed and configured on the target system , I mean on this newly creatred 22.4 system ?
how to access their environment ?
what kind of backup we will be getting from the customer - a physical or logival backup I mean 
What is the version of postgresql they are using it right now and what we will have on this 22.4 ? Is it edb in cloud or a regular edb installation ?
Additionally, clarification is sought on whether the installation will utilize a geo-redundant setup, with primary and replica instances situated in separate servers spanning different data centers. 
Any task list that wehave prepared for this ?
Any documentation that we have ?


Open points:
•	Database upgrade strategy between versions (logical replication)
•	SQL upgrade scripts for application changes -- to identify differences i.e. column level, table level and other databas objects level i.e. constraints, keys etc



--> execute an upgrade an old database 21.1 to 22.4 


access to env : 

telstra back in 2015 bscs upgrade and performance tuning 
cristos androud and bhaumik parekh. 

I provided support for Telstrack in 2015 during the BSCS upgrade, focusing on performance tuning and optimizations. The initiative was led by Christos Androu and Bhaumik.

ecm & EOC upgrade first
sanity for ecm and eoc 
then sr upgrade


no pc in use, rest all modules they use. 

