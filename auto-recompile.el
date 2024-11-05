;;; auto-recompile.el - compile while you think
;;
;; $Id: auto-recompile.el,v 1.5 2012-03-04 07:06:50 hubbe Exp $
;;
;; Copyright (C) 2005 Fredrik Hubinette <hubbe@hubbe.net>
;;
;;    This program is free software; you can redistribute it and/or modify
;;    it under the terms of the GNU General Public License as published by
;;    the Free Software Foundation; either version 2 of the License, or
;;    (at your option) any later version.
;;
;;    This program is distributed in the hope that it will be useful,
;;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;    GNU General Public License for more details.
;;
;;    You should have received a copy of the GNU General Public License
;;    along with this program; if not, write to the Free Software
;;    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
;;
;;; Commentary: 
;;
;; If you have any questions, suggestions or bugreports, pleas go to
;; the online forum:  http://fredrik.hubbe.net/hacker/
;;
;; Usage:
;;   M-x auto-recompile will toggle auto-recompile on and off.
;; 
;; When auto-recompile is active, your emacs will do some extra things:
;;
;; When you save a file, emacs will start a new compilation with the same
;; parameters as the last call to M-x compile. Any active previous compilation
;; will be killed, but it's buffer will remain so that you can still work
;; on any compilation errors in that buffer. Each new compilation will live
;; in it's own buffer.
;;
;; When you hit C-x ` to go to the next error, emacs will search all compilation
;; buffers, starting with the newest one until it finds one that has an error.
;; When it finds a buffer with an error, older compilation buffers will be
;; killed automatically as any error in those buffers aren't interesting anymore.
;;
;; If no error is found, emacs will show you the end of thelast compilation buffer.
;; This will tell you if the current compilation is still active, or if it
;; completed successfully.
;;
;; When using C-`, emacs will automatically save ALL buffers if the next error
;; is in a different buffer than the last one. This will automatically start a
;; new compilation.
;;
;; So, what does all this mean?
;; It means that after starting a compile with M-x compile, all you need to do
;; is to use C-x ` to go from error to error and fix them. Emacs will automatically
;; save and recompile as you work your way through the files. Occationally you may
;; want to save file explicitly, but it should not be needed.
;;
;; WARNING
;; auto-recompile mode can be dangerous. It will kill compilations without warning,
;; and it will save ALL buffers in your emacs without asking. To turn off the 
;; automatic saving of buffers, set auto-recompile-save to nil.
;;
;;; Code:

(defvar auto-recompile-mode 'nil)
(defvar auto-recompile-current 0)
(defvar auto-recompile-buffer-list 'nil)
(defvar auto-recompile-start-time 'nil)
(defvar auto-reocmpile-use-atime 'nil)
(defvar auto-recompile-last-error-buffer 'nil)
(defvar auto-recompile-save 't)
(defvar auto-recompile-debug 't)

(defun auto-recompile-debug-message (msg)
  (if auto-recompile-debug
      (message msg)))

(defun auto-recompile-name-function (mode)
  (setq auto-recompile-current (+ auto-recompile-current 1))
  (format "*auto-recompile-%d*" auto-recompile-current))

(defun auto-recompile-successful (buffer)
  (and buffer
       (buffer-live-p buffer)
       (let ((proc (get-buffer-process buffer)))
         (and proc
              (eq (process-status proc) 'exit)
              (eq (process-exit-status proc) 0)))))

(defun auto-recompile-has-error (buffer)
  (and (and buffer
            (buffer-live-p buffer))
       (let ((pt nil)
             (end nil)
             (msg nil)
             (result nil))
         (save-excursion
           (set-buffer buffer)
           (setq pt (or compilation-current-error
                        compilation-messages-start
                        (point-min)))
           (setq end (point-max))
           (setq pt (next-single-property-change pt 'message buffer))
           (while (and pt
                       (< pt end))
             (setq msg (get-text-property pt 'message buffer))
             (if (and msg
                      (>= (cadr msg) compilation-skip-threshold))
                 (setq result (cadr msg)
                       pt
                       end))
             (setq pt (next-single-property-change pt 'message buffer))))
         result)))

(defun auto-recompile-is-active (buffer)
  (and buffer
       (buffer-live-p buffer)
       (get-buffer-process buffer)
       (eq (process-status (get-buffer-process buffer)) 'run)))


(defun auto-recompile-find-most-current-error ()
  (let ((b auto-recompile-buffer-list))
    ;; walk the list and find most current compilation buffer
    ;; which has an error in it.
    (while (and b
                (not (auto-recompile-has-error (car b))))
      (setq b (cdr b)))
    (if b
        ;; Cleanup old buffers here
        (let ((q b))
          (while q
            (while (and (cdr q)
                        (auto-recompile-kill-compilation (cadr q)))
              (setcdr q
                      (cddr q)))
            (setq q (cdr q)))
          (car b))
      nil)))

;; Make a variable to control this behaviour
(defun auto-recompile-save-buffers ()
  (if auto-recompile-save
      (progn
        (message "Saving buffers (and starting new compilation if needed.)")
        (save-some-buffers t))))

(defun auto-recompile-next-error (&optional argp)
  (interactive "P")
  (if auto-recompile-mode
                                        ; If the last compilation is done, select it
      (if (and auto-recompile-buffer-list
               (not (auto-recompile-is-active (car auto-recompile-buffer-list)))
               (not (auto-recompile-has-error (car auto-recompile-buffer-list))))
          (progn
            (pop-to-buffer (car auto-recompile-buffer-list))
            (goto-char (point-max)))
        (let ((most-current (auto-recompile-find-most-current-error)))
                                        ; If there are errors in a previous compilation, select it
          (auto-recompile-debug-message (format "auto-recompiles: %S" auto-recompile-buffer-list))
          (auto-recompile-debug-message (format "most current: %S" most-current))
          (if most-current
              (progn
                (pop-to-buffer most-current)
                (setq next-error-last-buffer most-current))
                                        ; If there are no current errors, display the last compilation buffer
                                        ; This will show if the compilation is finished and if it finished
                                        ; sucessfully
            (if auto-recompile-buffer-list
                (progn
                  (if (not (eq (current-buffer) auto-recompile-buffer-list))
                      (auto-recompile-save-buffers))
                  (pop-to-buffer (car auto-recompile-buffer-list))
                  (goto-char (point-max))))))))
  (let ((old_buffer (current-buffer)))
    (next-error argp)
    ;; If we moved to a new buffer, or the last compilation is no longer
    ;; active, save everything and (optionally) start a new compilation.
    (if (and auto-recompile-mode
             (or (not (auto-recompile-is-active (car auto-recompile-buffer-list)))
                 (and (not (eq old_buffer (current-buffer)))
                      (not (eq old_buffer auto-recompile-last-error-buffer)))))
        (auto-recompile-save-buffers))
    (setq auto-recompile-last-error-buffer old_buffer)))

;; Kill a compilation, delete the buffer it if it is no longer needed
;; Return true if the buffer is now dead
(defun auto-recompile-kill-compilation (buffer)
  (if (auto-recompile-is-active buffer)
      (interrupt-process (get-buffer-process buffer)))
  (if (not (equal buffer next-error-last-buffer))
      (progn
        (auto-recompile-debug-message (format "auto-reply, killing: %S" buffer))
        (kill-buffer buffer)))
  (not (buffer-live-p buffer)))

(defun auto-recompile-start-compilation ()
  (if (or (get-buffer "*compilation*")
          next-error-last-buffer)
      (progn
        (set-buffer (or (get-buffer "*compilation*")
                        next-error-last-buffer))
        (let ((thisdir default-directory))
                                        ;(stack compilation-directory-stack))

          ;; Find the directory where the compilation was started
          ;;(while (cdr stack)
          ;;(setq stack (cdr stack)))
          (setq default-directory compilation-directory)
          (compile compile-command)
          (setq auto-recompile-start-time (current-time))
          (setq auto-recompile-last-error-buffer 'nil)
          (setq auto-recompile-buffer-list (cons next-error-last-buffer auto-recompile-buffer-list))
          ;; Set the directory back
          (setq default-directory thisdir)))))


(defun auto-recompile-kill-all ()
  (let ((b auto-recompile-buffer-list))
    (while b
      (auto-recompile-kill-compilation (car b))
      (setq b (cdr b))))
  (auto-recompile-kill-compilation next-error-last-buffer))

(defun auto-recompile-atime (file)
  (car (nthcdr 4
               (file-attributes file))))

(defun auto-recompile-matime (file)
  (car (nthcdr 5
               (file-attributes file))))

(defun auto-recompile-try-update-atime (file)
  (with-temp-buffer
    (insert-file-contents-literally file 'nil
                                    0 1 't)))

;; This shows why I don't like lisp
(defun auto-recompile-time-ge (x y)
  (or (> (car x) (car y))
      (and (= (car x) (car y))
           (>= (cadr x) (cadr y)))))

;; This doesn't work properly
                                        ;(defun auto-recompile-check-atime()
                                        ;  (let ((backup-name (car (find-backup-file-name buffer-file-name)))
                                        ;	(atime (auto-recompile-atime backup-name)))
                                        ;    (if (and auto-recompile-start-time
                                        ;	     (auto-recompile-time-ge auto-recompile-start-time atime))
                                        ;	(progn
                                        ;	  (auto-recompile-try-update-atime backup-name)
                                        ;	  (message (format "Passed first bar %S %S %S %S" auto-recompile-start-time atime (auto-recompile-atime backup-name) (auto-recompile-time-ge atime (auto-recompile-atime backup-name))))
                                        ;	  (not (auto-recompile-time-ge atime (auto-recompile-atime backup-name))))
                                        ;      nil)))

(defun auto-recompile-check-atime ()
  nil)

(defun auto-recompile-save-hook ()
  (if (and auto-recompile-mode
           (or (get-buffer "*compilation*")
               next-error-last-buffer))
      (if (and next-error-last-buffer
               (auto-recompile-is-active next-error-last-buffer)
               (auto-recompile-check-atime))
          (message "No need to recompile.")
        (progn
          (setq next-error-last-buffer (compilation-find-buffer))
          (auto-recompile-kill-all)
          (if (auto-recompile-has-error next-error-last-buffer)
              (let ((saved-comp-buffer next-error-last-buffer))
                (auto-recompile-start-compilation)
                (setq next-error-last-buffer saved-comp-buffer))
            (auto-recompile-start-compilation)))
        (message (format "Auto-compiling into *auto-recompile-%d*"
                         auto-recompile-current)))))

(defun auto-recompile ()
  "Toggles auto-recompile mode on or off."
  (interactive)
  (if auto-recompile-mode
      (progn
        (setq auto-recompile-mode nil)
        (remove-hook 'after-save-hook 'auto-recompile-save-hook)
        (message "Auto-recompile mode is off"))
    (define-key ctl-x-map "`" 'auto-recompile-next-error)
    (setq auto-recompile-mode t)
    (add-hook 'after-save-hook 'auto-recompile-save-hook)
    (message "Auto-recompile mode is on")))

