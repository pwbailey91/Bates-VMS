/*Query to generate the affiliation file for the VMS.*/
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
select /*+materialize*/ con.constituent_key, con.cons_id, con.pidm, con.donor_group_key, con.scy, con.parent_scy
from adv_constituent_d con
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
     left outer join first_yr_par fyp on con.constituent_key=fyp.constituent_key
where db.fiscal_year=rv.var_value
      and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (fyp.constituent_key is not null or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
)    
select pop.cons_id as constituent_id,
       dc.donor_code_ld as affiliation_name,
       case dc.donor_code_sd when 'A' then replace(pop.scy,'n/a')
                             when 'P' then replace(pop.parent_scy,'n/a') end as affiliation_year
from population pop
     inner join adv_donor_group_b dg on pop.donor_group_key=dg.donor_group_key
     inner join adv_donor_codes_d dc on dg.donor_code_key=dc.donor_code_key
where dc.donor_code_sd in ('A','P')
order by pop.cons_id
     
