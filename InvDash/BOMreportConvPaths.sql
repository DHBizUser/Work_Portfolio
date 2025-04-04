-- -*- mode: sql; sql-product: sqlite; -*-
/* Full Material Conversion Paths from BOM report in SAP
Authored by David Harris 2024-10-02

- Put BOMreport SAP output into SQlite DB to analyze related data
- Form a list of complete conversion paths from parent:component
	relationships, in steps.
	-------

--Remove problem chars--
Open MDLD in notepad++
put line break in on the first line after ' %SAPWIN%PLS200Xl8.5;Oa1 '
type 'lines' on the 2nd line and then new line
Ctrl+F   [^a-zA-Z0–9#-_\s]   replace with '#'
this replaces '|' with '#'
once replaced, use '|'as the separator to ensure the lines are not split

TODO -- figure out elisp to do this, put the elisp and the SQL together in Org Babel
;; (replace-regexp-in-region "[^a-zA-Z0–9#-_\s]" "#")


--in shell--to test--
cd ~/RM06analyst/BOMreportConvPaths
rm test.db;sqlite3 test.db ".read BOMreportConvPaths.sql";DBbrowser test.db&

--in shell--to commit to SharedDrive--
cd ~/RM06analyst/BOMreportConvPaths
git commit -a -m "**message describing the changes**"
cd "S:\CC Concurrence Workspace\HARRISDM\RM06analyst\BOMreportConvPaths"
git pull

==============================================================================*/


-- CREATE TABLE BOMreportimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23,_24,_25,_26,_27,_28,_29,_30,_31,_32,_33,_34,_35);
-- .mode tabs
-- .import "BOMreport_fixchar_20250307.dat" BOMreportimport
/*==BODY=====================================================================*/

CREATE temp TABLE IF NOT EXISTS Parms (_key, _value);
INSERT INTO Parms VALUES
	('iter',1),('FocusCust','--'),
	('FocusBOMstatus','01');

CREATE temp TABLE IF NOT EXISTS UnitEqivalences (_key, _value);
INSERT INTO UnitEqivalences VALUES
	('* KG* KG^-1',1),
	('* EA* EA^-1',1),
	('* GL*LTR^-1',0.264172),
	('* EA* EA^-1* KG* KG^-1',1),
	('* EA* EA^-1* GM* GM^-1',1),
	('* EA* EA^-1* EA* EA^-1',1),
	('* EA* EA^-1* EA* EA^-1* GM* GM^-1',1),
	('* GL*FOZ^-1',0.0078125),
	('* GL* GL^-1',1),
	('* KG* OZ^-1',0.02834952),
	('* EA* EA^-1* KG* OZ^-1',0.02834952),
	('* EA* EA^-1* EA* EA^-1* KG* KG^-1',1),
	('* EA* EA^-1* KG* OZ^-1* KG* KG^-1',0.02834952),
	('* KG* OZ^-1* KG* KG^-1',1),
	('* KG* GM^-1',0.001),
	('* EA* EA^-1* KG* GM^-1',0.001),
	('* KG* GM^-1* KG* KG^-1',0.001),
	('*  M* EA^-1',0.001),
	('* KG* KG^-1* KG* KG^-1',1),
	('* KG* KG^-1* KG* KG^-1* KG* KG^-1',1),
	('* KG* KG^-1* KG* KG^-1* KG* GM^-1',0.001);


CREATE temp TABLE IF NOT EXISTS BOMPairstable AS
	SELECT DISTINCT
		NULL AS BOMdepth,
		trim(_6) AS Cust,
		trim(_4) AS ParentMtrl,
		trim(_5) AS ParentDesc,
		NULLIF(REPLACE(TRIM(_9),',','')*1.0,"") AS ParentQty,
		SUBSTR('   '||trim(_11),-3,3) AS ParentUnit,
		trim(_15) AS ComponentMtrl,
		trim(_16) AS ComponentDesc,
		NULLIF(REPLACE(TRIM(_18),',','')*1.0,"") AS ComponentQty,
		IIF(trim(_19) = "******"," GL",
			SUBSTR('   '||trim(_19),-3,3)) AS ComponentUnit,
		NULLIF(REPLACE(TRIM(_18),',','')*1.0,"")
			/NULLIF(REPLACE(TRIM(_9),',','')*1.0,"") AS UnitUsage,
		IIF(trim(_19) = '******',' GL',SUBSTR('   '||trim(_19),-3,3)) || '*' ||
			SUBSTR('   '||trim(_11),-3,3) || '^-1'
			AS ConversionUnit,
		trim(_12) AS AltBOM,	
		trim(_2) AS BOM,
		trim(_14) AS BOMitem,
		TRIM(_22) AS BOMstatus
	FROM BOMReportimport
	WHERE trim(_2) LIKE '00%' AND LENGTH(trim(_15)) > 0;


