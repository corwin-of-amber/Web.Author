require! {
  '@codemirror/state': { EditorState }
  '../infra/keymap': { KeyMap }
  './layout.ls': { IDELayout, ProgressWidget, ActionsWidget }
  './config.ls': { IDEConfig }
  '../editor/editor-base': { setup, createWidgetPlugin }
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
    @project.on 'file:jump-to' ~> @file-jump-to it
    @project.on 'build:progress' ~> @build-progress it
    @project.on 'build:finished' ~> @build-finished it
    @editor.on 'open' ~> @project.select it.loc, {it.type, +silent}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to @file-of-project(it.file.path), it

    # - Global keyboard events -
    new KeyMap do
      "Mod-Enter": @~synctex-forward
      "Mod-F": @~multisearch
      "F1": @~help
      "Escape": @~bail
    .attach document.body

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

  file-jump-to: (item) ->
    @editor?jump-to item.loc, item.cursor

  synctex-forward: !->
    @_track?destroy!;
    one-shot = ~>
      {loc, at} = @editor.pos
      @viewer.synctex-forward {loc.filename, at.line}
    if !@_stay?value
      one-shot!; @_stay = @editor.stay-flag!
    else
      @_track = @editor.track-line one-shot

  /** starts a search in the editor and highlights matches in the PDF, so cool */
  multisearch: ->
    @editor.search.start!
      ..on 'input' ~> if @viewer.pdf? then @viewer.textOverlay
        if it then ..searchAndHighlightNaive it, @viewer.selected-page
        else ..clear!
      ..on 'close' ~> @viewer.textOverlay.clear!

  build-progress: !->
    @layout.bars.status
      if it.info?done then ..hide 50
      else
        task = if it.info.task then " (#{it.info.task.index}/#{it.info.task.total})" else ""
        widget = if it.info.download && it.info.download.downloaded > 1e6
          then ProgressWidget(" #{Math.floor(it.info.download?downloaded / 1e6)}MB")
        label = (it.info.uri ? it.info.path)?.replace(/^.*[/]/, '')
        switch it.stage
        | 'load'      => ..show text: "loading pdflatex..."
        | 'install'   => ..show text: "installing#{task} #{label}", widget: widget
        | 'compile'   => ..show text: "compiling #{it.info.filename}"
        | 'recompile' => ..show text: "recompiling #{it.info.filename}"
        | 'bibtex'    => ..show text: "running bibtex & recompiling..."
  
  build-finished: !->
    if it.outcome == 'error'
      type = it.error?$type ? it.error?name
      @layout.bars.status.show text: 'build failed.' + \
        (if type in ['ChildProcessError', 'BuildError'] then '' else ' (internal error!)')
    else
      @layout.bars.status.hide 50

  home: ->
    if @_back-to
      @viewer.state = @_back-to; @_back-to = void

  help: ->>
    @_back-to = @viewer.state
    await @viewer.open new URL("/data/toxin-manual/out/main.pdf", window.location)
    @viewer.fit!
  
  bail: ->  # escape all ongoing UI activities
    @viewer.synctex?blur!
    @editor.dialog?active?close!
    @_track?destroy!
    @home!

  interim-message: (msg-text, actions) ->
    @editor.cm.setState EditorState.create do
      doc: msg-text
      extensions: [createWidgetPlugin(-> ActionsWidget(actions).0).extension]


export IDE