# lock in save data
##cdata.conceptURI = hrefGnd(jsonld["@id"])
##cdata.conceptName = preferredName(jsonld)
##cdata.conceptSeeAlso = []
##for variantName in arrayify(variantName(jsonld))
##  if CUI.isPlainObject(variantName) and variantName["@value"]
##    cdata.conceptSeeAlso.push(variantName["@value"])
##  else
##    cdata.conceptSeeAlso.push(variantName)
##cdata.conceptType = jsonld["@type"]
##cdata.conceptDetails = {}
##if jsonld.dateOfDeath?
##  cdata.conceptDetails.dateOfDeath = jsonld.dateOfDeath["@value"]
##  if jsonld.dateOfBirth?
##    cdata.conceptDetails.dateOfBirth = jsonld.dateOfBirth["@value"]
##cdata.conceptDetails.professionOrOccupation = arrayify(jsonld.professionOrOccupation).map (p) ->
##    p.preferredName
## update form
#@__updateSeeAlsoDisplay(cdata)

# test external function

sayHello = () -> console.log "Hello there Inga how is your day going?"

# export { sayHello }
module.exports = sayHello