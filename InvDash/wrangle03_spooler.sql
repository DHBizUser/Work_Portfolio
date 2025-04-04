
-- -*- mode: sql; sql-product: sqlite; -*-

.cd "d:/home/RM06analyst/InvDash2.0/code"
.open "d:/home/RM06analyst/InvDash2.0/charfix-wrangle-data/wrangle_11.db"


--we always drop these from the last wrangle so they can be recreated in
--an up-to-date state.
drop table if exists wrangleparms;
drop table if exists ShiftCalendar;
drop table if exists dotimportSQL;

--these helper tables should already be temps unless under development
drop table if exists SP02import;
drop table if exists ZOPENPOimport;
drop table if exists ZOTIFimport;
drop table if exists MMRPimport;
drop table if exists BOMreportimport;
drop table if exists FocusCustParent;

--comment these out if you are stacking wrangle instances
--uncomment if you are redoing an import
 drop table if exists SP02wrangle;
 drop table if exists ZOTIFsalesorders;
 drop table if exists ZOPENPOpurchase;
 drop table if exists MMRPavail;
-- drop table if exists ALLPathsReport;

-- don't temp or drop the TFACS like we do with other import tables
-- unless you are redoing an import. We need the working days when we re-roll
-- it, which we do so that the calendar is always relative to the current time.
-- drop table if exists TFACSimport;


create table if not exists wrangleparms (_key,_value);
create temp table if not exists SP02import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10);
create table if not exists SP02wrangle (spoolNo,wrangleDate,title,filename);
create temp table if not exists ZOPENPOimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23,_24,_25,_26,_27);
create temp table if not exists ZOTIFimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20);
create table if not exists MDLDimport (_1);
create table if not exists TFACSimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,
	_13,_14,_15,_16,_17,_18,_19,_20);
create temp table if not exists MMRPimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14);
CREATE temp TABLE if not exists BOMreportimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23,_24,_25,_26,_27,_28,_29,_30,_31,_32,_33,_34,_35,_36);



create table if not exists ZOTIFsalesorders(
       spoolNo,
       wrangleDate,
       ProfitCenter,
       CustNo,
       SOCreated,
       SalesOrder,
       SalesOrdItm,
       Material,
       description,
       CustPOnum,
       batch,
       SalesOrderQty,
       SOCurrentQty,
       UnitPrice,
       SaleableUnit,
       NetValue,
       OriginalSTAT,
       CurrentSTAT,
       FarevaPlannedDelivery);



create table if not exists ZOPENPOpurchase (
       spoolNo,
       wrangleDate,
       CreatedBy,
       purchGroup,
       vendor,
       vendorDesc,
       purchCreationDate,
       purchOrd,
       purchOrditm,
       mtrlType,
       material,
       mtrlDesc,
       purchQty,
       OrderUnit,
       GRqty,
       GRDate,
       DelDate,
       Delind,
       DClind,
       openQty,
       openValue,
       unitCost,
       acknowlegementText,
       InfoRecord,
       PlannedDelTime,
       IncoTerms,
       IncoTermsText
       );



create table if not exists MMRPavail (
       spoolNo,
       wrangleDate,
       MRPdate,
       Material,
       Plant,
       ElementContext,
       RecReq,
       AvailQty,
       BaseUnit,
       El,
       MRPelement,
       MtrlType,
       MtrlTypeText,
       Vendor
       );




-- create table if not exists MDLDavail (
--        spoolNo,
--        wrangleDate,
--        material
--        );





-- Lets establish some parms around the current date, to pass in which folder we are going to pull data in from.
-- If we need to roll in past data, we would change currentwrangleDate to a specific date string in the
-- YYYY-MM-DD format or put a '-1 day' modifier in the date() function to achieve the same result, and then
-- change it back for next time. This is like a document header. It describes the last wrangle performed.

