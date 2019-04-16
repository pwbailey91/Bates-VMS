/*Query to generate the activity file for the VMS.*/
with first_yr_par as (
select distinct par.constituent_key
from aprpros
     inner join adv_constituent_d stu on aprpros_pidm=stu.pidm
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     inner join aprxref on aprpros_pidm=aprxref_pidm and aprxref_xref_code='PAR'
     inner join adv_constituent_d par on aprxref_xref_pidm=par.pidm
where aprpros_prtp_code='ADIN'
      and aprpros_prcd_code='FAN'
      and par.parent_scy=to_char(rv.VAR_VALUE+3)
),
population as (
select /*+materialize*/ con.constituent_key, con.cons_id, con.pidm
from adv_constituent_d con
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     --left outer join first_yr_par fyp on con.constituent_key=fyp.constituent_key
where db.fiscal_year=rv.var_value
      and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (con.parent_scy>=rv.var_value or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
)   
select con.cons_id       as "Constituent_Externalid",
       actc.stvactc_desc as "Activity_Name",
       actp.stvactp_desc as "Activity_Type",
       acyr.apracyr_year as "Activity_Year"
from population con
     inner join apracty acty on con.pidm=acty.apracty_pidm
     inner join stvactc actc on acty.apracty_actc_code=actc.stvactc_code
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join stvactp actp on actc.stvactc_actp_code=actp.stvactp_code
     left outer join apracyr acyr on con.pidm=acyr.apracyr_pidm and acty.apracty_actc_code=acyr.apracyr_actc_code
where actp.STVACTP_CODE in ('SOORG','SPRTS','ALUMN','ATHLE','PARNT')
      and actc.STVACTC_CODE not in ('DTYP','1276','1259')
