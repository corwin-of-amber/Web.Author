node_require = global.require ? -> {}
{EventEmitter} = require('events')
path = require('path')
glob-all = node_require('glob-all')

{DocumentClient} = client = require('dat-p2p-crowd/src/net/client')
{DirectorySync, FileSync, FileShare} = fssync = require('dat-p2p-crowd/src/addons/fs-sync')



class AuthorP2P extends DocumentClient
  (opts) ->
    @ <<<< new DocumentClient(opts)   # ES2015-LiveScript interoperability issue :/

  get-pdf: (docId='d1') ->
    new CrowdFile @sync.path(docId, ['out', 'pdf']), @crowd

  list-files: (docId='d1') ->
    @sync.path(docId, ['src']).get!

  share: (docId='d1', root-dir='/tmp/toxin') ->>
    await this.init!

    pdf-filename = @_find-local-pdf(root-dir)

    slots =
      pdf: @sync.path(docId, ['out', 'pdf'])
      src: @sync.path(docId, ['src'])
    @upload =
      pdf: new FileSync(slots.pdf, pdf-filename)
      src: new DirectorySync(slots.src, root-dir)

    @upload.src.populate '*.tex'

    await @upload.pdf.update @crowd
      ..watch debounce: 2000

  _find-local-pdf: (root-dir) ->
    fn = glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                       {cwd: root-dir})[0]
    fn && path.join(root-dir, fn)



class CrowdFile extends EventEmitter
  (@slot, @crowd) ->
    super!
    @age = 0
    @_watch = new WatchSlot @slot
      ..on 'change' ~> @receive it

  receive: (fileprops) ->>
    if fileprops?
      age = ++@age
      fileshare = FileShare.from(fileprops)
      console.warn fileshare
      blob = await fileshare.receiveBlob(@crowd)
      console.warn blob
      if age >= @age
        @emit 'change' (@blob = blob)



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



export AuthorP2P
