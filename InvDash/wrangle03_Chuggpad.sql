-- -*- mode: sql; sql-product: sqlite; -*-

-- Lets not even mess with a persistent database file yet. We'll use select statements in memory
-- to do variable substitution to prepare the SQL code we will use once our file paths are figured
-- out and we know where all are code and data is.

.open :memory:

-- Sqlite is on UTC/Zulu time -- 4 hours ahead of our locality during daylight savings time,
-- 5 hours ahead outside daylight savings time.

-- usually you want all timestamps in UTC under the hood, and converted to local time at presentation.
-- this is a funny case because we are not collecting any new timestamps. We just want a ReportDate
-- to calibrate our imports to the timestamps we get off of SAP report output, which are presented in
-- local time.


create table localtimeParms(
DSTstart,
DSTend,
UTCoffset_standard,
UTCoffset_DST
);

-- we take the 2025 DST start and end for our locality, and use the substr function to chop off
-- the first 5 characters, then a strftime placed at the beginning to add the current year.
-- This almost makes this DST parameter year agnostic, but you would have to make adjustments if
-- you tried to run this for a prior year.

-- TODO: the DST start and end seem to fall on Sundays with the same week number every year.
-- Not on the same date.  If its on an ISO week cadence, its probably possible to write this
-- truly year agnostic using the same logic employed by our Shift Calendar table.  It would be
-- easier too with version 3.46.0 or later that added strftime() substitutions for ISO 8601 weeks.
-- I'm developing this on SQLite 3.43.2 and I'd rather not upgrade right now.

insert into localtimeParms values(
strftime('%Y-','now')||substr(datetime('2025-03-09 02:00:00','-0.001 second','+5 hours'),6,100),
strftime('%Y-','now')||substr(datetime('2025-11-02 02:00:00','-0.001 second','+4 hours'),6,100),
'+5 hours','+4 hours');



----------------------------------------------------------------------------------
--copy/paste this region bound by dash rules if you are making a standalone MyEnvironment.sql

-- uncomment this drop line if you are making a standalone MyEnvironment.sql
-- that should overide David's default.

--drop table environment;


create table environment(
ReportDate,
OS,
hardwarePath,
dependencyPath,
folderPath,
repo
);




-- establish some paramaters around the current date and our working environment.
-- Set the ReportDate from the ReportDateSetter part up top. The rest of the
-- environment parameters should be set directly in the environment table.

insert into environment

-- usually we run the import from the start of current day perspective
-- Use '-x days' modifier, or type a specific datetime in
-- YYYY-MM-DD 00:00:00 format to import data from another day.

with ReportDateSetter as
(select

--datetime('now','start of day')
datetime('2025-03-31 00:00:00')
--datetime('now','start of day','-1 day')

as ReportDateSetter)
select

-- Notice we had time specificity on ReportDateSetter, but simplify it to just the date here after
-- we apply local offset. The wrangle instance concept is not designed to manage more than
-- one wrangle per day, but you can re-run the day's wrangle for development purposes, or to fix
-- things, so long as drop statements are set appropriately to avoid duplication.

-- I found while trying to develop this late one evening, It thought my ReportDate was one day
-- sooner than I intended. I realized it needs the local time and date for the 'start of day'
-- modifier to evaluate the start of OUR day here in our locality.

date(ReportDateSetter,
case
ReportDateSetter between DSTstart and DSTend
when true then UTCoffset_DST else UTCoffset_standard
end
) as ReportDate,

'windows' as OS,

 'd:' as hardwarePath,

 'WinApps' as dependencyPath,	

'home/RM06analyst' as folderPath,
'InvDash2.0' as repo
from ReportDateSetter cross join localtimeParms
;

----------------------------------------------------------------------------------
-- it would be cool to have users make thier own copy of the environment part,
-- just the ~40 lines of this file between the dash rules to this point, and
-- tailor it to their own computer.  Name the file exactly as below and save it
-- in the same folder this shell is called from. If you run this by double-clicking
-- a shortcut, it would be in the same folder as that shortcut.  If the file
-- doesn't exist, the program should throw an error and keep on going with
-- David's defaults.

.read MyEnvironment.sql

