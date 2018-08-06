/*Query to generate the activity file for the VMS.*/
with last_gift as (--Get fiscal year of most recent household gift, used in filtering parents to include
select hhg.household_key, max(hhg.fiscal_year) as fiscal_year
from adv_hh_giving_f hhg
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by hhg.household_key
)
select con.cons_id       as "Constituent_Externalid",
       actc.stvactc_desc as "Activity_Name",
       actp.stvactp_desc as "Activity_Type",
       acyr.apracyr_year as "Activity_Year"
from adv_constituent_d con
     inner join apracty acty on con.pidm=acty.apracty_pidm
     inner join stvactc actc on acty.apracty_actc_code=actc.stvactc_code
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     left outer join apracyr acyr on con.pidm=acyr.apracyr_pidm and acty.apracty_actc_code=acyr.apracyr_actc_code
     left outer join stvactp actp on actc.stvactc_actp_code=actp.stvactp_code
     left outer join last_gift on con.household_key=last_gift.household_key
where (con.primary_donor_code='A' 
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
