SELECT r.rolname, current_database(),'DATABASE',nspname||'.'||proname,'FUNCTION','FUNCTION OWNER',r.rolcanlogin
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
and r.oid = p.proowner ;
