node_require = global.require ? (->)
  fs = .. 'fs'
  path = .. 'path'
require! {
    events: {EventEmitter}
    lodash: _
}


class DirectoryWatcher extends EventEmitter
  ->
    super!
    @dirs = []
    @watches = []
    if (typeof window !== 'undefined')
      window.addEventListener('unload', @~clear)

  add: (dir) !->
    dir .= replace(/^file:\/\//, '')
    @dirs.push dir
    bind = ~> @handler dir, ...&
    @watches.push fs.watch(dir, {recursive: true, persistent: false}, bind)

  clear: !->
    for @watches => ..close!
    @watches = []
    @dirs = []

  single: (dir) !-> @clear! ; @add dir

  handler: (dir, ev, filename) ->
    setTimeout ~> 
      console.log "%cchanged: #{filename}  [#{dir}]" 'color: #ccf'
      @emit 'change' {dir, filename}
    , 0


class FileWatcher extends EventEmitter
  (debounce-ms=500) ->
    super!
    @filenames = []

    @@dir.on 'change' @~handler
    @debounce-emit = _.debounce (ev) ~> @emit 'change' ev, debounce-ms

  add: (filename) !->
    filename .= replace(/^file:\/\//, '')
    console.log "watch #{filename}"
    @filenames.push filename

  clear: !->
    @filenames = []

  single: (filename) !-> @clear! ; @add filename
  multiple: (filenames) !-> @clear! ; for filenames => @add ..

  handler: ({dir, filename}) ->
    filename = path.join(dir, filename)
    if @filenames.includes(filename)
      console.log "%cchanged: #{filename}" 'color: #bbe'
      @debounce-emit {filename}


FileWatcher.dir = new DirectoryWatcher



export FileWatcher