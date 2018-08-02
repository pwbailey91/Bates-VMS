/*Query to generate the degree file for the VMS.*/
select con.cons_id                                                            as "Constituent_Externalid",
       deg.apradeg_degc_code                                                  as "Constituent_Degree",
       to_char(deg.apradeg_date,'YYYY')                                       as "Constituent_DegreeYear",
       listagg(stv.stvmajr_desc,';') within group (order by stv.stvmajr_desc) as "Constituent_DegreeMajor"     
from adv_constituent_d con
inner join apradeg deg on con.pidm=deg.apradeg_pidm
left outer join apramaj maj on deg.apradeg_pidm=maj.apramaj_pidm and deg.apradeg_seq_no=maj.apramaj_adeg_seq_no
left outer join stvmajr stv on maj.apramaj_majr_code=stv.stvmajr_code
where deg.apradeg_sbgi_code='003076' --Bates
and con.primary_donor_code='A'
--and con.deceased_ind='N'
and deg.apradeg_degc_code is not null
group by con.cons_id, deg.apradeg_degc_code, deg.apradeg_date
