require! {
  '../infra/volume': { Volume }
  '../infra/volume-factory': { VolumeFactory }
}



class IDEConfig
  (@key='ide-config', config) ->
    @config = config || JSON.parse(localStorage[@key] || "{}");
    @config = deserialize @config
  
  save: ->
    localStorage[@key] = JSON.stringify(serialize @config)

  store: (ide) ->
    @capture-session ide
    @save!

  capture-session: (ide) ->
    @config.window = size: {width: window.outerWidth, height: outerHeight}
    @config.panes =
      sizes: ide.layout.split?get-sizes!
      project: ide.project?state
      editor: ide.editor?state
      viewer: ide.viewer?state
    @save!

  restore-session: (ide) ->
    if (win-sz = @config?window?size)?
      window.resizeTo win-sz.width, win-sz.height
    if (pane-szs = @config?panes?sizes)? && ide.layout.split
      ide.layout.split.set-sizes pane-szs
    if (pconf = @config?panes?project)? && ide.project
      ide.project.state = pconf
    if (econf = @config?panes?editor)? && ide.editor
      ide.editor.state = econf
    if (vconf = @config?panes?viewer)? && ide.viewer
      ide.viewer.state = vconf

  is-first-time: -> !@config.panes


/**
 * Serialization: handle `Volume` instances in locations throughout the
 * configuration.
 * This saves individual components the need to invoke the `VolumeFactory`,
 * and makes referring to file locations transparent.
 */
serialize = (o) ->
  transform o, -> 
    if it instanceof Volume then
      {$type: 'Volume'} <<< VolumeFactory.instance.describe(it)

deserialize = (o) ->
  transform o, -> 
    if it?$type == 'Volume' then VolumeFactory.instance.get(it)

transform = (o, f) ->
  if (fo = f(o))? then fo
  else if Array.isArray(o) then o.map(-> transform(it, f))
  else if o && typeof o == 'object'
    Object.fromEntries [...Object.entries(o)].map(([k,v]) -> [k, transform(v, f)])
  else o



export IDEConfig, serialize, deserialize
