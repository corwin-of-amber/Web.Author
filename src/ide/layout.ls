require! {
  jquery: $
  'split.js': Split
  '../editor/tex-editor.ls': { TeXEditor }
  '../viewer/viewer.ls': { Viewer }
  '../viewer/html-viewer': { HTMLViewer }
  './project.ls': { ProjectView }
}

require './ide.css'



class IDELayout
  ->
    @el = $('<div>').addClass('ide-layout')
  
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
    @project = new ProjectView
      ..on 'file:select' ~> @file-select it
      @create-pane('ide-pane-project', 15).append ..vue.$el

  create-editor: ->
    @editor = new TeXEditor(@create-pane('ide-pane-editor'))
  
  create-viewer-html: ->
    @viewer = new HTMLViewer(, @create-pane('ide-pane-viewer'))

  create-viewer-pdf: ->
    @viewer = new Viewer(, @create-pane('ide-pane-viewer'))

  file-select: (item) ->
    if item.path is /\.pdf$/
      @viewer?open item.path
    else
      @editor?open item.path



export IDELayout
