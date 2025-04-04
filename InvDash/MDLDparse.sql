/*
DailyMRP

--Remove problem chars--
Open MDLD in notepad++
put line break in on the first line after ' %SAPWIN%PLS200Xl8.5;Oa1 '
type 'lines' on the 2nd line and then new line
Ctrl+F   [^a-zA-Z0–9#-_\s]   replace with '#'
this replaces '|' with '#'
once replaced, use '|'as the separator to ensure the lines are not split

--in shell--to test--
cd ~/RM06analyst/MDLDparse
rm test.db;sqlite3 test.db ".read MDLDparse.sql";DBbrowser test.db&

--in shell--to commit to SharedDrive--
cd ~/RM06analyst/MDLDparse
git commit -a -m "**message describing the changes**"
cd "S:\CC Concurrence Workspace\HARRISDM\RM06analyst\MDLDparse"
git pull
==============================================================================

CREATE TABLE MDLDimport (_1);
.separator "\01" "\n"
.import "MDLD_raw.txt" MDLDimport

  '\01' is the Start of Header character. Its a good column separator
because its not present anywhere in the source report, thus every line is
just 1 column  

 CREATE temp TABLE ReportDate AS
        WITH _date AS (
        	    SELECT TRIM(SUBSTR(_1,1,15),' ') AS ReportDate
 	    FROM MDLDimport
 	    WHERE SUBSTR(_1,11,103) LIKE '%Print MRP List%'
  	    LIMIT 1 OFFSET 1)
 	SELECT
 		'w+0' AS RelativeWeekPeriod,
 		ReportDate,
 	       IIF(julianday(ReportDate,'weekday 4')
 		- julianday(ReportDate) > 3,
 			date(ReportDate,'weekday 4','-7 days'),
 			date(ReportDate,'weekday 4'))
 		AS ReportDayISOThurs
 	FROM _date
 ;
*/


CREATE temp TABLE PageHeaders AS
	SELECT
		rowid AS pgStart,
		TRIM(REPLACE(SUBSTR(_1,110),',',''))*1 AS PageNum
	FROM MDLDimport WHERE SUBSTR(_1,11,103) LIKE '%Print MRP List%';


CREATE temp TABLE PaginatedLines AS
	SELECT
		MAX(PageNum)
			OVER (ROWS BETWEEN 70 PRECEDING AND CURRENT ROW)
		AS PageNum,
		_1 AS lines
	FROM MDLDimport LEFT JOIN PageHeaders
		ON pgStart = MDLDimport.rowid;


CREATE temp TABLE PageMtrl AS
	SELECT
		PageNum,
		TRIM(SUBSTR(lines,11,19)) AS Material
	FROM PaginatedLines WHERE lines LIKE 'Material..%' ;


CREATE TABLE if not exists MtrlInfo AS
	WITH
		Info1 AS (
			SELECT
				PageNum,
				TRIM(SUBSTR(lines,11,19)) AS Material,
				TRIM(SUBSTR(lines,40,50)) AS Description
			FROM PaginatedLines WHERE lines LIKE 'Material..%' ),
		Info2 AS (
			SELECT
				PageNum,
				TRIM(SUBSTR(lines,16,6)) AS MRPc,
				TRIM(SUBSTR(lines,40,6)) AS MRPgroup,
				TRIM(SUBSTR(lines,80,4)) AS LotSz
			FROM PaginatedLines WHERE lines LIKE 'MRP controller%' ),
		Info3 AS (
			SELECT
				PageNum,
				TRIM(SUBSTR(lines,40,6)) AS MtrlType,
				TRIM(SUBSTR(lines,80,4)) AS Unit
			FROM PaginatedLines WHERE lines LIKE 'MRP type..%' )
	SELECT
		Material,
		Description,
		MRPc,
		MRPgroup,
		LotSz,
		MtrlType,
		Unit
	FROM
		(Info1 JOIN Info2 ON Info1.PageNum = Info2.PageNum)
			JOIN Info3 ON Info1.PageNum = Info3.PageNum;


