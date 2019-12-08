#lang racket/base
(require
  "common.rkt"
  racket/match
  racket/port
  racket/pretty
  racket/string
  web-server/servlet
  web-server/servlet-env
  web-server/managers/none
  net/url
  xml)

(print-as-expression #f)
(pretty-print-abbreviate-read-macros #f)

(define argv (current-command-line-arguments))
(define argv-optional '#(CONFIG_FILE))

(when (not (<= (vector-length argv) (vector-length argv-optional)))
  (error "optional arguments ~s; given ~s" argv-optional argv))

;; Loading will occur at first use if not explicitly forced like this.
(load-config #t (and (<= 1 (vector-length argv)) (vector-ref argv 0)))
(load-databases #t)

;; TODO:
;;; Query save file settings
(define WRITE_QUERY_RESULTS_TO_FILE            (config-ref 'query-results.write-to-file?))
(define QUERY_RESULTS_FILE_NAME                (config-ref 'query-results.file-name))
(define HUMAN_FRIENDLY_QUERY_RESULTS_FILE_NAME (config-ref 'query-results.file-name-human))
(define SPREADSHEET_FRIENDLY_QUERY_RESULTS_FILE_NAME (config-ref 'query-results.file-name-spreadsheet))
(define QUERY_RESULTS_FILE_MODE                (config-ref 'query-results.file-mode))
;;; Decreases/increases predicate names
(define DECREASES_PREDICATE_NAMES (config-ref 'decreases-predicate-names))
(define INCREASES_PREDICATE_NAMES (config-ref 'increases-predicate-names))

(define (xexpr->html-string xe)
  (string-append "<!doctype html>" (xexpr->string xe)))
(define mime:text/plain  (string->bytes/utf-8 "text/plain;charset=utf-8"))
(define mime:text/s-expr (string->bytes/utf-8 "text/plain;charset=utf-8"))
(define mime:text/html   (string->bytes/utf-8 "text/html;charset=utf-8"))
(define mime:text/css    (string->bytes/utf-8 "text/css;charset=utf-8"))
(define mime:text/js     (string->bytes/utf-8 "text/javascript;charset=utf-8"))
(define mime:json        (string->bytes/utf-8 "application/json;charset=utf-8"))
(define mime:binary      (string->bytes/utf-8 "application/octet-stream"))
(define (respond code message headers mime-type body)
  (response/full code (string->bytes/utf-8 message)
                 (current-seconds) mime-type headers
                 (list (string->bytes/utf-8 body))))

(define (css->string cexprs)
  (string-append*
    (map (lambda (cexpr)
           (define selector (car cexpr))
           (define attrs
             (map (lambda (a) (format "~a: ~a;\n" (car a) (cadr a)))
                  (cdr cexpr)))
           (format "~a {\n~a}\n" selector (string-append* attrs)))
         cexprs)))
(define (js->string jsexpr) (string-join jsexpr "\n"))

(define (read*/string s)
  (define (read*)
    (define datum (read))
    (if (eof-object? datum) '() (cons datum (read*))))
  (with-handlers (((lambda _ #t)
                   (lambda _ (printf "unreadable input string: ~s\n" s)
                     #f)))
                 (with-input-from-string s read*)))

(define (/query req)
  (define post-data (request-post-data/raw req))
  (define (e400/body body)
    (respond 400 "Bad Request" '() mime:text/plain body))
  (define (e400 reason)
    (e400/body (with-output-to-string
                 (lambda () (printf "~a:\n~s\n" reason
                                    (bytes->string/utf-8 post-data))))))
  (define (e400/failure failure)
    (e400/body (with-output-to-string
                 (lambda ()
                   (printf "Query failed:\n~s\n"
                           (bytes->string/utf-8 post-data))
                   (pretty-print failure)))))
  (define (ok200 data)
    (respond 200 "OK" '() mime:text/s-expr
             (with-output-to-string (lambda () (pretty-print data)))))
  (cond ((not post-data) (e400/body "Invalid POST data."))
        ((read*/string (bytes->string/utf-8 post-data))
         => (lambda (data)
              (match data
                ('()           (e400 "Empty POST"))
                ((list* x y z) (e400 "Too many POST s-expressions"))
                ((list datum)
                 (match datum
                   (`(concept ,subject? ,object? ,isa-count ,via-cui? ,strings)
                     (with-handlers
                       (((lambda _ #t) e400/failure))
                       (ok200 (find-predicates/concepts
                                subject? object?
                                (find-concepts/options
                                  subject? object? isa-count
                                  via-cui? strings)))))
                   (`(X ,subject ,object)
                     (with-handlers
                       (((lambda _ #t) e400/failure))
                       (ok200 (find-Xs subject object))))
                   (_ (e400 "Invalid query")))))))
        (else (e400 "Bad POST s-expression format"))))

(define (xe200 xexpr)
  (respond 200 "OK" '() mime:text/html (xexpr->html-string xexpr)))

;; TODO: define simple read/write for s-expressions.
(define ui.js
  '("window.addEventListener('load', function(){"
    "function query(show, data) {"
    "  var xhr = new XMLHttpRequest();"
    "  xhr.addEventListener('load', function(event){"
    "    show(xhr.responseText);"
    "  });"
    "  xhr.addEventListener('error', function(event){"
    "    alert('Server communication failure: ' + xhr.status + ' ' + xhr.statusText);"
    "  });"
    "  xhr.open('POST', '/query');"
    "  xhr.setRequestHeader('Content-Type', 'text/plain;charset=utf-8');"
    "  xhr.send(data);"
    "}"

    "function displayClear(display) {"
    "  while (display.lastChild) {"
    "    display.removeChild(display.lastChild);"
    "  }"
    "}"
    "function displayShow(display, data) {"
    "  displayClear(display);"
    "  var option = document.createElement('option');"
    "  var text = document.createTextNode(data);"
    "  option.appendChild(text);"
    "  option.setAttribute('value', data);"
    "  display.appendChild(option);"
    "}"

    "var subjectSearch = document.getElementById('subject:text-search');"
    "var subjectC = document.getElementById('subject:concepts');"
    "var subjectP = document.getElementById('subject:predicates');"
    "var objectSearch = document.getElementById('object:text-search');"
    "var objectC = document.getElementById('object:concepts');"
    "var objectP = document.getElementById('object:predicates');"

    "subjectSearch.addEventListener('change', function(event){"
    "  var strings = subjectSearch.value.split(/(\\s+)/);"
    "  var joined = '\"' + strings.join('\" \"') + '\"';"
    "  var qdatum = '(concept #t #f 0 #f (' + joined + '))'"
    "  query(function(data){displayShow(subjectC,data);}, qdatum);"
    "}, false);"
    "objectSearch.addEventListener('change', function(event){"
    "  var strings = objectSearch.value.split(/(\\s+)/);"
    "  var joined = '\"' + strings.join('\" \"') + '\"';"
    "  var qdatum = '(concept #f #t 0 #f (' + joined + '))'"
    "  query(function(data){displayShow(objectC,data);}, qdatum);"
    "}, false);"
    "});"))
(define ui.css
  '(("body"
      (font-family "'Lucida Grande', Verdana, Helvetica, sans-serif")
      (font-size   "80%")
      (line-height "120%"))
    (".concept-box label"
     (vertical-align "top"))
    (".result-box label"
     (vertical-align "top"))
    ))
(define ui.html
  `(html (head (title "mediKanren User Interface"))
         (body (script ,(js->string ui.js))
               (style ,(css->string ui.css))
               ;; TODO: label these.
               (div (input ((id "subject:text-search") (type "text") (autocomplete "off")))
                    (input ((id "subject:isa") (type "checkbox")))
                    (label "Include ISA-related concepts"))
               (div ((class "concept-box"))
                    (label "Concept 1")
                    (select ((id "subject:concepts") (multiple "") (size "15"))
                            (option ((value "c1")) "concept 1"))
                    (label "Predicate 1")
                    (select ((id "subject:predicates") (multiple "") (size "15"))
                            (option ((value "p1")) "predicate 1")))
               (div (label "Concept 1 -> Predicate 1 -> [X] -> Predicate 2 -> Concept 2"))
               (div (input ((id "object:text-search") (type "text") (autocomplete "off")))
                    (input ((id "object:isa") (type "checkbox")))
                    (label "Include ISA-related concepts"))
               (div ((class "concept-box"))
                    (label "Predicate 2")
                    (select ((id "object:predicates") (multiple "") (size "15"))
                            (option ((value "p2")) "predicate 2"))
                    (label "Concept 2")
                    (select ((id "object:concepts") (multiple "") (size "15"))
                            (option ((value "c2")) "concept 2")))
               (div (label "Found Xs"))
               (div ((class "result-box"))
                    (label "X")
                    (select ((id "X:concepts") (multiple ""))
                            (option ((value "X1")) "Subject - X1 - Object"))))))

(define (/ui req) (xe200 ui.html))

(define index.js
  '("window.addEventListener('load', function(){"
    "var display = document.getElementById('display');"
    "var formC = document.getElementById('form:concept');"
    "var formX = document.getElementById('form:X');"
    "var textC = document.getElementById('text:concept');"
    "var textX = document.getElementById('text:X');"
    "var submitC = document.getElementById('submit:concept');"
    "var submitX = document.getElementById('submit:X');"
    "var buttonClear = document.getElementById('button:clear');"

    "function show(data) {"
    ;"  display.innerText = data;"
    "  var p = document.createElement('pre');"
    "  var text = document.createTextNode(data);"
    "  p.appendChild(text);"
    "  display.appendChild(p);"
    "}"
    "function clearDisplay() {"
    "  while (display.lastChild) {"
    "    display.removeChild(display.lastChild);"
    "  }"
    "}"

    "function query(data) {"
    "  var xhr = new XMLHttpRequest();"
    "  xhr.addEventListener('load', function(event){"
    "    show(xhr.responseText);"
    "  });"
    "  xhr.addEventListener('error', function(event){"
    "    show('POST error');"
    "  });"
    "  xhr.open('POST', '/query');"
    "  xhr.setRequestHeader('Content-Type', 'text/plain;charset=utf-8');"
    "  xhr.send(data);"
    "}"

    "formC.addEventListener('submit', function(event){"
    "  event.preventDefault();"
    "  query(textC.value);"
    "}, false);"
    "formX.addEventListener('submit', function(event){"
    "  event.preventDefault();"
    "  query(textX.value);"
    "}, false);"
    "buttonClear.addEventListener('click', function(){"
    "  clearDisplay();"
    "}, false);"
    "});"
    ))
(define index.html
  `(html (head (title "mediKanren"))
         (body (script ,(js->string index.js))
               (div (p "Databases loaded:") .
                    ,(map (lambda (dbname) `(p (pre ,(symbol->string dbname))))
                          (config-ref 'databases)))
               (p "Use the " (a ((href "/ui")) "Interface"))
               (p "Or POST to /query using a form:")
               (form ((method "post") (action "/query") (id "form:concept"))
                     (div (textarea ((id "text:concept"))
                                    "(concept ...)"))
                     (div (button ((type "submit") (id "submit:concept"))
                                  "Find concepts")))
               (form ((method "post") (action "/query") (id "form:X"))
                     (div (textarea ((id "text:X"))
                                    "(X ...)"))
                     (div (button ((type "submit") (id "submit:X"))
                                  "Find Xs")))
               (button ((id "button:clear")) "Clear")
               (div ((id "display"))))))
(define (index req) (xe200 index.html))

(define (method-not-allowed req)
  (respond 405 "Method Not Allowed" '() mime:text/html
           (xexpr->html-string
             `(html (head (title "Method Not Allowed"))
                    (body (h1 "Method Not Allowed")
                          (pre ,(url->string (request-uri req)))
                          (p "does not support")
                          (pre ,(bytes->string/utf-8 (request-method req))))))))

(define (not-found req)
  (respond 404 "Not Found" '() mime:text/html
           (xexpr->html-string
             `(html (head (title "Not Found"))
                    (body (h1 "What are you looking for?")
                          (p "There was nothing found at")
                          (pre ,(url->string (request-uri req))))))))

(define-values (dispatcher _)
  (dispatch-rules
    (("")      #:method "get"         index)
    (("query") #:method "post"        /query)
    (("ui")    #:method "get"         /ui)
    (("")      #:method (regexp ".*") method-not-allowed)
    (("query") #:method (regexp ".*") method-not-allowed)
    (("ui")    #:method (regexp ".*") method-not-allowed)
    (else                             not-found)))

(serve/servlet dispatcher
               ;; The none-manager offers better performance when not using
               ;; web continuations.
               #:manager (create-none-manager #f)
               #:servlet-regexp #rx""
               #:launch-browser? #f)
