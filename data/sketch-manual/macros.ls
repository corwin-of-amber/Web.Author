{consume-next, env} = Traversal
txt = document~createTextNode

newcounter = (start-from, f) ->
  f.counter-value = start-from
  f

commands =
  section: -> $ '<h1>' .append consume-next it
  subsection: -> $ '<h2>' .append consume-next it
  seclabel: -> $ '<a>' .attr 'name' (consume-next it .text!)
  C: -> $ '<code>' .add-class 'code' .append consume-next it
  sqsubseteq: -> $ '<span>' .add-class 'rm' .text "⊑"
  geq: -> $ '<span>' .add-class 'rm' .text "≥"
  leq: -> $ '<span>' .add-class 'rm' .text "≤"
  neq: -> $ '<span>' .add-class 'rm' .text "≠"
  vdash: -> $ '<span>' .add-class 'rm' .text "⊢"
  sqcup: -> $ '<span>' .add-class 'rm' .text "⊔"
  bigsqcup: -> $ '<span>' .add-class 'rm big' .text "⊔"
  rightarrow: -> $ '<span>' .add-class 'rm' .text "→"
  Rightarrow: -> $ '<span>' .add-class 'rm' .text "⇒"
  wedge: -> $ '<span>' .add-class 'rm' .text "∧"
  forall: -> $ '<span>' .add-class 'rm' .text "∀"
  tau: -> $ txt "τ"
  Gamma: -> $ '<span>' .add-class 'rm' .text "Γ"
  ldots: -> $ '<span>' .text "..."
  cdot: -> $ '<span>' .text "·"
  flagdoc: ->
    $ '<dl>' .add-class 'flagdoc'
      $ '<dt>' .add-class 'parameter' .append consume-next(it) .append-to ..
      $ '<dd>' .append consume-next(it) .append-to ..
  paragraph: ->
    p = Traversal.par it .wrap-all '<p>' .parent! .add-class 'paragraph'
    $ '<a>' .add-class "parameter title" .append consume-next(it)
  secref: -> $ '<a>' .text "link" .attr 'href' ('#' + consume-next it .text!)
  emph: -> $ '<em>' .append consume-next(it)
  textit: -> $ '<i>' .append consume-next(it)
  lstinline: -> $ '<code>' .add-class 'lstinline' .append consume-next(it)

  begin: ->
    name = Traversal.peek-next it .text!
    if (envf = environments[name])?
      envf it
    else
      $ '<span>' .text "unknown environment"
  end: ->
    consume-next it
    $ '<span>' .add-class 'empty'

  item: -> $ '<li>' .add-class 'item' .append Traversal.next-until-cond it[0].nextSibling, ->
    Traversal.is-command it, '\\item'

  Sk: -> $ '<span>' .add-class 'Sketch'
  ie: -> $ '<i>' .add-class 'latin' .text "i.e."
  eg: -> $ '<i>' .add-class 'latin' .text "e.g."


# Extend TeX parser with a state for inline code via \lstinline
LSTINLINE =
  token-re: // (.) //g
  transition: (mo, texg) ->
    _ = texg
    _.state =
      token-re:  // ([$]) | (#{mo.1}) //g  # TODO: requires escaping
      transition: (mo, texg) ->
        _ = texg
        if mo.1 then _.enter(mo.1, TexGrouping.INITIAL)
        else _.emit _.leave ''

TexGrouping.INITIAL.special['\\lstinline'] = (, _) ->
  _.enter '{}', LSTINLINE


verbatim = (jdoms) ->
  jdoms.each ->
    jdom = $(@)
    if ! jdom.is('.math')
      # essentially reverses the effects of the parser :\
      contents = jdom.contents!
      if jdom.is('.group')
        $(@).replaceWith [txt "{"] ++ contents[to] ++ [txt "}"]
      else if jdom.is('.escaped')
        $(@).replaceWith [txt "\\"] ++ contents[to]
      else if jdom.is('.par-break')
        $(@).replaceWith contents

      contents.each -> verbatim $(@)

environments =
  lstlisting: ->
    $ '<div>' .add-class 'code' .append env it
      verbatim ..children!
      # strip leading whitespace (including newline)
      if Traversal.is-text(x = (..0.firstChild))
        x.nodeValue = x.nodeValue.replace(/^\s+/, '')
        if x.nodeValue == '' then x.remove!
  Example: ->
    $ '<div>' .add-class 'example'
    .append ($ '<p>' .attr 'counter-value' '?') .append env it
  itemize: ->
    $ '<ul>' .add-class 'itemize' .append env it
  enumerate: ->
    $ '<ol>' .add-class 'enumerate' .append env it
  center: ->
    $ '<div>' .add-class 'center' .append env it
  tabular: ->
    [opt, ...inner] = env it .remove!toArray!
    container = $ '<div>' .append inner
    expand-macros container
    inner = container.contents!
    $ '<table>' .add-class 'tabular'
      next-row = ->
        $ '<td>' .append-to ($ '<tr>' .append-to ..)
      next-column = ->
        $ '<td>' .insert-after current-cell
      current-cell = next-row!
      for node in inner
        if $(node).is('.command') && $(node).text! == '\\\\'
          current-cell = next-row!
        else if node.nodeType == document.TEXT_NODE && node.nodeValue == '&'
          current-cell = next-column!
        else
          current-cell.append node


aftermath =
  math: ->
    verbatim it.children!
    for dom in it.contents!
      if dom.nodeType == document.TEXT_NODE
        if dom.nodeValue == /^~+$/
          dom.remove!
    katex.render it.text!, it[0], {displayMode: it.is('div'), -throwOnError}
    it.find '.katex-mathml' .remove!

  not-math: ->
    # @deprecated
    # A toy math processor
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
      gobble = Traversal.next-until-cond p[0].nextSibling, Traversal.is-block
      p.append gobble

  group: ->
    if it.contents!length == 0 then it.remove!

  'par-break': ->
    # collect preceding nodes up to a block element or beginning of parent
    # (this has to be done at DOM level to collect text nodes as well)
    gobble = Traversal.prev-until-cond it[0].previousSibling, Traversal.is-block
    it.replaceWith $('<p>').append(gobble)




export commands, aftermath
