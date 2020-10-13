
safe = (op) ->
  try op!
  catch e => console.error(e)



export { safe }