-- MRP parsing from the SQ00 custom SAP query MRP report
-- Authored by David Harris

drop table if exists StockEl;
drop table if exists MRPimport;
drop table if exists MRPlist;
drop view if exists MRPcalc;
drop view if exists ElementAnalysis;
drop view if exists CheckCalc;
drop view if exists RunOutDate;
drop table if exists Path_RunOut;



attach "s:/xxx/BOMreportConvPaths/BOMreport_20250619.db" as BOMreport;


create table if not exists StockEl (El);
insert into StockEl values
('WB'),
('KB'),
('LB')
;





create table if not exists MRPimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14);

.import "s:/xxx/SAPdata/Charfixdata/SAPspool_20250624/charfix-FP10000056911.TXT" MRPimport



create table if not exists MRPlist as

select 


trim(_2) as MRPdate,

row_number() over (partition by trim(_3) order by rowid) as MRPseq,

trim(_3) as material,
trim(_5) as MRPdescription,


case
when substr(_6,-1,1) = ' ' then trim(replace(replace(_6,',',''),'-',''))*1.0
when substr(_6,-1,1) = '-' then trim(replace(replace(_6,',',''),'-',''))*-1.0
else null end as RecReqQty,


case
when substr(_7,-1,1) = ' ' then trim(replace(replace(_7,',',''),'-',''))*1.0
when substr(_7,-1,1) = '-' then trim(replace(replace(_7,',',''),'-',''))*-1.0
else null end as AvailQty,


trim(_8) as BaseUnit,



trim(_9) as El,
trim(_10) as Eltext,
trim(_11) as Mtype


from MRPimport
where
trim(_2) like '____-__-__'
and trim(_3) is not null
and trim(_3) is not 'Material'

order by rowid
;





create view if not exists MRPcalc as 

select *,

SUM(RecReqQty)
OVER (PARTITION BY material order by MRPseq)
AS CalcAvailQty

from MRPlist as a

-- where MRPseq is not null

ORDER BY material,MRPseq
;



-- 🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥


create view if not exists RunOutDate as
select *,
min(MRPdate) as RunOutDate
from MRPlist
where (El is 'AR' or El is 'SB') and AvailQty <= 0
group by material;




create table if not exists Path_RunOut as
select
a.Cust,
a.TopLvlMtrl,
a.ComponentMtrl,
b.RunOutDate,
a.MTRLpath,
a.DESCpath
from BOMreport.ALLPathsReport as a left join RunOutDate as b
on a.ComponentMtrl = b.material
where b.RunOutDate is not null
and a.TopLvlMtrl in

(select material
from MRPlist
where MRPdate < date('now','+6 month')
and (El is 'AR' or El is 'SB' or El is 'VC' or El is 'VJ' or El is 'PP'))

group by a.TopLvlMtrl, a.ComponentMtrl
order by b.RunOutDate, a.ComponentMtrl, a.TopLvlMtrl
;




-- 🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥

.separator \t
.headers on
.once "s:/xxx/Comp-stock-RunOut/Path_RunOut.txt"
select * from Path_RunOut;



-- 🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥



-- analysis to figure out which MRP elements to include or not include in the rolling availability

create view if not exists ElementAnalysis as
select
el,

Eltext,

case
when El is 'LB' or El is 'KB' then 'no' else 'yes'
end as AvailCalc,

group_concat(distinct mtype) as Affected_mTypes,
count(distinct material) as MaterialCount
from MRPlist
group by el
;



create view if not exists CheckCalc as
select
MRPseq,
material,
Mtype,
AvailQty,
CalcAvailQty,
AvailQty-CalcAvailQty as diff
from MRPcalc 
where 
--AvailQty <> CalcAvailQty
abs(AvailQty-CalcAvailQty) > 0.0001
;





