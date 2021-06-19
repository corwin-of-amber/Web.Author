require! {
  './layout.ls': {IDELayout}
  './config.ls': {IDEConfig}
}

class IDE
  ->
    @layout = new IDELayout
    @config = new IDEConfig
  
  start: ->
    @project = @layout.create-project!
    @editor = @layout.create-editor!
    @viewer = @layout.create-viewer-html!  # @todo
    @layout.make-resizable!

    @editor.cm.focus!
    @bind-events!
    @restore!

  bind-events: ->
    recent = void
    @project.on 'open' ~>
      recent := @project.lookup-recent it.project.uri
    @editor.on 'open' ~>
      recent?last-file = {it.type, it.uri}
    @viewer.on 'synctex-goto' ~> if @editor
      @editor.jump-to it.file.path, line: it.line

  store: -> @config.store @
  restore: -> @config.restore-session @


export IDE