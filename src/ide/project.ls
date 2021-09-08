node_require = global.require ? ->
fs = node_require 'fs'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'glob-all': glob-all
  'vue': Vue
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../infra/volume-factory': { VolumeFactory }
  '../infra/fs-watch.ls': { FileWatcher }
  '../infra/file-browse.ls': { FileDialog }
  '../typeset/latexmk.ls': { LatexmkBuild }
}

project-view-component = require('./components/project-view.vue').default



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @_recent = []

    @vue = new Vue project-view-component <<<
      methods:
        select: ~> @emit 'file:select', path: it
        action: ~> @action it
        build: ~> @build!
    .$mount!

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
    if project !instanceof TeXProject
      project = TeXProject.from-uri (project.uri ? project)
    @current = project
      @vue.loc = ..loc
      if ..uri then @add-recent that  # @todo use locator instead
      @emit 'open', project: ..
      if last-file? then @emit 'file:select', path: last-file.uri
  
  open-dialog: ->>
    dir = await @file-dialog.open!
    @open dir

  refresh: -> @vue.$refs.files.refresh!

  build: ->>
    if !@_builder?
      @_builder = @current.builder()
        ..on 'started' ~> @vue.build-status = 'in-progress'
        ..on 'finished' ~> @vue.build-status = it.outcome
    @_builder.make-watch!

  unbuild: ->
    if @_builder? then @_builder = void

  recent:~
    -> @_recent
    (v) -> @_recent = @vue.projects = v

  add-recent: (uri, name) ->
    if ! @lookup-recent uri
      @recent.splice 0, 0, {name: name ? path.basename(uri), uri}

  lookup-recent: (uri) -> @recent.find(-> it.uri == uri)

  @content-plugins = {folder: []}

  @detect-folder-source = (path) ->
    @content-plugins.folder.map (-> it(path)) .find (-> it)
      if !..? then throw new Error "invalid folder path '#{path}'"
  

class TeXProject
  (@loc) ->
    @path = loc.path
    FileWatcher.dir.single @path

  get-main-pdf-path: ->
    @_find-pdf @path

  get-main-tex-file: ->
    fn = glob-all.sync(Array.from(['*.tex', '**/*.tex'] ++ @@IGNORE),
                       {cwd: @path})
    fn.find ~>
      try      fs.readFileSync(path.join(@path, it), 'utf-8').match(/\\documentclass\s*[[{]/)
      catch => false

  builder: ->
    new LatexmkBuild @get-main-tex-file!, @path

  _find-pdf: (root-dir) ->
    fns = glob-all.sync(Array.from(['out/*.pdf', '*.pdf' ++ @@IGNORE]),
                        {cwd: root-dir})
    main-tex = @get-main-tex-file!
    pdf-matches = -> path.basename(main-tex).startsWith(path.basename(it).replace(/pdf$/, ''))
    if main-tex? && (fn = fns.find(pdf-matches)) then ;
    else fn = fns[0]
    fn && path.join(root-dir, fn)

  @from-uri = (uri) ->
    if typeof uri == 'string'
      path = uri.replace(/^file:\/\//, '').replace(/^~/, process.env['HOME'])
      new TeXProject({scheme: 'file', path}) <<< {uri}
    else
      throw new Error("invalid project specifier '#{project}'");

  @IGNORE = ['!_*/**', '!.*/**']  # for glob-all



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
        @files.splice 0, Infinity, ...dir-tree-sync(@volume, '', FOLDER_IGNORE)


const FOLDER_IGNORE = /^\.git$/

ProjectView.content-plugins.folder.push ->
  if !it || _.isString(it) then 'source-folder.directory'


dir-tree-sync = (vol, dir, ignore=/^$/, relpath=[]) ->
  vol.readdirSync(dir).filter(-> !it.match(ignore)).map (file) ->
    {name: file, path: path.join(dir, file), relpath: [...relpath, file]}
      if vol.statSync(..path).isDirectory!
        ..files = dir-tree-sync(vol, ..path, ignore, ..relpath)
  
list-create-file = (files, path, kind="file") ->
  if typeof path == 'string' then path = path.split('/')

  cwd = {name: '/', files}
  for pel in path
    if !cwd.files? then cwd.files = []
    e = cwd.files.find (e) -> e.name == pel
    if !e?
      e = {name: pel, files: undefined, tags: undefined}
      cwd.files.push e
    cwd = e

  if kind == 'folder' && !cwd.files
    cwd.files = []

  return cwd;



export ProjectView, TeXProject
