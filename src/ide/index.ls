require! {
  './layout.ls': { IDELayout, ProgressWidget }
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
    @project.on 'file:select' ~> @file-select it
    @project.on 'build:progress' ~> @build-progress it
    @project.on 'build:finished' ~> @build-finished it
    @editor.on 'open' ~>
      if it.loc.volume == @project.volume
        recent?last-file = {it.type, it.loc.filename}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to @file-of-project(it.file.path), line: it.line

    @editor.cm.addKeyMap do
      "Ctrl-Tab": @~synctex-lookup

  store: -> @config.store @
  restore: -> @config.restore-session @

  file-of-project: (filename) ->
    @project.current.get-file(filename)

  file-select: (item) ->
    if item.loc.filename is /\.pdf$/
      @viewer?open item.loc
    else
      @editor?open item.loc

  synctex-lookup: (cm) ->
    @viewer.synctex-lookup {@editor.loc.filename, line: cm.getCursor!line + 1}

  build-progress: !->
    @layout.bars.status
      if it.info?done then ..hide 50
      else
        widget = if it.info.download && it.info.download.downloaded > 1e6
          then ProgressWidget(" #{Math.floor(it.info.download?downloaded / 1e6)}MB")
        switch it.stage
        | 'install' => ..show text: "installing #{it.info.uri ? it.info.path}", widget: widget
        | 'compile' => ..show text: "compiling #{it.info.filename}"
        | 'bibtex'  => ..show text: "running bibtex & recompiling..."
  
  build-finished: !->
      if it.outcome == 'error'
        @layout.bars.status.show text: 'build failed.' + \
          (if it.error?log then '' else ' (internal error!)')


export IDE