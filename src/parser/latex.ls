
{flatten} = require 'prelude-ls'


class TexGrouping

  @INITIAL =
    token-re: // ([{$] | \\\[)    |  ([}] | \\\])   |
                 (\\[a-zA-Z]+)    |  (\\[\\~^])     |  \\([^a-zA-Z])  |
                 (\n\s*?(?:\n\s*)+)                 |  (\s+?)         |
                 (%.*\n)  //g
    matching: {'{': '}', '$': '$', '\\[': '\\]'}

    special: {}

    transition: (mo, texg) ->
      _ = texg
      matches = (tok) ~> tok == @matching[_.peek!]
      if matches(mo.0) then _.emit _.leave(mo.0)
      else if mo.0 of @matching then _.enter(mo.0)
      else if mo.2 || mo.3 || mo.4 then _.emit T(mo.0)
      else if mo.5 then _.emit T("\\").of(mo.5)
      else if mo.6 then _.emit T("¶").of(mo.6)
      else if mo.8 then _.emit T("%").of(mo.8)
      else _.emit _.strip(mo.0)

      if (f = @special[mo.0]) then f mo.0, texg

  ->
    @out = T('')
      ..state = @@INITIAL
    @stack = [@out]

  emit: (text) -> @stack[*-1].subtrees.push text
  peek: -> @stack[*-1].root
  enter: (tok, state) -> @stack.push T(tok) <<< {state: state ? @state}
  leave: (tok) -> @stack.pop!
    ..root += tok

  state:~
    -> @stack[*-1].state
    (it) -> @stack[*-1].state = it

  strip: (str) ->
    str.replace(/^\r+/, '')

  process: (text) ->
    exec-from = (re, text, pos) -> re.lastIndex = pos ; re.exec(text)
    pos = 0
    while (mo = exec-from(@state.token-re, text, pos))?
      if mo.index != pos
        @emit text.substr(pos, mo.index - pos)
      @state.transition(mo, @)

      pos = mo.index + mo.0.length

    while @stack.length > 1
      @emit @leave('')

    @out


Traversal = do ->

  is-text = (dom, txt) ->
    dom.nodeType == document.TEXT_NODE && (!txt? || dom.nodeValue == txt)
  is-command = (dom, cmd) ->
    $(dom).has-class 'command' and (!cmd? || $(dom).text! == cmd)
  is-math = (dom) ->
    dom.nodeType == document.ELEMENT_NODE && $(dom).has-class 'math'
  is-block = (dom) ->
    dom.nodeType == document.ELEMENT_NODE && \
      dom.tagName in <[ H1 H2 H3 DIV P DL UL OL TABLE ]>

  txt = document~createTextNode

  ungroup = -> it.contents!
  consume-next = (dom, treat-elements=ungroup) ->
    n = dom.map -> @nextSibling
    $ flatten n.map ->
      if is-text(@)
        txt @nodeValue[0]
          .. ; @nodeValue = @nodeValue.substring 1
      else
        treat-elements $(@).remove!  |>  (.[to])
  peek-next = (dom, treat-elements=ungroup) ->
    n = dom.map -> @nextSibling
    $ flatten n.map -> if is-text(@) then $ txt @nodeValue[0] else treat-elements $(@) |> (.[to])
  prev-bound = (dom, pred) ->
    x = void
    while dom? && !pred(dom) then x = dom ; dom = dom.previousSibling
    x ? dom.nextSibling
  next-until-cond = (dom, pred, inclusive=false) -> []
    while dom? && !pred(dom) then ..push dom ; dom = dom.nextSibling
    if inclusive && dom? then ..push dom
  prev-until-cond = (dom, pred, inclusive=false) -> []
    while dom? && !pred(dom) then ..unshift dom ; dom = dom.previousSibling
    if inclusive && dom? then ..push dom

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

  forward0 = (jdom) ->
    if      (x = jdom.next!).length then x
    else if (x = jdom.parent!).length then forward0 x
    else $ []

  forward = (jdom) ->
    if   !is-math(jdom[0]) && (x = $(jdom.children![0])).length then x
    else forward0 jdom

  {is-text, is-command, is-block, ungroup, consume-next,
  peek-next, prev-bound, next-until-cond, prev-until-cond,
  par, env, forward, forward0}


@ <<< {TexGrouping, Traversal, assert}
