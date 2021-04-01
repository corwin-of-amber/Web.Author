node_require = global.require ? ->
fs = node_require 'fs'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'glob-all': glob-all
  'vue': Vue
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../typeset/latexmk.ls': {LatexmkBuild}
}

project-view-component = require('./components/project-view.vue').default



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @_recent = []

    @vue = new Vue project-view-component <<<
      methods:
        select: ~> @emit 'file:select', path: it
        open: ~> @open it
        build: ~> @build!
    .$mount!

  has-fs: -> !!fs

  open: (project) ->
    @unbuild!
    if project !instanceof TeXProject
      project = TeXProject.from-uri (project.uri ? project)
    @current = project
      @vue.path = ..path
      if ..uri then @add-recent that
      @emit 'open', project: ..
  
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
  (@path) ->

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
      new TeXProject(path) <<< {uri}
    else
      throw new Error("invalid project specifier '#{project}'");

  @IGNORE = ['!_*/**', '!.*/**']  # for glob-all



Vue.component 'source-folder.directory', do
  props: ['path']
  data: -> files: []
  render: -> document.createElement('span')   # dummy element
  mounted: ->
    @$watch 'path' @~refresh, {+immediate}
  methods:
    refresh: ->
      if @path
        @files.splice 0, Infinity, ...all-files-sync(@path, FOLDER_IGNORE)
    get-path-of: (path-els) ->
      path.join @path, ...path-els
    create: (filename) ->
      @files.push name: filename

const FOLDER_IGNORE = /^\.git$/

ProjectView.content-plugins.folder.push ->
  if !it || _.isString(it) then 'source-folder.directory'


all-files-sync = (dir, ignore=/^$/) ->
  fs.readdirSync(dir).filter(-> !it.match(ignore)).map (file) ->
    {name: file, path: path.join(dir, file)}
      if fs.statSync(..path).isDirectory!
        ..files = all-files-sync(..path)
  


export ProjectView, TeXProject
