AuthoritiesClient = require("@ubhd/authorities-client")
debounce = require("lodash.debounce")

class CustomDataTypeWithCommonsWithSeeAlso extends CustomDataTypeWithCommons
  getFieldNames: ->
    fieldNames = @getFieldNamesForSearch()
    fieldNames.push [
      @fullName()+".conceptType"
      @fullName()+".conceptDetails"
    ]
    fieldNames

  getFieldNamesForSearch: ->
    return [
      @fullName()+".conceptURI"
      @fullName()+".conceptName"
      @fullName()+".conceptSeeAlso"
      ]

  getFieldNamesForSuggest: ->
    @getFieldNamesForSearch()

  # Version 5.34 added support for "_standard" Field in CustomDataTypePlugin.
  # https://docs.easydb.de/en/releases/releases.html#version-534
  # and
  # https://docs.easydb.de/en/technical/plugins/customdatatype/customdatatype.html#general-keys
  supportsStandard: ->
    true
  #----------------------------------------------------------------------
  # handle editorinput
  renderEditorInput: (data, top_level_data, opts) ->
    if not data[@name()]
      cdata = @buildEmptyData()
      data[@name()] = cdata
    else
      cdata = data[@name()]

    @__renderEditorInputPopover(data, cdata, opts)

  __renderEditorInputPopover: (data, cdata, opts) ->
    that = @
    layout
    buttons = [
      new CUI.Button
        text: ''
        icon: new CUI.Icon(class: "fa-ellipsis-v")
        class: 'pluginDirectSelectEditSearch'
        # show "dots"-menu on click on 3 vertical dots
        onClick: (e, dotsButton) =>
          dotsButtonMenu = new CUI.Menu
            element : dotsButton
            menu_items = [
                #search
                text: $$('custom.data.type.commons.controls.search.label')
                value: 'search'
                icon_left: new CUI.Icon(class: "fa-search")
                onClick: (e2, btn2) ->
                  that.showEditPopover(dotsButton, data, cdata, layout, opts)
            ]
            detailinfo =
              #detailinfo
              text: $$('custom.data.type.commons.controls.detailinfo.label')
              value: 'detail'
              icon_left: new CUI.Icon(class: "fa-info-circle")
              disabled: that.isEmpty(data, 0, 0)
              tooltip: @buildTooltipOpts(cdata, "w", true)
            menu_items.push detailinfo
            uriCall =
                # call uri
                text: $$('custom.data.type.commons.controls.calluri.label')
                value: 'uri'
                icon_left: new CUI.Icon(class: "fa-external-link")
                disabled: that.isEmpty(data, 0, 0) || ! CUI.parseLocation(cdata.conceptURI)
                onClick: ->
                  window.open cdata.conceptURI, "_blank"
            menu_items.push uriCall
            deleteClear =
                #delete / clear
                text: $$('custom.data.type.commons.controls.delete.label')
                value: 'delete'
                icon_left: new CUI.Icon(class: "fa-trash")
                disabled: that.isEmpty(data, 0, 0)
                onClick: ->
                  cdata = that.buildEmptyData()
                  data[that.name()] = cdata
                  that.__updateResult(cdata, layout, opts)
            menu_items.push deleteClear
            itemList =
              items: menu_items
          dotsButtonMenu.setItemList(itemList)
          dotsButtonMenu.show()
    ]
    # build layout for editor
    layout = new CUI.HorizontalLayout
      class: ''
      center:
        class: ''
      right:
        content:
          new CUI.Buttonbar
            buttons: buttons
    @__updateResult(cdata, layout, opts)
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
        ;["conceptName", "conceptURI"].map (n) ->
          field_value[n] = if cdata[n] then cdata[n].trim() else ""
        field_value.conceptType = if cdata.conceptType? then cdata.conceptType else ""
        # conceptDetails is an object
        field_value.conceptDetails = cdata.conceptDetails or {}
        # conceptSeeAlso is an array
        if cdata.conceptSeeAlso
          field_value.conceptSeeAlso = cdata.conceptSeeAlso


        save_data[@name()] = Object.assign field_value,
          _fulltext: UBHDGNDUtil.getFullText(cdata)
          _standard: UBHDGNDUtil.getStandard(cdata)
        console.log("UBHDGND saved data", save_data[@name()])

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
  # Instantiate authoritiesClient with the configured authorities_backend
  __getAuthoritiesClient: (custom_settings = {}) ->
    if @__authoritiesClient
      return @__authoritiesClient
    else if not CUI.util.isEmptyObject(custom_settings)
      pluginName = custom_settings.search?.authorities_backend
    else
      pluginName = @getCustomSchemaSetting("search", "authorities_backend")
    if not pluginName?
      pluginName = "ubhd/gnd"
    # TODO Add endpoint URL?
    @__authoritiesClient = AuthoritiesClient.plugin(pluginName, {width: 400})

  #----------------------------------------------------------------------
  # handle suggestions-menu
  __updateSuggestionsMenu: debounce((cdata, cdata_form, searchstring, input, suggest_Menu, searchsuggest_xhr, layout, opts) ->
    if not @__suggestMenu?
      @__suggestMenu = suggest_Menu
    if not searchstring or searchstring.length < 2
      # No search term has been entered
      suggest_Menu.hide()
      return
    types = @getCustomSchemaSetting("search", "gnd_types", [])
    # Default options for search, will be used for direct input in editor
    searchOpts =
      format: "opensearch"
      count: 50
      queryLevel: 1
      type: types
    # Form exists when the edit popover is open
    if cdata_form
      searchOpts.type = cdata.queryOptions.enabledGndTypes
      searchOpts.count = cdata.countOfSuggestions
      searchOpts.queryLevel = cdata.queryLevel

    @__getAuthoritiesClient().search(searchstring, searchOpts)
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
              value: UBHDGNDUtil.hrefGnd(gndId)
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
                Object.assign(cdata, UBHDGNDUtil.buildCustomDataFromJSONLD(jsonld) )
                # update form
                @__updateSeeAlsoDisplay(cdata)
                if cdata_form
                  if cdata.conceptSeeAlsoDisplay
                    cdata_form.getFieldsByName("conceptSeeAlsoDisplay")[0].show(true)
                  else
                    cdata_form.getFieldsByName("conceptSeeAlsoDisplay")[0].hide(true)
                  cdata_form.getFieldsByName("conceptURI")[0].setText(cdata.conceptURI)
                  cdata_form.getFieldsByName("conceptURI")[0].show(true)
                  cdata_form.displayValue()
                  cdata_form.triggerDataChanged()
                else
                  @__updateResult(cdata, layout, opts)
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
    additions = []
    if cdata.conceptDetails.dateOfDeath?
      if cdata.conceptDetails.dateOfBirth?
        dateOfBirthString = gYear(cdata.conceptDetails.dateOfBirth)
      else
        dateOfBirthString = "?"
      additions.push("#{dateOfBirthString} - #{gYear(cdata.conceptDetails.dateOfDeath)}")
    # Do not display professionOrOccupation
    #if cdata.conceptDetails.professionOrOccupation? && cdata.conceptDetails.professionOrOccupation.length > 0
    #  additions.push(cdata.conceptDetails.professionOrOccupation.join(", "))
    if additions.length > 0
      return "#{cdata.conceptName} (#{additions.join('; ')})"
    else
      return cdata.conceptName

  #----------------------------------------------------------------------
  # create form
  __getEditorFields: (cdata) ->
    @__suggestMenu = null
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
      types, @__getAuthoritiesClient().gndHierarchy,
      "custom.data.type.ubhdgnd.config.option.schema.search.gnd_types")
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
      tooltip = @buildTooltipOpts(cdata, "w", true)
    else
      tooltip = null
    tt_text = $$("custom.data.type.ubhdgnd.url.tooltip", name: cdata.conceptName)
    # label with name of entry and button with link to source
    new CUI.HorizontalLayout
      maximize: true
      left:
        content:
          new CUI.Label
            tooltip: tooltip
            text: @getConceptNameDisplay(cdata)
      center:
        content:
          # output Button with Name of picked Entry and Url to the Source
          new CUI.ButtonHref
            appearance: "link"
            href: cdata.conceptURI
            target: "_blank"
            tooltip:
              markdown: true
              text: tt_text
      right: null
    .DOM

  buildTooltipOpts: (cdata, placement="w") ->
    opts =
      placement: placement
      class: "gnd-tooltip"
      #placements: ["w","e","s"]
      content: (tooltip) =>
        @__getAdditionalTooltipInfo(cdata.conceptURI, tooltip)
        return new CUI.Label(icon: "spinner", text: "lade Informationen")
    opts


  __getAdditionalTooltipInfo: (encodedURI, tooltip, xhr) ->
    # download infos
    @__getAuthoritiesClient().infoBox(encodedURI, {showTypes: true, showThumbnail: true})
      .then (html) ->
        tooltip.__pane.replace(CUI.dom.htmlToNodes(html), "center")
        CUI.dom.setStyleOne(tooltip.DOM, "max-width", "50%")
        tooltip.autoSize()
      .catch (err) -> console.warn(new Error(err))


  #----------------------------------------------------------------------
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []
    enabledGndTypes = (custom_settings.search?.gnd_types or [])
    if enabledGndTypes.length == @__getAuthoritiesClient(custom_settings).gndHierarchy.count() or
       enabledGndTypes.length == 0
      tags.push "✓ " + $$("custom.data.type.ubhdgnd.config.option.schema.search.gnd_types.all")
    else
      enabledGndTypes.forEach (type) ->
        tags.push "✓ " + $$("custom.data.type.ubhdgnd.config.option.schema.search.gnd_types.#{type.trim()}")
    return tags


CustomDataType.register(CustomDataTypeUBHDGND)

# vim: sw=2 et
