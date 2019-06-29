
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

$ ->
  ide = new IDELayout

  $('body').append ide.el

  editor = new TeXEditor(ide.create-pane!)
  viewer = new Viewer(, ide.create-pane!)
    ..open '../data/popl2020.pdf' 'data/popl2020.synctex'

  editor.cm.focus!

  export ide, editor, viewer
