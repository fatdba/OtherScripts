SELECT r.rolname, current_database(),'DATABASE',l.lanname,'LANGUAGE',
ARRAY[(CASE WHEN has_language_privilege(r.rolname,lanname,'USAGE') THEN 'USAGE' ELSE NULL END)] ,r.rolcanlogin
FROM pg_catalog.pg_language l where has_language_privilege(r.rolname,lanname,'USAGE') 
;
