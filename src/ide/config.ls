require! {
  './problems.ls': { safe }
}



class IDEConfig
  (@key='ide-config', config) ->
    @config = config || JSON.parse(localStorage[@key] || "{}");
  
  save: ->
    localStorage[@key] = JSON.stringify(@config)

  store: (ide) ->
    @capture-session ide
    @save!

  capture-session: (ide) ->
    @config.window = size: {width: window.outerWidth, height: outerHeight}
    @config.panes =
      sizes: ide.layout.split?get-sizes!
      project: {path: ide.project?current?path, recent: ide.project?recent}
      editor: {filename: ide.editor?filename}
      viewer: {uri: ide.viewer?pdf?uri}
    @save!

  restore-session: (ide) ->
    if (win-sz = @config?window?size)?
      window.resizeTo win-sz.width, win-sz.height
    if (pane-szs = @config?panes?sizes)? && ide.layout.split
      ide.layout.split.set-sizes pane-szs
    if (precent = @config?panes?project?recent)? && ide.project
      ide.project.recent = precent
    if (ppath = @config?panes?project?path)? && ide.project
      safe -> ide.project.open ppath
    if (fpath = @config?panes?editor?filename)? && ide.editor
      safe -> ide.editor.open fpath
    if (pdf = @config?panes?viewer?uri)? && ide.viewer
      safe -> ide.viewer.open pdf



export IDEConfig
