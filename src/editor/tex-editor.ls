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
    './edit-items.ls': { VisitedFiles, FileEdit, SyncPadEdit }
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

    Ctrl = if @@is-mac then "Cmd" else "Ctrl"

    @cm.addKeyMap do
      "#{Ctrl}-S": @~save
      "#{Ctrl}-F": 'findPersistent'  # because non-persistent is just silly

    @containing-element[0].addEventListener 'blur' (ev) ->
      if ev.relatedTarget == null then ev.stopPropagation!
    , {+capture}

    @visited-files = new VisitedFiles

  open: (locator) ->
    @loc = locator
    if locator.volume           => @open-file locator
    #else if _.isObject(locator) => @open-syncpad locator
    else
      throw new Error "invalid document locator: '#{locator}'"

  open-file: (locator) ->
    @_pre-load!
    @visited-files.enter @cm, locator.filename, -> new FileEdit(locator)
    .then ~> @emit 'open', {type: 'file', loc: locator, uri: locator.filename}

  open-syncpad: (slot) ->
    @_pre-load!
    @visited-files.enter @cm, slot.uri, -> new SyncPadEdit(slot)
    .then ~> @emit 'open', {type: 'syncpad', slot.uri, slot}

  _pre-load: !->
    if @loc? then @visited-files.leave @cm, @loc.filename

  reload: ->
    if @loc? then @open-file @loc

  save: ->
    @visited-files.save @cm, @loc.filename
    if @@is-dat(@loc.filename)
      @emit 'request-save'

  jump-to: (loc, {line, ch}={}, focus=true) ->>
    #try
    #  filename := @volume.realpathSync filename
    #catch
    if !@loc || !(loc.volume == @loc.volume && loc.filename == @loc.filename)
      await @open loc
    if line?
      @cm.setCursor {line: line - 1, ch: ch ? 0}  # @todo that -1 is bogus
      @cm.scrollIntoView null, 150
    if focus then requestAnimationFrame ~> @cm.focus!

  state:~
    -> {@loc, cursor: @cm.getCursor!}
    (v) ->
      safe ~> v.loc && @jump-to v.loc, v.cursor, false

  @is-mac = navigator.appVersion is /Mac/

  @is-local-file = (filename) ->
    !filename.match(/^[^/]+:\//)

  @is-dat = (filename) ->
    filename.match(/^dat:\//)



export TeXEditor
