#lang racket
(provide (all-defined-out))

#|
name-file.edge.scm
:ID :START :END

ex-row: 1 ENSEMBL:ENSG00000004059 ENSEMBL:ENSP00000000233

name-file.edge-props.scm
:ID propname value

ex-row: 1 edge_label biolink:has_gene_product
  1 provided_by blah
  1
|#

(define directory-path
    "data/sri-reference-kg-0.2.0/")
(define edges-file
    "sri-reference-kg-0.2.0_edges.tsv")
(define export-path directory-path)
(define edges-export-path
  (format "~asri-reference-kg-0.2.0.edge.tsv" export-path))
(define edge-props-export-path
  (format "~asri-reference-kg-0.2.0.edgeprop.tsv" export-path))

(define edges-export-file
  (open-output-file edges-export-path))
(fprintf edges-export-file ":ID\t:START\t:END\n")

(define edge-props-export-file
  (open-output-file edge-props-export-path))
(fprintf edge-props-export-file ":ID\tpropname\tvalue\n")

(define input-edges
  (open-input-file (format "~a~a" directory-path edges-file)))

(let* ((header (read-line input-edges))
       (header (string-split header "\t" #:trim? #f)))
  (let loop ((i 0)
             (line-str (read-line input-edges)))
    (cond
      ((eof-object? line-str)
       (close-input-port input-edges)
       (close-output-port edges-export-file)
       (close-output-port edge-props-export-file))
      (else
        (let ((line (string-split (string-trim line-str "\n" #:left? #f) "\t" #:trim? #f)))
          (match line
            [`(,id ,subject ,edge_label ,object . ,prop*)
             (fprintf edges-export-file "~a\t~a\t~a\n" i subject object)
             (let loop-inner ((props (cons edge_label prop*))
                              (headers (match header
                                         [`(,id ,subject ,edge_label ,object . ,prop*)
                                          (cons edge_label prop*)])))
               (when (not (null? props))
                 (unless (string=? "" (car props))
                   (fprintf edge-props-export-file "~a\t~a\t~s\n" i (car headers) (car props)))
                 (loop-inner (cdr props) (cdr headers))))]))
        (loop
          (+ 1 i)
          (read-line input-edges))))))
