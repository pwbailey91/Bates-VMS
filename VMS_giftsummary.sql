/*Query to generate the gift summary file for the VMS.*/
select con.cons_id                                        as "Constituent_Externalid",
       sum(cr.credit_amount)                              as "GiftSummary_Amount",
       case when gd.credit_type='MATCH' then 'Matching Gift' 
            else 'Cash' end                               as "GiftSummary_Type",
       cr.fiscal_year                                     as "GiftSummary_Year"
from adv_constituent_d con
inner join adv_credit_f cr on con.household_key=cr.household_key
inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
inner join adv_reportvars_d rpt on rpt.var_name='FY_RPT'
where con.primary_donor_code='A'
--and con.deceased_ind='N'
and gd.soft_credit_ind='N'
and cr.fiscal_year between rpt.var_value-5 and rpt.var_value
group by con.cons_id, cr.fiscal_year, (case when gd.credit_type='MATCH' then 'Matching Gift' else 'Cash' end)
union all
select con.cons_id                                        as "Constituent_Externalid",
       sum(pcr.credit_amount-pcr.credit_amount_paid)      as "GiftSummary_Amount",
       'Pledge Balance'                                   as "GiftSummary_Type",
       pcr.fiscal_year                                    as "GiftSummary_Year"
from adv_constituent_d con
inner join adv_pledge_credit_f pcr on con.household_key=pcr.household_key
inner join adv_pldg_description_d pld on pcr.pledge_description_key=pld.pldg_description_key
inner join adv_reportvars_d rpt on rpt.var_name='FY_RPT'
where con.primary_donor_code='A'
--and con.deceased_ind='N'
and pld.soft_credit_ind='N'
and pcr.fiscal_year between rpt.var_value-5 and rpt.var_value
group by con.cons_id, pcr.fiscal_year, pld.pledge_code_ld
order by "Constituent_Externalid", "GiftSummary_Year", "GiftSummary_Type"
