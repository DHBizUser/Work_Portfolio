PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE localtimeParms(
DSTstart,
DSTend,
UTCoffset_standard,
UTCoffset_DST
);
INSERT INTO localtimeParms VALUES('2025-03-09 06:59:59','2025-11-02 05:59:59','+5 hours','+4 hours');
CREATE TABLE environment(
ReportDate,
OS,
hardwarePath,
dependencyPath,
folderPath,
repo
);
INSERT INTO environment VALUES('2025-03-31','linux','/media/chuggboarder/CHUGG',NULL,'home/RM06analyst','InvDash2.0');
CREATE TABLE wrangleparms(
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
INSERT INTO wrangleparms VALUES('emacs','sqlite3','sqlite_browser','2025-03-23 00:00:00','2025-03-31 23:59:59','/media/chuggboarder/CHUGG/home/RM06analyst/InvDash2.0/UnprocessedData','/media/chuggboarder/CHUGG/home/RM06analyst/InvDash2.0/ProcessedDB','/media/chuggboarder/CHUGG/home/RM06analyst/InvDash2.0/code','SAPspool_20250331');
COMMIT;
