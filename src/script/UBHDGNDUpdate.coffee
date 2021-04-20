class UBHDGNDUpdate
##start with main
  __start_update: ({server_config, plugin_config}) ->
      # TODO: do some checks, maybe check if the library server is reachable
      ez5.respondSuccess({
        # NOTE:
        # 'state' object can contain any data the update script might need between updates.
        # the easydb server will save this and send it with any 'update' request
        state: {
            "start_update": new Date().toUTCString()
        }
      })

  __updateData: ({objects, plugin_config}) ->
  ## what the heck??
    that = @
    objectsMap = {}
    UBHDGNDIds = []

    ## i think this checks if both of these things exist
    for object in objects
      if not (object.identifier and object.data)
        continue

      ## according to readme.me: conceptURI = URI to linked record
      ubhdgndURI = object.data.conceptURI
      ubhdgndID = ubhdgndURI.split('d-nb.info/ubhdgnd/')
      ## takes whates comes after this expression as the ID 
      ubhdgndID = ubhdgndID[1]
      if CUI.util.isEmpty(ubhdgndID)
        continue
      ## if objectMap is not yet defined it is initialized as an empty list
      if not objectsMap[ubhdgndID]
        objectsMap[ubhdgndID] = [] # It is possible to  have more than one object with the same ID in different objects.
      ## objects are added to this new list
      objectsMap[ubhdgndID].push(object)
      UBHDGNDIds.push(ubhdgndID)

    if UBHDGNDIds.length == 0
      return ez5.respondSuccess({payload: []})

    timeout = plugin_config.update?.timeout or 0
    timeout *= 1000 # The configuration is in seconds, so it is multiplied by 1000 to get milliseconds.

    # unique ubhdgnd-ids
    UBHDGNDIds = UBHDGNDIds.filter((x, i, a) => a.indexOf(x) == i)

    objectsToUpdate = []

    xhrPromises = []
    for UBHDGNDId, key in UBHDGNDIds
      deferred = new CUI.Deferred()
      xhrPromises.push deferred
    console.error "UBHDGNDIds ", UBHDGNDIds
    for UBHDGNDId, key in UBHDGNDIds
      do(key, UBHDGNDId) ->
        # get updates from lobid.org

        ## I think this somehow converts json files from the ubhdgnd to maybe a jsonp files, though i don't know why yet 
        ## i also think, that is the point where it gets the data from the norm database
        xurl = 'https://jsontojsonp.gbv.de/?url=' + CUI.encodeURIComponentNicely('https://lobid.org/ubhdgnd/' + UBHDGNDId)

        console.error "calling " + xurl
        growingTimeout = key * 100
        setTimeout ( ->
            extendedInfo_xhr = new (CUI.XHR)(url: xurl)
            extendedInfo_xhr.start()
            .done((data, status, statusText) ->
              # validation-test on data.preferredName
              if !data.preferredName
                console.error "Record https://d-nb.info/ubhdgnd/" + ubhdgndID + " not supported in lobid.org somehow"
                console.error data
                #ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: "Record https://d-nb.info/ubhdgnd/" + ubhdgndID + " not supported in lobid.org yet!?"})
              else

                ## here we need to add our data conversion to the
                ## I think..
                resultsUBHDGNDID = data['ubhdgndIdentifier']

                # then build new cdata and aggregate in objectsMap (see below)
                updatedUBHDGNDcdata = {}
                updatedUBHDGNDcdata.conceptURI = data['id']
                #updatedUBHDGNDcdata.conceptName = Date.now() + '_' + data['preferredName']
                updatedUBHDGNDcdata.conceptName = data['preferredName']

                updatedUBHDGNDcdata._standard =
                  text: updatedUBHDGNDcdata.conceptName

                updatedUBHDGNDcdata._fulltext =
                  string: ez5.UBHDGNDUtil.getFullTextFromEntityFactsJSON(data)
                  text: ez5.UBHDGNDUtil.getFullTextFromEntityFactsJSON(data)

                if !objectsMap[resultsUBHDGNDID]
                  console.error "UBHDGND nicht in objectsMap: " + resultsUBHDGNDID
                  console.error "da hat sich die ID von " + UBHDGNDId + " zu " + resultsUBHDGNDID + " geändert"
                for objectsMapEntry in objectsMap[UBHDGNDId]
                  if not that.__hasChanges(objectsMapEntry.data, updatedUBHDGNDcdata)
                    continue
                  objectsMapEntry.data = updatedUBHDGNDcdata # Update the object that has changes.
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
        return true
    return false


## start
## whatever data is is importer here
## I think in overall this just checks the "data" for some key arguments and if they check out it statrs the update
  main: (data) ->
    if not data
      ez5.respondError("custom.data.type.ubhdgnd.update.error.payload-missing")
      return

    for key in ["action", "server_config", "plugin_config"]
      if (!data[key])
        ##check if data has these keys in it 
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