create table wrangleparms(
emacs,
SQLite3,
DBbrowser,
wrangleFrom,
wrangleTo,
rawDataPath,
processedDataPath,
codePath,
wrangleDir
);


insert into wrangleparms
select

-- this is primarily for windows systems where the dependencies are on the same hardware with the repo,
-- which is, I think, a good practice. Also for business user computers that don't have shell aliases set up.
-- For this reason, a big focus is on keeping the toolchain as light as possible. The intent is to copy the
-- binary installations right onto a shared drive location within the organization, run the import process from
-- there but also encourage users to make their own local copies of the repo and dependencies. The user would make
-- their own MyEnvironment.sql point to their local copy. This approach is sensible because all business users
-- have their own domains they must analyze, with or without the help of this analysis pipeline we are developing.
-- SAP is ALREADY a normalized database implementation that persists everything required for the operation and the
-- business, and doing more adds administrative overhead -- at a cost.

-- This analysis pipeline provides LIMITED additional persistence of key information useful for time-series reporting
-- and complex Make-To-Order inventory custody relationships. Its NOT a "single source of truth" or any similar
-- language used in reference to enterprise data solutions because thats what SAP is for our local organization. We have
-- a few other sources here and there we could integrate if necessary, but generally speaking, we are only one central
-- organization tied to a single inventory system. This is an advantage we ought to leverage in this pipeline solution.

-- Anything other than 'windows' OS assumes the typical aliases on the shell calls you'd have on mac or linux
-- and thus no need to know the actual path to the dependencies.

case OS = 'windows' when true then
format('%s/%s/Emacs/emacs-29.4/bin/emacs.exe',hardwarePath,dependencyPath) else 'emacs'
end as emacs,

case OS = 'windows' when true then
format('%s/%s/SQLite_ODBC_Driver_Win64/sqlite3.exe',hardwarePath,dependencyPath) else 'sqlite3'
end as SQLite3,

case OS = 'windows' when true then
format('%s/%s/DB_Browser_SQLite/DB_Browser_SQLite.exe',hardwarePath,dependencyPath) else 'sqlite_browser'
end as DBbrowser,

-- SAP will hang onto your spoolers in SP02 for 8 days until they drop off the list.
datetime(ReportDate,'-8 days') as wrangleFrom,
datetime(ReportDate,'+1 day','-0.001 second') as wrangleTo,

format('%s/%s/%s/UnprocessedData',hardwarePath, folderPath, repo) as rawDataPath,
format('%s/%s/%s/ProcessedDB',hardwarePath, folderPath, repo) as processedDataPath,
format('%s/%s/%s/code',hardwarePath, folderPath, repo) as codePath,
format('SAPspool_%s',replace(ReportDate,'-','')) as wrangleDir

from environment
;


-- Lets use our environment parms to script an interface between our data pipeline
-- and the file structure we operate in.  This is a cool trick to make the whole
-- thing easy to port to any computer.
-- This script file is going to generate in whatever folder location the shell that calls it
-- happens to be, But the script ensures all subsequent files our program has to generate will
-- go in the repo where we expect.

.once dotOpener.sql
select
'-- dotOpener.sql was generated by InvDash2.0 authored by David Harris

-- the text writes will generate here
.cd "'||codePath||'"


--once we know where our files need to go we can prepare the charfix instruction.

.output CharfixCallerELISP.el
select
''
;; CharfixCallerELISP.el was generated by InvDash2.0 authored by David Harris
(load "'||codePath||'/charfix.el")
(charfix-folder "'||rawDataPath||'/'||wrangleDir||'"
"'||processedDataPath||'/'||wrangleDir||'")
'';

-- once our CharfixCallerELISP.el is written we can perform the shell call for charfix
.shell '||emacs||' --script '||codePath||'/CharfixCallerELISP.el

-- now that we have our files prepared with charfix, we can do a simple preliminary import
-- to check our files against our manifest and set up the main import.

.output SP02DotImportSQL.sql
select
''-- SP02DotImportSQL.sql was generated by InvDash2.0 authored by David Harris
.import "'||processedDataPath||'/'||wrangleDir||'/charfix-sp02.txt" SP02import
.import "'||processedDataPath||'/'||wrangleDir||'/charfix-manifest.txt" charfixmanifestimport
'';




