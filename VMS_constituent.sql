/*Query to generate the constituent file for the VMS. Pulls all alumni, current parents, parents from the past 3 class years, and parents who gave in the last year*/

with last_gift as (--Most recent gift per household with gift date and designation
select hhg.household_key,
       cal.calendar_date,
       cal.fiscal_year,
       des.designation_ld,
       sum(hhg.credit_amount) as gift_amount
from (select hhg.*, 
      max(hhg.date_key_gift) over (partition by hhg.household_key) as max_date,
      max(hhg.designation_key) over (partition by hhg.household_key,hhg.date_key_gift) as max_desg
      from adv_hh_giving_f hhg) hhg 
     inner join adv_calendar_dv cal on hhg.date_key_gift=cal.date_key
     inner join adv_designation_d des on hhg.designation_key=des.designation_key
where hhg.date_key_gift=hhg.max_date
      and hhg.designation_key=hhg.max_desg
group by hhg.household_key,cal.calendar_date,cal.fiscal_year,des.designation_ld
), 
exclusions as (--Pulls all exclusion codes into single row per constituent
select con.constituent_key,
       listagg(exc.exclusion_code_ld,';') within group (order by exc.exclusion_code_key) as exclusion_string
from adv_constituent_d con
     inner join adv_exclusion_group_b exg on con.exclusion_group_key=exg.exclusion_group_key
     inner join adv_exclusion_codes_d exc on exg.exclusion_code_key=exc.exclusion_code_key
group by con.constituent_key
),
alum_parent as (--Gets all constituents that are both alumni and parents
select con.constituent_key
from adv_constituent_d con
     inner join adv_donor_group_b dg on con.donor_group_key=dg.donor_group_key
     inner join adv_donor_codes_d dc on dg.donor_code_key=dc.donor_code_key
where dc.donor_code_sd in ('A','P')
group by con.constituent_key
having count(dc.donor_code_key)=2
),
affil as (--Pulls constituent affiliations into single row
select con.constituent_key,
       ';' || listagg(dc.donor_code_sd,';') within group (order by dc.donor_code_sd) || ';' as affil_short,
       listagg(dc.donor_code_ld,';') within group (order by dc.donor_code_sd) as affiliations
from adv_constituent_d con
     inner join adv_donor_group_b dg on con.donor_group_key=dg.donor_group_key
     inner join adv_donor_codes_d dc on dg.donor_code_key=dc.donor_code_key 
group by con.constituent_key    
)
--Main query
select con.cons_id                                                                                as "Constituent_Externalid",
       con.prefix                                                                                 as "Constituent_Prefix",
       con.first_name                                                                             as "Constituent_FirstName",
       con.middle_name                                                                            as "Constituent_MiddleName",
       con.last_name                                                                              as "Constituent_LastName",
       con.suffix                                                                                 as "Constituent_Suffix",
       con.pref_first_name                                                                        as "Preferred_FirstName",
       case when con.college_last_name is null then null 
            else(con.college_first_name || ' ' || con.college_middle_name 
                                        || ' ' || con.college_last_name) end                      as "Constituent_FormerName",
       con.gender                                                                                 as "Constituent_Gender",
       con.marital_desc                                                                           as "Constituent_MaritalStatus",
       con.scy                                                                                    as "Constituent_PrefClassYear",
       affil.affiliations                                                                         as "Constituent_Affiliation",
       case ci.pref_email when 'n/a' then null else ci.pref_email end                             as "Constituent_Email",
       case ci.home_phone when 'n/a' then null else ci.home_phone end                             as "Constituent_HomePhone",
       case ci.pref_mail_street1 when 'n/a' then null else ci.pref_mail_street1 end               as "Constituent_AddressStreet1",
       case ci.pref_mail_street2 when 'n/a' then null else ci.pref_mail_street2 end               as "Constituent_AddressStreet2",
       case ci.pref_mail_street3 when 'n/a' then null else ci.pref_mail_street3 end               as "Constituent_AddressStreet3",
       case ci.pref_mail_city when 'n/a' then null else ci.pref_mail_city end                     as "Constituent_AddressCity",
       case ci.pref_mail_state_code when 'n/a' then null else ci.pref_mail_state_code end         as "Constituent_AddressState",
       case ci.pref_mail_zip when 'n/a' then null else ci.pref_mail_zip end                       as "Constituent_AddressZip",
       case ci.pref_mail_nation_desc when 'n/a' then null else ci.pref_mail_nation_desc end       as "Constituent_AddressCountry",
       case when (instr(affil.affil_short,';T;')>0 or instr(affil.affil_short,';TS;')>0
                 or afr.afrctyp_sol_org='TP') then null 
                 else to_char(last_gift.calendar_date,'MM/DD/YYYY') end                           as "Constituent_LastGiftDate",
       case when (instr(affil.affil_short,';T;')>0 or instr(affil.affil_short,';TS;')>0
                 or afr.afrctyp_sol_org='TP') then null else last_gift.designation_ld end         as "LastGiftDesignation",
       case when (instr(affil.affil_short,';T;')>0 or instr(affil.affil_short,';TS;')>0
                 or afr.afrctyp_sol_org='TP') then null else last_gift.gift_amount end            as "Constituent_LastGiftAmount",
       case db.og_consec_yrs_giving when 0 then db.lyr_og_consec_yrs_giving 
                                    else db.og_consec_yrs_giving end                              as "ConsecutiveGivingYears",
       db.og_donor_status                                                                         as "Constituent_DonorStatus",
       afr.afrctyp_ask_amount                                                                     as "Constituent_AskAmount",
       case when instr(affil.affil_short,';T;')>0 then 'FALSE' --Trustee
            when instr(affil.affil_short,';TS;')>0 then 'FALSE' --Trustee spouse
            when afr.afrctyp_sol_org='TP' then 'FALSE' --Top Prospect
            when con.deceased_ind='Y' then 'FALSE' --Deceased
            else 'TRUE' end                                                                       as "Constituent_Selectable", 
       'TRUE'                                                                                     as "EditSelectableStatus",
       null                                                                                       as "Constituent_TeamManager",
       case con.deceased_ind when 'Y' then 'TRUE' else 'FALSE' end                                as "Constituent_Deceased",
       case exclusions.exclusion_string when 'none' then null 
            else exclusions.exclusion_string end                                                  as "Constituent_Restrictions",
       case afr.afrctyp_sol_org when 'TP' then 'Top Prospects'
                                when 'PA' then 'President''s Associates'  
                                when 'MDS' then 'Mount David Society Members'
                                when 'MDSP' then 'Mount David Society Prospects' 
                                when 'BFP' then 'Bates Fund Pipeline'
                                when 'GG' then 'General Giving'
                                when 'PAR' then 'Parents' end                                     as "Constituent_Segments",
       case sps.cons_id when 'n/a' then null else sps.cons_id end                                 as "Spouse_Externalid",
       case hhb.spouse_name when 'n/a' then null else hhb.spouse_name end                         as "Spouse_Name",
       case sps.scy when 'n/a' then null else sps.scy end                                         as "Spouse_ClassYear",
       apr.APREHIS_EMPL_POSITION                                                                  as "Business_JobTitle",
       coalesce(emp.last_name,apr.APREHIS_EMPR_NAME)                                              as "Business_Employer",
       atv.ATVSICC_DESC                                                                           as "Business_Industry",
       case emp.is_mg_company when 'Y' then 'TRUE' end                                            as "Business_EmployerMatch",
       case ci.work_city when 'n/a' then null else ci.work_city end                               as "Business_AddressCity",
       case ci.work_state_code when 'n/a' then null else ci.work_state_code end                   as "Business_AddressState",
       case when alum_parent.constituent_key is not null then 'TRUE' else 'FALSE' end             as "Constituent_AlumParent",
       case db.bf_consec_yrs_giving when 0 then db.lyr_bf_consec_yrs_giving 
                                    else db.bf_consec_yrs_giving end                              as "ConsecGivingYearsBF"
