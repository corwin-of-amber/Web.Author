require! {
  fs, path, os
  events: { EventEmitter }
  lodash: _
  'vue': { default: Vue }
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../infra/volume': { SubdirectoryVolume }
  '../infra/volume-factory': { VolumeFactory }
  '../infra/fs-watch.ls': { FileWatcher }
  '../infra/fs-traverse.ls': { dir-tree-sync, glob-all, MultiMatch }
  '../infra/file-browse.ls': { FileDialog }
  '../typeset/wasi-pdflatex': { PDFLatexBuild: WASI_PDFLatexBuild }
  '../typeset/latexmk.ls': { LatexmkBuild }
  '../typeset/error-reporting': { BuildLog }
  '../net/local': { VolumeArchive }
  './problems.ls': { safe }
}

project-view-component = require('./components/project-view.vue').default



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @_recent = []

    @vue = new Vue project-view-component
    .$mount!
      ..projects = @_recent

    @vue.$on 'action' @~action
    @vue.$on 'build' @~build
    @vue.$on 'select' ~> @emit 'file:select', loc: @current.get-file(it)
    @vue.$on 'error:goto-log' @~error-goto-log
    @vue.$on 'error:goto-source' @~error-goto-source

    @file-dialog = new FileDialog(/*select-directory*/true)

    @on 'build:started' ~> @vue.build-status = 'in-progress'
    @on 'build:finished' ~> @vue.build-status = it.outcome; @update-built it

  volume:~ -> @current?volume

  action: (ev) ->
    console.log ev
    switch ev.type
    | 'new' => @create-new!
    | 'open' => @open ev.item
    | 'open...' => @open-dialog!
    | 'refresh' => @refresh!
    | 'rename' => @rename-to ev.name
    | 'download:source' => @download-source!
    | 'download:built'  => @download-built!

  has-fs: -> !!fs

  create-new: ->
    proj-dir = VolumeFactory.get {scheme: 'memfs', path: "/proj"}
      ..mkdirSync '/', {+recursive}
      existing = ..readdirSync('/')
    i = 0
    while (d = "toxin-#{i}") in existing => i++
    TeXProject.create {scheme: 'memfs', path: "/proj/#{d}"}
      ..name = 'new-project'
      ..volume.writeFileSync 'main.tex', ''
      @open ..
      @emit 'file:select' {loc: ..get-file('main.tex'), +focus}

  open: (project) ->
    @_watch?clear!
    @unbuild!
    last-file = project.last-file
    project = TeXProject.promote(project)
    @current = project
      @vue <<< {..loc, ..name, opts: ..get-folder-opts!}
      @_watch = ..watch-config!on 'change' ~> @vue.opts = ..get-folder-opts!
      @add-recent ..loc
      @emit 'open', project: ..
      doc = if last-file then ..get-file(last-file.filename) else ..get-main-tex-file!
      if doc? then @emit 'file:select', loc: doc
  
  open-recent: (name) ->
    @open @recent.find(-> it.name == name) ? \
          TeXProject.create {scheme: 'memfs', path: "/proj/#{name}"}

  open-dialog: ->>
    dir = await @file-dialog.open!
    @open dir

  refresh: -> @vue.$refs.files.refresh!

  rename-to: (name) ->
    @current.name = name
    @lookup-recent(@current.loc)?name = name

  build: ->>
    @current.sync?!
    if !@_builder?
      @_builder = @current.builder()
        ..on 'started' ~> @emit 'build:started' it
        ..on 'finished' ~> @emit 'build:finished' it
        ..on 'progress' ~> @emit 'build:progress' it
        ..on 'intermediate' ~> @emit 'build:intermediate' it
    else
      @_builder.set-main @current.get-main-tex-file!
    @_builder.remake-watch!

  unbuild: ->
    @_builder?unwatch!
    @_builder = void
    @_built = void
    @vue.build-status = void

  update-built: (build-result) ->
    @_built = build-result; @update-log build-result

  update-log: (build-result) ->
    if (log = build-result.log ? build-result.error?log)?
      log.log.saveAs? @current.get-file('out/build.log')
      @build-log = log
        @vue.build-errors = ..errors
        console.log ..errors
    else
      @build-log = null
      @vue.build-errors = []
    if (out = build-result.out ? build-result.error?out)?
      out.saveAs? @current.get-file('out/build.out')
    @refresh!

  error-goto-log: ({error}) ->
    @current.get-file(error.inLog.log.loc.filename)
      @select .., {silent: true}
      @emit 'file:jump-to' loc: .., cursor: {error.inLog.offset}

  error-goto-source: ({error}) ->
    @current.get-file(error.at.filename)
      @select .., {silent: true}
      @emit 'file:jump-to' loc: .., cursor: {error.at.line}

  select: (loc, {type ? 'file', silent ? false} ? {}) ->
    if loc.volume == @volume
      @current.visit loc
      @lookup-recent(@current.loc)?last-file = {type, loc.filename}
      @vue.$refs.files.select loc.filename, {silent}

  recent:~
    -> @_recent
    (v) -> @_recent = @vue.projects = v

  add-recent: (loc, name, where_ = 'start') ->
    if p = @lookup-recent loc
      name && p.name = name ; p.loc <<< loc  # update record
    else
      name ?= path.basename(loc.path)
      if where_ == 'start' then @recent.unshift {name, loc}
                           else @recent.push {name, loc}

  lookup-recent: (loc) ->
    @recent.find(-> it.loc{scheme, path} === loc{scheme, path})

  download-source: ->
    new VolumeArchive(@volume).downloadZip("#{@current.name}.zip")

  download-built: ->
    VolumeArchive.download @_built.pdf.content, "#{@current.name}.pdf"

  state:~
    -> {current: @current{loc, name}, @recent}
    (v) ->
      if v.recent? then @recent = v.recent
      if v.current? then safe ~> @open v.current

  @content-plugins = {folder: []}

  @detect-folder-source = (loc) ->
    @content-plugins.folder.map(-> it(loc)).find(-> it)
      if !..? then throw new Error "invalid folder path '#{path}'"
  

