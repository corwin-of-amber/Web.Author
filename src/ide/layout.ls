

class IDELayout
  ->
    @el = $('<div>').addClass('ide-layout')
  
  create-pane: ->
    $('<div>').addClass('ide-pane').attr('tabindex', '0')
      @el.append ..



export IDELayout