CREATE TABLE if not exists StockMetrics AS
	WITH
		Metric0 AS (
			SELECT
				PageNum,
				TRIM(SUBSTR(lines,17,6))*1 AS LeadTime,
				REPLACE(TRIM(SUBSTR(lines,40,20)),',','')*1.0 AS UnrestrictedStock,
				REPLACE(TRIM(SUBSTR(lines,80,20)),',','')*1.0 AS MinLotSz
			FROM PaginatedLines WHERE lines LIKE 'Repl. lead time %' ),
		Metric1 AS (
			SELECT
				PageNum,
				TRIM(SUBSTR(lines,17,6)) AS ProcurementType,
				REPLACE(TRIM(SUBSTR(lines,40,20)),',','')*-1.0 AS FCSTreq,
				REPLACE(TRIM(SUBSTR(lines,80,20)),',','')*1.0 AS MaxLotSz
			FROM PaginatedLines WHERE lines LIKE 'Procurement type%' ),
		Metric2 AS (
			SELECT
				PageNum,
				REPLACE(TRIM(SUBSTR(lines,40,20)),',','')*-1.0 AS FIXEDreq,
				REPLACE(TRIM(SUBSTR(lines,80,20)),',','')*1.0 AS SafetyStock
			FROM PaginatedLines WHERE lines LIKE 'SpecialProc.key %' ),
		Metric3 AS (
			SELECT
				PageNum,
				REPLACE(TRIM(SUBSTR(lines,40,20)),',','')*1.0 AS FCSTrec,
				REPLACE(TRIM(SUBSTR(lines,80,20)),',','')*1.0 AS ReorderLevel
			FROM PaginatedLines WHERE lines LIKE 'Sp. procurement%' ),
		Metric4 AS (
			SELECT
				PageNum,
				REPLACE(TRIM(SUBSTR(lines,40,20)),',','')*1.0 AS FIXEDrec,
				REPLACE(TRIM(SUBSTR(lines,80,20)),',','')*1.0 AS MaxStockLevel
			FROM PaginatedLines WHERE lines LIKE 'Coverage.......%' )
	SELECT
		PageMtrl.Material,
		LeadTime,
		UnrestrictedStock,
		MinLotSz,
		ProcurementType,
		FCSTreq,
		MaxLotSz,
		FIXEDreq,
		SafetyStock,
		FCSTrec,
        ReorderLevel,		
		FIXEDrec,
		MaxStockLevel
	FROM
		((((Metric0 JOIN Metric1 ON Metric0.PageNum = Metric1.PageNum)
			JOIN Metric2 ON Metric0.PageNum = Metric2.PageNum)
				JOIN Metric3 ON Metric0.PageNum = Metric3.PageNum)
					JOIN Metric4 ON Metric0.PageNum = Metric4.PageNum)
						JOIN PageMtrl ON Metric0.PageNum = PageMtrl.PageNum;


CREATE TABLE if not exists BodyLines AS
	SELECT
		rowid,
		PageNum,

		TRIM(SUBSTR(lines,0,11)) AS MRPdate,
		TRIM(SUBSTR(lines,11,12)) AS MRPelement,
		TRIM(SUBSTR(lines,23,28)) AS ElementDesc,
		TRIM(SUBSTR(lines,51,4)) AS fix,
		TRIM(SUBSTR(lines,55,12)) AS Rdate,
		TRIM(SUBSTR(lines,67,2)) AS ExMsg,
		
		IIF(TRIM(SUBSTR(REPLACE(TRIM(SUBSTR(lines,69,20)),',',''),-1,1)) IS '-',
			-1.0*REPLACE(REPLACE(TRIM(SUBSTR(lines,69,20)),',',''),'-',''),
			1.0*REPLACE(TRIM(SUBSTR(lines,69,20)),',','')) AS RecReqQty,
			
		IIF(TRIM(SUBSTR(REPLACE(TRIM(SUBSTR(lines,89,24)),',',''),-1,1)) IS '-',
			-1.0*REPLACE(REPLACE(TRIM(SUBSTR(lines,89,24)),',',''),'-',''),
			1.0*REPLACE(TRIM(SUBSTR(lines,89,24)),',','')) AS AvailQty
			
	FROM PaginatedLines
	WHERE lines LIKE '____-__-__ %'
	ORDER BY rowid;
	
