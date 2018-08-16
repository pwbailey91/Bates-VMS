/*Query to generate the activity file for the VMS.*/
with last_gift as (--Get fiscal year of most recent gift, used in filtering parents to include
select cr.constituent_key_credit, max(cr.fiscal_year) as fiscal_year
from adv_credit_f cr
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by cr.constituent_key_credit
)
select con.cons_id       as "Constituent_Externalid",
       actc.stvactc_desc as "Activity_Name",
       actp.stvactp_desc as "Activity_Type",
       acyr.apracyr_year as "Activity_Year"
from adv_constituent_d con
     inner join apracty acty on con.pidm=acty.apracty_pidm
     inner join stvactc actc on acty.apracty_actc_code=actc.stvactc_code
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     inner join stvactp actp on actc.stvactc_actp_code=actp.stvactp_code
     left outer join apracyr acyr on con.pidm=acyr.apracyr_pidm and acty.apracty_actc_code=acyr.apracyr_actc_code
     left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and actp.STVACTP_CODE in ('SOORG','SPRTS','ALUMN','ATHLE','PARNT')
      and actc.STVACTC_CODE <> 'DTYP'
