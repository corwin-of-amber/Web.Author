
class IDEConfig
  (@key='ide-config', config) ->
    @config = config || JSON.parse(localStorage[@key] || "{}");
  
  save: ->
    localStorage[@key] = JSON.stringify(@config)

  restore-session: (ide) ->
    if (pdf = @config?pdf?last-filename)? && ide.viewer
      ide.viewer.open "file://#{pdf}"



export IDEConfig
