#lang racket/base
(require db
         racket/sequence
         racket/stream
         racket/list
         racket/string
         db/util/datetime
         srfi/19
         )

;; create sql connection object
(define sql_server
  (mysql-connect
   #:user ""
   #:database ""
   #:server ""
   #:port 
   #:password ""))

;; #:fetch 1 = lazy
;; #:fetch +inf.0 = entire table 
(define query-->stream
  (lambda (db-conn query)
    (sequence->stream
     (in-query
      db-conn
      query
      #:fetch +inf.0
      ;;#:fetch 1 
      ))))

(define normalize-string-for-TSV-export
  (lambda (row-item)
    (string-normalize-spaces
     (string-trim
      (list->string
       (remove #\tab
               (remove #\newline
                       (string->list row-item))))))))

(define row-item-cleaner
  (lambda (row-item)
    (cond
      ((boolean? row-item)
       row-item)
      ((sql-null? row-item) 
       "NULL")
      ((sql-timestamp? row-item)
       (date->string (sql-datetime->srfi-date row-item) "~1"))
      ((string? row-item)
       (cond
         ((or (string-contains? row-item "\t")
              (string-contains? row-item "\n"))
          (normalize-string-for-TSV-export row-item))
         (else
          (string-normalize-spaces row-item))))      
      (else
       row-item))))

(define print-table-row-to-TSV
  (lambda (ls port)
    (cond
      ((null? ls)       
       (fprintf port "~c" #\newline)
       (void))      
      ((null? (cdr ls))
       (fprintf port "~a" (row-item-cleaner (car ls)))
       (print-table-row-to-TSV (cdr ls) port))
      (else
       (fprintf port "~a~c" (row-item-cleaner (car ls)) #\tab)
       (print-table-row-to-TSV (cdr ls) port)))))

(define process-stream-to-TSV
  (lambda (stream port)
    (cond
      ((stream-empty? stream)
       (void))
      (else
       (begin
         (print-table-row-to-TSV (call-with-values (lambda () (stream-first stream)) list) port)
         (process-stream-to-TSV (stream-rest stream) port))))))


(define get-table-col-names-from-table-list
  (lambda (db-conn tbl-names/ls els)
    (cond
      ((null? tbl-names/ls)
       (flatten els))
      (else
       (get-table-col-names-from-table-list
        db-conn
        (cdr tbl-names/ls)
        (reverse (cons (map (lambda (x) (vector-ref x 0))
                            (query-rows db-conn (string-append "DESCRIBE " (car tbl-names/ls)))) els)))))))


(define export-query-result-to-TSV/with-table-names
  (lambda (db-conn tbl-names/ls query)
    (let* ((tbl-col-names (get-table-col-names-from-table-list db-conn tbl-names/ls '()))
           (output-file (open-output-file
                         (format
                          (find-system-path 'home-dir)                          
                          (string-join tbl-names/ls "_join_")
                          ) #:exists 'replace))  
           (stream (query-->stream db-conn query)))
      (begin
        (print-table-row-to-TSV tbl-col-names output-file)
        (process-stream-to-TSV stream output-file)
        (close-output-port output-file)))))

;;(export-query-result-to-TSV/with-table-names sql_server '("<table1>" "<table2>") "<query>;")

