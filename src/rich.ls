fs = require \fs




doc-fn = window.location.search?.replace(/^[?]/, '')

if doc-fn?
  doc-text = fs.readFileSync doc-fn, "utf-8"
  if doc-fn == /\.html$/
    doc-type = 'text/html'
  else if doc-fn == /\.tex$/
    doc-type = 'text/tex'
  else
    doc-type = void
    console.warn "Can't detect document type (#doc-fn)"
else
  doc-type = void



$ ->
  switch doc-type
  | 'text/html'
    $ '#document' .html doc-text
    $ '#tex' .text compile-dom document.getElementById 'document'
  | 'text/tex'
    $ '#tex' .text doc-text
    $ '#document' .append compile-latex doc-text
