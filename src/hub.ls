
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

process = _process


$ ->
  ide = new IDELayout

  $('body').append ide.el

  editor = ide.createEditor!
  viewer = ide.createViewer!

  ide.make-resizable!

  ide.config = new IDEConfig
    ..restore-session ide

  editor.cm.focus!

  export ide, editor, viewer