class TeXProject
  (@loc, @name) ->
    @path = @loc.path
    @name ?= path.basename(loc.path)
    @transient-config = {}

  volume:~
    -> VolumeFactory.get(@loc)

  create: ->
    @volume.mkdirSync '/', recursive: true

  get-main-pdf-path: ->
    @_find-pdf @path  # @todo use loc

  get-main-tex-file: ->
    volume = @volume
    if !(filename = @transient-config?main ? @get-config!?main)?
      glob-all(['*.tex', '**/*.tex'], {exclude: @_ignored, cwd: '', fs: volume})
        filename = [...(..)].find ~> @_is-document({volume, filename: it})
    filename && @get-file filename

  get-file: (filename) ->
    if filename.startsWith('/') and @loc.scheme == 'file'
      filename = path.relative(@loc.path, filename)
    volume = @volume
      filename = (..path ? path).normalize(filename)
    return {volume, filename}

  get-config: ->
    volume = @volume
    [...glob-all(['toxin.json', 'project.json'], {cwd: '', fs: volume, -recursive})]
    .map ~>
      try      JSON.parse(volume.readFileSync(it)) <<< {file: @get-file(it)}
      catch => void
    .find ~> it

  get-folder-opts: ->
    if @get-config! then that{ignore}

  watch-config: -> new FileWatcher
    if @get-config! then ..add that.file.filename, fs: that.file.volume

  builder: ->
    main-tex = @get-main-tex-file!
    if !main-tex then throw new Error('main TeX file not found in project')
    if @loc.scheme == 'file'   # that's one way to decide about it
      new LatexmkBuild main-tex, @path
    else
      new WASI_PDFLatexBuild main-tex

  visit: (loc) ->
    if @get-config!?mode == 'browse' && @_is-document(loc)
      @transient-config.main = @volume.path.relative('/', loc.filename)

  _find-pdf: (root-dir) ->
    fns = [...glob-all(['out/*.pdf', '*.pdf'],  /** @todo  out/*.pdf is currently defunct due to fs-traverse broken semantics */
                       {exclude: @_ignored, cwd: '', fs: @volume})]
    main-tex = @get-main-tex-file!
    pdf-matches = -> path.basename(main-tex).startsWith(path.basename(it).replace(/pdf$/, ''))
    if main-tex? && (fn = fns.find(pdf-matches)) then ;
    else fn = fns[0]
    fn && path.join(root-dir, fn)

  _is-document: ({volume, filename}) ->
    try      volume.readFileSync(filename, 'utf-8') \
               .match(/^\s*\\documentclass\s*[[{]/)
    catch => false

  _ignored:~ -> @@IGNORE ++ (@get-config!?ignore ? [])

  @promote = (loc) ->
    if loc instanceof TeXProject then return loc

    name = loc.name
    loc = loc.loc ? loc   # huh

    if typeof loc == 'string'
      path = loc.replace(/^file:\/\//, '').replace(/^~/, os.homedir())
      loc = {scheme: 'file', path}

    if loc.scheme?
      new TeXProject(loc, name)
    else
      throw new Error("invalid project specifier '#{uri}'");

  @create = (loc) -> new TeXProject(loc)
    ..create!

  @IGNORE = ['_*', '.*']  # for fs-traverse.glob-all



Vue.component 'source-folder.directory', do
  props: ['loc', 'opts']
  data: -> files: []
  render: -> document.createElement('span')   # dummy element
  mounted: ->
    #@$watch 'loc' @~refresh, {+immediate}
    @$watch (-> @{loc,opts}), @~refresh, {+immediate}
  methods:
    refresh: ->
      if @loc
        @volume = VolumeFactory.get(@loc)
        exclude = FOLDER_IGNORE ++ (@opts?ignore ? [])
        dir-tree-sync('', {fs: @volume, exclude}) |> sort-content
          @files.splice 0, Infinity, ... ..


const FOLDER_IGNORE = ['.git']  # for fs-traverse.glob-all

sort-content = (dir-entries, order=tex-first) ->
  for e in dir-entries
    if e.files then sort-content e.files
  _.sortBy dir-entries, order

tex-first = ({name}) ->
  | name is /[.]sty$/ => 0
  | name is /[.]tex$/ => 1
  | _ => 2


ProjectView.content-plugins.folder.push (loc) ->
  if loc.scheme in ['file', 'memfs'] then 'source-folder.directory'


window <<< {dir-tree-sync}
export ProjectView, TeXProject
