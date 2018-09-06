/*Query to generate the constituent file for the VMS.
Pulls all alumni from past 70 class years, current parents, parents from the past 3 class years, and parents who gave in the last year*/

with last_gift as (--Most recent gift per constituent with gift date and designation
select cr.constituent_key_credit,
       cal.calendar_date,
       cal.fiscal_year,
       des.designation_ld,
       sum(cr.credit_amount) as gift_amount
from (select cr.*, 
      max(cr.date_key_gift) over (partition by cr.constituent_key_credit) as max_date,
      max(cr.designation_key) over (partition by cr.constituent_key_credit,cr.date_key_gift) as max_desg
      from adv_credit_f cr
      inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
      where gd.soft_credit_ind='N' and gd.anon_ind='N') cr 
     inner join adv_calendar_dv cal on cr.date_key_gift=cal.date_key
     inner join adv_designation_d des on cr.designation_key=des.designation_key
where cr.date_key_gift=cr.max_date
      and cr.designation_key=cr.max_desg
group by cr.constituent_key_credit,cal.calendar_date,cal.fiscal_year,des.designation_ld
), 
exclusions as (--Pulls all exclusion codes into single row per constituent
select con.constituent_key,
       max(case when exc.exclusion_code_sd in ('NO','N25') then 1 else 0 end) as no_n25,
       sum(case when exc.exclusion_code_sd in ('NS','NSE','NP') then 1 else 0 end) as no_solc_parent,
       listagg(case when exc.exclusion_code_sd='N25' then null else exc.exclusion_code_ld end,';') within group (order by exc.exclusion_code_key) as exclusion_string
from adv_constituent_d con
     inner join adv_exclusion_group_b exg on con.exclusion_group_key=exg.exclusion_group_key
     inner join adv_exclusion_codes_d exc on exg.exclusion_code_key=exc.exclusion_code_key
where exc.exclusion_code_sd in ('DM','DME','NS','NSE','NP','NT','NAS','NBA','NO','NPA','NPM','REF','UNS','N25')
group by con.constituent_key
),
affil as (--Pulls constituent affiliations into single row
select con.constituent_key,
       max(case when dc.donor_code_sd in ('T','TS') then 1 else 0 end) as trustees,
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
            when con.college_first_name=con.first_name
                 and con.college_middle_name=con.middle_name
                 and con.college_last_name=con.last_name then null
            else replace(con.college_first_name || ' ' || con.college_middle_name 
                                        || ' ' || con.college_last_name,'  ',' ') end             as "Constituent_FormerName",
       con.gender                                                                                 as "Constituent_Gender",
       con.marital_desc                                                                           as "Constituent_MaritalStatus",
       replace(con.scy,'n/a')                                                                     as "Constituent_PrefClassYear",
       affil.affiliations                                                                         as "Constituent_Affiliation",
       replace(ci.pref_email,'n/a')                                                               as "Constituent_Email",
       replace(ci.home_phone,'n/a')                                                               as "Constituent_HomePhone",
       replace(ci.pref_mail_street1,'n/a')                                                        as "Constituent_AddressStreet1",
       replace(ci.pref_mail_street2,'n/a')                                                        as "Constituent_AddressStreet2",
       replace(ci.pref_mail_street3,'n/a')                                                        as "Constituent_AddressStreet3",
       replace(ci.pref_mail_city,'n/a')                                                           as "Constituent_AddressCity",
       replace(ci.pref_mail_state_code,'n/a')                                                     as "Constituent_AddressState",
       replace(ci.pref_mail_zip,'n/a')                                                            as "Constituent_AddressZip",
       replace(ci.pref_mail_nation_desc,'n/a')                                                    as "Constituent_AddressCountry",
       case when (affil.trustees=1 or afr.afrctyp_sol_org='TP') then null 
                 else to_char(last_gift.calendar_date,'MM/DD/YYYY') end                           as "Constituent_LastGiftDate",
       case when (affil.trustees=1 or afr.afrctyp_sol_org='TP') then null 
                 else last_gift.designation_ld end                                                as "LastGiftDesignation",
       case when (affil.trustees=1 or afr.afrctyp_sol_org='TP') then null 
                 else last_gift.gift_amount end                                                   as "Constituent_LastGiftAmount",
       case db.og_consec_yrs_giving when 0 then db.lyr_og_consec_yrs_giving 
                                    else db.og_consec_yrs_giving end                              as "ConsecutiveGivingYears",
       null                                                                                       as "Constituent_DonorStatus",
       afr.afrctyp_ask_amount                                                                     as "Constituent_AskAmount",
       case when affil.trustees=1 then 'FALSE' --Trustee/Trustee spouse
            when afr.afrctyp_sol_org='TP' then 'FALSE' --Top Prospect
            when con.deceased_ind='Y' then 'FALSE' --Deceased
            when exclusions.no_n25=1 then 'FALSE' --No contact (NO) / Not solicitable (N25)
            when exclusions.no_solc_parent=3 then 'FALSE' --All 3 of NS, NSE, and NP exclusions
            else 'TRUE' end                                                                       as "Constituent_Selectable", 
       'TRUE'                                                                                     as "EditSelectableStatus",
       null                                                                                       as "Constituent_TeamManager",
       case con.deceased_ind when 'Y' then 'TRUE' else 'FALSE' end                                as "Constituent_Deceased",
       replace(exclusions.exclusion_string,'none')                                                as "Constituent_Restrictions",
       case afr.afrctyp_sol_org when 'TP' then 'Top Prospects'
                                when 'PA' then 'President''s Associates'  
                                when 'MDS' then 'Mount David Society Members'
                                when 'MDSP' then 'Mount David Society Prospects' 
                                when 'BFP' then 'Bates Fund Pipeline'
                                when 'GG' then 'General Giving'
                                when 'PAR' then 'Parents' end                                     as "Constituent_Segments",
       replace(sps.cons_id,'n/a')                                                                 as "Spouse_Externalid",
       replace(hhb.spouse_name,'n/a')                                                             as "Spouse_Name",
       replace(sps.scy,'n/a')                                                                     as "Spouse_ClassYear",
       apr.APREHIS_EMPL_POSITION                                                                  as "Business_JobTitle",
       coalesce(emp.last_name,apr.APREHIS_EMPR_NAME)                                              as "Business_Employer",
       atv.ATVSICC_DESC                                                                           as "Business_Industry",
       case emp.is_mg_company when 'Y' then 'TRUE' else 'FALSE' end                               as "Business_EmployerMatch",
       replace(ci.work_city,'n/a')                                                                as "Business_AddressCity",
       replace(ci.work_state_code,'n/a')                                                          as "Business_AddressState",
       case db.bf_consec_yrs_giving when 0 then db.lyr_bf_consec_yrs_giving 
                                    else db.bf_consec_yrs_giving end                              as "ConsecGivingYearsBF"
from adv_constituent_d con
     inner join adv_contact_info_d ci on con.contact_info_key=ci.contact_info_key
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_household_b hhb on con.household_key=hhb.household_key and con.constituent_key=hhb.cons_key_sps1
     inner join adv_constituent_d sps on hhb.cons_key_sps2=sps.constituent_key
     inner join affil on con.constituent_key=affil.constituent_key
     left outer join exclusions on con.constituent_key=exclusions.constituent_key
     left outer join last_gift on con.constituent_key=last_gift.constituent_key_credit
     left outer join afrctyp afr on con.pidm=afr.afrctyp_constituent_pidm and afr.afrctyp_dcyr_code=rv.var_value
     left outer join aprehis apr on con.pidm=apr.APREHIS_PIDM and apr.APREHIS_PRIMARY_IND='Y' and apr.APREHIS_TO_DATE is null
     left outer join atvsicc atv on apr.APREHIS_SICC_CODE=atv.ATVSICC_CODE
     left outer join adv_constituent_d emp on apr.APREHIS_EMPR_PIDM=emp.pidm
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (replace(con.parent_scy,'n/a','0')>=rv.var_value-3 or last_gift.fiscal_year >= rv.var_value-1)))
      --or (con.primary_donor_code='P' and exclusions.no_n25=0 and exclusions.no_solc_parent<3)) 
      and db.fiscal_year=rv.var_value
