
;; -*- lexical-binding: t; -*-
;; Tue Apr 29 08:57:01 2025 -- chugg portable --
;; Authored by David Harris

;; A program to handle text pre-processing out of SAP and put it through sqlite3 CLI

;; should be icing for the sqlite3 CLI cake, not too deeply embedded using database functions
;; see:  (info "(elisp)database")   <-- I prefer calling the CLI through a shell over using those elisp functions
;; SQL is a more widely used lang than emacs lisp. The CLI allows the SQL parts to stand on their own.

;; Copilot prompt: 
;; write an emacs lisp function that replaces the values in a plist with the values in a new plist
;; ------------------------------------------------------

(defun replace-plist-values (original-plist new-plist)
  "Replace the values in ORIGINAL-PLIST with values from NEW-PLIST for matching keys."
  (let ((updated-plist original-plist))
    (while new-plist
      (let ((key (car new-plist))
            (value (cadr new-plist)))
        (setq updated-plist (plist-put updated-plist key value))
        (setq new-plist (cddr new-plist))))
    updated-plist))

;; ------------------------------------------------------

(defun my-environment-setup (default-tag specific-tag)
  "return a plist that represents the specifics of current working environment set atop a default."
  (replace-plist-values
   (cdr (assoc default-tag environment-alist))   
    (cdr (assoc specific-tag environment-alist))))


(defun charfix-file (rPath oDir)
  "replace all the non-ASCII characters that cause problems in SQLite. writes the charfixed
   input file to the specified directory"
  (let (
	(fileChanged-p nil)
	(oPath (file-name-concat oDir (concat "charfix-" (file-name-nondirectory rPath)))))
    (with-temp-buffer
      (insert-file-contents rPath)      
  (mark-whole-buffer)

  ;; All chars except a-z lower and upper case, digit 0-9,
  ;; the range of characters hash through underscore, which are all ASCII,
  ;; spaces, newline, tab, and pipe symbol. Replace with hash.
  
  (replace-regexp-in-region "[^a-zA-Z0–9#-_\s\n\t|]" "#")
  (goto-char (point-min))
  (insert (concat "charfix-" (file-name-nondirectory rPath) "  -- problem chars replaced with # -- charfix is authored by David Harris\n"))
  (setq fileChanged-p t)
  (make-directory oDir :parents)
  (when fileChanged-p (write-region (point-min) (point-max) oPath)))))

	       
(defun charfix-folder (rDir oDir)
  "charfix all files in a specified directory and print a manifest of all the files"
  (mapc (lambda (x) (charfix-file x oDir)) (directory-files rDir t directory-files-no-dot-files-regexp))
  (with-temp-buffer (insert "these files got charfixed -- charfix is authored by David Harris\nIf you re-run charfix on a folder that already had a manifest, you will see charfix-manfest.txt itself show up in this manifest.\nThis is fine and it doesnt really matter if that's there or not, its just helpful to understand.\n\n"
(mapconcat (lambda (x) (print x)) (directory-files oDir nil directory-files-no-dot-files-regexp) "\n"))
  (write-region (point-min) (point-max) (file-name-concat oDir "charfix-manifest.txt"))))


(defun get-string-from-file (filePath)
  "Return file content as string."
  (with-temp-buffer
    (insert-file-contents filePath)
    (buffer-string)))




;; -------NEED TO FIX--------------

;; (defun script-template-replacer (replacer-plist template-file output-file)
;;   "replace the placeholder texts in template-file with correspondant string literals defined in replacer-plist and write to output-file"
;;   (with-temp-buffer
;;     (setq x 0)
;;       (insert-file-contents template-file)
;;       (goto-char (point-min)) 
;; (while (<= x (length replacer-plist))
;;   ((re-search-forward (nth x replacer-plist))
;;   (replace-match (plist-get replacer-plist (nth x replacer-plist)))
;;         (goto-char (point-min))
;; (setq x (+ x 2))))
;; (write-region (point-min) (point-max) output-file)))



;; -------NEED TO FIX--------------

;; (defun script-template-replacer (replacer-plist template-file output-file)
;;   "replace the placeholder texts in template-file with correspondant string literals defined in replacer-plist and write to output-file"
;;   (with-temp-buffer
  
;;       (insert-file-contents template-file)
;;       (goto-char (point-min)) 

;;   (while (re-search-forward (nth 0 replacer-plist))
;;   (replace-match (plist-get replacer-plist (nth 0 replacer-plist)))
;;         (goto-char (point-min))


;;   (while (re-search-forward (nth 2 replacer-plist))
;;   (replace-match (plist-get replacer-plist (nth 2 replacer-plist)))
;;         (goto-char (point-min))

	
;; 	(write-region (point-min) (point-max) output-file))
;;   )))









