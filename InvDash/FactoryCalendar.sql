/*
Factory Calendar

merge SAP calendar used for MRP with the plant holiday schedule


.open "C:/Users/harrisdm/Desktop/CM01_to_MRP/FactoryCalendar.db"
--=============================================================================

CREATE TEMPORARY TABLE TFACSimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,
	_13,_14,_15,_16,_17,_18);
.mode tabs
.import "C:/Users/harrisdm/Desktop/CM01_to_MRP/TFACS_Z1_20241014.txt" TFACSimport

--=============================================================================
*/

CREATE TEMPORARY TABLE CalendarMonths (numMonth,textMonth,shortMonth);
INSERT INTO CalendarMonths
	VALUES
		('01','January','Jan'),
		('02','February','Feb'),
		('03','March','Mar'),
		('04','April','Apr'),
		('05','May','May'),
		('06','June','Jun'),
		('07','July','Jul'),
		('08','August','Aug'),
		('09','September','Sep'),
		('10','October','Oct'),
		('11','November','Nov'),
		('12','December','Dec');

CREATE TEMPORARY TABLE CalendarDaysofWeek (numDay,textDay,shortDay);
INSERT INTO CalendarDaysofWeek
	VALUES
		(0,'Sunday','Su'),
		(1,'Monday','M'),
		(2,'Tuesday','T'),
		(3,'Wednesday','W'),
		(4,'Thursday','Th'),
		(5,'Friday','F'),
		(6,'Saturday','S')
;

CREATE TEMPORARY TABLE HRholidayschedule (Holiday,DateObserved);
INSERT INTO HRholidayschedule
	VALUES
		('New Years Day 2024','2024-01-01'),
		('Carryover New Years Eve 2023','2024-01-02'),
		('Presidents Day','2024-02-19'),
		('Memorial Day','2024-05-27'),		
		('Independence Day','2024-07-05'),
		('Labor Day','2024-09-12'),
		('Thanksgiving Day','2024-11-28'),
		('Day Following Thankgiving Day','2024-11-29'),
		('Christmas Eve','2024-12-24'),
		('Christmas Day','2024-12-25'),
		('New Years Eve','2024-12-31'),

		('New Years Day 2025','2025-01-01'),
		('Presidents Day','2025-02-17'),
		('Memorial Day','2025-05-26'),		
		('Independence Day','2025-07-04'),
		('Labor Day','2025-09-01'),
		('Thanksgiving Day','2025-11-27'),
		('Day Following Thankgiving Day','2025-11-28'),
		('Christmas Eve','2025-12-24'),
		('Christmas Day','2025-12-25'),
		('New Years Eve','2025-12-31'),
		('New Years Day 2026','2026-01-01')
;		

CREATE TEMPORARY TABLE TFACS AS
	SELECT
		TRIM(_3) AS FactoryCalID,
		TRIM(_4)*1 AS "Year",
		TRIM(_5) AS MONTH_01,
		TRIM(_6) AS MONTH_02,
		TRIM(_7) AS MONTH_03,
		TRIM(_8) AS MONTH_04,
		TRIM(_9) AS MONTH_05,
		TRIM(_10) AS MONTH_06,
		TRIM(_11) AS MONTH_07,
		TRIM(_12) AS MONTH_08,
		TRIM(_13) AS MONTH_09,
		TRIM(_14) AS MONTH_10,
		TRIM(_15) AS MONTH_11,
		TRIM(_16) AS MONTH_12,		
		TRIM(_17)*1 AS CalDaySequence,
		TRIM(_18)*1 AS TotalWD,
		TRIM(_19)*1 AS TotalCalDay
	FROM TFACSimport
	-- WHERE TRIM(_4)*1 >= strftime('%Y','now')*1
;

CREATE TEMPORARY TABLE indexer AS
	WITH list (_index) AS (
	SELECT
		-3*7*30    					-- 30 weeks backlog
	UNION ALL
	SELECT 
		_index + 1
	FROM list
	WHERE _index < (3*7*53*1.5)		-- 1.5 years out
	)
	SELECT * FROM list
