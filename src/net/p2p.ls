node_require = global.require ? -> {}
require! {
  path
  events: { EventEmitter }
  assert
  lodash: _
  vue: Vue
  codemirror: CodeMirror
  'automerge-slots': { SlotBase }
  'dat-p2p-crowd/src/net/docs': { DocumentClient }
  'dat-p2p-crowd/src/ui/syncpad': { SyncPad }
  'dat-p2p-crowd/src/addons/fs-sync': { DirectorySync, FileSync, FileShare }
  '../ide/project.ls': { ProjectView, TeXProject }
  '../editor/edit-items.ls': { FileEdit }
}



class AuthorP2P extends DocumentClient
  (opts) ->
    @ <<<< new DocumentClient(opts)   # ES2015-LiveScript interoperability issue :/
    @slots =
      project-list: @sync.path('root', 'projects')
    @@register '*', @sync
    window?addEventListener 'beforeunload' @~close

  list-projects: ->>
    await (@_park ?= @slots.project-list.path(0).park!)  # wait for at least one project
    @slots.project-list.get!

  open-project: (docId) ->>
    new CrowdProject @sync.path(docId), {host: '*', path: [docId]}, @
    #  @on 'shout' -> ..upstream?download-src!

  close: ->
    @_park?cancel!; super!

  /**
   * Global host registry
   */

  @hosts = new Map

  @register = (host, docs-root) ->
    @hosts.set host, docs-root

  @resolve = ({host, path}) ->
    h = @hosts.get(host)
    if !h then throw new Error("unfamiliar P2P host '#{host}'")
    h.path(...path)


class CrowdProject extends TeXProject
  /**
   * @param slot an automerge-slots object
   * @param base-uri a P2P URI, an object of the form {host: '..', path: [...]}
   * @param client the AuthorP2P instance
   */
  (slot, @base-uri, @client) ->
    super {scheme: 'memfs', path: '/tmp/p2p'}
    @create!
    @slots =
      root: slot
      src: slot.path('src')

  get-file: (filename) ->
    super(filename)
      if !@is-local(..)
        ..p2p-uri = {@base-uri.host, path: @base-uri.path ++ ['src', filename]}

  is-local: (loc) ->
    loc.filename.match(/^\/?out\//)  # build outputs are always local

  /** Stores the contents of all files to the underlying memfs */
  sync: ->
    new DirectorySync(null, '/', @volume)
      ..save [{filename, content} for filename, content of @slots.src.get!]


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


class SyncPadEdit extends FileEdit
  ->
    super ...&
    @slot = AuthorP2P.resolve(@loc.p2p-uri)

  load: (cm) ->>
    @waiting cm
    assert !@pad
    @pad = new SyncPad(cm, @slot)
      await ..ready ; if !@pad? then return # cancelled; bail
      @doc = cm.getDoc!
    @rev.generation = @doc.changeGeneration!
    @rev.timestamp = @_timestamp!

  leave: (cm) -> @pad?destroy! ; @pad = null ; super cm

  watch: ->    /* don't! SyncPad should take care of changes */
  unwatch: ->

  waiting: (cm) ->
    cm.swapDoc @make-doc(cm, "opening synchronous document...")


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


ProjectView.content-plugins.folder.push (loc) ->
  # @todo currently this is always false
  if loc.scheme == 'dat' then 'source-folder.automerge'



export AuthorP2P, SyncPadEdit
