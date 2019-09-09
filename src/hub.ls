
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

process = @_process

{IDELayout} = require './ide/layout.ls'
{IDEConfig} = require './ide/config.ls'
{AuthorP2P} = require './net/p2p.ls'

global.console = window.console


$ ->
  ide = new IDELayout

  $('body').append ide.el

  project = ide.create-project!
  editor = ide.create-editor!
  viewer = ide.create-viewer!

  ide.make-resizable!

  ide.config = new IDEConfig
  #  ..restore-session ide

  #if project.has-fs!
  #  project.open '/tmp/toxin'

  editor.cm.focus!

  p2p = new AuthorP2P # servers: hub: 'ws://localhost:3300'
    ..getPdf!on 'change' ->
      if !project.current?path? then viewer.open it
    project.vue.path = ..sync.path('d1', ['src'])
    window.addEventListener 'beforeunload' ..~close

  window <<< {ide, project, editor, viewer, p2p}

  window.addEventListener 'beforeunload' ->
    Date::com$cognitect$transit$equals = \
    Date::com$cognitect$transit$hashCode = null
    for own prop of window
      if typeof window[prop] == 'object' then window[prop] = null
    document.body.innerHTML = ""
