-- -*- mode: sql; sql-product: sqlite; -*-

/*
"pre-combining" is the assemblage of multiple wrangle instances to source a higher level report.

Pre-combined output its itself a low-level report that analyses wrangled content against its own metadata and produces a summary output.

"pre-combining" is contrasted with "post-combining" which is persisting selected output from a past report into a current report for high level time-series analysis.

*/

-- start in a folder with all your prepared wrangle instances. Attach the last precombine instance and the current wrangle instance so we can append the new data.

.cd "d:/home/RM06analyst/InvDash2.0/ProcessedDB"


-- .open "./precombine01.db"

attach database "./wrangle01_20250306.db" AS CurrentData;


-- make a table of all the wrangle instances you are combining, distinguishing them with a name and date. This should describe the relationship each component instance has to the combined output.

update CombinerParams set WrangleSourceName = 'PastData';

insert into CombinerParams values
       ('CurrentData','wrangle01_20250305.db','2025-03-06');

-- for MB51, combine wrangle instances by stacking the data crossed with the date, then group by the unique key at the most recent date to remove duplicates.  MB51 is just a running ledger that can be pulled from SAP at any time by specifying the date range. However, this combination step saves us from having to pull the same data over and over again.


insert into MB51combined
select MAX(SourceDate) as LastWrangle, * from
(
select * from CurrentData.MB51mvt
cross join (select SourceDate from CurrentData.WrangleDates where DataSourceName is 'MB51')
)
group by mtrldoc,quantity
order by material,postingdate desc;


-- for MB52, we want to compare inventory balances at key intervals. We specify past data from current.


update MB52combined set WrangleSourceName = 'PastData';

insert into MB52combined
select 'CurrentData' as WrangleSourceName,*
from CurrentData.MB52balance cross join (
select SourceDate from CurrentData.WrangleDates where DataSourceName is 'MB52')
;
 









create view if not exists InventoryBatchQuantities as
select
WrangleSourceName,SourceDate,Material,MtrlDesc,MtrlGrp,SLoc,MType,Batch,SDdoc,BaseUnit,
'Unrestricted' as Status,
UnrestrictedStock as stock,
UnrestrictedValue as value
from MB52combined
where UnrestrictedStock*1.0 > 0
union all
select
WrangleSourceName,SourceDate,Material,MtrlDesc,MtrlGrp,SLoc,MType,Batch,SDdoc,BaseUnit,
'Restricted' as Status,
RestrictedStock as stock,
RestrictedValue as value
from MB52combined
where RestrictedStock*1.0 > 0
union all
select
WrangleSourceName,SourceDate,Material,MtrlDesc,MtrlGrp,SLoc,MType,Batch,SDdoc,BaseUnit,
'QualityInspection' as Status,
QualityInspectionStock as stock,
QualityInspectionValue as value
from MB52combined
where QualityInspectionStock*1.0 > 0.0
union all
select
WrangleSourceName,SourceDate,Material,MtrlDesc,MtrlGrp,SLoc,MType,Batch,SDdoc,BaseUnit,
'Blocked' as Status,
BlockedStock as stock,
BlockedValue as value
from MB52combined
where BlockedStock*1.0 > 0.0
union all
select
WrangleSourceName,SourceDate,Material,MtrlDesc,MtrlGrp,SLoc,MType,Batch,SDdoc,BaseUnit,
'Returns' as Status,
ReturnsStock as stock,
ReturnsValue as value
from MB52combined
where ReturnsStock*1.0 > 0.0
;






-- We write our combined and assembled data to a tab separated text file.
-- We purposefully use a file extention that will NOT open up Excel when double-clicked from the file explorer.
-- Excel Report-Artifacts will source the data file using Power Query.

.mode tabs
.headers on
.once "InvBalanceBarChart.dat"
select * from InventoryBatchQuantities;
