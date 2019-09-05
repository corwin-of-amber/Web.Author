node_require = global.require ? -> {}
{EventEmitter} = require('events')
path = require('path')
glob-all = node_require('glob-all')

{DocumentClient} = client = require('dat-p2p-crowd/src/net/client')
{DirectorySync, FileSync, FileShare} = fssync = require('dat-p2p-crowd/src/addons/fs-sync')
{SyncPad} = require('dat-p2p-crowd/src/ui/syncpad')



class AuthorP2P extends DocumentClient
  ->
    @ <<<< new DocumentClient   # ES2015-LiveScript interoperability issue :/

  get-pdf: (docId='d1') ->
    new CrowdFile @sync.path(docId, ['out', 'pdf']), @crowd

  share: (docId='d1') ->>
    root-dir = '/tmp/dirsync'
      pdf-filename = @_find-local-pdf(..)

    slots =
      pdf: @sync.path(docId, ['out', 'pdf'])
      src: @sync.path(docId, ['src'])
    @upload =
      pdf: new FileSync(slots.pdf, pdf-filename)
      src: new DirectorySync(slots.src, root-dir)

    await @upload.pdf.update @crowd
      ..watch debounce: 2000

  _find-local-pdf: (root-dir) ->
    glob-all.sync(global.Array.from(['out/*.pdf', '*.pdf']),
                  {cwd: root-dir})[0]



class CrowdFile implements EventEmitter::
  (@slot, @crowd) ->
    @age = 0
    @_handler = @slot.registerHandler @~receive
    @receive @slot.get!

  receive: (fileprops) ->>
    if fileprops?
      age = ++@age
      fileshare = FileShare.from(fileprops)
      console.warn fileshare
      blob = await fileshare.receiveBlob(@crowd)
      console.warn blob
      if age >= @age
        @emit 'change' (@blob = blob)



class DocumentSlotTrack implements EventEmitter::
  (@slot, immediate=true) -> @_track immediate

  _track: (immediate) ->
    last-val = @slot.get!
    @slot.docSlot ? @slot
      ..registerHandler h = (new-doc) ~>
        if (new-val = @slot.getFrom(new-doc)) != last-val
          p = last-val; last-val := new-val
          @emit 'change', new-val, p
      @_registered = {doc-slot: .., handler: h}
    if immediate && last-val?
      @emit 'change', last-val

  untrack: ->
    if @_registered?
      {doc-slot, handler} = @_registered
      doc-slot.unregisterHandler handler



global.console = window.console
window <<< {client, fssync, SyncPad}

export AuthorP2P
