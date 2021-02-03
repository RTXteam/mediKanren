#lang racket
(provide (all-defined-out))
(require json net/url)

(define (js-count js)
  (cond ((pair? js) (foldl + 0 (map js-count js)))
        ((hash? js) (foldl + 0 (hash-map js (lambda (k v) (js-count v)))))
        (else       1)))

;; Broad Institute KP
(define url.broad
  "https://translator.broadinstitute.org/molepro_reasoner")

;; Broad Institute KP specific for CHEMBL queries
(define url.broad_chembl
  "https://translator.broadinstitute.org/chembl")

(define chembl-drug-indications/transform
  "/indications/transform")

(define url.unsecret
  "https://unsecret.ncats.io")
(define path.predicates
  "/predicates")
(define path.query
  "/query")

(define (api-query url-string (optional-post-jsexpr (void)))
  (define-values (status headers in)
    (time (if (void? optional-post-jsexpr)
            (http-sendrecv/url
              (string->url url-string)
              #:method "GET")
            (http-sendrecv/url
              (string->url url-string)
              #:method "POST"
              #:data (jsexpr->string optional-post-jsexpr)
              #:headers '("Content-Type: application/json; charset=utf-8")))))
  (define response-string (time (port->string in)))
  (displayln (string-length response-string))
  (pretty-print headers)
  (hash 'status status
        'headers headers
        'response (string->jsexpr response-string)))

(define (js-query edges nodes)
  (hash 'message
        (hash 'query_graph
              (hash 'edges edges
                    'nodes nodes))))


#|
;; {} = hash                            ;
;; [] = list                            ;
;; key:value                            ;
                                        ;
QUERY/TRANSFORM QUERY STRUCTURE         ;
------------------------------

query = {
    'collection': [{
            'id':'',
            'identifiers': {'chembl':'ChEMBL:CHEMBL25'}
        }],
    'controls':[]
}
|#


(module+ main
  ;; test predicates available on Broad Institute KG
 #;(pretty-print
   (api-query (string-append url.broad path.predicates)))

  #;

(pretty-print
     (api-query (string-append url.broad path.query)
              (js-query (list (hash 'id        "e00"
                                    'source_id "n00"
                                    'target_id "n01"
                                    'type      "affects"))
                        (list (hash 'curie "CID:2244"
                                    'id    "n00"
                                    'type  "chemical_substance")
                              (hash 'id    "n01"
                                    'type  "gene")))))

  #;(js-count
    (time (api-query (string-append url.unsecret path.predicates))))

  #;(pretty-print
    (time
      (api-query (string-append url.unsecret path.query)
                (js-query (list (hash 'id        "e00"
                                       'source_id "n00"
                                       'target_id "n01"
                                       'type      "causes"))
                           (list (hash 'curie "UMLS:C0004096"
                                       'id    "n01"
                                       'type  "disease")
                                 (hash 'id    "n00"
                                       'type  "gene"))))))

  #;(pretty-print
    (time
       (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "causes"))
                            (list (hash 'curie "UMLS:C0004096"
                                        'id    "n01"
                                        'type  "disease")
                                  (hash 'id    "n00"
                                        'type  "gene"))))))
  
  #;(pretty-print
    (time (api-query (string-append url.unsecret path.query)
                     (js-query (list (hash 'id        "e00"
                                           'source_id "n00"
                                           'target_id "n01"
                                           'type      "affects"))
                               (list (hash 'curie "CID:2244"
                                           'id    "n00"
                                           'type  "chemical_substance")
                                     (hash 'id    "n01"
                                           'type  "gene"))))))

  ;;MOLEPRO drug --treats--> disease query w/ NO EVIDENCE
(pretty-print
 (time (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "treats"))
                            (list (hash 'curie "ChEMBL:CHEMBL25"
                                        'id    "n00"
                                        'type  "chemical_substance")
                                  (hash 'id    "n01"
                                        'type  "disease"))))))


;; addition provenance/evidence for drug indication query
(pretty-print
 (time
  (api-query
   (string-append (string-append url.broad_chembl chembl-drug-indications/transform))
   (js-query/transform
    "ChEMBL:CHEMBL25"))))


;; STRING gene->gene edge
(pretty-print
 (time (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "related_to"))
                            (list (hash 'curie "HGNC:4556"
                                        'id    "n00"
                                        'type  "gene")
                                  (hash 'id    "n01"
                                        'type  "gene"))))))

;; CMAP gene-to-compound query
(pretty-print
 (time (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "correlated_with"))
                            (list (hash 'curie "HGNC:4556"
                                        'id    "n00"
                                        'type  "gene")
                                  (hash 'id    "n01"
                                        'type  "chemical_substance"))))))

;; CMAP gene-to-gene query 
(pretty-print
 (time (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "correlated_with"))
                            (list (hash 'curie "HGNC:4556"
                                        'id    "n00"
                                        'type  "gene")
                                  (hash 'id    "n01"
                                        'type  "gene"))))))


)



#|
all breast cancer curies currently supported by molepro api for disease--treated_by--> Drug X
Malignant tumor of breast	MONDO:0021100	C0006142	254837009	DOID:1612
Hormone receptor positive malignant neoplasm of breast	UMLS:C1562029	C1562029	417181009	
Secondary malignant neoplasm of female breast	UMLS:C0346993	C0346993	94297009	
HER2-positive carcinoma of breast	MONDO:0006244	C1960398	427685000	
Human epidermal growth factor 2 negative carcinoma of breast	UMLS:C2316304	C2316304	431396003	
Carcinoma of female breast	MONDO:0004379	C3163805	447782002	
Carcinoma of breast	MONDO:0004989	C0678222	254838004	DOID:3459
Metastatic Breast Carcinoma				
Osteolytic Bone Metastases of Breast Cancer				
Advanced Breast Cancer Progression Post-Antiestrogen Therapy				
Metastatic Breast Cancer Progression Post-Antiestrogen Therapy				
Breastfeeding (mother)	UMLS:C1623040	C1623040	413712001	
HER2 Positive Carcinoma of Breast				
Early Breast Cancer Hormone Receptor Positive and Postmenopausal				
Prevention of Breast Carcinoma				
Fibrocystic breast changes	MONDO:0005219	C0016034	27431007	DOID:10354
Infiltrating duct carcinoma of breast	MONDO:0005590	C1134719	408643008	DOID:3008
|#

(pretty-print
 (time (api-query (string-append url.broad path.query)
                  (js-query (list (hash 'id        "e00"
                                        'source_id "n00"
                                        'target_id "n01"
                                        'type      "treated_by"))
                            (list (hash 'curie "MONDO:0021100"
                                        'id    "n00"
                                        'type  "disease")
                                  (hash 'id    "n01"
                                        'type  "chemical_substance"))))))


#| QUERY for presentation |#
(define (js-query/transform curie-prefix/lower-case curie)
  (hash 'collection
        (list
         (hash
          'id ""
          'identifiers
          (hash
           curie-prefix/lower-case curie)))     
        'controls '()))

#;(pretty-print
 (time
  (api-query
   (string-append (string-append url.broad_chembl chembl-drug-indications/transform))
   (js-query/transform
    'chembl
    "ChEMBL:CHEMBL25"))))

#|NOTES FOR SEPTEMBER 2020 RELAY API CALLS|#

#|
1. all "NO-evidence/provenance" queries are to the base broad.url
"https://translator.broadinstitute.org/molepro_reasoner

2. all "LIMITED evidence/provenance" queries are to the chembl url
"https://translator.broadinstitute.org/chembl"
|#