CREATE temp TABLE IF NOT EXISTS BOMCompData AS SELECT
	trim(_15) AS Material,
	trim(_16) AS Description,
	IIF(trim(_32) = 'S',NULLIF(TRIM(_33)*1.0,"")
		/ NULLIF(REPLACE(TRIM(_35),',','')*1.0,""),
		IIF(trim(_32) = 'V',NULLIF(TRIM(_34)*1.0,"")
			/ NULLIF(REPLACE(TRIM(_35),',','')*1.0,""),NULL))
			AS UnitPrice,
	IIF(trim(_19) = "******","GL",trim(_19)) AS ComponentUnit,
	IIF(TRIM(_23)>0,TRIM(_23),NULL)
	AS LeadTime
	FROM BOMReportimport WHERE _2 LIKE '00%' AND LENGTH(_15) > 0;


CREATE temp VIEW IF NOT EXISTS TopLvlParent AS
	SELECT DISTINCT ParentMtrl FROM BOMPairstable
	EXCEPT
		SELECT ComponentMtrl FROM BOMPairstable
	ORDER BY ParentMtrl;
	
UPDATE BOMPairstable SET BOMdepth = 1 WHERE ParentMtrl IN TopLvlParent;


CREATE TABLE IF NOT EXISTS FocusCustParent AS
	SELECT DISTINCT
		NULL AS _tbl, Cust, ParentMtrl
	FROM BOMPairstable
	WHERE	BOMdepth = 1
		AND BOMstatus = (SELECT _value FROM Parms WHERE _key IS 'FocusBOMstatus')
--		AND Cust = (SELECT _value FROM Parms WHERE _key IS 'FocusCust')
	ORDER BY ParentMtrl;
UPDATE FocusCustParent SET _tbl = FORMAT ('_%03uTLpaths',rowid);



/*===========================================================================*/

SELECT
'There are ' || COUNT(*) || ' top level SKUs to evaluate Multi-level BOM explosion for.'
AS Message FROM FocusCustParent;

/*
Once the BOMreport data is analyzed to this point, and the number of top 
level SKUs for the scope of the LogSpec is known,
the queries on these sql files will need to be tailored to that number.
=============================================================================*/


CREATE temp VIEW IF NOT EXISTS _tblGenerateSQL AS SELECT
'CREATE temp TABLE ' || _tbl || ' AS SELECT * FROM _G00TLpaths;
UPDATE ' || _tbl ||
	' SET
		EqHandler =
			(SELECT _value FROM UnitEqivalences WHERE _key = EqHandlerUnit),
		CombinedUnitUsage = CombinedUnitUsage*
			(SELECT _value FROM UnitEqivalences WHERE _key = EqHandlerUnit),
		CombinedConversionUnit = CombinedConversionUnit || EqHandlerUnit
	WHERE EqHandlerUnit IN (SELECT _key FROM UnitEqivalences);
