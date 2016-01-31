{consume-next, peek-next, next-until-cond, par, env} = Traversal
txt = document~createTextNode

is-text = (dom, txt) ->
  dom.nodeType == document.TEXT_NODE && (!txt? || dom.nodeValue == txt)
is-command = (dom, cmd) ->
  $(dom).has-class 'command' and (!cmd? || $(dom).text! == cmd)
is-block = (dom) ->
  dom.nodeType == document.ELEMENT_NODE && \
    <[ DIV P DL UL OL TABLE ]>.indexOf(dom.nodeName) >= 0

newcounter = (start-from, f) ->
  f.counter-value = start-from
  f

commands =
  section: -> $ '<h1>' .append consume-next it
  subsection: -> $ '<h2>' .append consume-next it
  seclabel: -> $ '<a>' .attr 'name' (consume-next it .text!)
  C: -> $ '<code>' .append consume-next it
  sqsubseteq: -> $ '<span>' .add-class 'rm' .text "⊑"
  geq: -> $ '<span>' .add-class 'rm' .text "≥"
  leq: -> $ '<span>' .add-class 'rm' .text "≤"
  neq: -> $ '<span>' .add-class 'rm' .text "≠"
  vdash: -> $ '<span>' .add-class 'rm' .text "⊢"
  sqcup: -> $ '<span>' .add-class 'rm' .text "⊔"
  bigsqcup: -> $ '<span>' .add-class 'rm big' .text "⊔"
  Rightarrow: -> $ '<span>' .add-class 'rm' .text "⇒"
  wedge: -> $ '<span>' .add-class 'rm' .text "∧"
  forall: -> $ '<span>' .add-class 'rm' .text "∀"
  tau: -> $ txt "τ"
  Gamma: -> $ '<span>' .add-class 'rm' .text "Γ"
  ldots: -> $ '<span>' .text "..."
  cdot: -> $ '<span>' .text "·"
  flagdoc: -> 
    $ '<dl>' .add-class 'flagdoc'
      $ '<dt>' .add-class 'parameter' .append consume-next it .append-to ..
      $ '<dd>' .append consume-next it .append-to ..
  paragraph: ->
    p = par it .wrap-all '<p>' .parent! .add-class 'paragraph'
    $ '<a>' .add-class "parameter title" .append consume-next it
  secref: -> $ '<a>' .text "link" .attr 'href' (consume-next it .text!)
  emph: -> $ '<em>' .append consume-next it
  textit: -> $ '<i>' .append consume-next it
  begin: ->
    name = peek-next it .text!
    if (envf = environments[name])?
      envf it
    else
      $ '<span>' .text "unknown environment"
  end: ->
    consume-next it
    $ '<span>' .add-class 'empty'
    
  item: -> $ '<li>' .add-class 'item' .append next-until-cond it[0].nextSibling, ->
    is-command it, '\\item'
  
  Sk: -> $ '<span>' .add-class 'Sketch'
  ie: -> $ '<i>' .add-class 'latin' .text "i.e."
  eg: -> $ '<i>' .add-class 'latin' .text "e.g."
    

verbatim = (jdoms) ->
  jdoms.each ->
    jdom = $(@)
    if ! jdom.is('.math')
      contents = jdom.contents!
      if jdom.is('.group')
        $(@).replace-with [txt "{"] ++ contents[to] ++ [txt "}"]
      else if jdom.is('.escaped')
        $(@).replace-with [txt "\\"] ++ contents[to]
      else if jdom.is('.par-break')
        $(@).replace-with contents
      
      contents.each -> verbatim $(@)
  
environments =
  lstlisting: ->
    $ '<div>' .add-class 'code' .append env it
      verbatim ..children!
      if is-text (x = (..0.firstChild)), "\n" then x.remove!
  Example: ->
    $ '<div>' .add-class 'example' 
    .append ($ '<p>' .attr 'counter-value' '?') .append env it
  itemize: ->
    $ '<ul>' .add-class 'itemize' .append env it
  center: ->
    $ '<div>' .add-class 'center' .append env it
  tabular: ->
    $ '<table>' .add-class 'tabular'
      $ '<tr>' .append-to ..
        $ '<td>' .append env it .append-to ..

    
aftermath =
  math: ->
    for dom in it.contents!
      if dom.nodeType == document.TEXT_NODE 
        if dom.nodeValue == /^~+$/
          dom.remove!
        else if dom.nodeValue == /~/
          dom.nodeValue = dom.nodeValue.replace '~' ' '
        else if (mo = (dom.nodeValue == /^(.*)_([^{])(.*)$/))
          dom.nodeValue = mo.1
          $ '<sub>' .text mo.2 .insert-after dom
            if mo.2 == /^[\d.]+$/ then ..add-class 'rm'
            if mo.3.length
              $ txt mo.3 .insert-after ..
    if it.text! == /^[\d.]+$/
      it.add-class "rm"

  example: newcounter 1 ->
    p = it.find "p[counter-value]"
    if p.length
      p.attr 'counter-value' aftermath.example.counter-value++
      gobble = next-until-cond p[0].nextSibling, is-block
      p.append $ gobble
      
  group: ->
    if it.contents!length == 0 then it.remove!


@ <<< {commands, aftermath}
