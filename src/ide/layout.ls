{TeXEditor} = require '../editor/tex-editor.ls'
{Viewer} = require '../viewer/viewer.ls'



class IDELayout
  ->
    @el = $('<div>').addClass('ide-layout')
  
  create-pane: (id) ->
    $('<div>').addClass('ide-pane').attr('tabindex', '0')
      if id? then ..attr 'id' id
      @el.append ..

  make-resizable: ->
    Split $('.ide-pane'), do
      elementStyle: (dimension, size, gutterSize) ->
        'flex-basis': "calc(#{size}% - #{gutterSize}px)"
      gutterStyle: (dimension, gutterSize) -> {}

  create-editor: ->
    @editor = new TeXEditor(@create-pane('ide-pane-editor'))
  
  create-viewer: ->
    @viewer = new Viewer(, @create-pane('ide-pane-viewer'))
      ..on 'synctex-goto' ~> if @editor
        @editor.jump-to it.file.path, line: it.line



export IDELayout
