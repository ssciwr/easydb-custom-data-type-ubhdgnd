# examples:
# VolksWagenStiftung - https://jsontojsonp.gbv.de/?url=https:%2F%2Flobid.org%2Fgnd%2F5004690-1
# Albrecht Dürer - https://jsontojsonp.gbv.de/?url=https:%2F%2Flobid.org%2Fgnd%2F11852786X
# Entdeckung der Zauberflöte . http://lobid.org/gnd/7599114-7.json
# Edvard Grieg - https://jsontojsonp.gbv.de/?url=https:%2F%2Flobid.org%2Fgnd%2F118697641

# some fields are missing, thats on purpose. This is a curated selection, because not all fields make sense

# "# ++" --> doublechecked
# "# + checked" --> should theoretically work, but needs more explicit testing

class UBHDGNDUtil
  @arrayify: (value) ->
    return if value then (if Array.isArray(value) then value else [value])  else []

  @hrefGnd: (id) ->
    if id.startsWith('http')
      return id
    return 'https://d-nb.info/gnd/' + id.replace(/^gnd:/, '')

  # Return the value that will be used as the "_standard" Field for the CustomDataType
  @getStandard: (custom_data) ->
    return { text: custom_data.conceptName }

  @getFullText: (custom_data) ->
    if CUI.isArray(custom_data.conceptSeeAlso)
      conceptSeeAlsoText = custom_data.conceptSeeAlso.join(" ")
    else
      conceptSeeAlsoText = custom_data.conceptSeeAlso
    if custom_data.conceptDetails?.placeOfBusiness?
      conceptPlaceOfBusiness = custom_data.conceptDetails.placeOfBusiness.join(" ")
    else
      conceptPlaceOfBusiness = ""
    return {
      text: custom_data.conceptName + " " + conceptSeeAlsoText + " " + conceptPlaceOfBusiness
      string: custom_data.conceptURI
    }

  @buildCustomDataFromJSONLD: (jsonld) ->
    cdata = {
      conceptURI: @hrefGnd(jsonld["@id"])
      conceptName: jsonld.preferredName
      conceptType: jsonld["@type"]
      conceptSeeAlso: []
    }
    for variantName in jsonld.variantName
      if CUI.isPlainObject(variantName) and variantName["@value"]
        cdata.conceptSeeAlso.push(variantName["@value"])
      else
        cdata.conceptSeeAlso.push(variantName)

    cdata.conceptDetails = {}
    if jsonld.dateOfDeath?
      cdata.conceptDetails.dateOfDeath = jsonld.dateOfDeath["@value"]
      if jsonld.dateOfBirth?
        cdata.conceptDetails.dateOfBirth = jsonld.dateOfBirth["@value"]
    cdata.conceptDetails.placeOfBusiness = @arrayify(jsonld.placeOfBusiness).map (p) ->
      p.preferredName
    cdata.conceptDetails.professionOrOccupation = @arrayify(jsonld.professionOrOccupation).map (p) ->
      p.preferredName

    return cdata
