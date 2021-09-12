node_require = global.require ? (->)
  path = .. 'path'
require! {
    fs
    events: {EventEmitter}
    lodash: _
}


class FileWatcher extends EventEmitter
  (debounce-ms=250) ->
    super!
    @watches = []
    @debounce-emit = _.debounce ((tag, ev) ~> @emit tag, ev), debounce-ms
    if (typeof window !== 'undefined')
      window.addEventListener('unload', @~clear)

  add: (filename, opts={}) !->
    _fs = opts.fs ? fs
    if !_fs?watch then return  # filesystem does not support watching
    filename .= replace(/^file:\/\//, '')
    console.log "%cwatch #{filename}", 'color: #999'
    bind = ~> @handler filename, ...&
    @watches.push _fs.watch(filename, opts{recursive ? false, persistent ? false}, bind)

  clear: !->
    for @watches => ..close!
    @watches = []

  single: (filename, opts) !-> @clear! ; @add filename, opts
  multiple: (filenames) !-> @clear! ; for filenames => @add ..

  handler: (origin, ev, filename) ->
    setTimeout ~> 
      console.log "%cchanged: #{filename}  [#{origin}]" 'color: #ccf'
      @debounce-emit 'change', {origin, filename}
    , 0


/** @deprecated */
class _FileWatcher extends EventEmitter
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


#FileWatcher.dir = new DirectoryWatcher



export FileWatcher