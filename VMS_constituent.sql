/*Query to generate the constituent file for the VMS.
Pulls all alumni from past 70 class years; all donor, lybunt, and sybunt2 parents; and all first year parents marked Advancement Interest*/

with last_gift as (--Most recent gift per household with gift date and designation
select hhg.household_key,
       cal.calendar_date,
       cal.fiscal_year,
       des.designation_ld,
       sum(hhg.credit_amount) as gift_amount
from (select hhg.*, 
      max(hhg.date_key_gift) over (partition by hhg.household_key) as max_date,
      max(hhg.designation_key) over (partition by hhg.household_key,hhg.date_key_gift) as max_desg
      from adv_hh_giving_f hhg
      inner join adv_gift_description_d gd on hhg.gift_description_key=gd.gift_description_key
      inner join adv_campaign_d cam on hhg.campaign_key=cam.campaign_key
      where gd.soft_credit_ind='N' and gd.anon_ind='N' and cam.campaign_type_sd='AF') hhg 
     inner join adv_calendar_dv cal on hhg.date_key_gift=cal.date_key
     inner join adv_designation_d des on hhg.designation_key=des.designation_key
where hhg.date_key_gift=hhg.max_date
      and hhg.designation_key=hhg.max_desg
group by hhg.household_key,cal.calendar_date,cal.fiscal_year,des.designation_ld
), 
exclusions as (--Pulls all exclusion codes into single row per constituent
select con.constituent_key,
       max(case when exc.exclusion_code_sd in ('NO','N25','VMS','MA') then 1 else 0 end) as no_n25,
       sum(case when exc.exclusion_code_sd in ('NS','NSE','NP') then 1 else 0 end) as no_solc_parent,
       listagg(case when exc.exclusion_code_sd='N25' then null else exc.exclusion_code_ld end,';') within group (order by exc.exclusion_code_key) as exclusion_string
from adv_constituent_d con
     inner join adv_exclusion_group_b exg on con.exclusion_group_key=exg.exclusion_group_key
     inner join adv_exclusion_codes_d exc on exg.exclusion_code_key=exc.exclusion_code_key
where exc.exclusion_code_sd in ('DM','DME','NS','NSE','NP','NT','NAS','NBA','NO','NPA','NPM','REF','UNS','N25','VMS','MA')
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
),
first_yr_par as (--Finds parents of first year students who are coded Advancement Interest
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
nonBF_giving (con_key) as (--Find constituents with non-BF commitments this year
select cr.constituent_key_credit
from adv_credit_f cr
     inner join adv_gift_description_d gd on cr.gift_description_key=gd.gift_description_key
     inner join adv_campaign_d cam on cr.campaign_key=cam.campaign_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
where gd.soft_credit_ind='N'
      and gd.anon_ind='N'
      and cam.campaign_type_sd<>'AF'
      and cr.fiscal_year=rv.VAR_VALUE
union
select pin.constituent_key_pledger
from adv_pledge_install_f pin
     inner join adv_pldg_description_d pld on pin.pledge_description_key=pld.pldg_description_key
     inner join adv_campaign_d cam on pin.campaign_key=cam.campaign_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
where pld.soft_credit_ind='N'
      and pld.anon_ind='N'
      and pld.pledge_status_sd='A'
      and cam.campaign_type_sd<>'AF'
      and pin.install_fiscal_year=rv.VAR_VALUE
),
staff_solicited as (--Find constituents with a staff solicitor
select con.constituent_key
from adv_assignments_f asn
     inner join adv_constituent_d con on asn.constituent_key_prospect=con.constituent_key
     inner join adv_staff_d stf on asn.staff_key=stf.staff_key
     inner join adv_constituent_d sol on stf.constituent_key_staff=sol.constituent_key
     inner join adv_reportvars_d rv on rv.VAR_NAME='VOLUNTR_FY'
where asn.wh_current_row='Y'
      and asn.solicitor_code='STAF'
      and stf.wh_current_row='Y'
      and not (sol.cons_id='000098135' and con.scy='2010') -- Evan
      and not (sol.cons_id='000354053' and con.scy='2007') -- Meghan
      and not (sol.cons_id='000362399' and con.scy='2007') -- Cary
      and not (sol.cons_id='000466745' and con.scy between rv.VAR_VALUE-10 and rv.VAR_VALUE-1) -- Nina
)
--Main query
select con.cons_id                                                                                as "Constituent_Externalid",
       con.prefix                                                                                 as "Constituent_Prefix",
       con.first_name                                                                             as "Constituent_FirstName",
       con.middle_name                                                                            as "Constituent_MiddleName",
       con.last_name                                                                              as "Constituent_LastName",
       con.suffix                                                                                 as "Constituent_Suffix",
       con.pref_first_name                                                                        as "Preferred_FirstName",
       case when con.college_last_name<>con.last_name then con.college_last_name end              as "Constituent_FormerName",
       con.gender                                                                                 as "Constituent_Gender",
       con.marital_desc                                                                           as "Constituent_MaritalStatus",
       replace(con.scy,'n/a')                                                                     as "Constituent_PrefClassYear",
       affil.affiliations                                                                         as "Constituent_Affiliation",
       replace(ci.pref_email,'n/a')                                                               as "Constituent_Email",
       replace(ci.home_phone,'n/a')                                                               as "Constituent_HomePhone",
       replace(ci.cell_primary,'n/a')                                                             as "Constituent_CellPhone",
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
            when (con.primary_donor_code='A' and con.scy>'1975' and deg.APRADEG_DEGC_CODE is null 
              and nvl(extract(year from last_gift.calendar_date),0)<rv.var_value-5) then 'FALSE' --Non-grads after 1975 with no gift in last 5 yrs
            when (con.primary_donor_code='P' and afr.AFRCTYP_ASK_AMOUNT>=5000) then 'FALSE' --Parents with ask amount over 5000
            when ss.constituent_key is not null then 'FALSE' --Has a staff solicitor
            else 'TRUE' end                                                                       as "Constituent_Selectable", 
       'TRUE'                                                                                     as "EditSelectableStatus",
       null                                                                                       as "Constituent_TeamManager",
       case con.deceased_ind when 'Y' then 'TRUE' else 'FALSE' end                                as "Constituent_Deceased",
       replace(exclusions.exclusion_string,'none')                                                as "Constituent_Restrictions",
       case when con.scy between '2002' and '2017' then 'Schuler'
            else (case afr.afrctyp_sol_org when 'TP' then 'Top Prospects'
                                when 'PA' then 'President''s Associates'  
                                when 'MDS' then 'Mount David Society Members'
                                when 'MDSP' then 'Mount David Society Prospects' 
                                when 'BFP' then 'Bates Fund Pipeline'
                                when 'GG' then 'General Giving'
                                when 'PAR' then 'Parents' end) end                                as "Constituent_Segments",
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
                                    else db.bf_consec_yrs_giving end                              as "ConsecGivingYearsBF",
       replace(con.parent_scy,'n/a')                                                              as "Parent_ClassYear",
       case sch.aprmail_mail_code when 'SIO' then 'Schuler Opportunity'
                                  when 'SIB' then 'Schuler Base' end                              as "SchulerStatus"
       --case when nonBF_giving.con_key is not null then 'TRUE' end                                 as "Constituent_NonBFGiving"
from adv_constituent_d con
     inner join adv_contact_info_d ci on con.contact_info_key=ci.contact_info_key
     inner join adv_donor_behavior_ps db on con.constituent_key=db.constituent_key
     inner join adv_reportvars_d rv on rv.var_name='VOLUNTR_FY'
     inner join adv_household_b hhb on con.household_key=hhb.household_key and con.constituent_key=hhb.cons_key_sps1
     inner join adv_constituent_d sps on hhb.cons_key_sps2=sps.constituent_key
     inner join affil on con.constituent_key=affil.constituent_key
     left outer join exclusions on con.constituent_key=exclusions.constituent_key
     left outer join last_gift on con.household_key=last_gift.household_key
     left outer join afrctyp afr on con.pidm=afr.afrctyp_constituent_pidm and afr.afrctyp_dcyr_code=rv.var_value
     left outer join aprehis apr on con.pidm=apr.APREHIS_PIDM and apr.APREHIS_PRIMARY_IND='Y' and apr.APREHIS_TO_DATE is null
     left outer join atvsicc atv on apr.APREHIS_SICC_CODE=atv.ATVSICC_CODE
     left outer join adv_constituent_d emp on apr.APREHIS_EMPR_PIDM=emp.pidm
     left outer join first_yr_par fyp on con.constituent_key=fyp.constituent_key
     --left outer join nonBF_giving on con.constituent_key=nonBF_giving.con_key
     left outer join apradeg deg on con.pidm=deg.APRADEG_PIDM and deg.APRADEG_SBGI_CODE='003076' and deg.APRADEG_DEGC_CODE in ('BA','BS')
     left outer join aprmail sch on con.pidm=sch.aprmail_pidm and sch.APRMAIL_MAIL_CODE in ('SIO','SIB')
     left outer join staff_solicited ss on con.constituent_key=ss.constituent_key
where ((con.primary_donor_code='A' and con.scy>=to_char(rv.var_value-70))
      or (con.primary_donor_code='P' and (fyp.constituent_key is not null or db.og_donor_status in ('Donor','Pledger','Partial Pledger','Lybunt','Sybunt2'))))
      and db.fiscal_year=rv.var_value
