/*Query to generate the gift file for the VMS.*/
with last_gift as (--Get fiscal year of most recent household gift, used in filtering parents to include
select hhg.household_key, max(hhg.fiscal_year) as fiscal_year
from adv_hh_giving_f hhg
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by hhg.household_key
),
trustee_giving as (--Only include BF giving for trustees and top prospects
select distinct con.constituent_key
from adv_constituent_d con
     inner join adv_donor_group_b dg on con.donor_group_key=dg.donor_group_key
     inner join adv_donor_codes_d dc on dg.donor_code_key=dc.donor_code_key
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     left outer join afrctyp afr on con.pidm=afr.afrctyp_pidm and afr.afrctyp_dcyr_code=rv.var_value
where dc.donor_code_sd in ('T','TS')
      or afr.AFRCTYP_SOL_ORG='TP'
)
select con.cons_id                                                                                                        as "Constituent_Externalid",
       hhg.credit_amount                                                                                                  as "Gift_Amount",
       'Cash In'                                                                                                          as "Gift_Type",
       des.designation_ld                                                                                                 as "Gift_Allocation",
       hhg.fiscal_year                                                                                                    as "Gift_Year",
       con.cons_id || hhg.date_key_gift || to_char(row_number() over 
                (partition by con.cons_id,hhg.date_key_gift 
                order by hhg.gift_number,hhg.campaign_key,hhg.designation_key,
                      hhg.gift_description_key,hhg.pledge_number),'FM09')                                                 as "Gift_TransactionId",
       to_char(cal.calendar_date,'MM/DD/YYYY')                                                                            as "Gift_Date"
from adv_constituent_d con
     inner join adv_hh_giving_f hhg on con.household_key=hhg.household_key
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
     inner join adv_designation_d des on hhg.designation_key=des.designation_key
     inner join adv_campaign_d cam on hhg.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on hhg.date_key_gift=cal.date_key
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     left outer join last_gift on con.household_key=last_gift.household_key
     left outer join trustee_giving on con.constituent_key=trustee_giving.constituent_key
where (con.primary_donor_code='A' 
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and hhg.fiscal_year between rv.var_value-5 and rv.var_value
      and (trustee_giving.constituent_key is null or (cam.campaign_type_sd='AF' and cam.campaign_sd like 'B_F%'))--Only BF for trustees
