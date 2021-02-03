# mediKanren

*** FOR RESEARCH PURPOSES ONLY ***

Proof-of-concept for reasoning over the SemMedDB knowledge base, using miniKanren + heuristics + indexing.

`./code/study-imatinib.rkt` contains the most iteresting examples currently.

TODO: add SemMedDB files, along with terms of use information for SemMedDB.

TODO: add simple instructions for running the queries.


## Setup

### Download and install Racket

https://download.racket-lang.org/


### Obtain a CSV dump of SemMed DB

You'll need to obtain the full data from: https://skr3.nlm.nih.gov/SemMedDB/

A small sample, `code/sample_semmed.csv`, is provided to demonstrate the format expected for processing.


### Index the data for consumption by mediKanren

Given `semmed.csv`, Run these commands from the `code` directory:

```
mkdir semmed

racket csv-semmed-ordered-unique-enum.rkt semmed.csv semmed

racket csv-semmed-simplify.rkt semmed.csv semmed

racket semmed-index-predicate.rkt semmed
```

Depending on the size of the CSV you're using, these commands could take up to a few hours to process all records.


## Use

### Interact with the GUI

The GUI is a convenient way to express some forms of simple queries.  For more power, see the section on running queries programmatically.

From the `code` directory, run `racket gui-simple.rkt` to start the GUI.

As you interact, the console will display additional information in some cases.

* When clicking on results, the corresponding PubMed URLs will be printed for your convenience.  If you're running on OSX within iTerm2, you can CMD+click a URL to open it in the browser.
* When querying with synthetic predicates such as `increases[*]/decreases[*]`, the results will not be displayed in the GUI, but will instead be continuously streamed to the console.


### Run queries programmatically

Start with `code/tacrine.rkt` `code/imatinib-query.rkt`, which includes queries taken from `code/study-imatinib.rkt`, and also includes a high-level description of the queries.

Take a look at the various `study-*.rkt` files in the `code` directory for examples.  You can run these from the command line, e.g., `racket study-imatinib.rkt`.


To write your own queries, either as a new `*.rkt` file or interactively, start with:

```
(require "mk-db.rkt")
```

to load the database and its indices (this will take several seconds, so be patient).  Once loaded, you will have access to the full underlying miniKanren language, plus the new semmed-specific relations:

```
(concepto c)
(fuzzy-concepto name c)
(cuio c cui)
(cui*o c cui*)
(edgeo `(,subject-concept ,object-concept ,predicate ,subject-type ,object-type ,pubref))
```

which you can compose freely in queries.  Being that mediKanren is an embedded DSL, you also have access to Racket for metaprogramming.
