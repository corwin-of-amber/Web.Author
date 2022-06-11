node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    events: {EventEmitter}
    lodash: _
    jquery: $
    '@codemirror/view': { EditorView, keymap }
    '@codemirror/state': { EditorState, EditorSelection }
    '@codemirror/commands': { defaultKeymap }
    '../infra/keymap': { KeyMap }
    '../infra/text-search.ls': text-search
    './editor-base': { setup, events }
    './edit-items.ls': { VisitedFiles, FileEdit }
    '../ide/problems.ls': { safe }
}

require 'codemirror/lib/codemirror.css'
require 'codemirror/addon/dialog/dialog.css'
require './editor.css'



class TeXEditor extends EventEmitter
  (@containing-element) ->
    @cm = new EditorView do
      state: EditorState.create do
        extensions: [setup]
      parent: @containing-element?0

    @_configure-keymap!
    window <<<< {events}

    @containing-element[0].addEventListener 'blur' (ev) ->
      if ev.relatedTarget == null then ev.stopPropagation!
    , {+capture}

    @visited-files = new VisitedFiles
    @_open-reent = 0

    @dialog = new DialogMixin(@)
    @search = new SearchMixin(@)
    @jumps = new JumpToMixin(@)

  open: (locator, props={}) ->>
    @_pre-load! ; reent = ++@_open-reent
    locator = @_normalize-loc locator
    @loc = locator
    try
      if locator.p2p-uri      => await @open-syncpad locator, props
      else if locator.volume  => await @open-file locator, props
      else
        throw new Error "invalid document locator: '#{locator}'"
    catch e
      if reent == @_open-reent then @loc = null  # @oops another `open` may have started in the meantime
      throw e

  open-file: (locator, props={}) ->
    @visited-files.enter @cm, locator, -> new FileEdit(locator) <<< props
    .then ~> @emit 'open', {type: 'file', loc: locator, uri: locator.filename}

  open-syncpad: (locator, props={}) ->
    require! '../net/p2p.ls': { SyncPadEdit }
    @visited-files.enter @cm, locator, -> new SyncPadEdit(locator) <<< props
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
      await @open loc, {scroll: null}
    /* @oops still need to wait; because open might have been in progress when this was called */
    requestAnimationFrame ~>
      if line? then set-cursor @cm, {line, ch: ch ? 0}
      if focus then @cm.focus!

  track-line: (on-move) -> new LineTracking(@cm, on-move)
  stay-flag: -> new StayFlag(@cm)

  _normalize-loc: (loc) ->
    if loc.volume?path
      loc = {...loc, loc.volume, filename: loc.volume.path.normalize loc.filename}
      if !loc.filename.startsWith('/') then loc.filename = '/' + loc.filename
    loc

  _configure-keymap: ->
    new KeyMap do
      "Mod-S": @~save
    .attach @containing-element.0

  pos:~
    -> {@loc, at: get-cursor @cm}

  state:~
    -> {@loc, cursor: get-cursor @cm}
    (v) ->
      safe ~> v.loc && @jump-to v.loc, v.cursor, false

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
    # Allow scrolling up when dialog covers the first few lines of text,
    # like in Atom
    @cm.getScrollerElement!
      ..scrollTop += height; ..style.paddingTop = "#{height}px";
      cleanup = ~>
        ..scrollTop -= height; ..style.paddingTop = ""
        @active = void

    @active = new @@Dialog(@cm) <<< do
      $el: $('<div>').addClass('ide-editor-dialog').css(height: "#{height}px") \
                     .appendTo(@containing-element)
      height: height
      close: ->
        if @$el.find(':focus') then @cm.focus!
        @$el.remove! ; cleanup! ; @emit 'close'

  class @Dialog extends EventEmitter
    (@cm) ->


