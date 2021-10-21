node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    events: {EventEmitter}
    lodash: _
    jquery: $
    codemirror: CodeMirror
    'codemirror/mode/stex/stex'
    'codemirror/mode/htmlmixed/htmlmixed'
    'codemirror/addon/dialog/dialog'
#    'codemirror/addon/search/searchcursor'
#    'codemirror/addon/search/search'
    'codemirror/addon/selection/mark-selection'
    'codemirror/addon/edit/matchbrackets'
    'codemirror/addon/selection/active-line'
    './edit-items.ls': { VisitedFiles, FileEdit }
    '../ide/problems.ls': { safe }
}

require 'codemirror/lib/codemirror.css'
require 'codemirror/addon/dialog/dialog.css'
require './editor.css'



class TeXEditor extends EventEmitter
  (@containing-element) ->
    @cm = new CodeMirror @containing-element?0, do
      mode: 'stex'
      lineWrapping: true
      lineNumbers: true
      styleSelectedText: true
      matchBrackets: true
      styleActiveLine: true

    @_configure-keymap!

    @containing-element[0].addEventListener 'blur' (ev) ->
      if ev.relatedTarget == null then ev.stopPropagation!
    , {+capture}

    @visited-files = new VisitedFiles
    @_open-reent = 0

    @dialog = new DialogMixin(@)
    @search = new SearchMixin(@)
    @jumps = new JumpToMixin(@)

  open: (locator) ->>
    @_pre-load! ; reent = ++@_open-reent
    locator = @_normalize-loc locator
    @loc = locator
    try
      if locator.p2p-uri      => await @open-syncpad locator
      else if locator.volume  => await @open-file locator
      else
        throw new Error "invalid document locator: '#{locator}'"
    catch e
      if reent == @_open-reent then @loc = null  # @oops another `open` may have started in the meantime
      throw e

  open-file: (locator) ->
    @visited-files.enter @cm, locator, -> new FileEdit(locator)
    .then ~> @emit 'open', {type: 'file', loc: locator, uri: locator.filename}

  open-syncpad: (locator) ->
    require! '../net/p2p.ls': { SyncPadEdit }
    @visited-files.enter @cm, locator, -> new SyncPadEdit(locator)
    .then ~> @emit 'open', {type: 'syncpad', loc: locator}

  _pre-load: !->
    if @loc? then @visited-files.leave @cm, @loc

  reload: ->
    if @loc? then @open-file @loc

  save: ->
    @visited-files.save @cm, @loc
    if @@is-dat(@loc.filename)
      @emit 'request-save'

  jump-to: (loc, {line, ch}={}, focus=true) ->>
    loc = @_normalize-loc loc
    if !@loc || !(loc.volume == @loc.volume && loc.filename == @loc.filename)
      await @open loc
    if line?
      @cm.setCursor {line, ch: ch ? 0}
      @cm.scrollIntoView null, 150
    if focus then requestAnimationFrame ~> @cm.focus!

  track-line: (on-move) -> new LineTracking(@cm, on-move)
  stay-flag: -> new StayFlag(@cm)

  _normalize-loc: (loc) ->
    if loc.volume?path
      loc = {...loc, loc.volume, filename: loc.volume.path.normalize loc.filename}
      if !loc.filename.startsWith('/') then loc.filename = '/' + loc.filename
    loc

  _configure-keymap: ->
    Ctrl = @Ctrl = if @@is-mac then "Cmd" else "Ctrl"

    @cm.addKeyMap do
      "#{Ctrl}-S": @~save
      #"#{Ctrl}-F": 'findPersistent'  # because non-persistent is just silly
      "Tab": 'indentMore',
      "Shift-Tab": 'indentLess',

  state:~
    -> {@loc, cursor: @cm.getCursor!}
    (v) ->
      safe ~> v.loc && @jump-to v.loc, v.cursor, false

  @is-mac = navigator.appVersion is /Mac/

  @is-local-file = (filename) ->
    !filename.match(/^[^/]+:\//)

  @is-dat = (filename) ->
    filename.match(/^dat:\//)


class DialogMixin
  (@_) ->
  cm:~ -> @_.cm
  containing-element:~ -> @_.containing-element

  open: (height) ->
    @active?close!
    # Allow scrolling up if dialog covers the first few lines of text,
    # like in Atom
    @cm.getScrollerElement!
      ..scrollTop += height; ..style.paddingTop = "#{height}px";
      cleanup = ~>
        ..scrollTop -= height; ..style.paddingTop = ""
        @active = void

    @active = new @@Dialog <<< do
      $el: $('<div>').addClass('ide-editor-dialog').css(height: "#{height}px") \
                     .appendTo(@containing-element)
      height: height
      close: -> @$el.remove! ; cleanup! ; @emit 'close'

  class @Dialog extends EventEmitter


class SearchMixin
  (@_) ->
  cm:~ -> @_.cm
  dialog:~ -> @_.dialog
  jumps:~ -> @_.jumps

  start: ->
    @dialog.open @@DIALOG_HEIGHT
      ..controls = $('<div>').addClass('ide-editor-dialog-content')
        ..append $('<span>').addClass('🔎').text('🔎')
        ..append ..box = $('<input>').addClass('search-box')
      ..$el.append ..controls
      ..controls.box.on 'input' (-> ..emit 'input', ..controls.box.val!)
        ..on 'focus' ~> @origin-pos = @cm.getCursor!
        ..focus!
      ..on 'input' ~> @show it
  
  show: (query) !->
    @hide!
    @query = @@Query.promote(query)
      @results = @_matches ..
    @cm.addOverlay @overlay = new @@Overlay(@query)
    @focus-fwd!

  hide: !-> if @overlay then @cm.removeOverlay that

  focus-fwd: (pos = @origin-pos ? @cm.getCursor!) ->
    idx = @cm.indexFromPos(pos)
    @results.find(-> it.index >= idx)
      .. && @jumps.focus-around ..

  _matches: (query) -> query.all(@cm.getValue!).map (mo) ~>
    at = (offset) ~> @cm.posFromIndex(mo.index + offset)
    {mo.index, from: at(0), to: at(mo.0.length)}

  class @Query
    (spec, flags = "") ->
      @re = if typeof spec == 'string' then @@_re-escape spec, "g#{flags}"
            else assert spec instanceof RegExp; spec 
      if !@re.global
        @re = new RegExp(@re.source, @re.ignoreCase ? "gi" : "g");

    all: (s, start = 0) -> [...s.matchAll(@re)]

    forward: (s, start = 0) ->
      @re.lastIndex = start
      @re.exec(s)

    @promote = -> if it instanceof @ then it else new @(it)

    @_re-escape = (s, flags) ->
      new RegExp(s.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"), flags)


  class @Overlay
    (@query) -> @token = @~_token
    _token: (stream) !->
      if (mo = @query.forward(stream.string, stream.pos))?
        if mo.index == stream.pos
          stream.pos += mo[0].length || 1; return "searching"
        else
          stream.pos = mo.index
      else
        stream.skipToEnd!


  @DIALOG_HEIGHT = 40


class JumpToMixin
  (@_) ->
  cm:~ -> @_.cm
  dialog:~ -> @_.dialog

  focus-around: (pos, clearance = @@DEFAULT_CLEARANCE) ->
    if pos.from? && pos.to? then @cm.setSelection pos.from, pos.to
    else @cm.setCursor pos
    @make-clearance clearance

  make-clearance: (clearance = @@DEFAULT_CLEARANCE) ->
    scroll-info = @cm.getScrollInfo!
    cursor = @cm.cursorCoords!
      if @dialog.active then ..top -= that.height
    adj-top = clearance.y - cursor.top
    adj-bot = cursor.bottom - (scroll-info.clientHeight - clearance.y)
    @cm.getScrollerElement!
      if adj-top > 0 then       ..scrollTop -= adj-top
      else if adj-bot > 0 then  ..scrollTop += Math.min(adj-bot, -adj-top)

  @DEFAULT_CLEARANCE = {y: 80}


/** Auxiliary class */
class EventHook
  (@cm, @event-type, @handler) ->
    @cm.on @event-type, @handler
  destroy: ->
    @cm.off @event-type, @handler


/**
 * Notifies whenever the current line changes.
 */
class LineTracking extends EventHook
  (cm, on-move) ->
    at-line = cm.getCursor!line
    super cm, 'cursorActivity', ~>
      l = @cm.getCursor!line
      if l != at-line then at-line := l; on-move!


/**
 * This flag is `true` as long as the cursor was not moved.
 */
class StayFlag extends EventHook
  (cm) ->
    @value = true
    super cm, 'cursorActivity', ~>
      @value = false; @destroy!



export TeXEditor, DialogMixin, SearchMixin, JumpToMixin
