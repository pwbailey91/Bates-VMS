/*Query to generate the gift summary file for the VMS.*/
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
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     left outer join afrctyp afr on con.pidm=afr.afrctyp_pidm and afr.afrctyp_dcyr_code=rv.var_value
where dc.donor_code_sd in ('T','TS')
      or afr.AFRCTYP_SOL_ORG='TP'
)
select con.cons_id                                        as "Constituent_Externalid",
       sum(cr.credit_amount)                              as "GiftSummary_Amount",
       'Cash In'                                          as "GiftSummary_Type",
       cr.fiscal_year                                     as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_credit_f cr on con.household_key=cr.household_key
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
     left outer join trustee_giving on con.constituent_key=trustee_giving.constituent_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cr.fiscal_year between rv.var_value-5 and rv.var_value
      and (trustee_giving.constituent_key is null or cam.campaign_type_sd='AF')--Only BF for trustees
group by con.cons_id, cr.fiscal_year
union all
select con.cons_id                                        as "Constituent_Externalid",
       sum(pin.expected_amt-pin.install_amt_paid)         as "GiftSummary_Amount",
       'Pledge Balance'                                   as "GiftSummary_Type",
       pin.install_fiscal_year                            as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_pledge_install_f pin on con.constituent_key=pin.constituent_key_pledger
     inner join adv_pldg_description_d pld on pin.pledge_description_key=pld.pldg_description_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_campaign_d cam on pin.campaign_key=cam.campaign_key
     left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
     left outer join trustee_giving on con.constituent_key=trustee_giving.constituent_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and pld.soft_credit_ind='N'
      and pld.anon_ind='N'
      and pld.pledge_status_sd='A'
      and pin.install_fiscal_year between rv.var_value-5 and rv.var_value
      and (trustee_giving.constituent_key is null or cam.campaign_type_sd='AF')--Only BF for trustees
group by con.cons_id, pin.install_fiscal_year
having sum(pin.expected_amt-pin.install_amt_paid)>0
order by "Constituent_Externalid", "GiftSummary_Year", "GiftSummary_Type"