--Lets dump our parms as rendered SQL content so we can read them back in to the database
--we are about to open.
.output parmdump.sql
.dump

-- our SQL will operate on this database file from here on.
.open "'||processedDataPath||'/wrangle.db"

-- remind the new session where we want our text writes
.cd "'||codepath||'"

' as dotOpener
from wrangleparms
;





-- This is our last chance to make sure the data we are wrangling is exported from SAP
-- and in the rawDataPath put in dated folders.
-- Thats how CharfixCallerELISP.el & SP02DotImportSQL.sql expect it.

-- in practice, this whole script will run one command after the other and we wont really
-- have time to check.  But it helps to understand this.

-- we have to charfix our raw data before anything else touches it, including Excel.
-- If you peek at the data in Excel, PLEASE close without saving. You don't want the sqlite
-- import to miss records because it doesn't like the apostrophe char used in L'Oreal
-- (not that one-- the curly one; its the worst) for example.  Or Excel to turn all your
-- dates into 45719.00 and put double quotes around text you aren't expecting, etc.

-- notice the call to Emacs, a text editor with find-and-replace capability thats well suited
-- for scripts, and remember up to this point we are not operating on a sqlite database file yet,
-- just using the sqlite3 command line interface for scripting.

-- by reading in the dotOpener.sql file we just wrote, we are writing the parametrized
-- CharfixCallerELISP.el & SP02DotImportSQL.sql, then running charfix, then opening up
-- our database file.




.read dotOpener.sql


-- our database has the results of past activity in it. We use drop statements to manage what to
-- keep and what to drop in order for the wrangle to go as expected.

-- Sqlite's .import process is always a bit messy in practice, because there are countless ways to
-- express data in text.  If you just let it create a table and define the columns it may do
-- unexpected things.  So we set it up.

-- The import tables have to exist at the time of import with the number of columns defined,
-- but no data in it yet.  Then .import puts raw text data in the temporary import table.
-- Then insert statements prepare and insert from the temporary import table into the main table

-- lets ditch the old parms so we can replace them with current ones.
drop table if exists localtimeParms;
drop table if exists environment;
drop table if exists wrangleparms;

-- should already be temps unless under development.
-- But we will drop them in case they are still around.
drop table if exists charfixmanifestimport;
drop table if exists SP02import;
drop table if exists ZOPENPOmport;
drop table if exists ZOTIFimport;
drop table if exists TFACSimport;
drop table if exists MMRPimport;
drop table if exists BOMreportimport;

-- We want the main tables so long as we don't duplicate data we already imported.
-- comment these out if you are stacking with past wrangle instances
-- uncomment if you are redoing an import
drop table if exists SP02wrangle;
drop table if exists tblList;
drop table if exists ZOTIFsalesorders;
drop table if exists ZOPENPOpurchase;
drop table if exists MMRPavail;
drop table if exists ALLPathsReport;
drop table if exists ShiftCalendar;


-- Its helpful to create all the tables first, immediately after the drops,
-- then do separate insert steps.  Error messages will refer to a specific point in the file,
-- so its good to structure the document in sections responsible for one thing at a time.


-- read our current parameters in
.read parmDump.sql

create table if not exists SAPreports(
pipelineStep,
importTable,
separators,
createdBy,
SAPtxn,
QUserGroup,
Qname,
SAPvariant,
SAPlayout,
SAPjobFrequency,
note,
sp02Match,
userMark
);


insert into SAPreports values
(0,ZOTIFimport,'| "\n"','David Harris','ZOTIF',null,null,'/SW FERT','/1SHIP-2','Daily at 07:00:00',
'feeds the ship plan and OTIF','%ZSD_COTY%',null),
(0,ZOPENPOimport,'| "\n"','David Harris','ZOPENPO',null,null,'/BUYER OOR','/DH_DEM','Daily at 07:00:00',
'All the Open POs for process inputs','%ZOPENPO%',null),
(0,MMRPimport,'| "\n"','David Harris','SQ00','ZUG_MMRP_01','ZQY_MMMRP_01','LELLOUCHET','/MRP','Daily at 07:00:00',
'MRP availabilities as displayed on MD04, but for all materials','%AQICZUG%',null),
(0,MDLDimport,'"\01" "\n"','David Harris','MDLD',null,null,null,null,'Daily at 07:00:00',
'"Print MRP List" MRP availabilities as displayed on MD04, but for all materials and including material context. This is a stock SAP report that prints 1 page per material. Its >30k pages and can take a long time to download. The MMMRP custom query is a good substitute in most cases','%RMDLDR%',null),


