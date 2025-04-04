-- -*- mode: sql; sql-product: sqlite; -*-

/*
Authored by David Harris 2025-03-14
wrangler for SAP extraction process using spooler


remove all non-ascii chars before processing any SAP output with SQlite.
--------------------------------
::in Notepad++::
Ctrl+F   [^a-zA-Z0–9#-_\s]   replace with '#'

::in emacs::
;; (replace-regexp-in-region "[^a-zA-Z0–9#-_\s]" "#")


  in shell
--------------

::To open in Notepad++::
> cd ~/RM06analyst/InvDash2.0/code/

::To Run::
> cd ~/RM06analyst/InvDash2.0/code/
> sqlite3 new_.db ".read wrangle02_spooler.sql"

::To View::
> DBbrowser ../UnprocessedData/rawdata_20250314/new_.db &




*/




-- Its easier to manage when we have all the charfixed data in the same folder and start there.

.cd "d:/home/RM06analyst/InvDash2.0/charfix-wrangle-data/SAPspool_20250318"


-- Filenames have to be hardcoded for .import steps in SQLite3.
-- I'm thinking an eLisp script to handle this by either changing the actual
-- filenames or the filename references in the SQL. We Need the chart on SP02
-- to tell us whats what.  


create table SP02import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10);
.mode tabs
.import "charfix-sp02.txt" SP02import

create table if not exists SP02wrangle (spoolNo,wrangleDate,mnemonic);
insert into SP02wrangle
select trim(_2),
trim(_5) ||" "|| trim(_6),
substr(trim(_9),12)
from SP02import
where length(_2) > 0
and trim(_2) not null
and trim(_2) not like '%s%';





-- import into an existing empty table that IDs a name and the fixes the number of columns. Set the mode for tab separated text so it aligns the columns.



-- CREATE  TABLE CM01import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22,_23);
-- .mode tabs
-- .import "./CM01_s.txt" CM01import


-- create table MB51import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22);
-- .mode tabs
-- .import "./MB51_s.txt" MB51import

-- create table MB52import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20,_21,_22);
-- .mode tabs
-- .import "./MB52_s.txt" MB52import



-- create table ZOTIFimport (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10,_11,_12,_13,_14,_15,_16,_17,_18,_19,_20);
-- .separator | "\n"
-- .import "./ZOTIF_spool.txt" ZOTIFimport


create table MDLDimport (_1);
.separator "\01" "\n"
.import "charfix-FP10000094148.TXT" MDLDimport

/*  '\01' is the Start of Header character. Its a good column separator
because its not present anywhere in the source report, thus every line is
just 1 column  */



