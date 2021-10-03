node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    events: {EventEmitter}
    lodash: _
    codemirror: CodeMirror
    'codemirror/mode/stex/stex'
    'codemirror/mode/htmlmixed/htmlmixed'
    'codemirror/addon/dialog/dialog'
    'codemirror/addon/search/searchcursor'
    'codemirror/addon/search/search'
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

  open: (locator) ->>
    locator = @_normalize-loc locator
    if locator.p2p-uri      => await @open-syncpad locator
    else if locator.volume  => await @open-file locator
    else
      throw new Error "invalid document locator: '#{locator}'"
    @loc = locator

  open-file: (locator) ->
    @_pre-load!
    @visited-files.enter @cm, locator, -> new FileEdit(locator)
    .then ~> @emit 'open', {type: 'file', loc: locator, uri: locator.filename}

  open-syncpad: (locator) ->
    require! '../net/p2p.ls': { SyncPadEdit }
    @_pre-load!
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
      "#{Ctrl}-F": 'findPersistent'  # because non-persistent is just silly
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



export TeXEditor