insert into wrangleparms
values 
('currentwrangleDate',date('now','start of day','-6 days')),
('repoPath','d:/home/RM06analyst/'),
('rawDataPath','d:/home/RM06analyst/InvDash2.0/UnprocessedData/'),
('charfixDataPath','d:/home/RM06analyst/InvDash2.0/charfix-wrangle-data/'),
('dirName',null),
('emacsBin','d:/WinApps/Emacs/emacs-29.4/bin/emacs.exe'),
('SQLite3Bin','d:/WinApps/SQLite_ODBC_Driver_Win64/sqlite3.exe'),
('DBbrowserBin','d:/WinApps/DB_Browser_SQLite/DB_Browser_SQLite.exe'),
('charfix','d:/home/RM06analyst/InvDash2.0/code/charfix.el')

;

update wrangleparms set _value =
'SAPspool_'||
replace(
(select _value from wrangleparms where _key is 'currentwrangleDate')
,'-','')||'/'
where _key IS 'dirName';




-- Lets see if we can call charfix.el right from this script. The dot commands have to be hard-coded,
-- so we are going to write some SQL to "write" our dot commands, then we will read them back in.
-- So we can manage it all from one place.  We employ this trick again further down. 


create temp table CharfixCallerELISP as select
'
;; this elisp generated by wrangle03_spooler.sql
(load "d:/home/RM06analyst/InvDash2.0/code/charfix.el")
(charfix-folder "'||(select _value from wrangleparms where _key is 'rawDataPath')||(select _value from wrangleparms where _key is 'dirName')||'" "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||'")
';


-- we write this elisp one-liner to a file that lives together with the DB file we are calling this SQL
-- script on. Then we call it with a .shell command, as though we were in a shell.

.once "CharfixCallerELISP.el"
select * from CharfixCallerELISP;

.shell d:/WinApps/Emacs/emacs-29.4/bin/emacs.exe --script d:/home/RM06analyst/InvDash2.0/code/CharfixCallerELISP.el


-- if that worked, our charfixed data now exists in the folder we expect

-- Filenames have to be hardcoded for .import steps in SQLite3.
-- we need a script to handle this by changing the filename references in the SQL.
--We Need the chart on SP02 to tell us what's what.  
--make sure the spools are selected when sp02 is exported so the columns line up right.


create temp table SP02DotImportSQL as select
'
--this SQL dot command generated by wrangle03.sql
.mode tabs
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||'charfix-sp02.txt" SP02import
';

.once "SP02DotImportSQL.sql"
select * from SP02DotImportSQL;
.read "SP02DotImportSQL.sql"



insert into SP02wrangle
select trim(_3),
trim(_6) ||" "|| trim(_7),
trim(_10),
'charfix-FP1'||format('%010d',trim(_3))||'.TXT'
from SP02import
where length(_3) > 0
and trim(_3) not null
and trim(_3) not like '%s%';




-- Lets write the SQL we need for our .imports using filenames evaluated above from SP02.
-- We are going to use this SQL to write it so we don't have to use another language.  If the SAP spool export
-- and charfix.el worked as expected, the filenames should match this query. Let this serve as a check.


create table if not exists dotimportSQL as select
'--this text file generated from the sql wrangler that read in sp02

.separator | "\n"
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%ZOPENPO%')||'" ZOPENPOimport

.separator | "\n"
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%ZSD_COTY%')||'" ZOTIFimport


--MDLD uses a different column separator because it is not a tabular report. "\01" is not a character
--thats used anywhere in the document.  We just need the lines in a single row table to parse later on.

--.separator "\01" "\n"
--.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%RMDLDR%')||'" MDLDimport


.separator | "\n"
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%1BCDWB%')||'" TFACSimport


.separator | "\n"
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%AQICZUG%')||'" MMRPimport



.separator | "\n"
.import "'||(select _value from wrangleparms where _key is 'charfixDataPath')||(select _value from wrangleparms where _key is 'dirName')||(select filename from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%AQICSLT%')||'" BOMreportimport
' as text;




-- like before with charfix, we write these .import commands to a file that lives alongside the DB we are running this SQL on.
-- then we read it back in as SQL code applied to the same database, constituting a wrangle instance.

.once "dotimportSQL.sql"
select * from dotimportSQL;

.read "dotimportSQL.sql"



