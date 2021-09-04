require! {
  jquery: $
  'split.js': Split
  '../editor/tex-editor.ls': { TeXEditor }
  './project.ls': { ProjectView }
}

require './ide.css'



class IDELayout
  ->
    @el = $('<div>').addClass('ide-layout')
    @panes = {}
  
  create-pane: (id, size) ->
    $('<div>').addClass('ide-pane').attr('tabindex', '0')
      if id? then ..attr 'id' id
      if size? then ..attr 'data-size' size
      @el.append ..

  make-resizable: ->
    @split = Split @el.find('.ide-pane'), do
      sizes: @_sizes!
      elementStyle: (dimension, size, gutterSize) ->
        'flex-basis': "calc(#{size}% - #{gutterSize}px)"
      gutterStyle: (dimension, gutterSize) -> {}
      snapOffset: 0
      minSize: 10

  _sizes: ->
    defd = @el.children!get!map -> $(it).attr('data-size') ? 0 |> Number
    sum = defd.reduce (+), 0
    undef = defd.filter (-> !it) .length
    w = (100 - sum) / undef
    defd.map -> it || w

  create-project: ->
    @panes.project = @create-pane('ide-pane-project', 15)
    new ProjectView
      @panes.project.append ..vue.$el

  create-editor: ->
    @panes.editor = @create-pane('ide-pane-editor')
    new TeXEditor(@panes.editor)
  
  create-viewer: !->
    @panes.viewer = @create-pane('ide-pane-viewer')



export IDELayout
