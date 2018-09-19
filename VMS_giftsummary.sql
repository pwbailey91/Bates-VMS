/*Query to generate the gift summary file for the VMS.*/
with last_gift as (--Get fiscal year of most recent household gift, used in filtering parents to include
select hhg.household_key, max(hhg.fiscal_year) as fiscal_year
from adv_hh_giving_f hhg
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by hhg.household_key
)
select con.cons_id                                        as "Constituent_Externalid",
       sum(cr.credit_amount)                              as "GiftSummary_Amount",
       'Cash In - Summary'                                as "GiftSummary_Type",
       cr.fiscal_year                                     as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_credit_f cr on con.constituent_key=cr.constituent_key_credit
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     left outer join last_gift on con.household_key=last_gift.household_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cr.fiscal_year between rv.var_value-5 and rv.var_value
      and cam.campaign_type_sd='AF' --Only BF gifts
group by con.cons_id, cr.fiscal_year
union all
select "Constituent_Externalid",
       "GiftSummary_Amount",
       "GiftSummary_Type",
       "GiftSummary_Year" 
from (
select con.cons_id                                        as "Constituent_Externalid",
       sum(pin.expected_amt-pin.install_amt_paid)         as "Pledge Balance",
       sum(pin.expected_amt)                              as "Pledge Amount",
       pin.install_fiscal_year                            as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_pledge_install_f pin on con.constituent_key=pin.constituent_key_pledger
     inner join adv_pldg_description_d pld on pin.pledge_description_key=pld.pldg_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on pin.campaign_key=cam.campaign_key
     left outer join last_gift on con.household_key=last_gift.household_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and pld.soft_credit_ind='N'
      and pld.anon_ind='N'
      and pld.pledge_status_sd='A'
      and pin.install_fiscal_year=rv.var_value
      and cam.campaign_type_sd='AF' --Only BF pledges
group by con.cons_id, pin.install_fiscal_year
) unpivot 
  ("GiftSummary_Amount" for "GiftSummary_Type" in ("Pledge Balance","Pledge Amount")
)
order by "Constituent_Externalid", "GiftSummary_Year", "GiftSummary_Type"