(defun auto-recompile-test-no-error ()
  (compile "sleep 20")
  (let ((buffer (get-buffer "*compilation*")))
    (if (auto-recompile-has-error buffer)
        (signal 'auto-recompile-has-error-false-positive-1
                nil))
    (sleep-for 1)
    (if (auto-recompile-has-error buffer)
        (signal 'auto-recompile-has-error-false-positive-2
                nil))
    (auto-recompile-kill-compilation buffer)))


(defun auto-recompile-test-error ()
  (setenv "COLON" ":")
  (compile "echo /etc/services${COLON}20${COLON} Syntax error;sleep 20")
  (sleep-for 1)
  (let ((buffer (get-buffer "*compilation*")))
    (if (not buffer)
        (signal 'auto-recompile-compilation-buffer-not-found
                nil))
    (if (not (auto-recompile-is-active buffer))
        (signal 'auto-recompile-compilation-buffer-not-active
                nil))
    (if (not (auto-recompile-has-error buffer))
        (signal 'auto-recompile-has-error-false-negative
                nil))
    (next-error 1)
    (if (auto-recompile-has-error buffer)
        (signal 'auto-recompile-has-error-false-positive-after-next-error
                nil))
    (auto-recompile-kill-compilation buffer)))


(defun auto-recompile-test-live-buffer ()
  (compile "echo test")
  (let ((buffer (get-buffer "*compilation*")))
    (sleep-for 1)
    (if (auto-recompile-is-active buffer)
        (signal 'auto-recompile-compilation-buffer-active-when-dead
                nil))
    (auto-recompile-kill-compilation buffer)))


(defun auto-recompile-test ()
  "Unit tests for auto recompile."
  (interactive)
  (auto-recompile-test-no-error)
  (sleep-for 1)
  (auto-recompile-test-error)
  (sleep-for 1)
  (auto-recompile-test-live-buffer)
  "success")

(provide 'auto-recompile)

;; auto-recompile.el has left the building
