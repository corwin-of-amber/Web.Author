node_require = global.require ? (->)
  fs = .. 'fs'
require! {
    events: {EventEmitter}
    lodash: _
}


class FileWatcher extends EventEmitter
  ->
    @watches = []
    if (typeof window !== 'undefined')
      window.addEventListener('unload', @~clear)
    
    @debounce-handler = _.debounce @~handler, 500

  add: (filename) !->
    filename .= replace(/^file:\/\//, '')
    @watches.push fs.watch(filename, {persistent: false}, @~debounce-handler)

  clear: !->
    for @watches => ..close!
    @watches = []

  single: (filename) !-> @clear! ; @add filename
  multiple: (filenames) !-> @clear! ; for filenames => @add ..

  handler: (ev, filename) ->
    console.log "%cchanged: #{filename}" 'color: #ccf'
    @emit 'change' {filename}



export FileWatcher