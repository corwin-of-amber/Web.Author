
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
    jdom = $ '<span>' .add-class 'par-break'
  else if tree.root == "!" && !tree.is-leaf!
    jdom = $ '<span>' .add-class 'special-token' .attr 'token' tree.subtrees[0]
  else if tree.root == "%"
    jdom = $ '<span>' .add-class 'comment'
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
      # >> I did not witness this happen in NWjs 0.30.2. perhaps it's gone...
      #if last?.nodeType == document.TEXT_NODE && last.nodeValue == /\S\s$/
      #  last.nodeValue += "\t"   # this is a hack to work around a rendering bug in nwjs
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
    console.error "warning: iteration limit reached (infinite loop?)"

post-process = (jdom) ->
  for class-name, am-func of aftermath
    jdom.find ".#class-name"
      if am-func.digest then am-func ..
      else
        for dom in .. then am-func $(dom)



export compile-latex, expand-macros
