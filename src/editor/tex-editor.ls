
is-mac = navigator.appVersion is /Mac/


class TeXEditor
  (@containing-element) ->
    @cm = new CodeMirror @containing-element?0, do
      mode: 'stex'
      lineWrapping: true
      lineNumbers: true

    Ctrl = if is-mac then "Cmd" else "Ctrl"

    @cm.addKeyMap do
      "#{Ctrl}-S": @~save

  open: (filename) -> new Promise (resolve, reject) ~>
    require! fs
    err, txt <~ fs.readFile filename, 'utf-8'
    if err?
      console.error "open in editor:", err
      reject err
    else
      @cm.setValue txt
      @filename = filename
      resolve @

  save: ->
    if @filename?
      require! fs
      fs.writeFile @filename, @cm.getValue!, ->

  jump-to: (filename, {line, ch}) ->>
    await @open filename
    if line?
      @cm.setCursor {line: line - 1, ch: ch ? 0}
      @cm.focus!


export TeXEditor
