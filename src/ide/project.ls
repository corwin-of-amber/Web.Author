node_require = global.require ? ->
fs = node_require 'fs'
glob-all = node_require 'glob-all'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'vue/dist/vue': Vue
  'vue-context': {VueContext}
  './components/file-list'
  #'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../typeset/latexmk.ls': {LatexmkBuild}
}



class ProjectView /*extends CrowdApp*/ implements EventEmitter::
  ->
    @vue = new Vue do
      data: path: null, clientState: void, projects: @@recent-projects!
      template: '''
        <div class="project-view">
          <project-header ref="header" :projects="projects" @open="open"/>
          <project-files ref="files" :path="path" @file:select="select"/>
        </div>
      '''
      methods:
        select: ~> @emit 'file:select', path: it
        open: ~> @open it
    
    .$mount!

  has-fs: -> !!fs

  open: (project) ->
    if project !instanceof TeXProject
      if project.uri then project = project.uri
      if typeof project == 'string'
        project .= replace(/^~/, process.env['HOME'])
        project = new TeXProject(project)
      else
        throw new Error("invalid project specifier '#{project}'");
    @current = project
      @vue.path = ..path
      @emit 'open', project: ..
  
  @recent-projects = -> x =
    * {name: 'sqzComp', uri: '~/var/workspace/papers/2020/sqzComp/FOLDER_1_WRITEUP'}
    * {name: 'suslik', uri: '~/var/workspace/papers/2020/suslik/cyclic/current'}

  @content-plugins = {folder: []}

  @detect-folder-source = (path) ->
    @content-plugins.folder.map (-> it(path)) .find (-> it)
      if !..? then throw new Error "invalid folder path '#{path}'"
  

class TeXProject
  (@path) ->

  get-main-pdf-path: ->
    @_find-pdf @path

  get-main-tex-file: ->
    fn = glob-all.sync(global.Array.from(['*.tex', '**/*.tex']),
                       {cwd: @path})
    fn.find ~>
      try      fs.readFileSync(path.join(@path, it), 'utf-8').match(/\\documentclass\s*[[{]/)
      catch => false

  builder: ->
    new LatexmkBuild @get-main-tex-file!, @path

  build: ->
    @builder!make!

  _find-pdf: (root-dir) ->
    fns = glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                        {cwd: root-dir})
    main-tex = @get-main-tex-file!
    pdf-matches = -> path.basename(main-tex).startsWith(path.basename(it).replace(/pdf$/, ''))
    if main-tex? && (fn = fns.find(pdf-matches)) then ;
    else fn = fns[0]
    fn && path.join(root-dir, fn)


Vue.component 'project-header', do
  props: ['projects']
  data: -> status: void, name: 'proj'
  template: '''
    <div class="project-header">
      <!-- <p2p.source-status ref="status" channel="doc2"/> -->
      <div class="bar" @click.prevent.stop="$refs.list.toggle">
        <span>{{name}}</span>
        <button name="badge" class="p2p" :class="status" @click.stop="toggle">❂</button>
      </div>
      <project-list-dropdown ref="list" :items="projects || []" @open="$emit('open', $event)"/>
    </div>
  '''
  mounted: ->
    #@$refs.status.$watch 'status', (@status) ~>
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
    act: (ev) ->
      console.log ev
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
    @$watch 'path' ~>
      if it
        @files.splice 0, Infinity, ...all-files-sync(it)
    , {+immediate}
  methods:
    get-path-of: (path-els) ->
      path.join @path, ...path-els
    create: (filename) ->
      @files.push name: filename

ProjectView.content-plugins.folder.push ->
  if !it || _.isString(it) then 'source-folder.directory'


all-files-sync = (dir) ->
  fs.readdirSync(dir).map (file) ->
    {name: file, path: path.join(dir, file)}
      if fs.statSync(..path).isDirectory!
        ..files = all-files-sync(..path)
  


export ProjectView, TeXProject
