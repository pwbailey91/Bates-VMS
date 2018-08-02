/*Query to generate the relatives file for the VMS.*/
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
where xref.aprxref_xref_code in ('SPS','CHL','SCH','WRD','PRT')
and con.primary_donor_code='A'
and rel.scy<>'n/a'
--and rel.primary_donor_code='A'
--and con.deceased_ind='N'