(defun cli-sqlite-file-runner (DB-file sql-file)
"runs sql-file through the sqlite3 cli on DB-file"
(async-shell-command
 (concat "\"" sqlite3 "\" -batch \"" DB-file "\" \".read \\\"" sql-file "\\\"\"")))

(defun open-in-sqlite-browser (DB-file)
  "opens the DB-file in the sqlite browser graphical interface"
  (async-shell-command
   (concat "\"" sqlite-browser "\" \"" DB-file "\"")))


(defun cli-sqlite-import-col-string (columns)
  "makes a string (_1,_2,_3,...); to use in a create statement for an import table when using the .import function on the sqlite3 cli."
(concat " (" (mapconcat 'identity
(mapcar (lambda (n) (format "_%d" n)) (number-sequence 1 columns)) ",") ");"))





(defun SAP-paste-to-SQL ()
"changes pasted text from SAP into SQL insert statement"
(replace-string "\t" ",")
(string-insert-rectangle (+ 2 (point)) (point-max) "(")
(move-end-of-line-2)
(string-insert-rectangle (point) (point-max) "),"))




;; the cdr of each association in the alist is a valid plist

(setq environment-alist
     '(("David Harris work laptop local"
	:operating-system "Windows"
	:storage-drive "c:"
	:home-dir "c:/Users/xxx"
	:sharedrive "s:/xxx"
	:sqlite3 "C:/Users/xxx/SQLite ODBC Driver for Win64/sqlite3.exe"
	:sqlitebrowser "C:/Users/xxx/DB Browser for SQLite/DB Browser for SQLite.exe"
	:SAP "C:/Program Files (x86)/SAP/FrontEnd/SapGui/saplogon.exe")

       ("work laptop chugg-portable"
	:operating-system "Windows"
	:storage-drive "d:"
	:home-dir "d:/home"
	:sharedrive "s:/xxx"
	:sqlite3 "d:/WinApps/SQLite_ODBC_Driver_Win64/sqlite3.exe"

	:sqlitebrowser "d:/WinApps/DB_Browser_SQLite/DB_Browser_SQLite.exe")

       ("chuggpad"
	:operating-system "Linux"
	:storage-drive "/media/chuggboarder/CHUGG"    ;this is chugg-portable, same SD card thats usually "d:" on Windows
	:home-dir "~"
	:sqlite3 "sqlite3"
	:sqlitebrowser "sqlitebrowser")))


;; environment property list
;; -------------------------
;; 1st arg is the default environment (work laptop).
;; 2nd arg is whatever less-permanent current environment whose attributes I want to overtake the default (portable storage, SharedDrive, or other computer). 
;; 
;; This provides a degree of portability while keeping development focused toward the normative default.  Goal is to port this to the SharedDrive at work and to potentially train coworkers to install and run on their machine(s).

;; (setq environment-plist (my-environment-setup "David Harris work laptop local" "work laptop chugg-portable"))


(setq environment-plist
      (my-environment-setup "David Harris work laptop local" "David Harris work laptop local"))


(setq sqlite3 (plist-get environment-plist :sqlite3)
      sqlite-browser (plist-get environment-plist :sqlitebrowser))



(setq project-repo "xxx/Comp-stock-RunOut/"
      wrangle-repo "xxx/SAPdata/")

   
(setq SAPspool-folder (file-name-concat (plist-get environment-plist :sharedrive) wrangle-repo "UnprocessedData/SAPspool_20250624")
      charfixed-folder (file-name-concat (plist-get environment-plist :sharedrive) wrangle-repo "Charfixdata/SAPspool_20250624"))
      


(setq project-DB (file-name-concat (plist-get environment-plist :sharedrive) project-repo "mrp-stock.db")

      project-sql (file-name-concat (plist-get environment-plist :sharedrive) project-repo "comp-stk-runout.sql"))









;; (charfix-folder SAPspool-folder charfixed-folder) 



;; (cli-sqlite-file-runner project-DB project-sql)


;; (open-in-sqlite-browser project-DB)
 
