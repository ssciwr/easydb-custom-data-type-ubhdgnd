AuthoritiesClient = require('@ubhd/authorities-client')

module.exports = \
class CustomDataTypeGND extends CustomDataTypeWithCommons

  constructor: () ->
    super
    @authoritiesClient = AuthoritiesClient()

  #######################################################################
  # return name of plugin
  getCustomDataTypeName: ->
    "custom:base.custom-data-type-gnd.gnd"


  #######################################################################
  # return name (l10n) of plugin
  getCustomDataTypeNameLocalized: ->
    $$("custom.data.type.gnd.name")


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
    @authoritiesClient
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
                  @authoritiesClient.infoBox(gndId)
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
        option = (
            value: 'DifferentiatedPerson'
            text: 'Individualisierte Personen'
          )
        dropDownSearchOptions.push option
    # offer CorporateBody?
    if @getCustomSchemaSettings().add_coorporates?.value
        option = (
            value: 'CorporateBody'
            text: 'Körperschaften'
          )
        dropDownSearchOptions.push option
    # offer PlaceOrGeographicName?
    if @getCustomSchemaSettings().add_geographicplaces?.value
        option = (
            value: 'PlaceOrGeographicName'
            text: 'Orte und Geographische Namen'
          )
        dropDownSearchOptions.push option
    # offer add_subjects?
    if @getCustomSchemaSettings().add_subjects?.value
        option = (
            value: 'SubjectHeading'
            text: 'Schlagwörter'
          )
        dropDownSearchOptions.push option
    # add "Alle"-Option? If count of options > 1!
    if dropDownSearchOptions.length > 1
        option = (
            value: ''
            text: 'Alle'
          )
        dropDownSearchOptions.unshift option
    # if empty options -> offer all
    if dropDownSearchOptions.length == 0
        dropDownSearchOptions = [
          (
            value: 'DifferentiatedPerson'
            text: 'Individualisierte Personen'
          )
          (
            value: 'CorporateBody'
            text: 'Körperschaften'
          )
          (
            value: 'PlaceOrGeographicName'
            text: 'Orte und Geographische Namen'
          )
          (
            value: 'SubjectHeading'
            text: 'Schlagwörter'
          )
        ]
    [{
      type: Select
      undo_and_changed_support: false
      form:
          label: $$('custom.data.type.gnd.modal.form.text.type')
      options: dropDownSearchOptions
      name: 'gndSelectType'
      class: 'commonPlugin_Select'
    }
    {
      type: Select
      undo_and_changed_support: false
      class: 'commonPlugin_Select'
      form:
          label: $$('custom.data.type.gnd.modal.form.text.count')
      options: [
        (
            value: 10
            text: '10 Vorschläge'
        )
        (
            value: 20
            text: '20 Vorschläge'
        )
        (
            value: 50
            text: '50 Vorschläge'
        )
        (
            value: 100
            text: '100 Vorschläge'
        )
      ]
      name: 'countOfSuggestions'
    }
    {
      type: Input
      undo_and_changed_support: false
      form:
          label: $$("custom.data.type.gnd.modal.form.text.searchbar")
      placeholder: $$("custom.data.type.gnd.modal.form.text.searchbar.placeholder")
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
        return new EmptyLabel(text: $$("custom.data.type.gnd.edit.no_gnd")).DOM
      when "invalid"
        return new EmptyLabel(text: $$("custom.data.type.gnd.edit.no_valid_gnd")).DOM

    # if status is ok
    conceptURI = CUI.parseLocation(cdata.conceptURI).url

    # if conceptURI .... ... patch abwarten

    tt_text = $$("custom.data.type.gnd.url.tooltip", name: cdata.conceptName)

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

    console.log custom_settings

    if custom_settings.add_differentiatedpersons?.value
      tags.push "✓ Personen"
    else
      tags.push "✘ Personen"

    if custom_settings.add_coorporates?.value
      tags.push "✓ Körperschaften"
    else
      tags.push "✘ Körperschaften"

    if custom_settings.add_geographicplaces?.value
      tags.push "✓ Orte"
    else
      tags.push "✘ Orte"

    if custom_settings.add_subjects?.value
      tags.push "✓ Schlagwörter"
    else
      tags.push "✘ Schlagwörter"

    if custom_settings.exact_types?.value
      tags.push "✓ Exakter Typ: " + custom_settings.exact_types?.value
    else
      tags.push "✘ Exakter Typ"

    tags


CustomDataType.register(CustomDataTypeGND)

# vim: sw=2 et
