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
        xurl = 'https://digi.ub.uni-heidelberg.de/normdaten/gnd/' + GNDId + '?resolveLabels=1'

        console.error "calling " + xurl
        growingTimeout = key * 100
        setTimeout ( ->
            extendedInfo_xhr = new (CUI.XHR)(url: xurl)
            extendedInfo_xhr.start()
            .done((data, status, statusText) ->
              # validation-test on data.preferredName
              try
                if !data.preferredName
                  console.error "Record https://d-nb.info/gnd/" + GNDId + " not found in digi.ub.uni-heidelberg.de/normdaten somehow"
                else
                  # console.error(JSON.stringify(data)) ##this here gives the json file with all objects that are being checked

                  resultsGNDID = data['gndIdentifier']
                  console.error key, "retrieved ", resultsGNDID
                  # initialize the new data
                  updatedGNDcdata = UBHDGNDUtil.buildCustomDataFromJSONLD(data)
                  # for standard and fulltext pass the updated data
                  updatedGNDcdata._fulltext = UBHDGNDUtil.getFullText(updatedGNDcdata)
                  updatedGNDcdata._standard = UBHDGNDUtil.getStandard(updatedGNDcdata)
                  console.error(key, "last modification date", data.meta.modified.$date)
                  console.error(key, updatedGNDcdata, "with the UB implementation")

                  if !objectsMap[resultsGNDID]
                    console.error "GND nicht in objectsMap: " + resultsGNDID
                    console.error "da hat sich die ID von " + GNDId + " zu " + resultsGNDID + " geändert"
                  #here is where the actual comparrison takes place
                  #only one difference replaces the entire object
                  for objectsMapEntry in objectsMap[GNDId]
                    if not that.__hasChanges(objectsMapEntry.data, updatedGNDcdata)
                      console.error key, "skipped", GNDId, "no changes"
                      continue
                    objectsMapEntry.data = updatedGNDcdata # Update the object that has changes.
                    objectsToUpdate.push(objectsMapEntry)
              catch error
                console.error(error)
                ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: error.toString()})
            )
            .fail ((data, status, statusText) ->
              console.error("promise failed", data, status, statusText)
              ez5.respondError("custom.data.type.ubhdgnd.update.error.generic",
                {error: "Request failed status: " + status + ",statusText: " + statusText})
            )
            .always =>
              xhrPromises[key].resolve()
              xhrPromises[key].promise()
        ), growingTimeout

    CUI.whenAll(xhrPromises).done( =>
      ez5.respondSuccess({payload: objectsToUpdate})
    )

  __hasChanges: (objectOne, objectTwo) ->
    for key in ["conceptName","conceptSeeAlso", "conceptURI", "_standard", "_fulltext"]
        if not CUI.util.isEqual(objectOne[key], objectTwo[key])
          console.error key, "is not equal"
          return true
        console.error key, "is equal"
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
