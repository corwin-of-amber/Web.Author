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
    @layout.create-status!
    @select-preset(mode)
    @layout.make-resizable!

    @editor.cm.focus!
    @bind-events!
    @restore!

  select-preset: (mode) ->
    @viewer?destroy!
    switch mode
    | 'tex' => @viewer = new PDFViewer(, @layout.panes.viewer)
    | 'html' => @viewer = new HTMLViewer(, @layout.panes.viewer)

  bind-events: ->
    recent = void
    @project.on 'open' ~>
      recent := @project.lookup-recent it.project.loc
    @project.on 'file:select' ~>
      @file-select it
    @project.on 'build:progress' ~>
      @build-progress it
    @editor.on 'open' ~>
      recent?last-file = {it.type, it.loc}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to @file-of-project(it.file.path), line: it.line

  store: -> @config.store @
  restore: -> @config.restore-session @

  file-of-project: (filename) ->
    @project.current.get-file(filename)

  file-select: (item) ->
    if item.loc.filename is /\.pdf$/
      @viewer?open item.loc
    else
      @editor?open item.loc

  build-progress: !->
    @layout.bars.status
      if it.info?done then ..hide 50
      else
        switch it.stage
        | 'install' => ..show "installing #{it.info.uri}"
        | 'compile' => ..show "compiling #{it.info.filename}"


export IDE