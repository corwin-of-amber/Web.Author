require! {
    assert
    lodash: _
    codemirror: CodeMirror
    '../infra/fs-watch.ls': {FileWatcher}
}


class VisitedFiles
  ->
    @info = new LocationMap

  get: (key, gen) ->
    if (rec = @info.get(key))? then rec
    else gen(key)
      @info.set key, ..

  enter: (cm, key, gen) ->> await (e = @get key, gen).enter cm ; e
  leave: (cm, key) ->       @get key, (->) ?.leave cm
  save:  (cm, key) ->       @get key, (-> assert false) .save cm


class LocationMap
  -> @map = new Map
  get: (loc) ->
    if (sub = @map.get(loc.volume)) then sub.get(loc.filename)
  set: (loc, value) ->
    if !(sub = @map.get(loc.volume)) then @map.set loc.volume, sub = new Map
    sub.set loc.filename, value


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
  (@loc) -> super! ; @rev = {}
  
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
    content-type = detect-content-type(@loc.filename) || cm.getOption('mode')
    @doc = new CodeMirror.Doc(txt, content-type, , \
                              detect-line-ends(txt))
    @rev.generation = @doc.changeGeneration!
    @rev.timestamp = @_timestamp!

  _read: ->>  # @todo async?
    @loc.volume.readFileSync(@loc.filename, 'utf-8')

  _write: ->>  # @todo async?
    @loc.volume.writeFileSync @loc.filename, @doc.getValue!

  _timestamp: -> @loc.volume.statSync(@loc.filename).mtimeMs

  watch: (cm) ->
    try @rev.timestamp = @_timestamp!
    catch => return
    @watcher ?= new FileWatcher! .on 'change' (~> @_reload cm)
      ..single @loc.filename, fs: @loc.volume

  unwatch: ->
    @watcher?clear! ; @watcher = null

  changed-on-disk: ->
    try @_timestamp! != @rev.timestamp
    catch => false

  _reload: (cm) ->>
    if @changed-on-disk!
      console.log 'reload', @loc.filename
      @enter cm


detect-line-ends = (txt) ->
  eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
  _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'


detect-content-type = (filename) ->
  if filename.match(/[.](html|wp)$/) then 'text/html'
  else if filename.match(/[.](tex|sty)$/) then 'stex'
  else undefined


export VisitedFiles, EditItem, FileEdit