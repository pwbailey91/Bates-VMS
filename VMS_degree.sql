/*Query to generate the degree file for the VMS.*/
with first_yr_par as (
select par.constituent_key
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
select con.cons_id                                                            as "Constituent_Externalid",
       deg.apradeg_degc_code                                                  as "Constituent_Degree",
       to_char(deg.apradeg_date,'YYYY')                                       as "Constituent_DegreeYear",
       listagg(stv.stvmajr_desc,';') within group (order by stv.stvmajr_desc) as "Constituent_DegreeMajor"     
from population con
     inner join apradeg deg on con.pidm=deg.apradeg_pidm
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     left outer join apramaj maj on deg.apradeg_pidm=maj.apramaj_pidm and deg.apradeg_seq_no=maj.apramaj_adeg_seq_no
     left outer join stvmajr stv on maj.apramaj_majr_code=stv.stvmajr_code
where deg.apradeg_sbgi_code='003076' --Bates
      and deg.apradeg_degc_code is not null
group by con.cons_id, deg.apradeg_degc_code, deg.apradeg_date
