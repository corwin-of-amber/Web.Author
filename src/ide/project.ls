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
  'dat-p2p-crowd/src/ui/ui.js': {App: CrowdApp}
}



class ProjectView extends CrowdApp implements EventEmitter::
  ->
    @vue = new Vue do
      data: path: null, clientState: void
      template: '''
        <div class="project-view">
          <project-header/>
          <project-files ref="files" :path="path" @select="select"/>
        </div>
      '''
      methods:
        select: ~> @emit 'file:select', path: it
    
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

  _find-pdf: (root-dir) ->
    fn = glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                       {cwd: root-dir})[0]
    fn && path.join(root-dir, fn)


Vue.component 'project-header', do
  template: '''
    <div class="project-header">
      <p2p.button-join channel="doc2"/>
    </div>
  '''


Vue.component 'project-files', do
  props: ['path'],
  data: -> files: []
  template: '''
    <div class="project-files" @contextmenu.prevent="$refs.contextMenu.open">
      <file-list :files="files" @action="act"/>
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
    create: ->
      @$refs.source.create 'new-file1.tex'


Vue.component 'project-context-menu', do
  template: '''
    <vue-context ref="m">
      <li><a name="new-file" @click="action">New File</a></li>
      <li><a name="rename" @click="action">Rename</a></li>
      <li><a name="delete">Delete</a></li>
    </vue-context>
  '''
  components: {VueContext}
  methods:
    open: -> @$refs.m.open it
    action: -> @$emit 'action' {it.currentTarget.name}


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
