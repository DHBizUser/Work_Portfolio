:: controller script for InvDash2.0
:: for Windows cmd
:: Authored by David Harris 2025-03-14


:: this is meant to be a script to automate moving files from the
:: default where SAP dumps its output into a directory structure
:: organized by date.
:: and then pass dated filenames as arguments to the sql & gnuplot scripts

:: When trying to develop this I accidentally overwrote unintended files
:: I'll have do do this file management part manually for now and circle back
:: improving Git workflow would minimize this kind of risk

:: update -- See textprep.el  -- elisp is a reasonable approach.
;; I wanted to minimize complexity of the toolchain by using the shell, but emacs is pretty easy to install on any computer.
;; Most of the text processing is accomplished in SQLite, but removing the unreadable chars has to be done beforehand.
;; This step is critical for data quality.


rem :: Navigate to where SAP puts GUI exports
rem cd C:\Users\harrisdm\Documents\SAP\SAP GUI

rem :: Create a new folder and move new files into it
rem mkdir D:\home\RM06analyst\InvDash2.0\UnprocessedData\rawdata_
rem for %%i in (.) do move "%%i" "%%ni"

rem :: Navigate to the new folder
rem cd D:\home\RM06analyst\InvDash2.0\UnprocessedData\rawdata_
rem pause


