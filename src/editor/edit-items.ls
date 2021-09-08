require! {
    assert
    lodash: _
    codemirror: CodeMirror
    '../infra/fs-watch.ls': {FileWatcher}
}


class VisitedFiles
  ->
    @info = new Map

  get: (key, gen) ->
    if (rec = @info.get(key))? then rec
    else gen(key)
      @info.set key, ..

  enter: (cm, key, gen) ->> await (e = @get key, gen).enter cm ; e
  leave: (cm, key) ->       @get key, (->) ?.leave cm
  save:  (cm, key) ->       @get key, (-> assert false) .save cm


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
  (@volume, @filename) -> super! ; @rev = {}
  
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
    content-type = detect-content-type(@filename) || cm.getOption('mode')
    @doc = new CodeMirror.Doc(txt, content-type, , \
                              detect-line-ends(txt))
    @rev.generation = @doc.changeGeneration!
    @rev.timestamp = @_timestamp!

  _read: ->>  # @todo async?
    @volume.readFileSync(@filename, 'utf-8')

  _write: ->>  # @todo async?
    @volume.writeFileSync @filename, @doc.getValue!

  _timestamp: -> @volume.statSync(@filename).mtimeMs

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


detect-line-ends = (txt) ->
  eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
  _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'


detect-content-type = (filename) ->
  if filename.match(/[.](html|wp)$/) then 'text/html'
  else if filename.match(/[.](tex|sty)$/) then 'stex'
  else undefined


export VisitedFiles, EditItem, FileEdit