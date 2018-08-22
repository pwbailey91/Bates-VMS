/*Query to generate the relatives file for the VMS. Gets all children and spouses that went to Bates.*/
with last_gift as (--Get fiscal year of most recent gift, used in filtering parents to include
select cr.constituent_key_credit, max(cr.fiscal_year) as fiscal_year
from adv_credit_f cr
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by cr.constituent_key_credit
)
select con.cons_id                                                  as "Constituent_Externalid",
       rel.cons_id                                                  as "Relative_ExternalId",
       rel.first_name || ' ' || rel.last_name                       as "Relative_Name",
       rel.scy                                                      as "Relative_ClassYear",
       case xref.aprxref_xref_code when 'SPS' then 'Spouse'
                                   when 'CHL' then 'Child'
                                   when 'SCH' then 'Stepchild'
                                   when 'WRD' then 'Ward'
                                   when 'PRT' then 'Partner' end    as "Relative_Type",
       rel.gender                                                   as "Relative_Gender",
       case rel.deceased_ind when 'Y' then 'TRUE' else 'FALSE' end  as "Relative_Deceased"
from adv_constituent_d con
inner join aprxref xref on con.pidm=xref.aprxref_pidm
inner join adv_constituent_d rel on xref.aprxref_xref_pidm=rel.pidm
inner join adv_reportvars_d rv on var_name='VOLUNTR_FY'
left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
where xref.aprxref_xref_code in ('SPS','CHL','SCH','WRD','PRT')
and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
and rel.scy<>'n/a'
