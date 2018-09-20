/*Query to generate the gift file for the VMS.*/

select con.cons_id                                                                                                        as "Constituent_Externalid",
       hhg.credit_amount                                                                                                  as "Gift_Amount",
       'Cash In'                                                                                                          as "Gift_Type",
       des.designation_ld                                                                                                 as "Gift_Allocation",
       hhg.fiscal_year                                                                                                    as "Gift_Year",
       hhg.gift_number||to_char(row_number() over 
       (partition by hhg.gift_number 
                  order by con.constituent_key,hhg.date_key_gift,hhg.campaign_key,
                        hhg.designation_key,hhg.gift_description_key,hhg.pledge_number),'FM09')                           as "Gift_TransactionId",
       to_char(cal.calendar_date,'MM/DD/YYYY')                                                                            as "Gift_Date"
from adv_constituent_d con
     inner join adv_hh_giving_f hhg on con.household_key=hhg.household_key
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
     inner join adv_designation_d des on hhg.designation_key=des.designation_key
     inner join adv_campaign_d cam on hhg.campaign_key=cam.campaign_key
     inner join adv_calendar_dv cal on hhg.date_key_gift=cal.date_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
where (con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and hhg.fiscal_year between rv.var_value-5 and rv.var_value
      and cam.campaign_type_sd='AF' --Only BF gifts
