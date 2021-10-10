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
    @bars = {}
  
  create-pane: (id, size) ->
    $('<div>').addClass('ide-pane').attr('tabindex', '0')
      if id? then ..attr 'id' id
      if size? then ..attr 'data-size' size
      @el.append ..

  with-focus-indicator: (pane) ->
    pane.append $('<span>').addClass('ide-pane-focus-indicator')

  make-resizable: ->
    @split = Split @el.children('.ide-pane'), do
      sizes: @_sizes!
      elementStyle: (dimension, size, gutterSize) ->
        'flex-basis': "calc(#{size}% - #{gutterSize}px)"
      gutterStyle: (dimension, gutterSize) -> {}
      snapOffset: 0
      minSize: 10

  _sizes: ->
    panes = @el.children('.ide-pane').get!
    defd = panes.map -> $(it).attr('data-size') ? 0 |> Number
    sum = defd.reduce (+), 0
    num-undef = defd.filter (-> !it) .length
    w = (100 - sum) / num-undef
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
      @with-focus-indicator ..

  create-status: ->
    @bars.status = new StatusBar
      @el.append ..el


/**
 * A minimalistic status bar.
 */
class StatusBar
  ->
    @el = $ '<div>' .addClass ['ide-bar-status', 'hidden']
    @rev = 0
  
  show: ({text ? '', widget}, duration) ->
    @rev++
    @el.removeClass 'hidden' .text text
      if widget? then ..append widget
    if duration? then @hide duration

  hide: (duration) ->
    if duration?
      rev = @rev
      setTimeout (~> if rev == @rev then @hide!), duration
    else
      @el.addClass 'hidden'


ProgressWidget = ->
  $ '<span>' .addClass 'progress' .text it


ActionsWidget = (actions) ->
  $ '<div>' .addClass 'ide-interim-actions'
    for let caption, op of actions
      ..append <| b = $ '<button>' .text caption .on 'click' ->
        b.prop 'disabled', true; setTimeout op, 1


export IDELayout, StatusBar, ProgressWidget, ActionsWidget
