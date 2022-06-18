require! {
    assert
    lodash: _
    'codemirror': { basicSetup }
    '@codemirror/state': { EditorState, EditorSelection }
    '@codemirror/language': { StreamLanguage }
    '@codemirror/legacy-modes/mode/stex': { stex }
    '../infra/fs-watch.ls': { FileWatcher }
    './editor-base': { setup, changeGeneration }
}


class VisitedFiles
  ->
    @info = new LocationMap

  get: (key, gen) ->
    if (rec = @info.get(key))? then rec
    else gen(key)
      .. && @info.set key, ..

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
  delete: (loc) ->
    if (sub = @map.get(loc.volume)) then sub.delete(loc.filename)


class EditItem
  enter: (cm) ->>
    if @doc?                => cm.setState @doc
    if (sel = @selections)? => @_set-selections cm, sel
    if (scroll = @scroll)?  => cm.scroll-to scroll
    else if scroll != null  => cm.scroll-to top: 0, left: 0

  leave: (cm) -> @checkpoint cm

  checkpoint: (cm) ->
    @selections = @_get-selections(cm)
    @scroll = cm.get-scroll!

  _set-selections: (cm, sel) ->
    cm.dispatch {selection: EditorSelection.fromJSON(sel)}
  
  _get-selections: (cm) -> cm.state.selection.toJSON!


class FileEdit extends EditItem
  (@loc) -> super! ; @rev = {}
  
  enter: (cm) ->>
    try
      if !@doc? || @changed-on-disk! then await @load cm
    catch e
      if e instanceof EditCancelled then return else throw e
    await super cm
    @watch cm

  save: (cm) ->>
    assert.equal cm.state.doc, @doc.doc
    @unwatch! ; await @_write! ; @watch cm
    @rev.generation = @doc.field(changeGeneration)

  leave: (cm) -> @unwatch! ; super cm

  make-doc: (cm, text, filename = @loc.filename) ->
    /** @todo do something with content-type (choose language) */
    /** @todo detect line endings in doc */
    content-type = detect-content-type(filename) || 'plain'
    EditorState.create do
      doc: text
      extensions: @_extensions!

  _extensions: -> [setup, new StreamLanguage(stex)]

  load: (cm) ->>
    @doc = @make-doc(cm, await @_read!)
    @rev.generation = @doc.field(changeGeneration)
    @rev.timestamp = @_timestamp!

  _read: ->>  # @todo async?
    @loc.volume.readFileSync(@loc.filename, 'utf-8')

  _write: ->>  # @todo async?
    @loc.volume.writeFileSync @loc.filename, @doc.sliceDoc!

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


class EditCancelled


detect-line-ends = (txt) ->
  eols = _.groupBy(txt.match(/\r\n?|\n/g), -> it)
  _.maxBy(Object.keys(eols), -> eols[it].length) ? '\n'


detect-content-type = (filename) ->
  if filename.match(/[.](html|wp)$/) then 'text/html'
  else if filename.match(/[.](tex|sty)$/) then 'stex'
  else undefined


export VisitedFiles, EditItem, FileEdit, EditCancelled