when trim(_8) like '%ZOPENPO%' then 'ZOPENPOimport'
when trim(_8) like '%ZSD_COTY%' then 'ZOTIFimport'
when trim(_8) like '%RMDLDR%' then 'MDLDimport'
when trim(_8) like '%1BCDWB%' then 'TFACSimport'
when trim(_8) like '%AQICZUG%' then 'MMRPimport'
when trim(_8) like '%AQICSLT%' then 'BOMreportimport'




create table if not exists tblList(
outputTable,
inputTable,
pipelineStep,
maintainer,
dropSQL,
createSQL,
convertSQL
);


create table if not exists compiledReportElements(
code,
maintainer,
compiler

);


create table if not exists ReportArtifacts(
pipelinestep,
filename,
content,
maintainer,
note
);






create temp table charfixmanifestimport (_1);
create temp table SP02import (_1,_2,_3,_4,_5,_6,_7,_8,_9);
create temp table ZOPENPOimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23,_24,_25,_26,_27);
create temp table ZOTIFimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20);
create temp table MDLDimport (_1);
create temp table TFACSimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,
	_13,_14,_15,_16,_17,_18,_19,_20);
create temp table MMRPimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14);
CREATE temp TABLE BOMreportimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23,_24,_25,_26,_27,_28,_29,_30,_31,_32,_33,_34,_35,_36);






create table if not exists SP02wrangle(
spoolNo,
wrangleDate,
title,
filename,
importTable,
separators,
_new
);

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
       FarevaPlannedDelivery
       );



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



-- Lets now read in this file we generated at the dotOpener step.
-- We always export SP02 itself as a list when we pull spools, to be a manifest
-- from SAP. We name the file sp02.txt in the folder with the data files.
-- "charfix-" will be appended to the filename by this point when we call it.
-- the spooler exports come out of SAP in .TXT files with the spoolNo in the filename.

-- in practice, not every spool SAP generates to the user's SP02 spool list actually gets
-- downloaded by the SAP user and fed into this import process. The user might use them elsewhere
-- or it might be a background job thats not in use that hasn't been deleted.
-- I think in our organization, any user can set up a background job from the transactions they have
-- access to, but jobs must be modified through SM37. I have requested access to SM37 through the
-- approrpriate channels but I have not been granted it (yet, hopefully).

-- We use sp02 and our charfix manifest to figure out which spool, and which filename, goes to
-- which import table.

.read SP02DotImportSQL.sql


-- this is the clean & insert step from the temporary import table to the main table,
-- but just for the manifest.  This is where we figure out which filenames to import next.

insert into SP02wrangle select
trim(replace(trim(_2),'X','')) as spoolNo,
trim(_4) ||' '|| trim(_5) as wrangleDate,
trim(_8) as title,
charfixmanifestimport._1 as filename,

-- the SQ00 queries show up on the sp02 manifest with a title specific enough to ID
-- the User Group but not the actual query. Also, If you wanted to pull 2 views from the
-- same SAP transaction and wrangle them as 2 different tables, The sp02 manifest title
-- is not specific enough for that either.

-- To handle these cases, when they come up, I think I'll peek at the data files and
-- manually edit sp02.txt before running the script to add a few identifying chars to the
-- title. And then add lines to this case statement to handle my custom edits the way we want.

case
when trim(_8) like '%ZOPENPO%' then 'ZOPENPOimport'
when trim(_8) like '%ZSD_COTY%' then 'ZOTIFimport'
when trim(_8) like '%RMDLDR%' then 'MDLDimport'
when trim(_8) like '%1BCDWB%' then 'TFACSimport'
when trim(_8) like '%AQICZUG%' then 'MMRPimport'
when trim(_8) like '%AQICSLT%' then 'BOMreportimport'
else null
end as importTable,

