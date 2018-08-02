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
       case when gd.credit_type='MATCH' then 'Matching Gift' 
            else 'Cash' end                               as "GiftSummary_Type",
       cr.fiscal_year                                     as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_credit_f cr on con.household_key=cr.household_key
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     left outer join last_gift on con.household_key=last_gift.household_key
where (con.primary_donor_code='A' 
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cr.fiscal_year between rv.var_value-5 and rv.var_value
group by con.cons_id, cr.fiscal_year, (case when gd.credit_type='MATCH' then 'Matching Gift' else 'Cash' end)
union all
select con.cons_id                                        as "Constituent_Externalid",
       sum(pcr.credit_amount-pcr.credit_amount_paid)      as "GiftSummary_Amount",
       'Pledge Balance'                                   as "GiftSummary_Type",
       pcr.fiscal_year                                    as "GiftSummary_Year"
from adv_constituent_d con
     inner join adv_pledge_credit_f pcr on con.household_key=pcr.household_key
     inner join adv_pldg_description_d pld on pcr.pledge_description_key=pld.pldg_description_key
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     left outer join last_gift on con.household_key=last_gift.household_key
where (con.primary_donor_code='A' 
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and pld.soft_credit_ind='N'
      and pld.anon_ind='N'
      and pcr.fiscal_year between rv.var_value-5 and rv.var_value
group by con.cons_id, pcr.fiscal_year, pld.pledge_code_ld
order by "Constituent_Externalid", "GiftSummary_Year", "GiftSummary_Type"
