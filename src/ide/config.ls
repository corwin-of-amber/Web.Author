
class IDEConfig
  (@key='ide-config', config) ->
    @config = config || JSON.parse(localStorage[@key] || "{}");
  
  save: ->
    localStorage[@key] = JSON.stringify(@config)

  capture-session: (ide) ->
    @config.window = size: {width: window.outerWidth, height: outerHeight}
    @config.panes =
      sizes: ide.split?get-sizes!
      project: {path: ide.project?current?path}
      editor: {filename: ide.editor?filename}
      viewer: {uri: ide.viewer?pdf?uri}
    @save!

  restore-session: (ide) ->
    if (win-sz = @config?window?size)?
      window.resizeTo win-sz.width, win-sz.height
    if (pane-szs = @config?panes?sizes)? && ide.split
      ide.split.set-sizes pane-szs
    if (ppath = @config?panes?project?path)? && ide.project
      ide.project.open ppath
    if (fpath = @config?panes?editor?filename)? && ide.editor
      ide.editor.open fpath
    if (pdf = @config?panes?viewer?uri)? && ide.viewer
      ide.viewer.open pdf



export IDEConfig
