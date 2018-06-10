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
  if doc-fn?
    $ 'title' .text "toxin [#{doc-fn}]"
  switch doc-type
  | 'text/html'
    $ '#document' .html doc-text
    $ '#tex' .text compile-dom document.getElementById 'document'
  | 'text/tex'
    $ '#tex' .text doc-text
    $ '#document' .append compile-latex doc-text

  if doc-fn? && (doc-settings = localStorage["doc.#{doc-fn}"])?
    doc-settings = JSON.parse(doc-settings)
    $(window).scrollTop(doc-settings.scroll-pos)
    setTimeout -> $(window).scrollTop(doc-settings.scroll-pos)
    , 1000
    # ^ ok that's a very inaccurate way to say "after KaTeX settles down"


window.addEventListener 'unload', ->
  if doc-fn?
    localStorage["doc.#{doc-fn}"] = JSON.stringify do
      scroll-pos: $(window).scrollTop!
