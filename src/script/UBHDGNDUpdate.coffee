path = require('path')
fs = require("fs")

# Global configuration
AUTHORITIES_ENDPOINT = 'https://digi.ub.uni-heidelberg.de/normdaten/gnd/'

class UBHDGNDUpdate
  __start_update: ({ server_config, plugin_config}) ->
    # TODO: do some checks, maybe check if the library server is reachable
    # create and open new log file and writestream
    # write start update and offset size
    startUpdate = new Date().toISOString()
    logFilePath = path.join "/easydb-5/var", "ubhdgnd-update-".concat(startUpdate, ".log")
    fs.writeFile(logFilePath, "Started update " + startUpdate + '\n', (err) =>
      if err
        console.error(err)
        ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: err.toString()})
      else
        console.error("Created log file ", logFilePath)
        ez5.respondSuccess({
          # NOTE:
          # 'state' object can contain any data the update script might need between updates.
          # the easydb server will save this and send it with any 'update' request
          state: {
            "start_update": startUpdate
            "log_file_path": logFilePath
          }
        })
    )

  __updateData: ({ objects, plugin_config , batch_info, state}) ->
    that = @
    objectsMap = {}
    GNDIds = []
    console.error("Writing log to ", state.log_file_path)
    logFile = fs.createWriteStream(state.log_file_path, {flags:'a'})
    logFile.on('error', (err) =>
      console.error "write to log file error: ", err
      ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: err.toString()})
    )
    logger = new console.Console({ stdout: logFile, stderr: logFile });
    logger.log(new Date().toISOString(), "Started batch", batch_info)
    for object in objects
      if not (object.identifier and object.data)
        continue
      gndURI = object.data.conceptURI
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
      do(key, GNDId) ->
        # get updates from UBHD norm data server
        extendedInfo_xhr = new (CUI.XHR) {
          url: AUTHORITIES_ENDPOINT + GNDId + '?resolveLabels=1',
          timeout: timeout
        }
        extendedInfo_xhr.start().done((jsonld, status, statusText) ->
            # validation-test on preferredName
            try
              if !jsonld.preferredName
                msg = "Record https://d-nb.info/gnd/" + GNDId + " not found in digi.ub.uni-heidelberg.de/normdaten somehow"
                logger.error key, msg
                ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: msg})
              else
                resultsGNDID = jsonld['gndIdentifier']
                logger.log key, "retrieved:", resultsGNDID, "last modified:", jsonld.meta.modified.$date
                # initialize the new data
                updatedGNDcdata = UBHDGNDUtil.buildCustomDataFromJSONLD(jsonld)
                # for standard and fulltext pass the updated data
                updatedGNDcdata._fulltext = UBHDGNDUtil.getFullText(updatedGNDcdata)
                updatedGNDcdata._standard = UBHDGNDUtil.getStandard(updatedGNDcdata)
                if !objectsMap[resultsGNDID]
                  logger.error key, "redirected GND entry from " + GNDId + " to " + resultsGNDID + " geändert"
                #here is where the actual comparison takes place
                #only one difference replaces the entire object
                for objectsMapEntry in objectsMap[GNDId]
                  # CUI.util.isEqual checks object equality for every property recursively
                  if CUI.util.isEqual(objectsMapEntry.data, updatedGNDcdata)
                    logger.log key, "skipped", GNDId, "no changes"
                    continue
                  objectsMapEntry.data = updatedGNDcdata # Update the object that has changes.
                  objectsToUpdate.push(objectsMapEntry)
            catch error
              logger.error(key, "updatedGNDcdata", updatedGNDcdata)
              logger.error(error)
              ez5.respondError("custom.data.type.ubhdgnd.update.error.generic", {error: error.toString()})
          )
          .fail ((data, status, statusText) ->
            logger.error("request failed", data, status, statusText)
            ez5.respondError("custom.data.type.ubhdgnd.update.error.generic",
              {error: "HTTP request failed, status: " + status + ", statusText: " + statusText})
          )
          .always =>
            xhrPromises[key].resolve()
            xhrPromises[key].promise()

    CUI.whenAll(xhrPromises).done( =>
      logger.log new Date().toISOString(), "Processed", batch_info.offset + objects.length, "/", batch_info.total
      # if the script does not wait for the callback and calls ez5.respondSuccess immediately the
      # previous line won't be written to the logfile
      logFile.end(() =>
        ez5.respondSuccess({payload: objectsToUpdate})
      )
    )

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
