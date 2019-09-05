
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

process = @_process

{IDELayout} = require './ide/layout.ls'
{IDEConfig} = require './ide/config.ls'
{AuthorP2P} = require './net/p2p.ls'


$ ->
  ide = new IDELayout

  $('body').append ide.el

  editor = ide.createEditor!
  viewer = ide.createViewer!

  ide.make-resizable!

  ide.config = new IDEConfig
    ..restore-session ide

  editor.cm.focus!

  p2p = new AuthorP2P
    ..getPdf!on 'change' ->
      if !viewer.pdf?filename?
        viewer.open it
    window.addEventListener 'beforeunload' ..~close

  window <<< {ide, editor, viewer, p2p}