-- for each import, make a new table that extracts the meaningful content from empty spaces,
-- punctuation, and non data lines. This set of prepared tables will be used in the actual transformations.
-- This hopefully keeps downstream results free from import artifacts.  If things break after a software update,
-- they would probably only break up to this point. 
-- If all works well, we can make the import tables "temp" so they go away once the script is run.
-- and we can make these main tables "if not exists" so we can run this same code on subsequent wrangle instances
-- and stack them.




-- Now we populate the content tables with the data from the import tables.
-- For most imports, this involves a single select statement for text parsing.
-- For the imports that require more complex parsing, lets manage the import
-- table from this file, but put the other steps
-- on another file we read in.


.read FactoryCalendar.sql
.read BOMreportConvPaths.sql
.read MDLDparse.sql


insert into ZOTIFsalesorders
select
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%ZSD_COTY%'))),
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%ZSD_COTY%'))),

trim(_2),
trim(_3) as CustNo,
trim(_4) as SOCreated,
trim(_5) as SalesOrder,
trim(_6) as SalesOrdItm,
trim(_7) as Material,
trim(_8) as description,
trim(_9) as CustPOnum,
trim(_10) as batch,
replace(trim(_11),',','') as SalesOrderQty,
replace(trim(_12),',','') as SOCurrentQty,

replace(trim(_13),',','')/replace(trim(_14),',','') as UnitPrice,
trim(_15) as SaleableUnit,
replace(trim(_16),',','') as NetValue,
trim(_17) as OriginalSTAT,
trim(_18) as CurrentSTAT,
trim(_19) as FarevaPlannedDeliviry

from ZOTIFimport
where trim(_5) LIKE '2____'
or trim(_5) LIKE '3____'
or trim(_5) LIKE '4____'
;



insert into ZOPENPOpurchase
select
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%ZOPENPO%'))),
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%ZOPENPO%'))),
trim(_2),
trim(_3),
trim(_4),
trim(_5),
trim(_6),
trim(_7),
trim(_8),
trim(_9),
trim(_10),
trim(_11),
replace(trim(_12),',',''),
trim(_13),
replace(trim(_14),',',''),
trim(_15),
trim(_16),
trim(_17),
trim(_18),
replace(trim(_19),',',''),
replace(trim(_20),',',''),
trim(_21)/trim(_22),
trim(_23),
trim(_24),
trim(_25),
trim(_26),
trim(_27)
from ZOPENPOimport
where trim(_6) like '____-__-__'
;



insert into MMRPavail
select
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICZUG%'))),
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICZUG%'))),

trim(_2),
trim(_3),
trim(_4),
trim(_5),

case
trim(substr(replace(trim(_6),',',''),-1,1))
when '-' then -1.0*replace(replace(trim(_6),',',''),'-','')
else 1.0*replace(replace(trim(_6),',',''),'-','')
end,

case
trim(substr(replace(trim(_7),',',''),-1,1))
when '-' then -1.0*replace(replace(trim(_7),',',''),'-','')
else 1.0*replace(replace(trim(_7),',',''),'-','')
end,

trim(_8),
trim(_9),
trim(_10),
trim(_11),
trim(_12),
trim(_13)
from MMRPimport
where trim(_2) like '____-__-__'
;




--This is the last step off of a multi-step transform of TFACS factory calendar.  It gives us the dates in modified ISO 8601 format with 3 shift days.  It has every day start at 07:00, every week, month, and year start on the nearest Monday to the standard Julian calendar.  The other steps are in its own file.



