/*Query to generate the relatives file for the VMS. Gets all children and spouses that went to Bates.*/
with first_yr_par as (
select distinct par.constituent_key
from aprpros
     inner join adv_constituent_d stu on aprpros_pidm=stu.pidm
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     inner join aprxref on aprpros_pidm=aprxref_pidm and aprxref_xref_code='PAR'
     inner join adv_constituent_d par on aprxref_xref_pidm=par.pidm
where aprpros_prtp_code='ADIN'
      and aprpros_prcd_code='FAN'
      and par.parent_scy=to_char(rv.VAR_VALUE+3)
),
population as (
select /*+materialize*/ con.constituent_key, con.cons_id, con.pidm
from adv_constituent_d con
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     left outer join first_yr_par fyp on con.constituent_key=fyp.constituent_key
where db.fiscal_year=rv.var_value
      and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (fyp.constituent_key is not null or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
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
