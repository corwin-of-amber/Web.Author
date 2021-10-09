node_require = global.require ? -> {}
require! {
  path
  events: { EventEmitter }
  assert
  lodash: _
  vue: Vue
  codemirror: CodeMirror
  automerge
  'dat-p2p-crowd/src/net/docs': { DocumentClient }
  'dat-p2p-crowd/src/ui/syncpad': { SyncPad, FirepadShare }
  'dat-p2p-crowd/src/addons/fs-sync': { DirectorySync, FileSync, FileShare }
  '../ide/project.ls': { ProjectView, TeXProject }
  '../editor/edit-items.ls': { FileEdit }
}



class AuthorP2P extends DocumentClient
  (opts) ->
    @ <<<< new DocumentClient(opts)   # ES2015-LiveScript interoperability issue :/
    @slots =
      project-list: @sync.path('root', 'projects')
    @host = opts?hostname ? '*'
    @@register @host, @sync
    window?addEventListener 'beforeunload' @~close

  list-projects: ->>
    await (@_park ?= @slots.project-list.path(0).park!)  # wait for at least one project
    @slots.project-list.get!

  open-project: (docId) ->>
    await (slot = @sync.path(docId)).park!
    new CrowdProject slot, {@host, path: [docId]}, @
    #  @on 'shout' -> ..upstream?download-src!

  create-project: ->
    CrowdProject.create @host, @sync.create!
      @add-project ..

  add-project: (project) !->
    [..._, id] = project.base-uri.path ; assert !_.length
    @slots.project-list
      if ..get! then ..change (.push id) else ..set [id]

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
   */
  (slot, @base-uri) ->
    super {scheme: 'dat', path: '/tmp/p2p', base-uri}
    @create!  # create a local directory
    @slots =
      root: slot
      src: slot.path('src')
      age: slot.path('age')

    @slots.age.registerHandler -> console.warn it

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

  @create = (host, slot) ->
    slot.change (<<< do
      name: 'new-p2p'
      src: {'main.tex': new FirepadShare}
      age: new automerge.Counter
    )
    new CrowdProject slot, {host, path: [slot.docId]}


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
      try await ..ready catch => return # cancelled; bail
      @doc = cm.getDoc!
    @rev.generation = @doc.changeGeneration!
    @rev.timestamp = @_timestamp!

  leave: (cm) -> super cm ; @pad?destroy! ; @pad = null

  watch: ->    /* don't! SyncPad should take care of changes */
  unwatch: ->

  changed-on-disk: -> true  # @todo
  _timestamp: -> 0

  waiting: (cm) ->
    cm.swapDoc @make-doc(cm, "opening synchronous document...")


Vue.component 'source-folder.automerge', do
  props: ['loc']
  data: -> files: []
  render: -> # the drive stores local copies of files in memfs
    it('source-folder.directory', {ref: 'drive', props: {@loc}})

  mounted: ->
    @$watch 'loc' @~refresh
    , {+immediate}

  methods:
    refresh: ->
      @$refs.drive.refresh!
      if @loc
        AuthorP2P.resolve(@loc.base-uri)
          @src = ..path('src') ; @age = ..path('age')
        dfiles = @filter-local(@$refs.drive.files ? [])
        rfiles = nested-files(Object.keys(@src.get())) ? []
        @files.splice 0, Infinity, ...combine-nested-files(dfiles, rfiles)
        # Create a proxy Volume to interact with the file-list
        v = ~> @$refs.drive.volume
        kick = ~> @age.change (.increment!)
        change-src = (f) ~> @src.change f ; kick!
        @volume =
          path:~ -> v!path
          writeFileSync: (fn) ~> v!writeFileSync ...&
            console.warn 'writeFileSync', fn
            .. ; change-src (.[fn] ?= new FirepadShare)
          renameSync: (from-fn, to-fn) ~> v!renameSync ...&
            .. ; change-src ->
              if it[from-fn] then
                it[to-fn] = FirepadShare.from(it[from-fn]).clone!  # cannot reassign object in automerge :(
                delete it[from-fn]


    
    filter-local: (files) ->
      files.filter (.name == 'out')  /** @oops DRY wrt `CrowdProject#is-local` */

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
  if loc.scheme == 'dat' then 'source-folder.automerge'


nested-files = (filenames) ->
  o = nested(filenames.map((.split('/'))))
  aux = (o) ->
    if _.isEmpty(o) then void
    else [{name: k, files: aux(v)} for k, v of o]
  aux(o)

nested = (paths) -> {}
  for path in paths
    at = ..
    for path => at = at.{}[..]

combine-nested-files = (...arrs) ->
  if arrs.length == 0 then return void
  [{name, files: combine-nested-files(...v.map((?files)).filter((?length)))} \
   for name, v of outer-join((.name), ...arrs)]

outer-join = (by-f, ...arrs) -> {}
  for a, i in arrs
    for el in a
      ..[][by-f(el)][i] = el


export AuthorP2P, SyncPadEdit
