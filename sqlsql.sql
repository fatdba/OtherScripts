SELECT r.rolname, current_database(),'DATABASE',fdwname,'FDW', 'FDW OWNER',r.rolcanlogin
FROM pg_catalog.pg_foreign_data_wrapper 
WHERE has_foreign_data_wrapper_privilege(r.rolname,fdwname,'USAGE')
and fdwowner =  r.oid;