/*
CREATE TABLE DatePeriods AS
	WITH
		ISOcalendarizer1 AS
		(WITH 
			ISOcalendarizer0 AS
			(SELECT DISTINCT
				ReportDate,
				ReportDayISOThurs,
				MRPdate,
				IIF(julianday(MRPdate,'weekday 4') - julianday(MRPdate) > 3,
					date(MRPdate,'weekday 4','-7 days'),
					date(MRPdate,'weekday 4'))
				AS ISOThurs
			FROM BodyLines CROSS JOIN ReportDate)
		SELECT *,
			strftime('%Y-%m',MRPdate) AS MonthPeriod,
			strftime('%Y-%m',ISOThurs) AS ISOMonthPeriod,	
			FORMAT('%02d',IIF(julianday(ISOThurs,'start of year','weekday 1')
				- julianday(ISOThurs,'start of year') > 0,
				strftime('%W',ISOThurs) + 1, strftime('%W',ISOThurs)))
			AS ISOweek,
			FORMAT('%02d',IIF(julianday(ReportDayISOThurs,'start of year','weekday 1')
				- julianday(ReportDayISOThurs,'start of year') > 0,
				strftime('%W',ReportDayISOThurs) + 1, strftime('%W',ReportDayISOThurs)))
			AS ReportDayISOweek
		FROM ISOcalendarizer0)
	SELECT
		*,
	       strftime('%Y-',ISOThurs)||ISOweek AS ISOWeekPeriod,
	       FORMAT('wk%+02d', (julianday(ISOThurs) - julianday(ReportDayISOThurs))/7) AS RelativeWeekPeriod
	FROM ISOcalendarizer1
;

CREATE TABLE wkPeriodList AS
	WITH list (_index) AS (
	SELECT
		-4    					-- 4 weeks backlog
	UNION ALL
	SELECT 
		_index + 1
	FROM list
	WHERE _index < 26		-- 26 weeks out
	)
	SELECT

	       FORMAT('wk%+02d', _index) AS RelativeWeekPeriod,
	       date(julianday(ReportDayISOThurs) + (7*_index)) AS ISOThurs,

		strftime('_%Gw%V',date(julianday(ReportDayISOThurs) + (7*_index)))
			AS xxFormatted,

		FORMAT('_%sw%s',
		strftime('%Y',date(julianday(ReportDayISOThurs) + (7*_index))),
		FORMAT('%02d',IIF(julianday(date(julianday(ReportDayISOThurs) + (7*_index),'start of year','weekday 1'))
				- julianday(date(julianday(ReportDayISOThurs) + (7*_index),'start of year')) > 0,
				strftime('%W',date(julianday(ReportDayISOThurs) + (7*_index))) + 1,
				strftime('%W',date(julianday(ReportDayISOThurs) + (7*_index))))))
			AS Formatted



	FROM list CROSS JOIN ReportDate
;


CREATE TABLE MRPlist AS
	WITH MRPlist0 AS
		(SELECT
			BodyLines.rowid,
			PageMtrl.Material,
			BodyLines.MRPdate, MRPelement, ElementDesc, fix, Rdate, ExMsg,
			RecReqQty, AvailQty		
		FROM
			PageMtrl JOIN BodyLines ON PageMtrl.PageNum = BodyLines.PageNum)
	SELECT
		MRPlist0.rowid,
		MRPlist0.Material,
		MtrlType,
		Unit,
		MRPc,
		MRPlist0.MRPdate,
		MRPelement,
		ElementDesc,
		fix,
		Rdate,
		ExMsg,
		RecReqQty,
		AvailQty AS SAPAvailQty,
		SUM(RecReqQty)
			OVER
				(PARTITION BY MRPlist0.Material
				ORDER BY MRPlist0.rowid
				ROWS UNBOUNDED PRECEDING)
			+ StockMetrics.UnrestrictedStock
		AS CalcAvailQty,

		SUM(RecReqQty)
		FILTER (WHERE MRPelement NOT LIKE '%Purch.ord.%' AND MRPelement NOT LIKE '%Proc.order%')
			OVER
				(PARTITION BY MRPlist0.Material
				ORDER BY MRPlist0.rowid
				ROWS UNBOUNDED PRECEDING)
			+ StockMetrics.UnrestrictedStock
		AS AvailNoReceipt,

		SUM(RecReqQty)
		FILTER (WHERE MRPelement NOT LIKE '%Safety Stock%')
			OVER
				(PARTITION BY MRPlist0.Material
				ORDER BY MRPlist0.rowid
				ROWS UNBOUNDED PRECEDING)
			+ StockMetrics.UnrestrictedStock
		AS AvailNoSafetyStock,

		SUM(RecReqQty)
		FILTER (WHERE MRPelement NOT LIKE '%Safety Stock%'
		AND MRPelement NOT LIKE '%Purch.ord.%' AND MRPelement NOT LIKE '%Proc.order%')
			OVER
				(PARTITION BY MRPlist0.Material
				ORDER BY MRPlist0.rowid
				ROWS UNBOUNDED PRECEDING)
			+ StockMetrics.UnrestrictedStock
		AS AvailNoReceiptNoSafetyStock,


		RelativeWeekPeriod,
		MonthPeriod,
		ISOMonthPeriod,
		ISOWeekPeriod
	FROM ((MRPlist0 JOIN DatePeriods
		ON MRPlist0.MRPdate = DatePeriods.MRPdate) JOIN MtrlInfo
			ON MRPlist0.Material = MtrlInfo.Material) JOIN StockMetrics
				ON MRPlist0.Material = StockMetrics.Material;
			
CREATE TABLE WeekGroups AS
       WITH SummaryScope AS
       (SELECT * FROM (SELECT DISTINCT Material,MRPc FROM MRPlist WHERE MRPc LIKE 'MS%') CROSS JOIN wkPeriodList),
       SummaryElements AS
       (SELECT
		MAX(rowid) AS IndexRow,
		Material,
		RelativeWeekPeriod,
		ISOMonthPeriod,
		ISOWeekPeriod,
		SUM(RecReqQty) AS NetRecReq,
		CalcAvailQty,
		AvailNoReceipt,
		AvailNoSafetyStock,
		AvailNoReceiptNoSafetyStock,

		CASE WHEN group_concat(MRPelement) LIKE '%Purch.ord.%' THEN '*'
		WHEN group_concat(MRPelement) LIKE '%Proc.order%' THEN '*'
		ELSE '' END AS ReceiptInd,

		CASE
		WHEN AvailNoSafetyStock > 0 AND AvailNoReceiptNoSafetyStock > 0 THEN 'G'
		WHEN AvailNoSafetyStock > 0 AND AvailNoReceiptNoSafetyStock <= 0 THEN 'Y'
		WHEN AvailNoSafetyStock <= 0 THEN 'R' 
		ELSE NULL END AS AvailTrafficLight

	FROM MRPlist WHERE MRPc LIKE 'MS%'
	GROUP BY Material,RelativeWeekPeriod
	ORDER BY Material,IndexRow)

	SELECT *,
		ReceiptInd||AvailTrafficLight AS SummaryString		
	FROM SummaryScope AS a LEFT JOIN SummaryElements AS b ON a.Material IS b.Material AND a.RelativeWeekPeriod IS b.RelativeWeekPeriod
;



CREATE TABLE _1WeekGroups AS
   select julianday(ISOThurs),
          coalesce(IndexRow,
                   (
                      select IndexRow
                        from WeekGroups
                       where julianday(ISOThurs) < julianday(o.ISOThurs)
                         and IndexRow is not null
                    order by julianday(ISOThurs) desc
                       limit 1
                   ),
                   '--'
                  ) as IndexRow,
          coalesce(SummaryString,
                   (
                      select SummaryString
                        from WeekGroups
                       where julianday(ISOThurs) < julianday(o.ISOThurs)
                         and SummaryString is not null
                    order by julianday(ISOThurs) desc
                       limit 1
                   ),
                   '--'
                  ) as SummaryString
    from WeekGroups as o
order by julianday(ISOThurs)
;

 Made a few attempts to fill in the nulls on the WeekGroups 


--UPDATE WeekGroups SET SummaryString = AvailTrafficLight FROM WeekGroups WHERE  

CREATE TABLE _1WeekGroups AS
       SELECT
	Material,
	RelativeWeekPeriod,
	ISOThurs,
	Formatted,
	LAST_VALUE(IndexRow) FILTER (WHERE IndexRow NOT NULL) OVER (PARTITION BY Material ORDER BY Material,ISOThurs GROUPS UNBOUNDED PRECEDING) AS _ind
	FROM WeekGroups ORDER BY Material,ISOThurs
;



CREATE TABLE _1WeekGroups AS
with recursive filltable as
(
select
min(julianday(ISOThurs)) AS fillorder,
Material,
RelativeWeekPeriod,
Formatted,
coalesce(IndexRow,'--') AS IndexRow, --<value you want if the first temp is null>
coalesce(SummaryString,'--') AS SummaryString --<value you want if the first humidity is null>
from WeekGroups

union all

select
julianday(WeekGroups.ISOThurs),
WeekGroups.Material,
WeekGroups.RelativeWeekPeriod,
WeekGroups.Formatted,
coalesce(WeekGroups.IndexRow, filltable.IndexRow) AS IndexRow,
coalesce(WeekGroups.AvailTrafficLight, filltable.SummaryString) AS SummaryString
from
filltable inner join WeekGroups
on julianday(WeekGroups.ISOThurs) = (
    select julianday(ISOThurs)
    from WeekGroups
    where julianday(ISOThurs) > filltable.fillorder
    order by julianday(ISOThurs)
    limit 1
)
)
select * from filltable
order by fillorder
;




CREATE TABLE wkTablesSQL AS
       SELECT
       'CREATE TABLE '||Formatted||' AS
       SELECT
              Material,
	      MRPc,
	      RelativeWeekPeriod,
	      AvailTrafficLight,
	      SummaryString
       FROM WeekGroups 
       WHERE RelativeWeekPeriod IS '''||RelativeWeekPeriod||''';'
       AS "--" FROM wkPeriodList
;

CREATE TABLE MRPsummarySQL AS
SELECT
	'CREATE TABLE MRPsummary AS
	SELECT
	a.Material,a.MRPc,' AS "--"
UNION ALL
SELECT
	Formatted||'.SummaryString AS '||Formatted||','
FROM wkPeriodList
UNION ALL
SELECT 'FROM WeekGroups AS a'
UNION ALL
SELECT
'LEFT JOIN '||Formatted||' ON a.Material IS '||Formatted||'.Material'
FROM wkPeriodList
UNION ALL
SELECT
'GROUP BY a.Material ORDER BY a.Material;'
;

UPDATE MRPsummarySQL SET "--" = Formatted ||'.SummaryString AS '||Formatted FROM wkPeriodList WHERE MRPsummarySQL.rowid = (SELECT MAX(rowid) FROM wkPeriodList)+1
;

.headers off
.once wkTables.sql
SELECT * FROM wkTablesSQL;

.once MRPsummary.sql
SELECT * FROM MRPsummarySQL;

.read wkTables.sql
.read MRPsummary.sql

.mode tabs
.headers on
.once MRPsummary_print.txt
SELECT * FROM MRPsummary;

*/
