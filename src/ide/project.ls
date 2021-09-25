node_require = global.require ? ->
fs = node_require 'fs'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'vue': Vue
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../infra/volume': { SubdirectoryVolume }
  '../infra/volume-factory': { VolumeFactory }
  '../infra/fs-watch.ls': { FileWatcher }
  '../infra/fs-traverse.ls': { dir-tree-sync, glob-all, MultiMatch }
  '../infra/file-browse.ls': { FileDialog }
  '../typeset/wasi-pdflatex': { PDFLatexBuild: WASI_PDFLatexBuild }
  '../typeset/latexmk.ls': { LatexmkBuild }
  './problems.ls': { safe }
}

project-view-component = require('./components/project-view.vue').default



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @_recent = []

    @vue = new Vue project-view-component <<<
      methods:
        select: ~> @emit 'file:select', loc: {@volume, filename: it}
        action: ~> @action it
        build: ~> @build!
    .$mount!
      ..projects = @_recent

    @file-dialog = new FileDialog(/*select-directory*/true)

    @on 'build:started' ~> @vue.build-status = 'in-progress'
    @on 'build:finished' ~> @vue.build-status = it.outcome; @update-log it

  volume:~
    -> @vue.$refs.files.$refs.source.volume

  action: ({type, item}) ->
    switch type
    | 'open' => @open item
    | 'open...' => @open-dialog!
    | 'refresh' => @refresh!

  has-fs: -> !!fs

  open: (project) ->
    @unbuild!
    last-file = project.last-file
    project = TeXProject.promote(project)
    @current = project
      @vue.loc = ..loc; @vue.name = ..name
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

  build: ->>
    if !@_builder?
      @_builder = @current.builder()
        ..on 'started' ~> @emit 'build:started' it
        ..on 'finished' ~> @emit 'build:finished' it
        ..on 'progress' ~> @emit 'build:progress' it
        ..on 'intermediate' ~> @emit 'build:intermediate' it
    else
      @_builder.set-main @current.get-main-tex-file!
    @_builder.make-watch!

  unbuild: ->
    if @_builder? then @_builder = void
    @vue.build-status = void

  update-log: (build-result) ->
    if (log = build-result.log ? build-result.error?log)?
      log.saveAs(@current.get-file('out/build.log'))
      @refresh!

  select: (loc, {type ? 'file', silent ? false} ? {}) ->
    if loc.volume == @volume
      @current.visit loc
      @lookup-recent(@current.loc)?last-file = {type, loc.filename}
      @vue.$refs.files.select(loc.filename, silent)

  recent:~
    -> @_recent
    (v) -> @_recent = @vue.projects = v

  add-recent: (loc, name, where_ = 'start') ->
    if ! @lookup-recent loc
      name ?= path.basename(loc.path)
      if where_ == 'start' then @recent.unshift {name, loc}
                           else @recent.push {name, loc}

  lookup-recent: (loc) -> @recent.find(-> it.loc === loc)

  state:~
    -> {loc: @current?loc, @recent}
    (v) ->
      if v.recent? then @recent = v.recent
      if v.loc? then safe ~> @open v.loc

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
    @volume.mkdirSync @loc.path, recursive: true

  get-main-pdf-path: ->
    @_find-pdf @path  # @todo use loc

  get-main-tex-file: ->
    volume = @volume
    if !(filename = @transient-config?main ? @get-config!?main)?
      glob-all(['*.tex', '**/*.tex'], {exclude: @@IGNORE, cwd: '', fs: volume})
        filename = [...(..)].find ~> @_is-document({volume, filename: it})
    filename && {volume, filename}

  get-file: (filename) ->
    volume = @volume
      filename = (..path ? path).normalize(filename)
    return {volume, filename}

  get-config: ->
    volume = VolumeFactory.get(@loc)
    [...glob-all(['toxin.json', 'project.json'], {cwd: '', fs: volume})]
    .map ~>
      try      JSON.parse(volume.readFileSync(it))
      catch => void
    .find -> it

  builder: ->
    main-tex = @get-main-tex-file!
    if !main-tex then throw new Error('main TeX file not found in project')
    if @loc.scheme == 'file'   # that's one way to decide about it
      new LatexmkBuild main-tex.filename, @path
    else
      new WASI_PDFLatexBuild main-tex

  visit: (loc) ->
    if @get-config!?mode == 'browse' && @_is-document(loc)
      @transient-config.main = @volume.path.relative('/', loc.filename)

  _find-pdf: (root-dir) ->
    fns = glob-all.sync(Array.from(['out/*.pdf', '*.pdf' ++ @@IGNORE]),
                        {cwd: root-dir})
    main-tex = @get-main-tex-file!
    pdf-matches = -> path.basename(main-tex).startsWith(path.basename(it).replace(/pdf$/, ''))
    if main-tex? && (fn = fns.find(pdf-matches)) then ;
    else fn = fns[0]
    fn && path.join(root-dir, fn)

  _is-document: ({volume, filename}) ->
    try      volume.readFileSync(filename, 'utf-8').match(/\\documentclass\s*[[{]/)
    catch => false

  @promote = (loc) ->
    if loc instanceof TeXProject then return loc

    loc = loc.loc ? loc   # huh

    if typeof loc == 'string'
      path = loc.replace(/^file:\/\//, '').replace(/^~/, process.env['HOME'])
      loc = {scheme: 'file', path}

    if loc.scheme?
      new TeXProject(loc)
    else
      throw new Error("invalid project specifier '#{uri}'");

  @create = (loc) -> new TeXProject(loc)
    ..create!

  @IGNORE = ['_*/**', '.*/**']  # for glob-all



Vue.component 'source-folder.directory', do
  props: ['loc']
  data: -> files: []
  render: -> document.createElement('span')   # dummy element
  mounted: ->
    @$watch 'loc' @~refresh, {+immediate}
  methods:
    refresh: ->
      if @loc
        @volume = VolumeFactory.get(@loc)
        @files.splice 0, Infinity, ...sort-content(
          dir-tree-sync('', {fs: @volume, exclude: FOLDER_IGNORE}))


const FOLDER_IGNORE = new MultiMatch([/^\.git$/])

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



export ProjectView, TeXProject