;

CREATE TEMPORARY TABLE ShiftCalendarizer AS
	SELECT *,

		FORMAT('S%+.4d',_index) AS ShiftPeriod,

		datetime(julianday('now','localtime')
			+ (_index*(8.0/24.0)))
		AS ReferenceTime

	FROM indexer
;

CREATE TEMPORARY TABLE ShiftCal AS
	SELECT *,
		
		CASE
			WHEN julianday(time(ReferenceTime))
				> julianday(time('07:00:00'))
				AND julianday(time(ReferenceTime))
				< julianday(time('15:00:00'))
			THEN 1
			WHEN julianday(time(ReferenceTime))
				> julianday(time('15:00:00'))
				AND julianday(time(ReferenceTime))
				< julianday(time('23:00:00'))
			THEN 2
			ELSE 3
		END AS Shift,
		CASE
			WHEN julianday(time(ReferenceTime))
				< julianday(time('07:00:00'))
			THEN date(ReferenceTime,'-1 days')
			ELSE date(ReferenceTime,'-0 days')
		END AS ShiftDate
	FROM ShiftCalendarizer
;

CREATE TEMPORARY TABLE ISOWeekCal AS
	SELECT
		*,
		datetime(julianday(ShiftDate)+((Shift*8.0-1.0)/24.0)) AS ShiftStart,
		datetime(ShiftDate,'+7 hours') AS WorkDayStart,
		CASE
			julianday(ShiftDate,'weekday 01') - julianday(ShiftDate) > 0
			WHEN TRUE
			THEN datetime(ShiftDate,'weekday 01','-7 days','+7 hours')
			ELSE datetime(ShiftDate,'+7 hours')
		END AS WorkWeekStart,
		CASE
			julianday(ShiftDate,'weekday 04') - julianday(ShiftDate) > 3
			WHEN TRUE
			THEN strftime('%Y',ShiftDate,'weekday 04','-7 days')
			ELSE strftime('%Y',ShiftDate,'weekday 04','-0 days')
		END AS ISOYear,
		CASE
			julianday(ShiftDate,'weekday 04') - julianday(ShiftDate) > 3
			WHEN TRUE
			THEN strftime('%m',ShiftDate,'weekday 04','-7 days')
			ELSE strftime('%m',ShiftDate,'weekday 04','-0 days')
		END AS ISOMonth,
		Holiday,
		SUBSTR(
			MONTH_01||MONTH_02||MONTH_03||MONTH_04||MONTH_05||MONTH_06||
			MONTH_07||MONTH_08||MONTH_09||MONTH_10||MONTH_11||MONTH_12,
			strftime('%j',ShiftDate)*1,1		
		) AS FactoryCalWD
	FROM (ShiftCal LEFT JOIN HRholidayschedule
		ON DateObserved = ShiftDate)
			LEFT JOIN TFACS ON
				(strftime('%Y',Shiftdate)*1 IS "Year")
;

CREATE TEMPORARY TABLE ISOYearCal1 AS
	SELECT
		*,
		CASE
			WHEN
				julianday(ISOYear||'-01-01','weekday 01')
					- julianday(ISOYear||'-01-01') > 0
				AND strftime('%W',ShiftDate)*1 > 52
			THEN 1
			WHEN
				julianday(ISOYear||'-01-01','weekday 01')
					- julianday(ISOYear||'-01-01') > 0
			THEN strftime('%W',ShiftDate)*1 + 1
			ELSE strftime('%W',ShiftDate)*1
		END AS ISOWeek,
		strftime('%J',datetime(ISOYear||'-01-01 00:00:00',
			'weekday 01','+7 hours'))
		AS WorkYearfwd,
		strftime('%J',datetime(ISOYear||'-01-01 00:00:00',
			'weekday 01','-7 days','+7 hours'))
		AS WorkYearback,		
		strftime('%J',datetime(ISOYear||'-01-01 00:00:00')) AS CalYearStart,
		strftime('%J',datetime(ISOYear||'-'||ISOMonth||'-01 00:00:00',
			'weekday 01','+7 hours'))
		AS WorkMonthfwd,
		strftime('%J',datetime(ISOYear||'-'||ISOMonth||'-01 00:00:00',
			'weekday 01','-7 days','+7 hours'))
		AS WorkMonthback,		
		strftime('%J',datetime(ISOYear||'-'||ISOMonth||'-01 00:00:00'))
		AS CalMonthStart,
		SUM(FactoryCalWD)
			OVER
				(ORDER BY ShiftStart RANGE UNBOUNDED PRECEDING)
		AS ShiftCountFactoryCal0
	FROM ISOWeekCal
