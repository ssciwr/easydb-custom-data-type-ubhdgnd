AuthoritiesClient = require('@ubhd/authorities-client')

module.exports = \
class CustomDataTypeUBHDGND extends CustomDataTypeWithCommons


  #######################################################################
  # return name of plugin
  getCustomDataTypeName: ->
    "custom:base.custom-data-type-ubhdgnd.ubhdgnd"


  #######################################################################
  # return name (l10n) of plugin
  getCustomDataTypeNameLocalized: ->
    $$("custom.data.type.ubhdgnd.name")


  #######################################################################
  # handle suggestions-menu
  __updateSuggestionsMenu: (cdata, cdata_form, suggest_Menu) ->

    # TODO debounce
    gnd_searchterm = cdata_form.getFieldsByName("searchbarInput")[0].getValue()
    gnd_searchtypes = cdata_form.getFieldsByName("gndSelectType")[0].getValue()

    console.log({gnd_searchtypes, gnd_searchterm})

    # XXX TODO reenable configurable
    # if "search-all-types", search all allowed types
    # if gnd_searchtypes == 'all_supported_types'
    #   gnd_searchtypes = []
    #   if @getCustomSchemaSettings().add_differentiatedpersons?.value
    #     gnd_searchtypes.push 'DifferentiatedPerson'
    #   if @getCustomSchemaSettings().add_coorporates?.value
    #     gnd_searchtypes.push 'CorporateBody'
    #   if @getCustomSchemaSettings().add_geographicplaces?.value
    #     gnd_searchtypes.push 'PlaceOrGeographicName'
    #   if @getCustomSchemaSettings().add_subjects?.value
    #     gnd_searchtypes.push 'SubjectHeading'

    # # if only a "subclass" is active
    # subclass = @getCustomSchemaSettings().exact_types?.value
    # subclassQuery = ''

    # if subclass != undefined
    #   if subclass != 'ALLE'
    #     subclassQuery = '&exact_type=' + subclass

    # gnd_countSuggestions = cdata_form.getFieldsByName("countOfSuggestions")[0].getValue()

    # if gnd_searchterm.length == 0
    #     return

    # # run autocomplete-search via xhr
    # if searchsuggest_xhr.xhr != undefined
    #     # abort eventually running request
    #     searchsuggest_xhr.xhr.abort()

    # start new request
    authoritiesClient = AuthoritiesClient()
    authoritiesClient
      .suggest(gnd_searchterm, {type: gnd_searchtypes, format: 'opensearch', withSubTypes: true})
      .then((data) =>
        # create new menu with suggestions
        menu_items = []
        for i of data[1]
          # console.log(suggestion, i)
          do(i) =>
            # the actual Featureclass...
            suggestion = data[1][i]
            aktType    = data[2][i]
            gndId      = data[3][i]
            lastType   = data[2][i-1]
            if i == 0
              menu_items.push label: aktType
              menu_items.push divider: true
            else if aktType != lastType
              menu_items.push divider: true
              menu_items.push label: aktType
              menu_items.push divider: true
            menu_items.push
              text: suggestion
              value: "http://d-nb.info/gnd/#{gndId}"
              tooltip:
                markdown: false
                placement: "n"
                content: (tooltip) =>
                  # # if enabled in mask-config
                  # XXX TODO reenable configurable
                  # return unless @getCustomMaskSettings().show_infopopup?.value
                  # download infos
                  authoritiesClient.infoBox(gndId)
                    .then (html) ->
                      tooltip.DOM.html(html)
                      tooltip.DOM.style.maxWidth = '100%'
                    .catch (err) -> console.log("GND / FAIL", err)
                  return new Label(icon: "spinner", text: "lade Informationen")

        # set new items to menu
        itemList =
          onClick: (ev2, btn) ->
            # lock in save data
            cdata.conceptURI = btn.getOpt("value")
            cdata.conceptName = btn.getText()
            # lock in form
            cdata_form.getFieldsByName("conceptName")[0].storeValue(cdata.conceptName).displayValue()
            # nach eadb5-Update durch "setText" ersetzen und "__checkbox" rausnehmen
            cdata_form.getFieldsByName("conceptURI")[0].__checkbox.setText(cdata.conceptURI)
            cdata_form.getFieldsByName("conceptURI")[0].show()

            # clear searchbar
            cdata_form.getFieldsByName("searchbarInput")[0].setValue('')
            # hide suggest-menu
            suggest_Menu.hide()
            return @
          items: menu_items

        # if no hits set "empty" message to menu
        if itemList.items.length == 0
          itemList =
            items: [
              text: "kein Treffer"
              value: undefined
            ]

        suggest_Menu.setItemList(itemList)

        suggest_Menu.show()
    )


  #######################################################################
  # create form
  __getEditorFields: (cdata) ->
    # read searchtypes from datamodell-options
    dropDownSearchOptions = []

    # offer DifferentiatedPerson
    if @getCustomSchemaSettings().add_differentiatedpersons?.value
      dropDownSearchOptions.push
        value: 'DifferentiatedPerson'
        text: 'Individualisierte Personen'

    # offer CorporateBody?
    if @getCustomSchemaSettings().add_coorporates?.value
      dropDownSearchOptions.push
        value: 'CorporateBody'
        text: 'Schmörperschaften'

    # offer PlaceOrGeographicName?
    if @getCustomSchemaSettings().add_geographicplaces?.value
      dropDownSearchOptions.push
        value: 'PlaceOrGeographicName'
        text: 'Orte und Geographische Namen'

    # offer add_subjects?
    if @getCustomSchemaSettings().add_subjects?.value
      dropDownSearchOptions.push
        value: 'SubjectHeading'
        text: 'Schlagwörter'

    # add "Alle"-Option? If count of options > 1!
    if dropDownSearchOptions.length > 1
      dropDownSearchOptions.unshift
        value: ''
        text: 'Alle'

    # if empty options -> offer all
    if dropDownSearchOptions.length == 0
        dropDownSearchOptions = [
            value: 'DifferentiatedPerson'
            text: 'Individualisierte Personen'
          ,
            value: 'CorporateBody'
            text: 'Körperschaften'
          ,
            value: 'PlaceOrGeographicName'
            text: 'Orte und Geographische Namen'
          ,
            value: 'SubjectHeading'
            text: 'Schlagwörter'
        ]

    return [
      {
        type: Select
        undo_and_changed_support: false
        form:
            label: $$('custom.data.type.ubhdgnd.modal.form.text.type')
        options: dropDownSearchOptions
        name: 'gndSelectType'
        class: 'commonPlugin_Select'
      }
      {
        type: Select
        undo_and_changed_support: false
        class: 'commonPlugin_Select'
        form:
            label: $$('custom.data.type.ubhdgnd.modal.form.text.count')
        options: [10, 20, 50, 100].map n -> {value: n, text: "#{n} Vorschläge"}
        name: 'countOfSuggestions'
      }
      {
        type: Input
        undo_and_changed_support: false
        form:
            label: $$("custom.data.type.ubhdgnd.modal.form.text.searchbar")
        placeholder: $$("custom.data.type.ubhdgnd.modal.form.text.searchbar.placeholder")
        name: "searchbarInput"
        # class: 'commonPlugin_Input'
      }
      {
        form:
          label: "Gewählter Eintrag"
        type: Output
        name: "conceptName"
        data: {conceptName: cdata.conceptName}
      }
      {
        form:
          label: "Verknüpfte URI"
        type: FormButton
        name: "conceptURI"
        icon: new Icon(class: "fa-lightbulb-o")
        text: cdata.conceptURI
        onClick: (evt,button) =>
          window.open cdata.conceptURI, "_blank"
        onRender : (_this) =>
          if cdata.conceptURI == ''
            _this.hide()
      }
    ]


  #######################################################################
  # renders the "result" in original form (outside popover)
  __renderButtonByData: (cdata) ->

    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new EmptyLabel(text: $$("custom.data.type.ubhdgnd.edit.no_gnd")).DOM
      when "invalid"
        return new EmptyLabel(text: $$("custom.data.type.ubhdgnd.edit.no_valid_gnd")).DOM

    # if status is ok
    conceptURI = CUI.parseLocation(cdata.conceptURI).url

    # if conceptURI .... ... patch abwarten

    tt_text = $$("custom.data.type.ubhdgnd.url.tooltip", name: cdata.conceptName)

    # output Button with Name of picked Entry and Url to the Source
    new ButtonHref
      appearance: "link"
      href: cdata.conceptURI
      target: "_blank"
      tooltip:
        markdown: true
        text: tt_text
      text: cdata.conceptName
    .DOM



  #######################################################################
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []
    tags.push if custom_settings.add_differentiatedpersons?.value then "✓ Personen"                                           else "✘ Personen"
    tags.push if custom_settings.add_coorporates?.value           then "✓ Körperschaften"                                     else "✘ Körperschaften"
    tags.push if custom_settings.add_geographicplaces?.value      then "✓ Orte"                                               else "✘ Orte"
    tags.push if custom_settings.add_subjects?.value              then "✓ Schlagwörter"                                       else "✘ Schlagwörter"
    tags.push if custom_settings.exact_types?.value               then "✓ Exakter Typ: " + custom_settings.exact_types?.value else "✘ Exakter Typ"
    return tags


CustomDataType.register(CustomDataTypeUBHDGND)

# vim: sw=2 et