from adv_constituent_d con
     inner join adv_donor_codes_d pdc on con.primary_donor_code=pdc.donor_code_sd
     inner join adv_contact_info_d ci on con.contact_info_key=ci.contact_info_key
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.var_name='FY_RPT'
     inner join exclusions on con.constituent_key=exclusions.constituent_key
     inner join adv_household_b hhb on con.household_key=hhb.household_key and con.constituent_key=hhb.cons_key_sps1
     inner join adv_constituent_d sps on hhb.cons_key_sps2=sps.constituent_key
     inner join affil on con.constituent_key=affil.constituent_key
     left outer join last_gift on con.household_key=last_gift.household_key
     left outer join afrctyp afr on con.pidm=afr.afrctyp_constituent_pidm and afr.afrctyp_dcyr_code=rv.var_value
     left outer join aprehis apr on con.pidm=apr.APREHIS_PIDM and apr.APREHIS_PRIMARY_IND='Y' and apr.APREHIS_TO_DATE is null
     left outer join atvsicc atv on apr.APREHIS_SICC_CODE=atv.ATVSICC_CODE
     left outer join adv_constituent_d emp on apr.APREHIS_EMPR_PIDM=emp.pidm
     left outer join alum_parent on con.constituent_key=alum_parent.constituent_key
where (con.primary_donor_code='A' 
      or (con.primary_donor_code='P' and ((case con.parent_scy when 'n/a' then '0' else con.parent_scy end)>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      and db.fiscal_year=rv.var_value
