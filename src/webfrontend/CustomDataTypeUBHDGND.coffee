AuthoritiesClient = require("@ubhd/authorities-client")
debounce = require("lodash.debounce")

class CustomDataTypeWithCommonsWithSeeAlso extends CustomDataTypeWithCommons
  getFieldNames: ->
    return [
      @fullName()+".conceptURI"
      @fullName()+".conceptName"
      @fullName()+".conceptSeeAlso"
      @fullName()+".conceptType"
      @fullName()+".conceptDetails"
      ]

  #----------------------------------------------------------------------
  # handle editorinput
  renderEditorInput: (data, top_level_data, opts) ->
    if not data[@name()]
      cdata = @buildEmptyData()
      data[@name()] = cdata
    else
      cdata = data[@name()]

    @__renderEditorInputPopover(data, cdata)

  renderFieldAsGroup: ->
    return false

  __renderEditorInputPopover: (data, cdata) ->
    layout = new CUI.HorizontalLayout
      maximize_horizontal: false
      left:
        content:
          new CUI.Buttonbar(
            buttons: [
              new CUI.Button
                text: ""
                icon: "edit"
                group: "groupA"
                onClick: (ev, btn) =>
                  @showEditPopover(btn, cdata, layout)
              new CUI.Button
                text: ""
                icon: "trash"
                group: "groupA"
                onClick: (ev, btn) =>
                  # delete data
                  cdata = @buildEmptyData()
                  data[@name()] = cdata
                  # trigger form change
                  @__updateResult(cdata, layout)
                  CUI.Events.trigger
                    node: @__layout
                    type: "editor-changed"
                  CUI.Events.trigger
                    node: layout
                    type: "editor-changed"
              ]
            )
      right: {}
    @__updateResult(cdata, layout)
    layout


  #----------------------------------------------------------------------
  # is called, when record is being saved by user
  getSaveData: (data, save_data, opts) ->
    if opts.demo_data
      # return demo data here
      return {
        conceptName : "Example"
        conceptURI : "https://example.com"
        conceptSeeAlso : ["Beispiel", "Exemplo" ,"Instance"]
        conceptType : "ExampleType"
        conceptDetails:
          dateOfBirth: "1979"
      }

    cdata = data[@name()] or data._template?[@name()]

    switch @getDataStatus(cdata)
      when "invalid"
        throw InvalidSaveDataException

      when "empty"
        save_data[@name()] = null

      when "ok"
        field_value = {}
        ;["conceptName", "conceptURI", "conceptType"].map (n) ->
          field_value[n] = if cdata[n] then cdata[n].trim() else ""
        # conceptDetails is an object
        field_value.conceptDetails = cdata.conceptDetails or {}
        # conceptSeeAlso is an array
        if cdata.conceptSeeAlso
          field_value.conceptSeeAlso = cdata.conceptSeeAlso
        if CUI.isArray(field_value.conceptSeeAlso)
          conceptSeeAlsoText = field_value.conceptSeeAlso.join(" ")
        else
          conceptSeeAlsoText = field_value.conceptSeeAlso
        save_data[@name()] = Object.assign field_value,
          _fulltext:
            text: field_value.conceptName + " " + conceptSeeAlsoText
            string: field_value.conceptURI

  buildEmptyData: () ->
    {
      conceptName : ""
      conceptURI : ""
      conceptSeeAlso: []
      conceptType: ""
      conceptDetails: {}
    }

  #----------------------------------------------------------------------
  # checks the form and returns status
  getDataStatus: (cdata) ->
    if (cdata)
      if cdata.conceptURI and cdata.conceptName
        # check url for valididy
        uriCheck = CUI.parseLocation(cdata.conceptURI)

        nameCheck = if cdata.conceptName then cdata.conceptName.trim() else undefined

        if uriCheck and nameCheck
          return "ok"

        if cdata.conceptURI.trim() == "" and cdata.conceptName.trim() == ""
          return "empty"

        return "invalid"
      else
        cdata = @buildEmptyData()
        return "empty"
    else
      cdata = @buildEmptyData()
      return "empty"

  #----------------------------------------------------------------------
  # @param {string} name setting name
  # @param {*} fallback Fallback value if no value or value is falsey
  # @return {string} the value of a field config setting or null if not defined
  getCustomSchemaSetting: (group, parameter, fallback) ->
    @getCustomSchemaSettings()[group]?[parameter] ? fallback