UPDATE Parms SET _value = _value + 1 WHERE _key IS ''iter'';
select '''|| _tbl || ' has been performed, out of ''|| (select count(*) from FocusCustParent) ||'' top level SKUs'';'
AS "--_tblGenerateSQL" FROM FocusCustParent;


CREATE temp TABLE IF NOT EXISTS _PathsSQL01 AS SELECT
'CREATE temp TABLE IF NOT EXISTS _01Paths AS' AS "--_PathsSQL01"
Union ALL SELECT
'SELECT * FROM ' ||  _tbl || ' UNION ALL' AS "--_PathsSQL01"
FROM FocusCustParent LIMIT 450;

UPDATE _PathsSQL01 SET "--_PathsSQL01" =
'SELECT * FROM ' ||
	(SELECT _tbl FROM FocusCustParent WHERE rowid =
		(SELECT MAX(rowid)FROM _PathsSQL01)-1)
	|| ';  CREATE temp TABLE IF NOT EXISTS _02Paths AS'
WHERE rowid = (SELECT MAX(rowid)FROM _PathsSQL01);


CREATE temp TABLE IF NOT EXISTS _PathsSQL02 AS SELECT
'SELECT * FROM ' ||  _tbl || ' UNION ALL' AS "--_PathsSQL02"
FROM FocusCustParent LIMIT 450 OFFSET 449;

UPDATE _PathsSQL02 SET "--_PathsSQL02" =
'SELECT * FROM ' ||
	(SELECT _tbl FROM FocusCustParent WHERE rowid =
		(SELECT MAX(rowid)FROM _PathsSQL01)
		+(SELECT MAX(rowid)FROM _PathsSQL02)-1)
	|| ';'
WHERE rowid = (SELECT MAX(rowid)FROM _PathsSQL02);




CREATE temp VIEW IF NOT EXISTS _AllPathsSQL AS
	SELECT * FROM _PathsSQL01 UNION ALL
	SELECT * FROM _PathsSQL02;


CREATE temp VIEW IF NOT EXISTS _G00TLpaths AS
	WITH RecursiveBOMexplode (
		TopLvlNo,
		Cust,
		TopLvlMtrl,
		BOMdepth,	
		MTRLpath,
		DESCpath,
		ComponentMtrl,
		UnitUsage,
		ConversionUnit,
		EqHandler,
		EqHandlerUnit,
		AltBOM,
		BOMpath,
		BOMitem,
		BOMstatus,
		CombinedUnitUsage,
		CombinedConversionUnit,
		PathUnit
		) AS
	(	SELECT
			p.ROWID,
			Root.Cust,
			p.ParentMtrl,
			1,
			FORMAT('(%s %s)',p.ParentMtrl,Root.ComponentMtrl),
			FORMAT('((''%s'')  ''%s'')',Root.ParentDesc,Root.ComponentDesc),
			Root.ComponentMtrl,
			Root.UnitUsage,
			Root.ConversionUnit,
			1,
			'',
			Root.AltBOM,
			FORMAT('(%s)',Root.BOM),
			Root.BOMitem,
			Root.BOMstatus,
			Root.UnitUsage,
			Root.ConversionUnit,
			Root.ConversionUnit
		FROM BOMPairstable AS Root LEFT JOIN FocusCustParent AS p
			ON Root.ParentMtrl = p.ParentMtrl
		WHERE p.ROWID =	(SELECT _value FROM Parms WHERE _key IS 'iter')
		UNION all
		SELECT
			Uplvl.TopLvlNo,
			Uplvl.Cust,
			Uplvl.TopLvlMtrl,
			Uplvl.BOMdepth + 1,
			FORMAT('(%s %s)',Uplvl.MTRLPath,Dwnlvl.ComponentMtrl),
			FORMAT('(%s  ''%s'')',Uplvl.DESCpath,Dwnlvl.ComponentDesc),
			Dwnlvl.ComponentMtrl,
			Dwnlvl.UnitUsage,
			Dwnlvl.ConversionUnit,			
			1,
			Uplvl.EqHandlerUnit || '*' ||
				SUBSTR(Dwnlvl.ConversionUnit,5,3) || '*' ||
				SUBSTR(Uplvl.ConversionUnit,1,3) || '^-1',
			Dwnlvl.AltBOM,
			FORMAT('(%s %s)',Uplvl.BOMpath,Dwnlvl.BOM),
			Dwnlvl.BOMitem,
			Dwnlvl.BOMstatus,
			Uplvl.CombinedUnitUsage*Dwnlvl.UnitUsage,
			Uplvl.CombinedConversionUnit || '*' || Dwnlvl.ConversionUnit,
			SUBSTR(Dwnlvl.ConversionUnit,1,3) || '*' ||
				SUBSTR(Uplvl.CombinedConversionUnit,-6,3) || '^-1'
		FROM RecursiveBOMexplode AS Uplvl,
			BOMPairstable AS Dwnlvl
		WHERE Uplvl.ComponentMtrl = Dwnlvl.ParentMtrl
			AND Uplvl.BOMdepth < 5	)
		SELECT * FROM RecursiveBOMexplode;




.headers off
.once "TableGenerateSQL.sql"
SELECT * FROM _tblGenerateSQL;
.once "AllPathsSQL.sql"
SELECT * FROM _AllPathsSQL;

.read "TableGenerateSQL.sql"
.read "AllPathsSQL.sql"





/*

CREATE TABLE ALLPathsReport AS
	SELECT ToplvlNo,Cust,TopLvlMtrl,BOMdepth,
		'''('||REPLACE(REPLACE(MTRLpath,'(',''),')','')||')' AS MTRLpath,
		'''('||REPLACE(REPLACE(DESCpath,'(',''),')','')||')'AS DESCpath,
--		SUBSTR(DESCpath,4,15)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)/3,8)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)-15,15) AS ShortDESCpath,
		ComponentMtrl,
		CombinedUnitUsage,PathUnit,
		AltBOM,
		'''('||REPLACE(REPLACE(BOMpath,'(',''),')','')||')' AS BOMpath,
		BOMitem,BOMstatus
	FROM _01Paths UNION ALL
	SELECT ToplvlNo,Cust,TopLvlMtrl,BOMdepth,
		'''('||REPLACE(REPLACE(MTRLpath,'(',''),')','')||')' AS MTRLpath,
		'''('||REPLACE(REPLACE(DESCpath,'(',''),')','')||')'AS DESCpath,
--		SUBSTR(DESCpath,4,15)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)/3,8)||'.'||SUBSTR(DESCpath,LENGTH(DESCpath)-15,15) AS ShortDESCpath,
		ComponentMtrl,
		CombinedUnitUsage,PathUnit,
		AltBOM,
		'''('||REPLACE(REPLACE(BOMpath,'(',''),')','')||')' AS BOMpath,
		BOMitem,BOMstatus
	FROM _02Paths;



.headers on
.once "ConversionPathsBOM.txt"
SELECT * FROM FocusCustAllPathsGrps;

	
==END=BODY==============================================================

CREATE VIEW IF NOT EXISTS EqUnitCheck AS
	SELECT DISTINCT EqHandlerUnit FROM FocusCustAllPathsGrps
	WHERE
		SUBSTR(EqHandlerUnit,1,3) IS NOT SUBSTR(EqHandlerUnit,5,3)
		 AND EqHandlerUnit IS NOT '1';

*/