case
when trim(_8) like '%RMDLDR%' then '"\01" "\n"'
else '| "\n"'
end as separators,

-- case spoolNo not in (select spoolNo from SP02wrangle)
-- when true then 'X' else null end as _new
null as _new

from SP02import left join charfixmanifestimport
on format('charfix-FP1%010d.TXT',trim(replace(trim(_2),'X',''))) is charfixmanifestimport._1
where length(_3) > 0
and trim(_2) not null
and trim(_2) not like '%s%'
;

-- TODO: maybe keep a table of all the import tables,content tables and parms so new reports
-- can be integrated into the pipeline without changing this file much.

-- The wrangle instance concept presupposes 1 and only 1 import per structured source output.
-- That is how we are able to match the data to the spoolNo and wrangleDate on the manifest
-- and stack it with past wrangles without mixing things up.

-- This means, if you have 2 raw spooler outputs from ZOPENPO from different days,
-- and you want to upload them both, you'll have to run this process twice. They ought to be
-- actually from different days, not the same day at different times. You might capture them
-- by adjusting the ReportDate or the wrangleFrom or wrangleTo parms. But you might not even
-- have to do that. SP02wrangle is designed to import the most recent spool of each type thats
-- not already in the main table.

-- Lets enforce this by putting an X indicator on the most recent spool of each report type
-- that falls within the specified date range in relation to ReportDate.


update SP02wrangle set _new = 'X' where
spoolNo in (select spoolNo from (select max(wrangleDate),spoolNo
from SP02wrangle group by importTable))
and wrangleDate between (select wrangleFrom from wrangleparms)
and (select wrangleTo from wrangleparms);






-- Lets write the SQL we need for our .imports using filenames evaluated above from SP02.
-- If the SAP spool export and charfix.el worked as expected, the filenames should match up.

.once dotimportSQL.sql
select
'
.separator '||separators||'
.import "'||processedDataPath||'/'||wrangleDir||'/'||filename||'" '||importTable||'
'
from SP02wrangle cross cross join wrangleparms where _new is 'X' 
;

.read dotimportSQL.sql



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
(select spoolNo from SP02wrangle where importTable is 'ZOTIFimport' and _new is 'X'),
(select wrangleDate from SP02wrangle where importTable is 'ZOTIFimport' and _new is 'X'),
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
where trim(_5) LIKE '3____'
or trim(_5) LIKE '4____'
;



insert into ZOPENPOpurchase
select
(select spoolNo from SP02wrangle where importTable is 'ZOPENPOimport' and _new is 'X'),
(select wrangleDate from SP02wrangle where importTable is 'ZOPENPOimport' and _new is 'X'),
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
(select spoolNo from SP02wrangle where importTable is 'MMRPimport' and _new is 'X'),
(select wrangleDate from SP02wrangle where importTable is 'MMRPimport' and _new is 'X'),
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
trim(_12),
trim(_13)
from MMRPimport
where trim(_2) like '____-__-__'
;




--This is the last step off of a multi-step transform of TFACS factory calendar.  It gives us the dates in modified ISO 8601 format with 3 shift days.  It has every day start at 07:00, every week, month, and year start on the nearest Monday to the standard Julian calendar.  The other steps are in its own file.



create table if not exists ShiftCalendar as
	SELECT
(select spoolNo from SP02wrangle where importTable is 'TFACSimport' and _new is 'X') as spoolNo,
(select wrangleDate from SP02wrangle where importTable is 'TFACSimport' and _new is 'X') as wrangleDate,

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
(select spoolNo from SP02wrangle where importTable is 'BOMreportimport' and _new is 'X') as spoolNo,
(select wrangleDate from SP02wrangle where importTable is 'BOMreportimport' and _new is 'X') as wrangleDate,

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
(select spoolNo from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%AQICSLT%') as spoolNo,
(select wrangleDate from SP02wrangle where wrangleDate BETWEEN datetime((select _value from wrangleparms where _key is 'currentwrangleDate')) AND datetime((select _value from wrangleparms where _key is 'currentwrangleDate'),'+1 day','-0.001 second') and title like '%AQICSLT%') as wrangleDate,

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