create table if not exists ShiftCalendar as
	SELECT
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%1BCDWB%'))) as spoolNo,
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%1BCDWB%'))) as wrangleDate,


		ShiftPeriod,

		FORMAT('D%+.4d', julianday(ShiftDate)
			- (SELECT julianday(ShiftDate)
				FROM ISOYearCal3 WHERE _index = 0)
		) AS DayPeriod,

		FORMAT('W%+.3d', 52*ISOYear+1*ISOWeek
			- (SELECT 52*ISOYear+1*ISOWeek
				FROM ISOYearCal3 WHERE _index = 0)
		) AS WeekPeriod,	

		FORMAT('M%+.2d', 12*ISOYear+1*ISOMonth
			- (SELECT 12*ISOYear+1*ISOMonth
				FROM ISOYearCal3 WHERE _index = 0)
		) AS MonthPeriod,

		FORMAT('Y%+.1d', ISOYear
			- (SELECT ISOYear
				FROM ISOYearCal3 WHERE _index = 0)
		) AS YearPeriod,
		
		Shift,
		ShiftDate,
		ISOWeek,
		ISOMonth,
		WorkMonthWeekSeq,
		ISOYear,
		
		FORMAT('%s#%.1d',ShiftDate,Shift) AS WorkDayShift,

		FORMAT('%s-W%.2d-%s#%.1d',ISOYear,
			ISOWeek,
			CASE 
				WHEN strftime('%w',ShiftDate)*1 IS 0 THEN 7
				ELSE strftime('%w',ShiftDate)*1
			END,
			Shift
		) AS ISOWeekDayShift,

		FORMAT('%s%s[%s%s]#%.1d',ISOYear,
			(SELECT shortMonth FROM CalendarMonths WHERE numMonth = ISOMonth),
				WorkMonthWeekSeq,
				(SELECT shortDay FROM CalendarDaysofWeek
					WHERE numDay = strftime('%w',ShiftDate)*1),Shift
		) AS WorkYearMonthWeekSeqDayShift,

		FORMAT('%s-W%.2d-%s',ISOYear,
			ISOWeek,
			CASE 
				WHEN strftime('%w',ShiftDate)*1 IS 0 THEN 7
				ELSE strftime('%w',ShiftDate)*1
			END
		) AS ISOWeekDate,

		FORMAT('%s-W%.2d',ISOYear,ISOWeek) AS ISOYearWeek,

		FORMAT('%s%s[%s]',ISOYear,
			(SELECT shortMonth FROM CalendarMonths WHERE numMonth = ISOMonth),
				WorkMonthWeekSeq
		) AS WorkYearMonthWeekSeq,		

		FORMAT('%s%s',ISOYear,
			(SELECT shortMonth FROM CalendarMonths WHERE numMonth = ISOMonth)
		) AS WorkYearMonth,


		FactoryCalWD,
		ShiftCountFactoryCal,
		Holiday,

		ShiftStart,
		WorkDayStart,
		WorkWeekStart,
		WorkMonthStart,
		WorkYearStart

	FROM ISOYearCal4 
;






CREATE TABLE if not exists ALLPathsReport AS
	SELECT
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICSLT%'))),
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICSLT%'))),

ToplvlNo,Cust,TopLvlMtrl,BOMdepth,
		'''('||REPLACE(REPLACE(MTRLpath,'(',''),')','')||')' AS MTRLpath,
		'''('||REPLACE(REPLACE(DESCpath,'(',''),')','')||')'AS DESCpath,
--		SUBSTR(DESCpath,4,15)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)/3,8)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)-15,15) AS ShortDESCpath,
		ComponentMtrl,
		CombinedUnitUsage,PathUnit,
		AltBOM,
		'''('||REPLACE(REPLACE(BOMpath,'(',''),')','')||')' AS BOMpath,
		BOMitem,BOMstatus
	FROM _01Paths UNION ALL
	SELECT
(select spoolNo from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICSLT%'))),
(select wrangleDate from (select spoolNo,MAX(wrangleDate) as wrangleDate from (select * from SP02wrangle where title like '%AQICSLT%'))),

ToplvlNo,Cust,TopLvlMtrl,BOMdepth,
		'''('||REPLACE(REPLACE(MTRLpath,'(',''),')','')||')' AS MTRLpath,
		'''('||REPLACE(REPLACE(DESCpath,'(',''),')','')||')'AS DESCpath,
--		SUBSTR(DESCpath,4,15)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)/3,8)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)-15,15) AS ShortDESCpath,
		ComponentMtrl,
		CombinedUnitUsage,PathUnit,
		AltBOM,
		'''('||REPLACE(REPLACE(BOMpath,'(',''),')','')||')' AS BOMpath,
		BOMitem,BOMstatus
	FROM _02Paths;

drop table if exists FocusCustParent;
