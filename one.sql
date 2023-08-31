select rolname,'ALL','ALL','ALL','ALL','SUPERUSER','SERVER',rolcanlogin from pg_roles where rolsuper is true;

select rolname,'ALL','ALL','ALL','ALL','CREATE DATABASE','SERVER',rolcanlogin from pg_roles where rolcreatedb is true and rolsuper is false;

select rolname,'ALL','ALL','ALL','ALL','REPLICATION','SERVER',rolcanlogin from pg_roles where rolreplication is true and rolsuper is false;

select rolname,'ALL','ALL','ALL','ALL','CREATE ROLE','SERVER',rolcanlogin from pg_roles where rolcreaterole is true and rolsuper is false;
