node_require = global.require ? ->
fs = node_require 'fs'
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

  open: (path) ->
    @vue.path = path


Vue.component 'project-files', do
  props: ['path'],
  data: -> files: []
  template: '''
    <div>
      <file-list :files="files" @action="act"/>
      <source-directory ref="source" :path="path"/>
    </div>
  '''
  mounted: -> @files = @$refs.source.files
  methods:
    act: (ev) ->
      if ev.type == 'select'
        path.join @path, ...ev.path
          @$emit 'select', ..


Vue.component 'source-directory', do
  props: ['path']
  data: -> files: []
  template: '<span/>'
  mounted: ->
    @$watch 'path' ~>
      it && fs.readdir it, (err, res) ~> if !err?
        files = res.map -> name: it
        @files.splice 0, Infinity, ...files
    , immediate: true



export ProjectView
