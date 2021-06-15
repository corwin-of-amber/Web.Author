require! {
  jquery: $
}


class FileDialog
  (@select-directory = false) ->

  open: -> new Promise (resolve, reject) ~>
    el = $ '<input>' .attr type: 'file'
      if @select-directory then ..attr 'nwdirectory' ''
      ..on 'change' -> resolve ..val!
      ..trigger 'click'


export FileDialog