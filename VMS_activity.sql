/*Query to generate the activity file for the VMS.*/

select con.cons_id       as "Constituent_Externalid",
       actc.stvactc_desc as "Activity_Name",
       actp.stvactp_desc as "Activity_Type",
       acyr.apracyr_year as "Activity_Year"
from adv_constituent_d con
     inner join apracty acty on con.pidm=acty.apracty_pidm
     inner join stvactc actc on acty.apracty_actc_code=actc.stvactc_code
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join stvactp actp on actc.stvactc_actp_code=actp.stvactp_code
     left outer join apracyr acyr on con.pidm=acyr.apracyr_pidm and acty.apracty_actc_code=acyr.apracyr_actc_code
where (con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      and actp.STVACTP_CODE in ('SOORG','SPRTS','ALUMN','ATHLE','PARNT')
      and actc.STVACTC_CODE <> 'DTYP'
