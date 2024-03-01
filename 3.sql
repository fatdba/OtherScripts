vi /etc/init.d/oraclestartnew

  904  systemctl daemon-reload
  905  systemctl start oracle-db
  906  systemctl status oracle-db



=========

dixitdb:/u01/app/oracle/product/19.0.0/dbhome_1:Y

# chkconfig: 345 90 10
The service is configured to be active in runlevels 3, 4, and 5.
During startup, it has a start priority of 90, meaning it will start after services with lower start priorities and before those with higher start priorities.
During shutdown, it has a stop priority of 10, meaning it will stop before services with lower stop priorities and after those with higher stop priorities.

#!/bin/bash
# Author : Prashant 
# Purpose : This is a standard INIT script
# Next is the service priority runlevel startpriority stoppriority 
# chkconfig: 345 90 10
# Set Oracle environment variables
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_OWNER=oracle
#LOG_FILE=/tmp/oraclestartup.log
# Start Oracle Database using dbstart
su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/dbstart" > /dev/null 2>&1 &
su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/lsnrctl start"  > /dev/null 2>&1 &

# Exit the script without waiting for the background process
exit 0
[root@oracleontario init.d]#



[root@oracleontario init.d]# ln -s /etc/init.d/oraclestartnew /etc/rc.d/rc0.d/K01oraclestartnew
--> So, this command is creating a symbolic link named K01oraclestartnew in the /etc/rc.d/rc0.d/ directory, pointing to the service script /etc/init.d/oraclestartnew. During system shutdown (when entering runlevel 0), this link will instruct the system to stop the oraclestartnew service with a priority of 01, meaning it should be one of the first services to be stopped.

[root@oracleontario init.d]# ln -s /etc/init.d/oraclestartnew /etc/rc.d/rc3.d/S99oraclestartnew
--> So, this command is creating a symbolic link named S99oraclestartnew in the /etc/rc.d/rc3.d/ directory, pointing to the service script /etc/init.d/oraclestartnew. During system startup (when entering runlevel 3), this link will instruct the system to start the oraclestartnew service with a priority of 99, meaning it should be one of the last services to be started.
Multiple user modes under the command line interface and not under the graphical user interface.

[root@oracleontario init.d]# ln -s /etc/init.d/oraclestartnew /etc/rc.d/rc5.d/S99oraclestartnew
--> So, this command is creating a symbolic link named S99oraclestartnew in the /etc/rc.d/rc5.d/ directory, pointing to the service script /etc/init.d/oraclestartnew. During system startup (when entering runlevel 5), this link will instruct the system to start the oraclestartnew service with a priority of 99, meaning it should be one of the last services to be started.
Multiple user mode under GUI (graphical user interface) and this is the standard runlevel

[root@oracleontario init.d]# chkconfig --add oraclestartnew
[root@oracleontario init.d]#
[root@oracleontario init.d]# service oraclestartnew start
[root@oracleontario init.d]#
[root@oracleontario init.d]# service oraclestartnew status
[root@oracleontario init.d]#
[root@oracleontario init.d]# ps -ef|egrep 'tns|pmon'
root         14      2  0 11:10 ?        00:00:00 [netns]
oracle    48793      1  1 21:24 ?        00:00:00 /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr LISTENER -inherit
oracle    49017      1  0 21:24 ?        00:00:00 ora_pmon_dixitdb
root      49396  25648  0 21:25 pts/1    00:00:00 grep -E --color=auto tns|pmon
[root@oracleontario init.d]#


[root@oracleontario init.d]# reboot
login as: root
root@192.168.68.73's password:
Last login: Thu Feb 29 17:21:02 2024 from 192.168.68.59


[root@oracleontario ~]#
[root@oracleontario ~]# ps -ef|egrep 'tns|pmon'
root         14      2  0 21:28 ?        00:00:00 [netns]
oracle     1817      1  0 21:28 ?        00:00:00 /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr LISTENER -inherit
oracle     2291      1  0 21:29 ?        00:00:00 ora_pmon_dixitdb
root       2319   2123  0 21:29 pts/0    00:00:00 grep -E --color=auto tns|pmon
[root@oracleontario ~]#
