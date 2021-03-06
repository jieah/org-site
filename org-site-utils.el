;;; org-site-utils.el --- various utils for org-site
;; Copyright (C) 2006-2013 Free Software Foundation, Inc.

;; Author: Xiao Hanyu <xiaohanyu1988 AT gmail DOT com>
;; Keywords: org-mode, site-generator
;; Version: 0.01

;; This file is not part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;; This file contains various utility functions for org-site:
;; 1. project create and load functions
;; 2. template loader and render functions, inspired by Django
;; 3. preamble/footer/postamble generators


(require 'ht)
(require 'mustache)
(require 'with-namespace)

(require 'org-site-vars)

(defun file-to-string (file)
  "Return the file contents as a string"
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun mustache-file-render (file context)
  "Read the file contents, then render it with a hashtable context

Actually, this function is a shortcut function inspired by Django's
render_to_response."
  (mustache-render (file-to-string file) context))

(with-namespace "org-site"
  (defun new-project (&optional project-directory)
    "Create a new org-site project.

This function just build a basic directory structure and copy a necessary
org-site configuration file to the project's directory"
    (interactive "GProject directory: ")
    (unless project-directory
      (setq project-directory default-directory))
    (unless (file-exists-p project-directory)
      (make-directory project-directory))
    (setq old-default-directory default-directory)
    (unwind-protect
        (progn
          (cd project-directory)
          (make-directory "post")
          (make-directory "wiki")
          (copy-file (expand-file-name "org-site-config.el"
                                       org-site-load-directory)
                     project-directory)
          (org-site-new-org-file
           (expand-file-name "index.org"
                             project-directory)
           nil)
          (org-site-new-org-file
           (expand-file-name "about.org"
                             project-directory)
           nil)
          (org-site-new-org-file
           (expand-file-name "post/post1.org"
                             project-directory)
           nil)
          (org-site-new-org-file
           (expand-file-name "wiki/wiki1.org"
                             project-directory)
           nil)
      (cd old-default-directory))))

  (defun load-project (&optional project-directory)
    "Load the project settings and make org-site know its current project."
    (interactive
     (list (read-directory-name "Project directory: " org-site-project-directory)))
    (unless project-directory
      (setq project-directory default-directory))
    (setq old-default-directory default-directory)
    (unwind-protect
        (progn
          (cd project-directory)
          (load-file "org-site-config.el"))
      (cd old-default-directory))
    (setq org-site-project-directory project-directory))

  (defun load-template (theme template)
    (expand-file-name
     (format "template/%s/%s" theme template)
     (or org-site-load-directory default-directory)))

  (defun get-static-dir ()
    (file-name-as-directory
     (expand-file-name "static"
                       org-site-load-directory)))

  (defun get-org-file-title (org-file)
    "Get org file title based on contents or filename.

Org-mode has a `org-publish-find-title` function, but this function has some
minor problems with `org-publish-cache`."
    (with-temp-buffer
      (insert-file-contents org-file)
      (setq opt-plist (org-infile-export-plist))
      (or (plist-get opt-plist :title)
          (file-name-sans-extension
           (file-name-nondirectory filename)))))

  (defun new-org-file (org-file &optional view-org-file)
    "Find a new org-file and insert some basic org options.

if `view-org-file` is non-nil, switch to that buffer, else, kill that buffer."
    (if (file-exists-p org-file)
        (error "File already exists, please type a new file."))
    (let ((buffer (find-file-noselect org-file)))
      (set-buffer buffer)
      (org-insert-export-options-template)
      (save-buffer)
      (if view-org-file
          (switch-to-buffer buffer)
        (kill-buffer buffer))))

  (defun new-post (org-file)
    (interactive
     (list (read-file-name
            "file name: "
            (file-name-as-directory
             (expand-file-name "post"
                               org-site-project-directory)))))
    (new-org-file org-file))

  (defun new-wiki (org-file)
    (interactive
     (list (read-file-name
            "file name: "
            (file-name-as-directory
             (expand-file-name "wiki"
                               org-site-project-directory)))))
    (new-org-file org-file))

  (defun render (template context)
    (mustache-file-render
     (org-site-load-template org-site-theme template)
     context))

  (defun generate-preamble ()
    (let ((context
           (ht-from-plist
            `("site-title" ,org-site-title
              "nav-post" "post/"
              "nav-wiki" "wiki/"
              "nav-tags" "tags/"
              "nav-about" "about.html"))))
      (org-site-render "preamble.html" context)))

  (defun generate-comment ()
    (let ((context
           (ht-from-plist
            `("disqus-identifier" ,org-site-disqus-identifier
              "disqus-url" ,org-site-disqus-url
              "disqus-shortname" ,org-site-disqus-shortname))))
      (org-site-render "comment.html" context)))

  (defun generate-meta-info ()
    (let ((context
           (ht-from-plist
            `("post-date" "post-date"
              "update-date" "update-date"
              "tags" "tags"
              "author-name" ,org-site-author-name))))
      (org-site-render "meta-info.html" context)))

  (defun generate-footer ()
    (let ((context
           (ht-from-plist
            `("author-email" ,org-site-author-email
              "author-name" ,org-site-author-name))))
      (org-site-render "footer.html" context)))

  (defun generate-postamble ()
    (let ((context
           (ht-from-plist
            `("footer" ,(org-site-generate-footer)))))
      (if org-site-enable-meta-info
          (ht-set context
                  "meta-info"
                  (org-site-generate-meta-info)))
      (if org-site-enable-comment
          (ht-set context
                  "comment"
                  (org-site-generate-comment)))
      (org-site-render "postamble.html" context))))

(provide 'org-site-utils)
