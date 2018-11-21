/*Query to generate the gift summary file for the VMS.*/
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
select con.cons_id                                        as "Constituent_Externalid",
       sum(cr.credit_amount)                              as "GiftSummary_Amount",
       'Cash In - Summary'                                as "GiftSummary_Type",
       cal.fiscal_year                                    as "GiftSummary_Year"
from population con
     inner join adv_credit_f cr on con.constituent_key=cr.constituent_key_credit
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on cam.date_key_est=cal.date_key
where gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cal.fiscal_year between rv.var_value-4 and rv.var_value
      and cam.campaign_type_sd='AF' --Only BF gifts
group by con.cons_id, cal.fiscal_year
union all
select con.cons_id                                        as "Constituent_Externalid",
       sum(cr.credit_amount)                              as "GiftSummary_Amount",
       'Cash In'                                          as "GiftSummary_Type",
       cal.fiscal_year                                    as "GiftSummary_Year"
from population con
     inner join adv_hh_giving_f cr on con.household_key=cr.household_key
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on cam.date_key_est=cal.date_key
where gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cal.fiscal_year between rv.var_value-4 and rv.var_value
      and cam.campaign_type_sd='AF' --Only BF gifts
group by con.cons_id, cal.fiscal_year
union all
select "Constituent_Externalid",
       "GiftSummary_Amount",
       "GiftSummary_Type",
       "GiftSummary_Year" 
from (
select con.cons_id                                        as "Constituent_Externalid",
       sum(pin.expected_amt-pin.install_amt_paid)         as "Pledge Balance",
       sum(pin.expected_amt)                              as "Pledge Amount",
       sum(pin.expected_amt-pin.install_amt_paid)/
       (count(distinct sps.constituent_key)+1)            as "Pledge Balance - Summary",
       sum(pin.expected_amt)/
       (count(distinct sps.constituent_key)+1)            as "Pledge Amount - Summary",
       cal.fiscal_year                                    as "GiftSummary_Year"
from population con
     inner join adv_pledge_install_f pin on con.constituent_key=pin.constituent_key_pledger
     inner join adv_pldg_description_d pld on pin.pledge_description_key=pld.pldg_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on pin.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on cam.date_key_est=cal.date_key
     inner join adv_household_b hhb on con.household_key=hhb.household_key and con.constituent_key=hhb.cons_key_sps1
     left outer join adv_constituent_d sps on hhb.cons_key_sps2=sps.constituent_key and sps.primary_donor_code='A'
where pld.soft_credit_ind='N'
      and pld.anon_ind='N'
      and pld.pledge_status_sd='A'
      and cal.fiscal_year=rv.var_value
      and cam.campaign_type_sd='AF' --Only BF pledges
group by con.cons_id, cal.fiscal_year
) unpivot 
  ("GiftSummary_Amount" for "GiftSummary_Type" in ("Pledge Balance","Pledge Amount","Pledge Balance - Summary","Pledge Amount - Summary")
)

