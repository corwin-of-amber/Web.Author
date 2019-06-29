
#nw.Window.open "", {id: "rich1", focus: false}, ->
#  it.window.location = "/src/rich.html?data/sketch-manual/baseLanguage.html"

#nw.Window.open "", {id: "rich2", focus: false}, ->
#  it.window.location = "/src/rich.html?data/scratch/document.tex"

process = _process

WORKDIR = "#{process.env.HOME}/var/workspace/papers/tech-srl-refl/oe"

$ ->
  ide = new IDELayout

  $('body').append ide.el

  editor = new TeXEditor(ide.create-pane!)
  viewer = new Viewer(, ide.create-pane!)
    ..open "file://#{WORKDIR}/out/popl2020.pdf" "#{WORKDIR}/out/popl2020.synctex.gz"
    ..on 'synctex-goto' -> editor.jump-to it.file.path, line: it.line

  editor.cm.focus!

  export ide, editor, viewer
