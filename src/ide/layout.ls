

class IDELayout
  ->
    @el = $('<div>').addClass('ide-layout')
  
  create-pane: ->
    $('<div>').addClass('ide-pane').attr('tabindex', '0')
      @el.append ..

  make-resizable: ->
    Split $('.ide-pane'), do
      elementStyle: (dimension, size, gutterSize) ->
        'flex-basis': "calc(#{size}% - #{gutterSize}px)"
      gutterStyle: (dimension, gutterSize) -> {}



export IDELayout
