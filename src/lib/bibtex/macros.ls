{consume-next} = Traversal
{digest-func} = Commands


commands =
  cite: ->
    keys = consume-next it .text! .split ',' .map (.trim!)
    punct = -> $ '<span>' .text it
    $ '<span>' .add-class 'cite'
      ..append punct('[')
      for key, i in keys
        if i > 0 then ..append (punct ',')
        ..append ($ '<a>' .add-class 'bib-xref' .attr 'data-key' key)
      ..append (punct ']')


aftermath =
  'bib-xref': digest-func (xrefs) ->
    bib-keys = {}
      for el in xrefs
        if (key = $(el).attr('data-key'))? then ..[key] = {}
    index = Object.keys(bib-keys).sort!
    for el in xrefs
      $(el).text '' + (1 + index.indexOf($(el).attr('data-key')))



@commands <<< commands
@aftermath <<< aftermath
