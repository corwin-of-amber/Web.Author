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
    origin = {fs: _fs, filename, opts, mtime: 0}
    bind = ~> @handler origin, ...&
    @watches.push _fs.watch(filename, opts{recursive ? false, persistent ? false}, bind)

  clear: !->
    for @watches => ..close!
    @watches = []

  single: (filename, opts) !-> @clear! ; @add filename, opts
  multiple: (filenames) !-> @clear! ; for filenames => @add ..

  handler: (origin, ev, filename) ->
    setTimeout ~>
      mtime = if origin.opts.recursive then void
              else origin.fs.statSync(origin.filename).mtimeMs
      console.log "%cchanged: #{filename}  #{mtime}  [#{origin.filename}]" 'color: #ccf'
      if (!mtime? || mtime != origin.mtime)
        origin.mtime = mtime
        @debounce-emit 'change', {origin, filename}
    , 0


export FileWatcher