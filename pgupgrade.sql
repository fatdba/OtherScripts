Upgrading PostgreSQL from version 9.6 to version 14 can be done with minimal downtime using a parallel installation approach. This method involves installing the new PostgreSQL version alongside the existing one, migrating the data, and then switching over. 


1. backup data of existing database :
/app/rnc/rnc-sql/bin/pg_dumpall -U postgres -f backup.sql


2. Install PostgreSQL 14: Install the new PostgreSQL version without removing the old version. 
sudo yum install -y https://download.postgresql.org/pub/repos/yum/14/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y postgresql14 postgresql14-server

or else using zip/tarball downloaded from PostgreSQL official website.
Lets assume the new directory is /app/rnc/rnc-sql14/bin


3. Initialize PostgreSQL 14 Database Cluster:
sudo -u postgres /app/rnc/rnc-sql14/bin/initdb -D /app/rnc/rnc-sql14/data


4. Data Migration
- Stop PostgreSQL 9.6.
  pg_ctl -D /app/rnc/rnc-sql/data stop
- Verify the database that it has been gracefully shut down.

5. Data Migration Using pg_upgrade.
The pg_upgrade tool allows you to upgrade your database to a new version with minimal downtime.

Run pg_upgrade:
sudo -u postgres /app/rnc/rnc-sql14/bin/pg_upgrade \
    -b /app/rnc/rnc-sql/bin \
    -B /app/rnc/rnc-sql14/bin \
    -d /app/rnc/rnc-sql/data \
    -D /app/rnc/rnc-sql14/data

Reference :
-b : The -b option specifies the directory containing the executables for the old PostgreSQL cluster (version 9.6 in this case). This is where the binaries like postgres, pg_ctl, etc., for version 9.6 are located.
-B : The -B option specifies the directory containing the executables for the new PostgreSQL cluster (version 14). This is where the binaries like postgres, pg_ctl, etc., for version 14 are located.
-d : The -d option specifies the data directory of the old PostgreSQL cluster (version 9.6). This is where the data files for version 9.6 are stored.
-D : The -D option specifies the data directory of the new PostgreSQL cluster (version 14). This is where the data files for version 14 will be stored after the upgrade.


We can also use with option --link. The --link option, if used, creates hard links rather than copying files, which can speed up the process.

sudo -u postgres /app/rnc/rnc-sql14/bin/pg_upgrade \
    --link \
    -b /app/rnc/rnc-sql/bin \
    -B /app/rnc/rnc-sql14/bin \
    -d /app/rnc/rnc-sql/data \
    -D /app/rnc/rnc-sql14/data




6. Post-Upgrade Steps: 
start PostgreSQL 14
  /app/rnc/rnc-sql14/bin/pg_ctl -D /app/rnc/rnc-sql/data start


7. ReIndex and Analyze :
sudo -u postgres /app/rnc/rnc-sql14/bin/vacuumdb --all --analyze-in-stages
sudo -u postgres /app/rnc/rnc-sql14/bin/reindexdb --all


8. Do sanity testing from application to make sure if all is running. 

9. Drop the previous 9.6 directory ONLY if the sanity went well. 
Maybe we still keep it for few days/weeks before dropping it. 




rollback :
==============
1. Initial Preparation
Ensure you have a complete and consistent backup before starting the upgrade process.

/app/rnc/rnc-sql/bin/pg_dumpall -U postgres -f backup.sql


2. Preserve Configuration Files
Before starting the upgrade, make a copy of the configuration files (postgresql.conf, pg_hba.conf, etc.) from both PostgreSQL 9.6 and PostgreSQL 14.

cp /app/rnc/rnc-sql/data/postgresql.conf /app/rnc/rnc-sql/data/postgresql.conf.bak
cp /app/rnc/rnc-sql14/data/postgresql.conf /app/rnc/rnc-sql14/data/postgresql.conf.bak
cp /app/rnc/rnc-sql/data/pg_hba.conf /app/rnc/rnc-sql/data/pg_hba.conf.bak
cp /app/rnc/rnc-sql14/data/pg_hba.conf /app/rnc/rnc-sql14/data/pg_hba.conf.bak

3. Stop PostgreSQL 14 and Start PostgreSQL 9.6
If the upgrade fails or you encounter issues with PostgreSQL 14, you can stop PostgreSQL 14 and restart PostgreSQL 9.6.


4. Restore Data from Backup
If you need to revert back to PostgreSQL 9.6 and data has changed during the attempted upgrade, you can restore the data from the backup.

5. Reinitialize PostgreSQL 9.6 Data Directory (if needed):

sudo -u postgres /app/rnc/rnc-sql/bin/initdb -D /app/rnc/rnc-sql/data


6. Restore the backup:
psql -U postgres -f backup.sql



7. Restore Configuration Files
If you made any changes to the configuration files during the upgrade, restore the backup copies:

cp /app/rnc/rnc-sql/data/postgresql.conf.bak /app/rnc/rnc-sql/data/postgresql.conf
cp /app/rnc/rnc-sql/data/pg_hba.conf.bak /app/rnc/rnc-sql/data/pg_hba.conf
