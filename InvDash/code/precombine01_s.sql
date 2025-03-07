-- -*- mode: sql; sql-product: sqlite; -*-

/*

Authored by David Harris starting Feb of 2025.


"pre-combining" is the assemblage of multiple wrangle instances to source a higher level report.

Pre-combined output its itself a low-level report that analyses wrangled content against its own metadata and produces a summary output.

"pre-combining" is contrasted with "post-combining" which is persisting selected output from a past report into a current report for high level time-series analysis.


"precombine01_s.sql" is the initial assemblage of 2 or more wrangle instances.  This is where we develop the pipeline from, integrating more tables from the wrangle scripts

"precombine02_s.sql" is used instead, on routine basis, once we have the database file of past data and just want to add a single wrangle instance -- Current Data -- to it.


*/

-- start in a folder with all your prepared wrangle instances

.cd "d:/home/RM06analyst/InvDash2.0/ProcessedDB"


--attach database "./wrangle01_old.db" AS _old_db;

attach database "./wrangle01_20250224.db" AS _1db;
attach database "./wrangle01_20250225.db" AS _2db;

--attach database "./wrangle01_20250226.db" AS _4db;
--attach database "./wrangle01_20250304.db" AS _5db;


-- make a table of all the wrangle instances you are combining, distinguishing them with a name and date. This should describe the relationship each component instance has to the combined output.

create table CombinerParams (WrangleSourceName,FilePath,WrangleDate);
insert into CombinerParams values

--       ('_old_db','wrangle01_old.db','2025-02-11'),

	 ('_1db','wrangle01_20250224.db','2025-02-24'),
	 ('_2db','wrangle01_20250225.db','2025-02-25');

--       ('_3db','wrangle01_20250226.db','2025-02-26'),
--       ('_4db','wrangle01_20250304.db','2025-03-04');

-- for MB51, combine wrangle instances by stacking the data crossed with the date, then group by the unique key at the most recent date to remove duplicates.  MB51 is just a running ledger that can be pulled from SAP at any time by specifying the date range. However, this combination step saves us from having to pull the same data over and over again.

create table MB51combined as
select MAX(SourceDate) as LastWrangle, * from
(
select * from _1db.MB51mvt
cross join (select SourceDate from _1db.WrangleDates where DataSourceName is 'MB51')
union all
select * from _2db.MB51mvt
cross join (select SourceDate from _2db.WrangleDates where DataSourceName is 'MB51')

-- union all
-- select * from _3db.MB51mvt
-- cross join (select SourceDate from _3db.WrangleDates where DataSourceName is 'MB51')
-- union all
-- select * from _4db.MB51mvt
-- cross join (select SourceDate from _4db.WrangleDates where DataSourceName is 'MB51')
-- union all
-- select * from _5db.MB51mvt
-- cross join (select SourceDate from _5db.WrangleDates where DataSourceName is 'MB51')

)
group by mtrldoc,quantity
order by material,postingdate desc;


-- for MB52, we want to compare inventory balances at key intervals. We specify the source date of the wrangle instance for now so we can just stack it all together, to summarize at Report step.

-- TODO: This is going to quickly snowball into too much - almost redundant - data.  Integrate MB5L Month end balances and do a production-week ending balance to summarize data within the current month, so we only stack MB52 balances within the current week.  This will probably be something with CREATE TABLE / DROP TABLE on "preconbine02_s.sql" 

create table MB52combined as
select '_1db' as WrangleSourceName,*
from _1db.MB52balance cross join (
select SourceDate from _1db.WrangleDates where DataSourceName is 'MB52')
union all
select '_2db' as WrangleSourceName,*
from _2db.MB52balance cross join (
select SourceDate from _2db.WrangleDates where DataSourceName is 'MB52')

-- union all
-- select '_3db' as WrangleSourceName,*
-- from _3db.MB52balance cross join (
-- select SourceDate from _3db.WrangleDates where DataSourceName is 'MB52')
-- union all
-- select '_4db' as WrangleSourceName,*
-- from _4db.MB52balance cross join (
-- select SourceDate from _4db.WrangleDates where DataSourceName is 'MB52')
-- union all
-- select '_5db' as WrangleSourceName,*
-- from _5db.MB52balance cross join (
-- select SourceDate from _5db.WrangleDates where DataSourceName is 'MB52')

;


-- for CM01, we want to analyze changes to the production plan as they occur to determine FIFO-derived "path changes" at key intervals.  Such path changes carry Ownership implications in a Make-to-Order environment.  They represent the business decisions we enact on the production schedule so that the operation supports the business.
