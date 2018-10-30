/*Query to generate the relatives file for the VMS. Gets all children and spouses that went to Bates.*/
with population as (
select con.constituent_key, con.cons_id, con.pidm
from adv_constituent_d con
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
where db.fiscal_year=rv.var_value
      and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (con.parent_scy=to_char(rv.var_value+3) or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
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
from population con
     inner join aprxref xref on con.pidm=xref.aprxref_pidm
     inner join adv_constituent_d rel on xref.aprxref_xref_pidm=rel.pidm
     inner join adv_reportvars_d rv on var_name='VOLUNTR_FY'
where xref.aprxref_xref_code in ('SPS','CHL','SCH','WRD','PRT')
      and rel.scy<>'n/a'
