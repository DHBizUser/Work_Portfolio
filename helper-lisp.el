;; Thu Jun 26 19:52:19 2025 -- chuggpup --
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



;(mkdir "~/Projects/Work_Portfolio")


(cd "~/Projects/Work_Portfolio")

(pwd)



(shell-command "git clone git@github.com:DHBizUser/Work_Portfolio.git")

(shell-command "git remote -v")

(shell-command "git status")

(shell-command "git restore --staged .")

(shell-command "git commit -m \"CVadjust, gitignore\"")

(shell-command "git push origin")

(shell-command "git add .")


(shell-command "git config --local user.name DHBizUser")
(shell-command "git config --local user.email davidh804408@gmail.com")

(shell-command "git commit --amend --reset-author -m \"fix author\"")



(browse-url "https://github.com/DHBizUser/Work_Portfolio")


(shell-command "git rm --cached ResumeCV/DHBizUser_resume.aux")



;; -- 🗎pdflatex on the CV --

(cd "~/Projects/Work_Portfolio/ResumeCV")
(shell-command "pdflatex t_BAresume.tex")

(shell-command "pdflatex DHBizUser_resume.tex")

(pwd) "Directory /home/chuggboarder/Projects/Work_Portfolio/ResumeCV/"

(browse-url "file:///home/chuggboarder/Projects/Work_Portfolio/ResumeCV/DHBizUser_resume.pdf")
