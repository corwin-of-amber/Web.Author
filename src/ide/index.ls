require! {
  'codemirror': { keyName }:CodeMirror
  './layout.ls': { IDELayout, ProgressWidget }
  './config.ls': { IDEConfig }
  '../viewer/pdf-viewer.ls': { PDFViewer }
  '../viewer/html-viewer': { HTMLViewer }
}

class IDE
  ->
    @layout = new IDELayout
    @config = new IDEConfig
    @app-title = document.title ? 'ToXin'
  
  start: ({mode ? 'tex', restore ? '*'} = {}) ->
    @project = @layout.create-project!
    @editor = @layout.create-editor!
    @layout.create-viewer!
    @layout.create-status!
    @select-preset(mode)
    @layout.make-resizable!

    @editor.cm.focus!
    @bind-events!
    @restore restore

  select-preset: (mode) ->
    @viewer?destroy!
    switch mode
    | 'tex' => @viewer = new PDFViewer(, @layout.panes.viewer)
    | 'html' => @viewer = new HTMLViewer(, @layout.panes.viewer)

  bind-events: ->
    recent = void
    @project.on 'open' ~>
      document.title = "#{it.project.name} │ #{@app-title}"
      recent := @project.lookup-recent it.project.loc
    @project.on 'file:select' ~> @file-select it
    @project.on 'build:progress' ~> @build-progress it
    @project.on 'build:finished' ~> @build-finished it
    @editor.on 'open' ~> @project.select it.loc, {it.type, +silent}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to @file-of-project(it.file.path), line: it.line - 1

    # - Global keyboard events -
    document.body.addEventListener 'keydown' -> global-keymap[keyName(it)]?!

    Ctrl = @editor.Ctrl
    global-keymap =
      "#{Ctrl}-Enter": @~synctex-forward
      "F1": @~help
      "Esc": ~> @viewer.synctex?blur!; @_track?destroy!; @home!

  store: -> @config.store @
  restore: (what) -> @config.restore-session @, what

  file-of-project: (filename) ->
    @project.current.get-file(filename)

  file-select: (item) ->
    if item.loc.filename is /\.pdf$/
      @viewer?open item.loc
    else
      @editor?open item.loc
      if item.focus then @editor.cm.focus!

  synctex-forward: ->
    {loc, cm} = @editor
    one-shot = ~>
      @viewer.synctex-forward {loc.filename, line: cm.getCursor!line + 1}
    if !@_stay?value
      one-shot!; @_track?destroy!; @_stay = @editor.stay-flag!
    else
      @_track = @editor.track-line one-shot

  build-progress: !->
    @layout.bars.status
      if it.info?done then ..hide 50
      else
        widget = if it.info.download && it.info.download.downloaded > 1e6
          then ProgressWidget(" #{Math.floor(it.info.download?downloaded / 1e6)}MB")
        switch it.stage
        | 'install'   => ..show text: "installing #{it.info.uri ? it.info.path}", widget: widget
        | 'compile'   => ..show text: "compiling #{it.info.filename}"
        | 'recompile' => ..show text: "recompiling #{it.info.filename}"
        | 'bibtex'    => ..show text: "running bibtex & recompiling..."
  
  build-finished: !->
      if it.outcome == 'error'
        type = it.error?$type ? it.error?name
        @layout.bars.status.show text: 'build failed.' + \
          (if type in ['ChildProcessError', 'BuildError'] then '' else ' (internal error!)')

  home: ->
    if @_back-to
      @viewer.state = @_back-to; @_back-to = void

  help: ->>
    @_back-to = @viewer.state
    await @viewer.open new URL("/data/toxin-manual/out/main.pdf", window.location)
    @viewer.fit!
  
  interim-message: (msg-text) ->
    @editor.cm.swapDoc new CodeMirror.Doc(msg-text)


export IDE