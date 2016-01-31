fs = require \fs
htmldoc = fs.readFileSync "#{projdir}/data/sketch-manual/baseLanguage.html" "utf-8"
texdoc = fs.readFileSync "#{projdir}/data/sketch-manual/baseLanguage.tex" "utf-8"

assert = (cond, msg) ->
  if !cond then throw Error (if msg? then "Assertion failed; #msg" else "Assertion failed.")

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
    
  for sub in tree.subtrees
    if sub instanceof Tree
      jdom.append compile-latex-groups sub
    else
      jdom.append document.createTextNode sub #($ '<span>' .text sub)
  jdom


ungroup = -> it.contents!
consume-next = -> ungroup it.next!remove!
peek-next = -> ungroup it.next!
prev-bound = (dom, pred) ->
  x = void
  while dom? && !pred(dom) then x = dom ; dom = dom.previousSibling
  x ? dom.nextSibling
next-until-cond = (dom, pred) -> []
  while dom? && !pred(dom) then ..push dom ; dom = dom.nextSibling

par = (jdom) ->
  assert jdom.length == 1, "'par' must get a single element"
  dom = jdom[0]
  start = prev-bound dom, (-> $ it .has-class 'par-break')
  $ next-until-cond start, (-> $ it .has-class 'par-break')

env = (jdom) ->
  assert jdom.length == 1, "'env' must get a single element"
  name = consume-next jdom .text!
  dom = jdom[0]
  $ next-until-cond dom.nextSibling, -> 
    $ it .has-class 'command' and $ it .text! == '\\end' and peek-next $ it .text! == name

forward = (jdom) ->
  forward0 = (jdom) ->
    if      (x = jdom.next!).length then x
    else if (x = jdom.parent!).length then forward0 x
    else $ []
  if      (x = $(jdom.children![0])).length then x
  else forward0 jdom

@ <<< {Traversal: {ungroup, consume-next, peek-next, prev-bound, next-until-cond, par, env, forward}}

lookup-command = (name) -> commands[if name == /^\\(.*)$/ then that.1 else name]

expand-macros = (jdom) ->
  child = $(jdom.children![0])
  i = 0 ; NLIMIT = 10000
  while child.length && (++i < NLIMIT)
    if child.has-class 'command' and (f = lookup-command child.text!)?
      child = do -> f child
        child.replace-with ..
    child = forward child
    
  if i >= NLIMIT
    console.error "warning: iteration limit reach (infinite loop?)"

post-process = (jdom) ->
  for class-name, amf of aftermath
    for dom in jdom.find ".#class-name"
      amf $(dom)

$ ->
  #$ '#document' .html htmldoc
  #$ '#tex' .text compile document.getElementById 'document'
  $ '#tex' .text texdoc
  $ '#document' .append compile-latex texdoc
