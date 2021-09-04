require! {
  './layout.ls': { IDELayout }
  './config.ls': { IDEConfig }
  '../viewer/pdf-viewer.ls': { PDFViewer }
  '../viewer/html-viewer': { HTMLViewer }
}

class IDE
  ->
    @layout = new IDELayout
    @config = new IDEConfig
  
  start: (mode = 'tex') ->
    @project = @layout.create-project!
    @editor = @layout.create-editor!
    @layout.create-viewer!
    @_preset(mode)
    @layout.make-resizable!

    @editor.cm.focus!
    @bind-events!
    @restore!

  _preset: (mode) ->
    switch mode
    | 'tex' => @viewer = new PDFViewer(, @layout.panes.viewer)
    | 'html' => @viewer = new HTMLViewer(, @layout.panes.viewer)

  bind-events: ->
    recent = void
    @project.on 'open' ~>
      recent := @project.lookup-recent it.project.uri
    @project.on 'file:select' ~>
      @file-select it
    @editor.on 'open' ~>
      recent?last-file = {it.type, it.uri}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to it.file.path, line: it.line

  store: -> @config.store @
  restore: -> @config.restore-session @

  file-select: (item) ->
    if item.path is /\.pdf$/
      @viewer?open item.path
    else
      @editor?open item.path


export IDE