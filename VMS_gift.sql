/*Query to generate the gift file for the VMS.*/
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
select /*+materialize*/ con.constituent_key, con.household_key, con.cons_id
from adv_constituent_d con
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     left outer join first_yr_par fyp on con.constituent_key=fyp.constituent_key
where db.fiscal_year=rv.var_value
      and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (fyp.constituent_key is not null or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
)          
select con.cons_id                                                                                                        as "Constituent_Externalid",
       hhg.credit_amount                                                                                                  as "Gift_Amount",
       'Cash In'                                                                                                          as "Gift_Type",
       des.designation_ld                                                                                                 as "Gift_Allocation",
       cal2.fiscal_year                                                                                                   as "Gift_Year",
       hhg.gift_number||to_char(row_number() over 
       (partition by hhg.gift_number 
                  order by con.constituent_key,hhg.date_key_gift,hhg.campaign_key,
                        hhg.designation_key,hhg.gift_description_key,hhg.pledge_number),'FM09')                           as "Gift_TransactionId",
       to_char(cal.calendar_date,'MM/DD/YYYY')                                                                            as "Gift_Date"
from population con
     inner join adv_hh_giving_f hhg on con.household_key=hhg.household_key
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
     inner join adv_designation_d des on hhg.designation_key=des.designation_key
     inner join adv_campaign_d cam on hhg.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on hhg.date_key_gift=cal.date_key
     inner join adv_calendar_dv cal2 on cam.date_key_est=cal2.date_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
where gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cal2.fiscal_year between rv.var_value-4 and rv.var_value
      and cam.campaign_type_sd='AF' --Only BF gifts
