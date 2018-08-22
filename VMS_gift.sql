/*Query to generate the gift file for the VMS.*/

with last_gift as (--Get fiscal year of most recent gift, used in filtering parents to include
select cr.constituent_key_credit, max(cr.fiscal_year) as fiscal_year
from adv_credit_f cr
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by cr.constituent_key_credit
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
select con.cons_id                                                                                                      as "Constituent_Externalid",
       cr.credit_amount                                                                                                 as "Gift_Amount",
       'Cash In'                                                                                                        as "Gift_Type",
       des.designation_ld                                                                                               as "Gift_Allocation",
       cr.fiscal_year                                                                                                   as "Gift_Year",
       cr.gift_number||to_char(row_number() over 
       (partition by cr.gift_number 
                  order by con.constituent_key,cr.date_key_gift,cr.campaign_key,
                        cr.designation_key,cr.gift_description_key,cr.pledge_number),'FM09')                            as "Gift_TransactionId",
       to_char(cal.calendar_date,'MM/DD/YYYY')                                                                          as "Gift_Date"
from adv_constituent_d con
     inner join adv_credit_f cr on con.constituent_key=cr.constituent_key_credit
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_designation_d des on cr.designation_key=des.designation_key
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on cr.date_key_gift=cal.date_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
     left outer join trustee_giving on con.constituent_key=trustee_giving.constituent_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cr.fiscal_year between rv.var_value-5 and rv.var_value
      and (trustee_giving.constituent_key is null or cam.campaign_type_sd='AF')--Only BF for trustees
