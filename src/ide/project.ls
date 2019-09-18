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
  'dat-p2p-crowd/src/ui/ui': {App: CrowdApp}
  '../typeset/latexmk.ls': {LatexmkBuild}
}



class ProjectView extends CrowdApp implements EventEmitter::
  ->
    @vue = new Vue do
      data: path: null, clientState: void
      template: '''
        <div class="project-view">
          <project-header ref="header"/>
          <project-files ref="files" :path="path" @select="select"/>
        </div>
      '''
      methods:
        select: ~> @emit 'file:select', path: it
        open: ~> @open it
    
    .$mount!

  has-fs: -> !!fs

  open: (project) ->
    if typeof project == 'string'
      project = new TeXProject(project)
    @current = project
      @vue.path = ..path
  
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
      try      fs.readFileSync(path.join(@path, it), 'utf-8').match(/\\documentclass\s*{/)
      catch => false

  builder: ->
    new LatexmkBuild @get-main-tex-file!, @path

  build: ->
    @builder!make!

  _find-pdf: (root-dir) ->
    fn = glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                       {cwd: root-dir})[0]
    fn && path.join(root-dir, fn)


Vue.component 'project-header', do
  data: -> status: void, name: 'proj'
  template: '''
    <div class="project-header">
      <p2p.source-status ref="status" channel="doc2"/>
      <div class="bar" @click.prevent.stop="$refs.list.toggle">
        <span>{{name}}</span>
        <button name="badge" class="p2p" :class="status" @click.stop="toggle">❂</button>
      </div>
      <project-list-dropdown ref="list"/>
    </div>
  '''
  mounted: ->
    @$refs.status.$watch 'status', (@status) ~>
    , {+immediate}
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
    @$watch 'path' ~> @files = @$refs.source?files  # it is quite unfortunate that this cannot
    , {+immediate}                                  # be done with a computed property
  methods:
    act: (ev) ->
      if ev.type == 'select'
        @$emit 'select', @$refs.source.get-path-of ev.path
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
  template: '''
    <vue-context ref="l">
      <li><a>shrinker [fs]</a></li>
      <li><a>toxin [fs]</a></li>
      <li><a>doc2 [p2p]</a></li>
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

    

Vue.component 'source-folder.directory', do
  props: ['path']
  data: -> files: []
  template: '<span/>'
  mounted: ->
    @$watch 'path' ~>
      it && fs.readdir it, (err, res) ~> if !err?
        files = res.map -> name: it
        @files.splice 0, Infinity, ...files
    , {+immediate}
  methods:
    get-path-of: (path-els) ->
      path.join @path, ...path-els
    create: (filename) ->
      @files.push name: filename

ProjectView.content-plugins.folder.push ->
  if !it || _.isString(it) then 'source-folder.directory'



export ProjectView, TeXProject
