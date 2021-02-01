node_require = global.require ? ->
fs = node_require 'fs'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'glob-all': glob-all
  'vue/dist/vue': Vue
  'vue-context': {VueContext}
  '../../packages/file-list/index.vue': {default: file-list}
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../typeset/latexmk.ls': {LatexmkBuild}
}



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @_recent = []

    @vue = new Vue do
      data: path: null, clientState: void, projects: @_recent, build-status: void
      template: '''
        <div class="project-view">
          <project-header ref="header" name="project" :build-status="buildStatus"
            :projects="projects" @open="open" @build="build"/>
          <project-files ref="files" :path="path" @file:select="select"/>
        </div>
      '''
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
    @_builder.make!

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


Vue.component 'project-header', do
  props: ['name', 'build-status', 'projects']
  data: -> p2p-status: void
  template: '''
    <div class="project-header">
      <!-- <p2p.source-status ref="status" channel="doc2"/> -->
      <div class="bar" @click.prevent.stop="$refs.list.toggle">
        <span>{{name}}</span>
        <button name="build" class="badge hammer" :class="buildStatus" @click.stop="$emit('build')">⚒</button>
        <!-- <button class="badge p2p" :class="p2pStatus" @click.stop="toggle">❂</button> -->
      </div>
      <project-list-dropdown ref="list" :items="projects || []" @open="$emit('open', $event)"/>
    </div>
  '''
  mounted: ->
    #@$refs.status.$watch 'status', (@p2p-status) ~>
    #, {+immediate}
  methods:
    toggle: -> @$refs.status.toggle!


Vue.component 'project-files', do
  props: ['path'],
  data: -> files: []
  template: '''
    <div class="project-files" @contextmenu.prevent="$refs.contextMenu.open">
      <file-list ref="list" :files="files" @action="act"/>
      <component :is="sourceType" ref="source" :path="path"></component>
      <project-context-menu ref="contextMenu" @action="onmenuaction"/>
    </div>
  '''
  computed:
    sourceType: -> ProjectView.detect-folder-source(@path)
  mounted: ->
    @$watch 'path' ~>                     # it is quite unfortunate that this cannot
      @files = @$refs.source?files ? []   # be done with a computed property
      @$refs.list.collapseAll!
    , {+immediate}              
  methods:
    refresh: -> @$refs.source?refresh!
    act: (ev) ->
      if ev.type == 'select' && ev.kind == 'file'
        @$emit 'file:select', @$refs.source.get-path-of(ev.path)
    onmenuaction: (ev) ->
      switch ev.name
      | 'new-file' => @create!
      | 'rename'   => @rename!
    create: ->
      @$refs.source.create 'new-file1.tex'
    rename: ->
      if (sel = @$refs.list.selection[0])?
        @$refs.list.rename-start sel
  components: {file-list}


Vue.component 'project-context-menu', do
  template: '''
    <vue-context ref="m">
      <li><a name="new-file" @click="action">New File</a></li>
      <li><a name="rename" @click="action">Rename</a></li>
      <li><a name="delete" @click="action">Delete</a></li>
    </vue-context>
  '''
  components: {VueContext}
  methods:
    open: -> @$refs.m.open it
    action: -> @$emit 'action' {it.currentTarget.name}


Vue.component 'project-list-dropdown', do
  props: ['items']
  template: '''
    <vue-context ref="l">
      <li v-for="item in items"><a @click="open(item)">{{item.name}}</a></li>
    </vue-context>
  '''
  components: {VueContext}
  methods:
    toggle: ->
      if !@$refs.l.show
        @$refs.l.open @position!
      else @$refs.l.close!
    position: ->
      box = @$el.parentElement.getBoundingClientRect!
      {clientX: box.left, clientY: box.bottom}
    open: (item) ->
      this.$emit 'open' item

    

Vue.component 'source-folder.directory', do
  props: ['path']
  data: -> files: []
  template: '<span/>'
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
