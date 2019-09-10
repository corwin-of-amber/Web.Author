
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

process = @_process

require! {
  lodash: _
  './ide/layout.ls': {IDELayout}
  './ide/config.ls': {IDEConfig}
  './net/p2p.ls':    {AuthorP2P}
}

global.console = window.console


CLIENT_OPTS = void
#CLIENT_OPTS = servers: hub: 'ws://localhost:3300'


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

  p2p = new AuthorP2P(CLIENT_OPTS)
    do ->> p2p.project = await p2p.open-project 'd1'
      project.open ..
      ..getPdf!on 'change' viewer~open
    window.addEventListener 'beforeunload' ..~close

  window <<< {ide, project, editor, viewer, p2p}

  window.addEventListener 'beforeunload' ->
    Date::com$cognitect$transit$equals = \
    Date::com$cognitect$transit$hashCode = null
    for own prop of window
      if typeof window[prop] == 'object' then window[prop] = null
    document.body.innerHTML = ""
