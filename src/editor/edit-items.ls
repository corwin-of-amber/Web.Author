node_require = global.require ? (->)
    fs = .. 'fs'
require! {
    assert
    lodash: _
    'dat-p2p-crowd/src/ui/syncpad': {SyncPad}
    '../infra/fs-watch.ls': {FileWatcher}
}


class VisitedFiles
  ->
    @info = new Map

  get: (key, gen) ->
    if (rec = @info.get(key))? then rec
    else gen(key)
      @info.set key, ..

  enter: (cm, key, gen) -> (e = @get key, gen).enter cm ; e
  leave: (cm, key) ->      @get key, (->) ?.leave cm
  save:  (cm, key) ->      @get key, (-> assert false) .save cm


class EditItem
  enter: (cm) ->>
    if @doc?                => cm.swapDoc @doc
    if (sel = @selections)? => cm.setSelections sel
    if (scroll = @scroll)?  => cm.scrollTo scroll.left, scroll.top

  leave: (cm) -> @checkpoint cm

  checkpoint: (cm) ->
    @selections = cm.listSelections!
    @scroll = cm.getScrollInfo!


class FileEdit extends EditItem
  (@filename) -> super! ; @rev = {}
  
  enter: (cm) ->>
    if !@doc? || @changed-on-disk! then await @load cm
    super cm
    @watch cm

  save: (cm) ->>
    assert.equal cm.getDoc!, @doc
    @unwatch! ; await @_write! ; @watch cm
    @rev.generation = @doc.changeGeneration!

  leave: (cm) -> @unwatch! ; super cm

  load: (cm) ->>
    txt = await @_read!
    @doc = new CodeMirror.Doc(txt, cm.getOption('mode'), , \
                              detect-line-ends(txt))
    @rev.generation = @doc.changeGeneration!
    @rev.timestamp = @_timestamp!

  _read: -> new Promise (resolve, reject) ~>
    err, txt <~ fs.readFile @filename, 'utf-8'
    if err? then reject err else resolve txt

  _write: -> new Promise (resolve, reject) ~>
    err, txt <~ fs.writeFile @filename, @doc.getValue!
    if err? then reject err else resolve txt

  _timestamp: -> fs.statSync(@filename).mtimeMs

  watch: (cm) ->
    try @rev.timestamp = @_timestamp!
    catch => return
    @watcher ?= new FileWatcher! .on 'change' (~> @_reload cm)
      ..single @filename

  unwatch: ->
    @watcher?clear! ; @watcher = null

  changed-on-disk: ->
    try @_timestamp! != @rev.timestamp
    catch => false

  _reload: (cm) ->>
    if @changed-on-disk!
      console.log 'reload', @filename
      @checkpoint cm
      await @load cm
      @watch! ; @enter cm


class SyncPadEdit extends EditItem
  (@slot) ->

  enter: (cm) ->
    @pad = new SyncPad(cm, @slot)
      ..ready.then ~> super cm

  leave: (cm) -> @pad.destroy! ; super cm


detect-line-ends = (txt) ->
  eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
  _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'



export VisitedFiles, EditItem, FileEdit, SyncPadEdit