########################################################################
#
#
#
#
#
#
########################################################################

module.exports =\
class CustomDataTypeUBHDGND extends CustomDataTypeWithCommonsWithSeeAlso

  getCustomDataTypeName: -> "custom:base.custom-data-type-ubhdgnd.ubhdgnd"

  getCustomDataTypeNameLocalized: -> $$("custom.data.type.ubhdgnd.name")

  getEditPopoverTitle: -> $$("custom.data.type.ubhdgnd.modal.title")

  #----------------------------------------------------------------------
  # make sure enabled overridable options are actually enabled
  showEditPopover: (args...) ->
    super(args...)
    console.log @getCustomSchemaSettings()

  #----------------------------------------------------------------------
  # Instantiate authoritiesClient with the configured authorities_backend
  __getAuthoritiesClient: () ->
    if @__authoritiesClient
      return @__authoritiesClient
    else
      pluginName = @getCustomSchemaSetting("search", "authorities_backend")
      # TODO Add endpoint URL?
      @__authoritiesClient = AuthoritiesClient.plugin(pluginName, {width: 400})

  #----------------------------------------------------------------------
  # handle suggestions-menu
  __updateSuggestionsMenu: debounce((cdata, cdata_form, suggest_Menu) ->
    if not @__suggestMenu?
      @__suggestMenu = suggest_Menu
    if not cdata.searchbarInput or cdata.searchbarInput.length < 2
      # No search term has been entered
      suggest_Menu.hide()
      return
    {preferredName, variantName, arrayify, hrefGnd} = AuthoritiesClient.utils.handlebars.helpers
    searchOpts =
      format: "opensearch"
      type: cdata.queryOptions.enabledGndTypes
      count: cdata.countOfSuggestions
      queryLevel: cdata.queryLevel
    @__getAuthoritiesClient().search(cdata.searchbarInput, searchOpts)
      .then (data) =>
        # create new menu with suggestions
        menu_items = []
        for i of data[1]
          # the actual Featureclass...
          suggestion = data[1][i]
          aktType    = data[2][i]
          gndId      = data[3][i]
          #lastType   = data[2][i-1]

          # style menu
          #if aktType != lastType
          #  if i == 0
          #    menu_items.push divider: true
          #  menu_items.push label: aktType
          #  menu_items.push divider: true

          do (gndId) =>
            menu_items.push
              text: suggestion
              value: hrefGnd(gndId)
              tooltip: @buildTooltipOpts( { conceptURI: gndId }, "e")

        # set new items to menu
        itemList =
          items: menu_items
          onClick: (ev2, btn) =>
            gndUri = btn.getOpt("value")
            @__getAuthoritiesClient().get(gndUri)
              .then (jsonld) =>
                # reset input
                cdata.searchbarInput = ""
                # lock in save data
                cdata.conceptURI = hrefGnd(jsonld["@id"])
                cdata.conceptName = preferredName(jsonld)
                cdata.conceptSeeAlso = arrayify(variantName(jsonld))
                cdata.conceptType = jsonld["@type"]
                cdata.conceptDetails = {}
                if jsonld.dateOfDeath?
                  cdata.conceptDetails.dateOfDeath = jsonld.dateOfDeath["@value"]
                  if jsonld.dateOfBirth?
                    cdata.conceptDetails.dateOfBirth = jsonld.dateOfBirth["@value"]
                cdata.conceptDetails.professionOrOccupation = arrayify(jsonld.professionOrOccupation).map (p) ->
                    p.preferredName
                # update form
                @__updateSeeAlsoDisplay(cdata)
                if cdata.conceptSeeAlsoDisplay
                  console.log "seeAlsoDisplay true"
                  cdata_form.getFieldsByName("conceptSeeAlsoDisplay")[0].show(true)
                else
                  cdata_form.getFieldsByName("conceptSeeAlsoDisplay")[0].hide(true)
                cdata_form.getFieldsByName("conceptURI")[0].setText(cdata.conceptURI)
                cdata_form.getFieldsByName("conceptURI")[0].show(true)
                cdata_form.displayValue()
                cdata_form.triggerDataChanged()
                console.log("selected", cdata)
              .catch (err) -> console.error(err)
            return @

        # if no hits set "empty" message to menu
        if itemList.items.length == 0
          itemList =
            items: [
              text: "kein Treffer"
              value: undefined
            ]

        suggest_Menu.setItemList(itemList)
        suggest_Menu.show()
      .catch (err) ->
        console.warn(new Error(err))
  , 200)

  __updateSeeAlsoDisplay: (cdata) ->
    if CUI.isArray(cdata.conceptSeeAlso) and cdata.conceptSeeAlso.length > 0
      cdata.conceptSeeAlsoDisplay = cdata.conceptSeeAlso.join('\n')
    else
      cdata.conceptSeeAlsoDisplay = ""

  getConceptNameDisplay: (cdata) ->
    unless cdata.conceptDetails?
      return cdata.conceptName
    gYear = AuthoritiesClient.utils.handlebars.helpers.gYear  
    displayString = cdata.conceptName
    additions = []
    if cdata.conceptDetails.dateOfDeath?
      additions.push(gYear(cdata.conceptDetails.dateOfBirth) + " - #{gYear(cdata.conceptDetails.dateOfDeath)}")
    if cdata.conceptDetails.professionOrOccupation? && cdata.conceptDetails.professionOrOccupation.length > 0
      additions.push(cdata.conceptDetails.professionOrOccupation.join(", "))
    if additions.length > 0
      displayString += " (#{additions.join('; ')})"
    return displayString

  #----------------------------------------------------------------------
  # create form
  __getEditorFields: (cdata) ->
    @__suggestMenu = null
    console.log cdata
    types = @getCustomSchemaSetting("search", "gnd_types", [])
    # Set defaults
    cdata.countOfSuggestions = 50
    cdata.queryOptions = { enabledGndTypes: types }
    typeOpts =
      type: CUI.Options
      undo_and_changed_support: false
      min_checked: 1
      name: 'enabledGndTypes'
      horizontal: false
    @__updateSeeAlsoDisplay(cdata)
    typesField = OptionsTreeConfigPlugin.buildOptionsField(typeOpts,
      types, @__getAuthoritiesClient().gndHierarchy)
    fields = [
      {
        type: CUI.Input
        undo_and_changed_support: false
        form:
            label: $$("custom.data.type.ubhdgnd.modal.form.text.searchbar")
        placeholder: $$("custom.data.type.ubhdgnd.modal.form.text.searchbar.placeholder")
        name: "searchbarInput"
        onFocus: (input, evt) =>
          if input.getValue()            
            @__suggestMenu?.show()
        # class: "commonPlugin_Input"
      }
      {
        type: CUI.Checkbox
        undo_and_changed_support: false
        form:
          label: $$("custom.data.type.ubhdgnd.modal.form.text.querylevel")
          hint: $$("custom.data.type.ubhdgnd.modal.form.text.querylevel.hint")
        name: "queryLevel"
        value: 0
        value_unchecked: 1
      }
      {
        type: CUI.FormPopover
        popover:
          class:
            "gnd-types-popover"
        undo_and_changed_support: false
        form:
          label: $$("custom.data.type.ubhdgnd.modal.form.text.restrictsearch")
        name: "queryOptions"
        button:
          text: $$("custom.data.type.ubhdgnd.modal.form.text.type")
          icon_inactive: new CUI.Icon(class: "fa-angle-down")
          icon_active: new CUI.Icon(class: "fa-angle-up")
        fields:
          [
            typesField
            # type: CUI.Options
            # undo_and_changed_support: false
            # # class: "commonPlugin_Select"
            # #form:
            # #  label: $$("custom.data.type.ubhdgnd.modal.form.text.type")
            # name: "enabledGndTypes"
            # horizontal: false
            # min_checked: 1
            # options: types.map (type) ->
            #   value: type
            #   text: $$("custom.data.type.ubhdgnd.config.option.schema.search.gnd_types.#{type}")
          ]
      }
      {
        type: CUI.Select
        undo_and_changed_support: false
        class: "commonPlugin_Select"
        form:
            label: $$("custom.data.type.ubhdgnd.modal.form.text.count")
        options: [20, 50, 100, 500].map (n) -> value: n
        name: "countOfSuggestions"
      }
      {
        form:
          label: "Gewählter Eintrag"
        type: CUI.Output
        name: "conceptName"
        getValue: (value, data) =>
          @getConceptNameDisplay(cdata)
      }
      {
        form:
          label: $$("custom.data.type.ubhdgnd.modal.form.text.uri.label")
        type: CUI.FormButton
        appearance: "link"
        icon: "external_link"
        name: "conceptURI"
        text: cdata.conceptURI
        tooltip: @buildTooltipOpts(cdata, "e")
        onClick: (evt,button) ->
          window.open cdata.conceptURI, "_blank"
        onRender: (_this) ->
          if cdata.conceptURI == ""
            _this.hide()
      }
      {
        form:
          label: $$("custom.data.type.ubhdgnd.modal.form.text.conceptSeeAlso.label")
        type: CUI.Input
        undo_and_changed_support: false
        textarea: true        
        readonly: true
        readonly_select_all: false
        hidden: cdata.conceptSeeAlsoDisplay == ""
        name: "conceptSeeAlsoDisplay"
      }
    ]

    return fields


  #----------------------------------------------------------------------
  # renders the "result" in original form (outside popover)
  __renderButtonByData: (cdata) ->

    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new CUI.EmptyLabel(
          text: $$("custom.data.type.ubhdgnd.edit.no_gnd"))
        .DOM
      when "invalid"
        return new CUI.EmptyLabel(
          text: $$("custom.data.type.ubhdgnd.edit.no_valid_gnd"))
        .DOM

    # if status is ok
    conceptURI = CUI.parseLocation(cdata.conceptURI).url

    # if conceptURI .... ... patch abwarten
    # show infobox tooltip if enabled in mask settings
    if @getCustomMaskSettings().show_infopopup?.value
      tooltip = @buildTooltipOpts(cdata, "w")
    else
      tooltip =
        markdown: true
        placement: "w"
        content: $$("custom.data.type.ubhdgnd.url.tooltip", name: cdata.conceptName)
    # output Button with Name of picked Entry and Url to the Source
    return new CUI.ButtonHref
      appearance: "link"
      href: cdata.conceptURI
      target: "_blank"
      tooltip: tooltip
      text: @getConceptNameDisplay(cdata)
    .DOM

  buildTooltipOpts: (cdata, placement="w") ->
    markdown: true
    placement: placement
    class: "gnd-tooltip"
    #placements: ["w","e","s"]
    content: (tooltip) =>
      # download infos
      @__getAuthoritiesClient().infoBox(cdata.conceptURI)
        .then (html) ->
          tooltip.__pane.replace(CUI.dom.htmlToNodes(html), "center")
          CUI.dom.setStyleOne(tooltip.DOM, "max-width", "50%")
          tooltip.autoSize()
          #tooltip.DOM.style.maxWidth = "40%"
        .catch (err) -> console.warn(new Error(err))
      return new CUI.Label(icon: "spinner", text: "lade Informationen")


  #----------------------------------------------------------------------
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []
    console.log custom_settings
    # TODO If all types enabled just display "All Types", "Alle Typen"
    (custom_settings.search?.gnd_types or []).forEach (gndClass) ->
      tags.push "✓ " + $$("custom.data.type.ubhdgnd.config.option.schema.search.gnd_types.#{gndClass.trim()}")
    return tags


CustomDataType.register(CustomDataTypeUBHDGND)

# vim: sw=2 et
