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
      @vue.loc = ..loc
      @add-recent ..loc
      @emit 'open', project: ..
      doc = if last-file then ..get-file(last-file.filename) else ..get-main-tex-file!
      if doc? then @emit 'file:select', loc: doc
  
  open-dialog: ->>
    dir = await @file-dialog.open!
    @open dir

  refresh: -> @vue.$refs.files.refresh!

  build: ->>
    if !@_builder?
      @_builder = @current.builder()
        ..on 'started' ~> @vue.build-status = 'in-progress'; @emit 'build:started' it
        ..on 'finished' ~> @vue.build-status = it.outcome; @emit 'build:finished' it
        ..on 'progress' ~> @emit 'build:progress' it
    @_builder.make-watch!

  unbuild: ->
    if @_builder? then @_builder = void
    @vue.build-status = void

  recent:~
    -> @_recent
    (v) -> @_recent = @vue.projects = v

  add-recent: (loc, name) ->
    if ! @lookup-recent loc
      @recent.splice 0, 0, {name: name ? path.basename(loc.path), loc}

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
  (@loc) ->
    @path = @loc.path

  get-main-pdf-path: ->
    @_find-pdf @path  # @todo use loc

  get-main-tex-file: ->
    volume = VolumeFactory.instance.get(@loc)
    glob-all(['*.tex', '**/*.tex'], {exclude: @@IGNORE, cwd: '', fs: volume})
      filename = [...(..)].find ~>
        try      volume.readFileSync(it, 'utf-8').match(/\\documentclass\s*[[{]/)
        catch => false
    filename && {volume, filename}

  get-file: (filename) ->
    volume = VolumeFactory.instance.get(@loc)
      filename = (..path ? path).normalize(filename)
    return {volume, filename}

  builder: ->
    main-tex = @get-main-tex-file!
    if !main-tex then throw new Error('main TeX file not found in project')
    if @loc.scheme == 'file'   # that's one way to decide about it
      new LatexmkBuild main-tex.filename, @path
    else
      new WASI_PDFLatexBuild main-tex

  _find-pdf: (root-dir) ->
    fns = glob-all.sync(Array.from(['out/*.pdf', '*.pdf' ++ @@IGNORE]),
                        {cwd: root-dir})
    main-tex = @get-main-tex-file!
    pdf-matches = -> path.basename(main-tex).startsWith(path.basename(it).replace(/pdf$/, ''))
    if main-tex? && (fn = fns.find(pdf-matches)) then ;
    else fn = fns[0]
    fn && path.join(root-dir, fn)

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
        @volume = VolumeFactory.instance.get(@loc)
        @files.splice 0, Infinity, ...dir-tree-sync('', {fs: @volume, exclude: FOLDER_IGNORE})


const FOLDER_IGNORE = new MultiMatch([/^\.git$/])

ProjectView.content-plugins.folder.push (loc) ->
  if loc.scheme in ['file', 'memfs'] then 'source-folder.directory'



export ProjectView, TeXProject
