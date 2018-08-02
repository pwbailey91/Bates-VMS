/*Query to generate the activity file for the VMS.*/
select con.cons_id       as "Constituent_Externalid",
       actc.stvactc_desc as "Activity_Name",
       actp.stvactp_desc as "Activity_Type",
       acyr.apracyr_year as "Activity_Year"
from adv_constituent_d con
inner join apracyr acyr on con.pidm=acyr.apracyr_pidm
inner join stvactc actc on acyr.apracyr_actc_code=actc.stvactc_code
left outer join stvactp actp on actc.stvactc_actp_code=actp.stvactp_code
where con.primary_donor_code='A'
--and con.deceased_ind='N'
