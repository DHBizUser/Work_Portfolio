-- -*- mode: sql; sql-product: sqlite; -*-

/*

wrangler for DataRetrieval01_s.vbs

"wrangling" is the preliminary text processing that must be done to trasfer data between applications.

This takes text files from SAP that are prepared the same way every time I have to pull them, usually with variants or layouts within the SAP application.

it produces a database of tables cleaned up and ready for further SQL processing, The raw import table artifacts, and a table of wrangled items and dates pulled.

The resulting output represents a single wrangled instance (with all the wrangle dates around the same time).


I've found imports work best when:
all dates are rendered in YYYY-MM-DD format. I have this set in my SAP GUI settings.
all figures use comma as thousand separator and dot as decimal point. This can be set in SAP GUI settings if not already.
data is exported from SAP as a "spreadsheet" via codepage 1101.  This makes it tab separated text, ASCII characters only, using SAP native UTF-8 encoding 
data is NOT TOUCHED by MS Excel prior to import. I save it with txt extension to encourage myself to use Notepad, or at least right click -> open with excel and then CLOSE WITHOUT SAVING.


*/


-- Its easier to manage when we have all the data in the same folder and start there.

.cd "d:/home/RM06analyst/InvDash2.0/UnprocessedData/DataFolder_20250305"


-- import into an existing empty table that IDs a name and the fixes the number of columns. Set the mode for tab separated text so it aligns the columns.


CREATE  TABLE CM01import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23);
.mode tabs
.import "./CM01_s.txt" CM01import


create table MB51import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22);
.mode tabs
.import "./MB51_s.txt" MB51import

create table MB52import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22);
.mode tabs
.import "./MB52_s.txt" MB52import

create table ZOTIFimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20);
.mode tabs
.import "./ZOTIF_s.txt" ZOTIFimport








--FilePath must be hard-coded in the SQlite .import steps. Its included in the WrangleDates table just as a reference.

-- WrangleDates should be derived from the imported document if possible, or input manually otherwise

create table WrangleDates (DataSourceName,FilePath,SourceDate);
insert into WrangleDates values

       ('CM01','CM01_s.txt','2025-03-05'),
       ('MB51','MB51_s.txt',(select substr(trim(_1),1,10) from MB51import limit 1)),
       ('MB52','MB52_s.txt','2025-03-05'),
       ('ZOTIF','ZOTIF_s.txt',(select substr(trim(_1),1,10) from ZOTIFimport limit 1));



-- for each import, make a new table that extracts the meaningful content from empty spaces, punctuation, and non data lines. This set of prepared tables will be used in the actual transformations.  This hopefully keeps downstream results free from import artifacts.  If things break after a software update, they would probably only break up to this point. 


create table MB51mvt as select
trim(_3) as Material,
trim(_4) as PurchOrd,
trim(_5) as itm,
trim(_6) as mtrldesc,
trim(_7) as expiry,
trim(_8) as mvt,
trim(_9) as mtrldoc,
trim(_10) as mvtText,
trim(_11) as batch,
replace(trim(_12),',','') as quantity,
replace(trim(_13),',','') as LCamount,
trim(_14) as baseunit,
format('%s %s',trim(_15), trim(_16)) as postingdate,
trim(_18) as UserName,
trim(_19) as ReferenceText,
trim(_20) as DocHeaderText,
trim(_21) as ProcessOrder,
trim(_22) as Vendor

from MB51import
where trim(_3) is not null
and trim(_3) is not ''
and trim(_3) is not 'Material';



create table MB52balance as select
trim(_2) as Material,
trim(_3) as MtrlDesc,
trim(_7) as MtrlGrp,
trim(_8) as SLoc,
trim(_9) as MType,
trim(_10) as Batch,
trim(_11) as SDdoc,
trim(_12) as BaseUnit,
replace(trim(_13),',','') as UnrestrictedStock,
replace(trim(_14),',','') as RestrictedStock,
replace(trim(_15),',','') as QualityInspectionStock,
replace(trim(_16),',','') as BlockedStock,
replace(trim(_17),',','') as ReturnsStock,
replace(trim(_18),',','') as UnrestrictedValue,
replace(trim(_19),',','') as QualityInspectionValue,
replace(trim(_20),',','') as RestrictedValue,
replace(trim(_21),',','') as ReturnsValue,
replace(trim(_22),',','') as BlockedValue

from MB52import
where trim(_2) is not null
and trim(_2) is not 'Material'
and (trim(_9) is 'ZPAK'
or trim(_9) is 'ZRAW'
or trim(_9) is 'HALB'
or trim(_9) is 'FERT')

group by trim(_10);



-- the ZOTIF report pulled on 2025-02-24 had all lined indented one tab more than the ZOTIF pulled on 2025-01-31 -- all these columns needed to be adjusted

create table ZOTIFsalesorders as select
trim(_3) as ProfitCenter,
trim(_4) as CustNo,
trim(_5) as SOCreated,
trim(_6) as SalesOrder,
trim(_7) as SalesOrdItm,
trim(_8) as Material,
trim(_9) as description,
trim(_10) as CustPOnum,
trim(_11) as batch,
replace(trim(_12),',','') as SalesOrderQty,
replace(trim(_13),',','') as SOCurrentQty,

replace(trim(_14),',','')/replace(trim(_15),',','') as UnitPrice,
trim(_16) as SaleableUnit,
replace(trim(_17),',','') as NetValue,
trim(_18) as OriginalSTAT,
trim(_19) as CurrentSTAT,
trim(_20) as FarevaPlannedDeliviry

from ZOTIFimport
where trim(_3) is not null
and trim(_3) is not 'Profit Center';



CREATE TABLE CM01plan AS 
	SELECT
		rowid,
		TRIM(_4) AS WorkCenter,
		TRIM(_5) AS Material,
		TRIM(_9) AS PeggedRqmt,

		CASE
			TRIM(_9) LIKE 'R_____' OR TRIM(_9) LIKE 'T_____'
			WHEN TRUE THEN 1 ELSE 2	
		END AS RqmtTypeRank,
		
		CASE
			TRIM(_9) LIKE 'R_____' OR TRIM(_9) LIKE 'T_____'
			WHEN TRUE THEN 'FIXED' ELSE 'FCST'	
		END AS RqmtType,
		
		REPLACE(TRIM(_10),',','')*1.0 AS RqmtQty,
		TRIM(_11) AS RqmtUnit,
		TRIM(_12) AS SchedLatestStart,
		TRIM(_13) AS SchedLatestFinish,
		SUM(TRIM(_14)*1.0) AS SAPDuration,	
		TRIM(_15) AS DurUnit
	FROM CM01import WHERE _2 LIKE '____-__'
	GROUP BY TRIM(_9) order by rowid asc
;
