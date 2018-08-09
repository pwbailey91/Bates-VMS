/*Query to generate the degree file for the VMS.*/
with last_gift as (--Get fiscal year of most recent household gift, used in filtering parents to include
select hhg.household_key, max(hhg.fiscal_year) as fiscal_year
from adv_hh_giving_f hhg
     inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
where gd.soft_credit_ind='N' and gd.anon_ind='N'
group by hhg.household_key
)
select con.cons_id                                                            as "Constituent_Externalid",
       deg.apradeg_degc_code                                                  as "Constituent_Degree",
       to_char(deg.apradeg_date,'YYYY')                                       as "Constituent_DegreeYear",
       listagg(stv.stvmajr_desc,';') within group (order by stv.stvmajr_desc) as "Constituent_DegreeMajor"     
from adv_constituent_d con
inner join apradeg deg on con.pidm=deg.apradeg_pidm
inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
left outer join apramaj maj on deg.apradeg_pidm=maj.apramaj_pidm and deg.apradeg_seq_no=maj.apramaj_adeg_seq_no
left outer join stvmajr stv on maj.apramaj_majr_code=stv.stvmajr_code
left outer join last_gift on con.household_key=last_gift.household_key
where deg.apradeg_sbgi_code='003076' --Bates
and ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
and deg.apradeg_degc_code is not null
group by con.cons_id, deg.apradeg_degc_code, deg.apradeg_date
