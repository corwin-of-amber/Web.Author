_ = require 'lodash'



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

  open: (filename, unless-identical=void) -> new Promise (resolve, reject) ~>
    require! fs
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
        resolve @
      catch e => reject e

  reload: ->
    if @filename then @open that, @_last-file-contents

  save: ->
    if @filename?
      require! fs
      @watcher.clear!
      @cm.getValue!
        @_last-file-contents = ..
        fs.writeFile @filename, .., ~>
          @watcher.single @filename

  jump-to: (filename, {line, ch}) ->>
    if filename != @filename
      await @open filename
    if line?
      @cm.setCursor {line: line - 1, ch: ch ? 0}
      @cm.scrollIntoView null, 150
      requestAnimationFrame ~> @cm.focus!

  @is-mac = navigator.appVersion is /Mac/

  @detect-line-ends = (txt) ->
    eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
    _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'


export TeXEditor
