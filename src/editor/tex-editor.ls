node_require = global.require ? -> {}
fs = node_require 'fs'
require! { 
    lodash: _
    'dat-p2p-crowd/src/ui/syncpad': {SyncPad}
    '../viewer/viewer.ls': {FileWatcher}
}



class TeXEditor
  (@containing-element) ->
    @cm = new CodeMirror @containing-element?0, do
      mode: 'stex'
      lineWrapping: true
      lineNumbers: true

    Ctrl = if @@is-mac then "Cmd" else "Ctrl"

    @cm.addKeyMap do
      "#{Ctrl}-S": @~save

    @watcher = new FileWatcher  /* defined in viewer.ls :/ */
      ..on 'change' @~reload
    
    @file-positions = new Map

  open: (locator, unless-identical=void) ->
    if _.isString(locator)      => @open-file locator, unless-identical
    else if _.isObject(locator) => @open-syncpad locator
    else
      throw new Error "invalid document locator: '#{locator}'"

  open-file: (filename, unless-identical=void) -> new Promise (resolve, reject) ~>
    @_pre-load!
    err, txt <~ fs.readFile filename, 'utf-8'
    if err?
      console.error "open in editor:", err
      reject err
    else
      try
        if txt != unless-identical
          @cm.setOption 'lineSeparator' @@detect-line-ends(txt)
          @cm.setValue txt
          @_last-file-contents = txt
          @filename = filename
            @watcher.single ..
          @_recall-positions!
        resolve @
      catch e => reject e

  open-syncpad: (slot) ->
    @_pre-load!
    @pad = new SyncPad(@cm, slot)
    @filename = slot.uri
    @pad.ready.then ~> @watcher.clear! ; @_recall-positions!

  _pre-load: ->
    @_remember-positions!
    if @pad then @pad.destroy! ; @pad = null

  reload: ->
    if @filename then @open that, @_last-file-contents

  save: ->
    if @filename?
      @watcher.clear!
      @cm.getValue!
        @_last-file-contents = ..
        fs.writeFile @filename, .., ~>
          @watcher.single @filename

  jump-to: (filename, {line, ch}={}) ->>
    if filename != @filename
      await @open filename
    if line?
      @cm.setCursor {line: line - 1, ch: ch ? 0}
      @cm.scrollIntoView null, 150
    requestAnimationFrame ~> @cm.focus!

  _remember-positions: ->
    if @filename
      @file-positions.set @filename, do
        selections: @cm.listSelections!
        scroll: @cm.getScrollInfo!

  _recall-positions: ->
    if @filename && (rec = @file-positions.get(@filename))?
      @cm.setSelections rec.selections
      @cm.scrollTo rec.scroll.left, rec.scroll.top

  @is-mac = navigator.appVersion is /Mac/

  @detect-line-ends = (txt) ->
    eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
    _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'


export TeXEditor
