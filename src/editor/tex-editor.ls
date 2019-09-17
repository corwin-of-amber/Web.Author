node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    events: {EventEmitter}
    lodash: _
    'dat-p2p-crowd/src/ui/syncpad': {SyncPad}
    './edit-items.ls': {VisitedFiles, FileEdit, SyncPadEdit}
}



class TeXEditor extends EventEmitter
  (@containing-element) ->
    @cm = new CodeMirror @containing-element?0, do
      mode: 'stex'
      lineWrapping: true
      lineNumbers: true

    Ctrl = if @@is-mac then "Cmd" else "Ctrl"

    @cm.addKeyMap do
      "#{Ctrl}-S": @~save

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

  open-syncpad: (slot) ->
    @_pre-load!
    @filename = slot.uri
    @visited-files.enter @cm, @filename, -> new SyncPadEdit(slot)

  _pre-load: !->
    if @filename? then @visited-files.leave @cm, @filename

  reload: ->
    if @filename then @open that

  save: ->
    @visited-files.save @cm, @filename

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



export TeXEditor
