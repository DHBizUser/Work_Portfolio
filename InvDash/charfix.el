;; Fri Mar 14 08:22:52 2025 -- chugg portable --

;; started with
;; http://xahlee.info/emacs/emacs/elisp_open_read_write_file.html


;; writes the charfixed file to the specified directory

;; ---from shell---
;; D:/WinApps/Emacs/emacs-29.4/bin/emacs.exe --script charfix.el


;; (let ()



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
  "charfix all files in a directory to the specified directory"
  (mapc (lambda (x) (charfix-file x oDir)) (directory-files rDir t directory-files-no-dot-files-regexp))
  (with-temp-buffer (insert "these files got charfixed -- charfix is authored by David Harris\nIf you re-run charfix on a folder that already had a manifest, you will see charfix-manfest.txt itself show up in this manifest.\nThis is fine and it doesnt really matter if that's there or not, its just helpful to understand.\n\n"
(mapconcat (lambda (x) (print x)) (directory-files oDir nil directory-files-no-dot-files-regexp) "\n"))
  (write-region (point-min) (point-max) (file-name-concat oDir "charfix-manifest.txt"))))
 


;;(defun dated-dir-init (SAPdumpDir oDir)
;;  "create the folder to invoke charfix-folder on and copy the raw SAP spool into it."
;;)



;; (charfix-folder

;; ;; rDir -- full directory path of the raw input folder
 
;;  "D:/home/RM06analyst/InvDash2.0/UnprocessedData/SAPspool_20250319"

;; ;; "/media/chuggboarder/CHUGG/home/RM06analyst/InvDash2.0/UnprocessedData/SAPspool_20250317_TEST01"

 
;;  ;; oDir -- the output directory

;;  "D:/home/RM06analyst/InvDash2.0/charfix-wrangle-data/SAPspool_20250319")

;; ;; "/media/chuggboarder/CHUGG/home/RM06analyst/InvDash2.0/charfix-wrangle-data/SAPspool_20250317"






;;  )


