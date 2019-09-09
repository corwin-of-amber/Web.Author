
class IDEConfig
  (@key='ide-config', config) ->
    @config = config || JSON.parse(localStorage[@key] || "{}");
  
  save: ->
    localStorage[@key] = JSON.stringify(@config)

  restore-session: (ide) ->
    if (pdf = @config?pdf?last-uri)? && ide.viewer
      ide.viewer.open pdf
    if (sizes = @config?panes?sizes)? && ide.split
      ide.split.setSizes sizes



export IDEConfig
