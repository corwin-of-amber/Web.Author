fs = require \fs


compile-dom = (dom) ->
  if dom.nodeType == document.TEXT_NODE
    dom.data
  else
    inner = [compile-dom n for n in dom.childNodes] .join ''
    inner = /^\n?([\s\S]*?)(\n\s*)?$/.exec inner .1  # strip leading/trailing \n
    if (clsses = $(dom).attr('class'))?
      for cls in clsses.split /\s+/ .reverse!
        if (f = styles[cls])?
          inner = f inner, {dom} <<< get-attributes dom
    inner


get-attributes = (dom) -> {}
  for att in dom.attributes
    ..[att.nodeName] = att.nodeValue

    
compile-latex = (latex) ->
  t = new TexGrouping()
  compile-latex-groups t.process(latex)
    expand-macros ..
    post-process ..
  
compile-latex-groups = (tree) ->
  if tree.root == ''
    jdom = $ '<div>'
  else if tree.root == /^\\/ && tree.is-leaf!
    jdom = $ '<span>' .add-class 'command' .text tree.root
  else if tree.root == "{}"
    jdom = $ '<span>' .add-class 'group'
  else if tree.root == "$$"
    jdom = $ '<span>' .add-class 'math'
  else if tree.root == "\\[\\]"
    jdom = $ '<div>' .add-class 'math'
  else if tree.root == "\\"
    jdom = $ '<span>' .add-class 'escaped'
  else if tree.root == "¶"
    jdom = $ '<span>' .add-class 'par-break'# .text tree.root
  else
    jdom = $ '<span>' .text tree.root

  append-text-aware jdom, do
    for sub in tree.subtrees
      if sub instanceof Tree
        compile-latex-groups sub
      else
        document.createTextNode sub

  jdom

/**
 * Appends all the `elements` to `jdom`, but merges adjacent text
 * nodes.
 */
append-text-aware = (jdom, elements) ->
  last = jdom.children![*-1]
  for element in elements
    if element.nodeType == document.TEXT_NODE
      if last?.nodeType == document.TEXT_NODE
        last.nodeValue += element.nodeValue
      else
        jdom.append (last = element)
    else
      if last?.nodeType == document.TEXT_NODE && last.nodeValue == /\S\s$/
        last.nodeValue += "\t"   # this is a hack to work around a rendering bug in nwjs
      jdom.append (last = element)


lookup-command = (name) -> commands[if name == /^\\(.*)$/ then that.1 else name]

expand-macros = (jdom) ->
  child = $(jdom.children![0])
  i = 0 ; NLIMIT = 10000
  while child.length && (++i < NLIMIT)
    if child.has-class 'command' and (f = lookup-command child.text!)?
      child = do -> f child
        child.replace-with ..
    child = Traversal.forward child
    
  if i >= NLIMIT
    console.error "warning: iteration limit reach (infinite loop?)"

post-process = (jdom) ->
  for class-name, am-func of aftermath
    for dom in jdom.find ".#class-name"
      am-func $(dom)


@ <<< {expand-macros}


doc-fn = "#{projdir}/data/sketch-manual/baseLanguage.html"

doc-text = fs.readFileSync doc-fn, "utf-8"
if doc-fn == /\.html$/
  doc-type = 'text/html'
else if doc-fn == /\.tex$/
  doc-type = 'text/tex'
else
  doc-type = void
  console.warn "Can't detect document type (#doc-fn)"
  
#texdoc = fs.readFileSync "#{projdir}/data/sketch-manual/baseLanguage.tex" "utf-8"
#texdoc = fs.readFileSync "#{projdir}/data/sketch-manual/excerpts/math.tex" "utf-8"


$ ->
  switch doc-type
  | 'text/html'
    $ '#document' .html doc-text
    $ '#tex' .text compile-dom document.getElementById 'document'
  | 'text/tex'
    $ '#tex' .text doc-text
    $ '#document' .append compile-latex doc-text
