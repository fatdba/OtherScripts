with elevated_perm_proc as
(
SELECT  row_number() over( order by p.oid),p.oid,nspname,proname,format_type(unnest(proargtypes)::oid,NULL)
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
pg_authid a ON a.oid = p.proowner 
WHERE prosecdef OR NOT proconfig IS NULL
),

func_with_elvated_priv as
(
select  oid,nspname,proname,array_to_string(array_agg(format_type),',') as proc_param
from elevated_perm_proc
group by oid,nspname,proname
union
select p.oid,nspname,proname,' ' as proc_param
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
pg_authid a ON a.oid = p.proowner 
WHERE (prosecdef OR NOT proconfig IS NULL)
and p.oid not in
(select oid from elevated_perm_proc )
),
func_with_elvated_priv1 as
( select current_database() as dbname,'DATABASE' as level ,nspname||'.'||proname||'('||proc_param||')' as f
from func_with_elvated_priv 
            where nspname not in ('dbms_scheduler','dbms_session','pg_catalog','sys','utl_http')
)
SELECT r.rolname, func.*,'FUNCTION','Elevated Privileges',r.rolcanlogin
from func_with_elvated_priv1 func
where has_function_privilege(r.rolname,func.f,'execute')=true;
