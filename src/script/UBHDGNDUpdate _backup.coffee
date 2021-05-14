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
    GNDIds = []


    # console.log(" Now we are doing an update ")



    ## i think this checks if both of these things exist
    for object in objects
      if not (object.identifier and object.data)
        continue

      console.error "Print the object", object

      ## according to readme.me: conceptURI = URI to linked record
      # IU: this is the same for the UBHDGND plugin and should work as is
      gndURI = object.data.conceptURI
      console.error "Print the object concept uri", gndURI
      gndID = gndURI.split('d-nb.info/gnd/')
      ## takes whates comes after this expression as the ID
      gndID = gndID[1]

      if CUI.util.isEmpty(gndID)
        continue
      ## if objectMap is not yet defined it is initialized as an empty list
      if not objectsMap[gndID]
        objectsMap[gndID] = [] # It is possible to  have more than one object with the same ID in different objects.
      ## objects are added to this new list
      objectsMap[gndID].push(object)
      GNDIds.push(gndID)


    # console.log({"test",UBHDGNDIds}) ## at the moment we get no ids, so it finishes here
    #console.log(JSON.stringify(UBHDGNDIds.toString()))

  
    console.error "print the ids:", GNDIds

    if GNDIds.length == 0
      return ez5.respondSuccess({payload: []})

    timeout = plugin_config.update?.timeout or 0
    timeout *= 1000 # The configuration is in seconds, so it is multiplied by 1000 to get milliseconds.

    # unique ubhdgnd-ids
    GNDIds = GNDIds.filter((x, i, a) => a.indexOf(x) == i)

    objectsToUpdate = []

    xhrPromises = []
    for GNDId, key in GNDIds
      deferred = new CUI.Deferred()
      xhrPromises.push deferred
    console.error "GNDIds: ", GNDIds
    for GNDId, key in GNDIds
      do(key, GNDId) ->
        # get updates from lobid.org

        ## I think this somehow converts json files from the ubhdgnd to maybe a jsonp files, though i don't know why yet
        ## i also think, that is the point where it gets the data from the norm database
        # IU: it will return the JSON data inside a JS function to avoid issues with cross-domain requests
        ## old address
        #xurl = 'https://jsontojsonp.gbv.de/?url=' + CUI.encodeURIComponentNicely('https://lobid.org/gnd/' + GNDId)
        
        ##our address with CUI encode
        #xurl = 'https://jsontojsonp.gbv.de/?url=' + CUI.encodeURIComponentNicely('https://digi.ub.uni-heidelberg.de/normdaten/gnd/' + GNDId)

        ##our address
        xurl = 'https://jsontojsonp.gbv.de/?url=https://digi.ub.uni-heidelberg.de/normdaten/gnd/' + GNDId

        console.error "calling " + xurl
        growingTimeout = key * 100
        setTimeout ( ->
            extendedInfo_xhr = new (CUI.XHR)(url: xurl)
            extendedInfo_xhr.start()
            .done((data, status, statusText) ->
              # validation-test on data.preferredName
              if !data.preferredName
                console.error "Record https://d-nb.info/ubhdgnd/" + GNDId + " not supported in lobid.org somehow"
                #console.error data #from me
                #ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: "Record https://d-nb.info/ubhdgnd/" + ubhdgndID + " not supported in lobid.org yet!?"})
              else

                ## here we need to add our data conversion to the 
                console.error "This should be the third data"
                console.error(JSON.stringify(data)) ##this here gives the json file with all objects that are being checked
                console.error "third data ended \n"



                ## I think..
                console.error "get identifier " + data['gndIdentifier'] #from me
                # IU: not sure where data['gndIdentifier'] is set? there is no
                # gndIdentifier entry in the data JSON files
                resultsGNDID = data['gndIdentifier']

                console.error "post the identifier: ",resultsGNDID  #from me

                # then build new cdata and aggregate in objectsMap (see below)
                updatedGNDcdata = {}
                # IU: this could be the ID of the specific data object that is
                # defined in the top of the JSON data file
                
                #updatedGNDcdata.conceptURI = data['id'] # old one
                ##test something
                console.error "post the gnd identifierI: ", data['gndIdentifier']

                updatedGNDcdata.conceptURI = "https://d-nb.info/gnd/" + data['gndIdentifier'] #works for us
                #updatedGNDcdata.gndIdentifier = data['gndIdentifier'] # only the id


                console.error "post the new concept URI: ", updatedGNDcdata.conceptURI

                #updatedGNDcdata.conceptName = Date.now() + '_' + data['preferredName']
                updatedGNDcdata.conceptSeeAlso = data['variantNameForThePerson']
                
                ##this doesn't seem to work

                updatedGNDcdata.conceptName = data['preferredNameForThePerson']


                # IU: this is also contained in the JSON data file - the concept name
                # seems to contain the field entry of the data object for each of the
                # specified fields (like, 'preferredName')
                updatedGNDcdata._standard =
                  text: updatedGNDcdata.conceptName

                ##also from me
                console.error "print updated_ubhdgndcdata.conceptName: " + updatedGNDcdata.conceptName #from me
                #console.error(JSON.stringify(data))

                updatedGNDcdata._fulltext =
                  string: ez5.UBHDGNDUtil.getFullTextFromEntityFactsJSON(data)
                  text: ez5.UBHDGNDUtil.getFullTextFromEntityFactsJSON(data)

                console.error "print Fulltext:: " + JSON.stringify(updatedGNDcdata._fulltext) #from me

                if !objectsMap[resultsGNDID]
                  console.error "GND nicht in objectsMap: " + resultsGNDID
                  console.error "da hat sich die ID von " + GNDId + " zu " + resultsGNDID + " geändert"
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

    ##for key in ["conceptName", "conceptURI", "_standard","conceptSeeAlso", "_fulltext"]
      ##comparisson
      console.error "compare the two objects"
      console.error "object one:", objectOne[key]
      console.error "object two:", objectTwo[key]

      if not CUI.util.isEqual(objectOne[key], objectTwo[key])
        return true
    return false


## start
## whatever data is is importer here
## I think in overall this just checks the "data" for some key arguments and if they check out it starts the update
  main: (data) ->
    if not data
      ez5.respondError("custom.data.type.ubhdgnd.update.error.payload-missing")
      return

   ########################################
    ## this type of output actually works!!!
   # console.error "This should be the first data"
   # console.error(JSON.stringify(data)) #this gives the first print of data, the one thats not useful
   # console.error "first data ended \n"



    for key in ["action", "server_config", "plugin_config"]
      if (!data[key])
        ##check if data has these keys in it
        ez5.respondError("custom.data.type.ubhdgnd.update.error.payload-key-missing", {key: key})
        return

    console.error (data.action) #from me temp
    if (data.action == "start_update")
      @__start_update(data)

      console.error "this is start_update" ##from me temp
      return

    else if (data.action == "update")

      console.error "this is update" ##from me temp

      ##################################
      console.error "This should be the second data"
      console.error(JSON.stringify(data)) ##this here gives the json file with all objects that are being checked
      console.error "second data ended \n"


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
