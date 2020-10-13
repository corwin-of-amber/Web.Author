node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    events: {EventEmitter}
    lodash: _
    codemirror: CodeMirror
    'codemirror/mode/stex/stex'
    'codemirror/addon/dialog/dialog'
    'codemirror/addon/search/searchcursor'
    'codemirror/addon/search/search'
    'codemirror/addon/selection/mark-selection'
    'codemirror/addon/edit/matchbrackets'
    'codemirror/addon/selection/active-line'
    './edit-items.ls': {VisitedFiles, FileEdit, SyncPadEdit}
}



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
    if _.isString(locator)      => @open-file locator
    else if _.isObject(locator) => @open-syncpad locator
    else
      throw new Error "invalid document locator: '#{locator}'"

  open-file: (filename) ->
    @_pre-load!
    @filename = fs.realpathSync filename
    @visited-files.enter @cm, @filename, -> new FileEdit(it)
    .then ~> @emit 'open', {type: 'file', uri: filename}

  open-syncpad: (slot) ->
    @_pre-load!
    @filename = slot.uri
    @visited-files.enter @cm, @filename, -> new SyncPadEdit(slot)
    .then ~> @emit 'open', {type: 'syncpad', slot.uri, slot}

  _pre-load: !->
    if @filename? then @visited-files.leave @cm, @filename

  reload: ->
    if @filename then @open that

  save: ->
    @visited-files.save @cm, @filename
    if @@is-dat(@filename)
      @emit 'request-save'

  jump-to: (filename, {line, ch}={}) ->>
    try
      filename := fs.realpathSync filename
    catch
    if filename != @filename
      await @open filename
    if line?
      @cm.setCursor {line: line - 1, ch: ch ? 0}
      @cm.scrollIntoView null, 150
    requestAnimationFrame ~> @cm.focus!

  @is-mac = navigator.appVersion is /Mac/

  @is-local-file = (filename) ->
    !filename.match(/^[^/]+:\//)

  @is-dat = (filename) ->
    filename.match(/^dat:\//)



export TeXEditor
