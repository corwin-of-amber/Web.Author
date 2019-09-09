node_require = global.require ? ->
fs = node_require 'fs'
glob-all = node_require 'glob-all'
require! path
require! events: {EventEmitter}
require! 'vue/dist/vue': Vue
require! './components/file-list'



class ProjectView extends EventEmitter
  ->
    @vue = new Vue do
      data: path: null
      template: '<project-files :path="path" @select="select"/>'
      methods:
        select: ~> @emit 'file:select', path: it
    
    .$mount!

  has-fs: -> !!fs

  open: (project) ->
    if typeof project == 'string'
      project = new TeXProject(project)
    @current = project
      @vue.path = ..path
  

class TeXProject
  (@path) ->

  get-main-pdf-path: ->
    @_find-pdf @path

  _find-pdf: (root-dir) ->
    fn = glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                       {cwd: root-dir})[0]
    fn && path.join(root-dir, fn)


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
    sourceType: ->
      if typeof path == 'string' then 'source-folder.directory'
      else 'source-folder.automerge'
  mounted: ->
    @$watch 'path' ~> @files = @$refs.source.files  # it is quite unfortunate that this cannot
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


Vue.component 'source-folder.automerge', do
  props: ['path']
  data: -> files: [], pathSlot: undefined
  template: '<span/>'
  mounted: ->
    @$watch 'path' (slot) ~>
      @unregister! ; if slot? then @register slot
    , {+immediate}
  methods:
    get-path-of: (path-els) ->
      l = @path.get!
      subpath =
        for el in path-els
          if !l then break
          index = l.findIndex (-> it.filename == el)
            l = l[..]
      l && @path.path(subpath ++ ['content'])
        ..uri = @uri-of(path-els)

    uri-of: (path-els) ->
      doc-id = @path.docSlot.docId
      path = @path._path ++ path-els
      "dat://*/#{docId}/#{path.join('/')}"

    register: (slot) ->
      slot.registerHandler h = ~> @update it
      h slot.get!
      @_registered = {slot, h}
    unregister: ->
      if @_registered?
        {slot, h} = @_registered
        slot.unregisterHandler h
    update: (file-entries=[]) ->
      file-entries .= map -> {name: it.filename}
      @files.splice 0, Infinity, ...file-entries



export ProjectView
