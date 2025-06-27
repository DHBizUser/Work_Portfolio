;; notes on my github workflow as it develops.
;; I execute these from an emacs buffer, so as long as the system im accessing has Git & Emacs
;; and I can get to my github portfolio to clone it -- I can work off this file.
;; would also require a Latex engine to compile a PDF copy of my resume.


;; 🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥🥥



;; Thu Jun 26 19:52:19 2025 --
;; S-<insert>   ~/setxkbmap-setter
;; toggles the keyboard
;; this is the custom layout on CapsLock and the bottom row
;; ------                                             ------
;; Meta                                               Return
;; ------            {Programmer Dvorak}              ------
;; Shift                                               Shift
;; ---------------------------------------------------------
;; Hyper - Super - Ctrl - Space - Ctrl - Meta - Menu - Hyper
;; ---------------------------------------------------------

;; radio:
;; H-r 1  ~/🚀synthwavecityFM-radio
;; H-r 2  ~/🍄psybient-radio
;; H-r 3  ~/🖭NewRetroWave


;; C-x 5 2    opens another emacs frame, or C-<F1> using the desktop
;; s-<end>  to save-buffers-kill-emacs

;; This buffer is for text that is not saved, and for Lisp evaluation.
;; To create a file, visit it with C-x C-f and enter text in its buffer.



;; -- these are   🥥chuggpad🥥    linux 🐧 paths

;(mkdir "~/Projects/Work_Portfolio")

(cd "~/Projects/Work_Portfolio")



;; -- these are   🪟 Windows   paths   🥥chuggportable


(cd "~/Work_Portfolio")    ; "e:/home/Work_Portfolio/"

(pwd)


;; the SSH "remote" works on Linux; HTTP "remote" works on both Win and Linux. For reasons specific to my system(s)
;; I call the remote "origin" from either local.

(shell-command "git remote rename HTTPportfolio origin")



(shell-command "git clone git@github.com:DHBizUser/Work_Portfolio.git")

(shell-command "git remote -v")


(shell-command "git status")

(shell-command "git restore --staged .")

(shell-command "git commit -m \"CV\"")

(shell-command "git push origin")

(shell-command "git add .")


(shell-command "git config --local user.name DHBizUser")
(shell-command "git config --local user.email dav******@gmail.com")   ;contact me through Linkedin please

(shell-command "git commit --amend --reset-author -m \"fix author\"")



(browse-url "https://github.com/DHBizUser/Work_Portfolio")


(shell-command "git rm --cached ResumeCV/DHBizUser_resume.aux")



;; -- 🗎pdflatex on the CV --

(cd "ResumeCV")

(shell-command "pdflatex t_BusinessAnalyst.tex")

(shell-command "pdflatex DHBizUser_resume.tex")



;; -- these are   🥥chuggpad🥥    linux 🐧 paths

(pwd) "Directory /home/chuggboarder/Projects/Work_Portfolio/ResumeCV/"

(browse-url "file:///home/chuggboarder/Projects/Work_Portfolio/ResumeCV/DHBizUser_resume.pdf")
