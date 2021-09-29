# import arrayify from 'arrayify'

class UBHDGNDUpdate
##start with main
  __start_update: ({ server_config, plugin_config }) ->
      # TODO: do some checks, maybe check if the library server is reachable
      ez5.respondSuccess({
        # NOTE:
        # 'state' object can contain any data the update script might need between updates.
        # the easydb server will save this and send it with any 'update' request
        state: {
            "start_update": new Date().toUTCString()
        }
      })

  __updateData: ({ objects, plugin_config }) ->
    that = @
    objectsMap = {}
    GNDIds = []

    for object in objects
      if not (object.identifier and object.data)
        continue

      gndURI = object.data.conceptURI
      console.error "Print the object concept uri", gndURI
      gndID = gndURI.split('gnd/')
      # takes whates comes after this expression as the ID
      gndID = gndID[1]

      if CUI.util.isEmpty(gndID)
        continue
      # if objectMap is not yet defined it is initialized as an empty list
      if not objectsMap[gndID]
      # It is possible to  have more than one object with the same ID in different objects.
        objectsMap[gndID] = []
      # objects are added to this new list
      objectsMap[gndID].push(object)
      GNDIds.push(gndID)
  
    # testing if modules work with the current setting
    console.error "Testing modules"
    # sayHello = require './object.coffee'
    sayHello() 

    if GNDIds.length == 0
      return ez5.respondSuccess({ payload: [] })

    timeout = plugin_config.update?.timeout or 0
    # The configuration is in seconds, so it is multiplied by 1000 to get milliseconds.
    timeout *= 1000
    # unique ubhdgnd-ids
    GNDIds = GNDIds.filter((x, i, a) => a.indexOf(x) == i)
    objectsToUpdate = []

    xhrPromises = []
    for GNDId, key in GNDIds
      deferred = new CUI.Deferred()
      xhrPromises.push deferred
    for GNDId, key in GNDIds
      do(key, GNDId) ->
        # get updates from UBHD norm data server
        xurl = 'https://digi.ub.uni-heidelberg.de/normdaten/gnd/' + GNDId

        console.error "calling " + xurl
        growingTimeout = key * 100
        setTimeout ( ->
            extendedInfo_xhr = new (CUI.XHR)(url: xurl)
            extendedInfo_xhr.start()
            .done((data, status, statusText) ->
              # validation-test on data.preferredName
              if !data.preferredName
                console.error "Record https://d-nb.info/ubhdgnd/" + GNDId + " not supported in lobid.org somehow"
              else
                # console.error(JSON.stringify(data)) ##this here gives the json file with all objects that are being checked

                resultsGNDID = data['gndIdentifier']
                # initialize the new data
                updatedGNDcdata = {}
                # this here section to be moved to object.coffee start++++++++++++++++++
                updatedGNDcdata.conceptURI = ("https://d-nb.info/gnd/"+data["@id"].split('gnd:')[1])
                updatedGNDcdata.conceptName = data.preferredName
                updatedGNDcdata.conceptSeeAlso = []
                # get all name variations, check for objects so that array of strings is returned
                for i in [0..data.variantName.length-1]
                  if CUI.isPlainObject(data.variantName[i]) and data.variantName[i]["@value"]
                    updatedGNDcdata.conceptSeeAlso.push(data.variantName[i]["@value"])
                  else
                    updatedGNDcdata.conceptSeeAlso.push(data.variantName[i])
                updatedGNDcdata.conceptType = data["@type"]
                updatedGNDcdata.conceptDetails = {}
                if data.dateOfDeath?
                  updatedGNDcdata.conceptDetails.dateOfDeath = data.dateOfDeath["@value"]
                  if data.dateOfBirth?
                    updatedGNDcdata.conceptDetails.dateOfBirth = data.dateOfBirth["@value"]
                updatedGNDcdata.conceptDetails.professionOrOccupation = []
                for i in [0..data.professionOrOccupation.length-1]
                # the profession or occupation is given as URL to the GND ID
                # updatedGNDcdata.conceptDetails.professionOrOccupation[i] = ("https://d-nb.info/gnd/"+data.professionOrOccupation[i]["@id"].split('gnd:')[1])
                # other possibility would be only leaving the ID
                  updatedGNDcdata.conceptDetails.professionOrOccupation[i] = data.professionOrOccupation[i]["@id"]
                # for standard and fulltext
                field_value = {}
                ;["conceptName", "conceptURI"].map (n) ->
                  field_value[n] = if updatedGNDcdata[n] then updatedGNDcdata[n].trim() else ""
                field_value.conceptType = if updatedGNDcdata.conceptType? then updatedGNDcdata.conceptType else ""
                # conceptDetails is an object
                field_value.conceptDetails = updatedGNDcdata.conceptDetails or {}
                # conceptSeeAlso is an array
                if updatedGNDcdata.conceptSeeAlso
                  field_value.conceptSeeAlso = updatedGNDcdata.conceptSeeAlso
                if CUI.isArray(field_value.conceptSeeAlso)
                  field_value.conceptSeeAlsoText = field_value.conceptSeeAlso.join(" ")
                else
                  conceptSeeAlsoText = field_value.conceptSeeAlso
                updatedGNDcdata._fulltext = { 
                  text: field_value.conceptName + " " + field_value.conceptSeeAlsoText
                  string: field_value.conceptURI }
                updatedGNDcdata._standard = { 
                  text: field_value.conceptName }
                # updatedGNDcdata[@name] = Object.assign field_value,
                 # _fulltext:
                 #  text: field_value.conceptName + " " + field_value.conceptSeeAlsoText
                 #  string: field_value.conceptURI
                 # _standard:
                 #  text: field_value.conceptName
                # this here section to be moved to object.coffee stop+++++++++++++++++++

                console.error(updatedGNDcdata, "with the UB implementation")

                if !objectsMap[resultsGNDID]
                  console.error "GND nicht in objectsMap: " + resultsGNDID
                  console.error "da hat sich die ID von " + GNDId + " zu " + resultsGNDID + " geändert"
                #here is where the actual comparrison takes place
                #only one difference replaces the entire object
                for objectsMapEntry in objectsMap[GNDId]
                  if not that.__hasChanges(objectsMapEntry.data, updatedGNDcdata)
                    continue
                  objectsMapEntry.data = updatedGNDcdata # Update the object that has changes.
                  objectsToUpdate.push(objectsMapEntry)

            )
            .fail ((data, status, statusText) ->
              ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {searchQuery: searchQuery, error: e + "Error connecting to entityfacts"})
            )
            .always =>
              xhrPromises[key].resolve()
              xhrPromises[key].promise()
        ), growingTimeout

    CUI.whenAll(xhrPromises).done( =>
      ez5.respondSuccess({payload: objectsToUpdate})
    )

  __hasChanges: (objectOne, objectTwo) ->
    for key in ["conceptName", "conceptURI", "_standard", "_fulltext"]
        if not CUI.util.isEqual(objectOne[key], objectTwo[key])
          console.error "is not equal"
          return true
        console.error "is equal"
      return false


  main: (data) ->
    if not data
      ez5.respondError("custom.data.type.ubhdgnd.update.error.payload-missing")
      return

    for key in ["action", "server_config", "plugin_config"]
      if (!data[key])
        # check if data has these keys in it
        ez5.respondError("custom.data.type.ubhdgnd.update.error.payload-key-missing", {key: key})
        return

    if (data.action == "start_update")
      @__start_update(data)
      return

    else if (data.action == "update")
      if (!data.objects)
        ez5.respondError("custom.data.type.ubhdgnd.update.error.objects-missing")
        return

      if (!(data.objects instanceof Array))
        ez5.respondError("custom.data.type.ubhdgnd.update.error.objects-not-array")
        return

      # NOTE: state for all batches
      # this contains any arbitrary data the update script might need between batches
      # it should be sent to the server during 'start_update' and is included in each batch
      if (!data.state)
        ez5.respondError("custom.data.type.ubhdgnd.update.error.state-missing")
        return

      # NOTE: information for this batch
      # this contains information about the current batch, espacially:
      #   - offset: start offset of this batch in the list of all collected values for this custom type
      #   - total: total number of all collected custom values for this custom type
      # it is included in each batch
      if (!data.batch_info)
        ez5.respondError("custom.data.type.ubhdgnd.update.error.batch_info-missing")
        return

      # TODO: check validity of config, plugin (timeout), objects...
      @__updateData(data)
      ## now go to __updateData
      return
    else
      ez5.respondError("custom.data.type.ubhdgnd.update.error.invalid-action", {action: data.action})

module.exports = new UBHDGNDUpdate()
