node_require = global.require ? ->
fs = node_require 'fs'
glob-all = node_require 'glob-all'
require! {
  path
  events: {EventEmitter}
  lodash: _
  'vue/dist/vue': Vue
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
          <project-files :path="path" @select="select"/>
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
    <div>
      <file-list :files="files" @action="act"/>
      <component :is="sourceType" ref="source" :path="path"></component>
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

ProjectView.content-plugins.folder.push ->
  if !it || _.isString(it) then 'source-folder.directory'



export ProjectView, TeXProject