class SearchMixin
  (@_) ->
    @flags = 'i'
    @keymap =
      Down: @~focus-fwd
      Up: @~focus-bwd
  cm:~ -> @_.cm
  dialog:~ -> @_.dialog
  jumps:~ -> @_.jumps

  start: ->
    @dialog.open @@DIALOG_HEIGHT
      ..controls = $('<div>').addClass('ide-editor-dialog-content')
        ..append $('<span>').addClass('🔎').text('🔎')
        ..append ..box = $('<input>').addClass('search-box')
        ..append ..nav-down = $('<button>').addClass('▼')
        ..append ..nav-up = $('<button>').addClass('▲')
      ..$el.append ..controls
      ..controls.box.on 'input' (-> ..emit 'input', ..controls.box.val!)
        ..on 'keydown' ~> @keymap[CodeMirror.keyName(it)]?! && it.preventDefault!
        ..on 'focus' ~> @origin-pos = @cm.getCursor!
        ..focus!
      ..controls.nav-up.on 'click' ~> @focus-bwd!
      ..controls.nav-down.on 'click' ~> @focus-fwd!
      ..on 'input' ~> @show it
      ..on 'close' ~> @hide!
  
  show: (query) !->
    @hide!
    @query = @@Query.promote(query, @flags)
      @results = @_matches ..
    @cm.addOverlay @overlay = new @@Overlay(@query)
    @focus-fwd @origin-pos

  hide: !-> if @overlay then @cm.removeOverlay that

  focus-fwd: (pos = @cm.getCursor!) ->
    idx = @cm.indexFromPos(pos)
    @results.find(-> it.index >= idx)
      .. && @jumps.focus-around ..

  focus-bwd: (pos = @cm.getCursor('from')) ->
    idx = @cm.indexFromPos(pos)
    [...@results].reverse!find(-> it.index < idx)
      .. && @jumps.focus-around ..

  _matches: (query) -> query.all(@cm.getValue!).map (mo) ~>
    at = (offset) ~> @cm.posFromIndex(mo.index + offset)
    {mo.index, from: at(0), to: at(mo.0.length)}

  @Query = text-search.Query

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


set-cursor = (cm, pos) ->
  if typeof pos != 'number' then pos = pos-to-offset(cm, pos)
  cm.dispatch cm.state.update do
    selection: EditorSelection.create([EditorSelection.cursor(pos)])
    effects: EditorView.scrollIntoView pos, y: 'center'

get-cursor = (cm) ->
  offset-to-pos cm, cm.state.selection.asSingle().ranges[0].from

pos-to-offset = (cm, pos) ->
  cm.state.doc.line(pos.line).from + pos.ch

offset-to-pos = (cm, offset) ->
  line = cm.state.doc.lineAt(offset)
  {line: line.number, ch: offset - line.from}


class JumpToMixin
  (@_) ->
  cm:~ -> @_.cm
  dialog:~ -> @_.dialog

  focus-around: (pos, clearance = @@DEFAULT_CLEARANCE) ->
    if pos.from? && pos.to? then @cm.setSelection pos.from, pos.to
    else @cm.setCursor pos
    # Need to let CodeMirror reposition the cursor first
    requestAnimationFrame ~> @make-clearance clearance

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
  (@emitter, @event-type, @handler) ->
    @emitter.on @event-type, @handler
  destroy: ->
    @emitter.off @event-type, @handler

/** Adapter for CodeMirror 6 events */
class CMEventHook extends EventHook
  (@cm, event-type, handler) ->
    super cm.state.field(events), event-type, handler

/**
 * Notifies whenever the current line changes.
 */
class LineTracking extends CMEventHook
  (cm, on-move) ->
    at-line = cm.getCursor!line
    super cm, 'cursorActivity', ~>
      l = @cm.getCursor!line
      if l != at-line then at-line := l; on-move!


/**
 * This flag is `true` as long as the cursor was not moved.
 */
class StayFlag extends CMEventHook
  (cm) ->
    @value = true
    super cm, 'cursorActivity', ~>
      @value = false; @destroy!



export TeXEditor, DialogMixin, SearchMixin, JumpToMixin
