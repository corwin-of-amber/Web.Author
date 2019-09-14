node_require = global.require ? -> {}
glob-all = node_require('glob-all')
require! {
  path
  events: {EventEmitter}
  lodash: _
  'vue/dist/vue': Vue
  'automerge-slots': {SlotBase}
  'dat-p2p-crowd/src/net/client': {DocumentClient}
  'dat-p2p-crowd/src/addons/fs-sync': {DirectorySync, FileSync, FileShare}
  '../ide/project.ls': {ProjectView, TeXProject}
}



class AuthorP2P extends DocumentClient
  (opts) ->
    @ <<<< new DocumentClient(opts)   # ES2015-LiveScript interoperability issue :/

  open-project: (docId) ->>
    await this.init!
    new CrowdProject @sync.path(docId), @
      @on 'shout' -> ..upstream?download-src!


class CrowdProject
  (slot, @client) -> 
    @slots =
      root: slot
      src: slot.path(['src'])
      pdf: slot.path(['out', 'pdf'])

  path:~ -> @slots.src

  get-pdf: -> new CrowdFile @slots.pdf, @client

  share: (tex-project='/tmp/toxin') ->
    @sync tex-project
      ..upload!

  sync: (tex-project='/tmp/toxin') ->
    if _.isString(tex-project)
      tex-project = new TeXProject(tex-project)

    @upstream = new @@Upstream @client.crowd, do
      pdf: new FileSync(@slots.pdf, tex-project.get-main-pdf-path!)
      src: new DirectorySync(@slots.src, tex-project.path)

  class @Upstream
    (@crowd, {@pdf, @src}) ->

    upload: ->
      @upload-src! ; @upload-build!

    upload-src: ->
      @src.populate '*.tex'

    upload-build: ->>
      await @pdf.update @crowd
        @watch = ..watch debounce: 2000
    
    download-src: ->
      @src.save!



class CrowdFile extends EventEmitter
  (@slot, @client) ->
    super!
    @age = 0
    @_watch = new WatchSlot @slot
      ..on 'change' @~receive

  receive: (fileprops) ->>
    if fileprops?
      age = ++@age
      fileshare = FileShare.from(fileprops)
      console.warn fileshare
      @emit 'receive' fileshare
      try
        await @wait-for-sync!
      catch => if e instanceof @@Canceled then return else throw e
      try
        blob = await fileshare.receiveBlob(@client.crowd)
      catch
        console.warn "file cannot be received (#e)"; return
      console.warn blob
      if age >= @age
        @emit 'change' (@blob = blob)

  wait-for-sync: -> new Promise (resolve, reject) ~>
    if @client.isSynchronized! then resolve!
    else
      h1 = (-> cleanup! ; resolve!) ; h2 = (-> cleanup! ; reject new Canceled)
      cleanup = ~>
        @client.removeListener 'doc:sync' h1 ; @removeListener 'receive' h2
      @client.once 'doc:sync' h1 ; @once 'receive' h2
  
  class @Canceled


class WatchSlot extends EventEmitter
  (@slot, immediate=true) -> super!; @_track immediate

  _track: (immediate) ->
    @slot.registerHandler h = ~> @emit 'change' it
    @_registered = h
    if immediate
      process.nextTick ~> @emit 'change' @slot.get!

  untrack: ->
    if @_registered?
      @slot.unregisterHandler @_registered


Vue.component 'source-folder.automerge', do
  props: ['path']
  data: -> files: []
  template: '<span/>'

  mounted: ->
    @$watch 'path' (slot) ~>
      @unregister! ; if slot? then @register slot
    , {+immediate}

  methods:
    get-path-of: (path-els) ->
      l = @path.get!
      subpath =
        for el in path-els
          if !l then break
          index = l.findIndex (-> it.filename == el)
            l = l[..]
      l && @path.path(subpath ++ ['content'])
        ..uri = @uri-of(path-els)

    uri-of: (path-els) ->
      doc-id = @path.docSlot.docId
      path = @path._path ++ path-els
      "dat://*/#{docId}/#{path.join('/')}"

    register: (slot) ->
      slot.registerHandler h = ~> @update it
      h slot.get!
      @_registered = {slot, h}
    unregister: ->
      if @_registered?
        {slot, h} = @_registered
        slot.unregisterHandler h
    update: (file-entries=[]) !->
      file-entries.map (-> {name: it.filename})
        @files.splice 0, Infinity, ... ..


ProjectView.content-plugins.folder.push ->
  if it instanceof SlotBase then 'source-folder.automerge'



export AuthorP2P
