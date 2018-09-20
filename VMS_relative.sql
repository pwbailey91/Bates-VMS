/*Query to generate the relatives file for the VMS. Gets all children and spouses that went to Bates.*/

select con.cons_id                                                                  as "Constituent_Externalid",
       rel.cons_id                                                                  as "Relative_ExternalId",
       rel.first_name || ' ' || rel.last_name || 
                      case when xref.APRXREF_XREF_CODE in ('CHL','SCH','WRD') then 
                        (' ''' || substr(rel.scy,3,2) ||
                        case when rel.deceased_ind='Y' then ' (d)' end) end         as "Relative_Name",
       rel.scy                                                                      as "Relative_ClassYear",
       case xref.aprxref_xref_code when 'SPS' then 'Spouse'
                                   when 'CHL' then 'Child'
                                   when 'SCH' then 'Stepchild'
                                   when 'WRD' then 'Ward'
                                   when 'PRT' then 'Partner' end                    as "Relative_Type",
       rel.gender                                                                   as "Relative_Gender",
       case rel.deceased_ind when 'Y' then 'TRUE' else 'FALSE' end                  as "Relative_Deceased"
from adv_constituent_d con
     inner join aprxref xref on con.pidm=xref.aprxref_pidm
     inner join adv_constituent_d rel on xref.aprxref_xref_pidm=rel.pidm
     inner join adv_reportvars_d rv on var_name='VOLUNTR_FY'
where xref.aprxref_xref_code in ('SPS','CHL','SCH','WRD','PRT')
      and (con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      and rel.scy<>'n/a'