;

CREATE TEMPORARY TABLE ISOYearCal2 AS
	SELECT
		*,
		ShiftCountFactoryCal0
			- (SELECT ShiftCountFactoryCal0
				FROM ISOYearCal1 WHERE ShiftPeriod LIKE 'S+0000')
		AS ShiftCountFactoryCal,
		WorkYearfwd-CalYearStart AS WorkYearAdjfwd,
		WorkYearback-CalYearStart AS WorkYearAdjback,	
		WorkMonthfwd-CalMonthStart AS WorkMonthAdjfwd,
		WorkMonthback-CalMonthStart AS WorkMonthAdjback
	FROM ISOYearCal1
;

CREATE TEMPORARY TABLE ISOYearCal3 AS
	SELECT *,
		CASE
			MIN(ABS(WorkMonthAdjfwd),ABS(WorkMonthAdjback))
			WHEN ABS(WorkMonthAdjfwd)
			THEN datetime(CalMonthStart + WorkMonthAdjfwd)
			ELSE datetime(CalMonthStart + WorkMonthAdjback)
		END AS WorkMonthStart,
		CASE
			MIN(ABS(WorkYearAdjfwd),ABS(WorkYearAdjback))
			WHEN ABS(WorkYearAdjfwd)
			THEN datetime(CalYearStart + WorkYearAdjfwd)
			ELSE datetime(CalYearStart + WorkYearAdjback)
		END AS WorkYearStart
	FROM ISOYearCal2
;

CREATE TEMPORARY TABLE ISOYearCal4 AS
	SELECT *,
		CAST(
			((strftime('%J', WorkWeekStart)
				- strftime('%J', WorkMonthStart)) / 7) +1
		AS INTEGER) AS WorkMonthWeekSeq
	FROM ISOYearCal3
;





/*=========================================================================

CREATE TABLE ShiftCalendar AS
	SELECT
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



===========================================================================


		FORMAT('%s-%.2d[%s]',ISOYear,ISOWeek,
			(SELECT shortDay FROM CalendarDaysofWeek
				WHERE numDay = strftime('%w',ShiftDate)*1)
		) AS WorkYearWeekDay,

		FORMAT('%s%s[%s%s]',ISOYear,
			(SELECT shortMonth FROM CalendarMonths WHERE numMonth = ISOMonth),
				WorkMonthWeekSeq,
				(SELECT shortDay FROM CalendarDaysofWeek
					WHERE numDay = strftime('%w',ShiftDate)*1)
		) AS WorkYearMonthWeekSeqDay,
		
		FORMAT('%s-%.2d[%s]#%.1d',ISOYear,ISOWeek,
			(SELECT shortDay FROM CalendarDaysofWeek
				WHERE numDay = strftime('%w',ShiftDate)*1),Shift
		) AS WorkYearWeekDayShift,
		
		ShiftCountFactoryCal*(8.0)
		- (SELECT ShiftCountFactoryCal*(8.0)
				FROM ISOYearCal3 WHERE ShiftPeriod IS 'S+0000')
		AS SchedDurationFactoryCal,
		ReferenceTime,	
*/

