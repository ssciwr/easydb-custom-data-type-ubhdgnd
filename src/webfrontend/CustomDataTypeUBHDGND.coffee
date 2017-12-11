AuthoritiesClient = require('@ubhd/authorities-client')

module.exports =\
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
  # @param {string} name setting name
  # @param {*} fallback Fallback value if no value or value is falsey
  # @return {string} the value of a field config setting or null if not defined
  getCustomSchemaSetting: (name, fallback) -> @getCustomSchemaSettings()[name]?.value or fallback

  #######################################################################
  # make sure enabled overridable options are actually enabled
  showEditPopover: (args...) ->
    super(args...)
    # XXX This will check all the checkboxes for types that can be overridden
    # (i.e. show in the edit popover) and are also enabled by default
    valuesToEnable = @getCustomSchemaSetting("gnd_types_enabled_default", [])
    if valuesToEnable.length
      @popover.getPane()._content.getFieldsByName("enabledGndTypes")[0].setValue(valuesToEnable)


  #######################################################################
  # Instantiate authoritiesClient with the configured authorities_backend
  __getAuthoritiesClient: () ->
    if @__authoritiesClient
      return @__authoritiesClient
    else
      pluginName = @getCustomSchemaSetting('authorities_backend')
      @__authoritiesClient = AuthoritiesClient.plugin(pluginName)

  #######################################################################
  # handle suggestions-menu
  __updateSuggestionsMenu: (cdata, cdata_form, suggest_Menu) ->

    console.log({cdata_form, type, gnd_searchterm})

    # TODO debounce
    {preferredName, variantName, arrayify} = AuthoritiesClient.utils.handlebars.helpers
    format = 'opensearch'

    type = cdata_form.getFieldsByName("enabledGndTypes")[0].getValue()
    gnd_searchterm = cdata_form.getFieldsByName("searchbarInput")[0].getValue()
    withSubTypes = false # TODO configurable

    @__getAuthoritiesClient().suggest(gnd_searchterm, {type, format, withSubTypes})
      .then (data) =>
        # create new menu with suggestions
        menu_items = []
        for i of data[1]
          # the actual Featureclass...
          suggestion = data[1][i]
          aktType    = data[2][i]
          gndId      = data[3][i]
          lastType   = data[2][i-1]

          # style menu
          if aktType != lastType
            if i == 0
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
                return unless @getCustomMaskSettings().show_infopopup?.value
                # download infos
                @__getAuthoritiesClient().infoBox(gndId)
                  .then (html) ->
                    tooltip.DOM.innerHTML = html
                    tooltip.DOM.style.maxWidth = '100%'
                  .catch (err) -> console.warn(new Error(err))
                return new CUI.Label(icon: "spinner", text: "lade Informationen")

        # set new items to menu
        itemList =
          items: menu_items
          onClick: (ev2, btn) =>
            @__getAuthoritiesClient().get(btn.getOpt("value"))
              .then (jsonld) ->
                # lock in save data
                cdata.conceptURI = "http://d-nb.info/gnd/#{jsonld['@id'].substr(4)}"
                cdata.conceptName = preferredName(jsonld)
                cdata.conceptSeeAlso = arrayify(variantName(jsonld)).join(', ')
                # lock in form
                cdata_form.getFieldsByName("conceptName")[0].storeValue(cdata.conceptName).displayValue()
                # nach eadb5-Update durch "setText" ersetzen und "__checkbox" rausnehmen
                cdata_form.getFieldsByName("conceptURI")[0].__checkbox.setText(cdata.conceptURI)
                cdata_form.getFieldsByName("conceptURI")[0].show()
                cdata_form.getFieldsByName("conceptSeeAlso")[0].__checkbox.setText(cdata.conceptSeeAlso)
                cdata_form.getFieldsByName("conceptSeeAlso")[0].show()

                # clear searchbar
                cdata_form.getFieldsByName("searchbarInput")[0].setValue('')
                # hide suggest-menu
              .catch (err) -> console.error(err)
              suggest_Menu.hide()
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


  #######################################################################
  # create form
  __getEditorFields: (cdata) ->
    fields = [
      {
        type: CUI.Options
        undo_and_changed_support: false
        # class: 'commonPlugin_Select'
        form:
          label: $$('custom.data.type.ubhdgnd.modal.form.text.type')
        name: 'enabledGndTypes'
        options: @getCustomSchemaSetting('gnd_types_overridable', []).map (gndClass) ->
          value: gndClass
          text: $$("custom.data.type.ubhdgnd.config.option.schema.gnd_types_overridable.value.#{gndClass}")
      }
    ]
    # if the subtype search has been marked as overrideable
    if @getCustomSchemaSetting('override_subtype_search', false)
      fields.push
        type: CUI.Checkbox
        undo_and_changed_support: false
        class: 'commonPlugin_Select'
        form:
            label: $$('custom.data.type.ubhdgnd.modal.form.enable_subtype_search.label')
        value: @getCustomSchemaSetting('enable_subtype_search_default', false)
        name: 'includeSubTypes'
    fields.push(
      {
        type: CUI.Select
        undo_and_changed_support: false
        class: 'commonPlugin_Select'
        form:
            label: $$('custom.data.type.ubhdgnd.modal.form.text.count')
        options: [10, 20, 50, 100].map (n) -> value: n, text: "#{n} Vorschläge"
        name: 'countOfSuggestions'
      }
      {
        type: CUI.Input
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
        type: CUI.Output
        name: "conceptName"
        data: {conceptName: cdata.conceptName, conceptSeeAlso: cdata.conceptSeeAlso}
      }
      {
        form:
          label: "Verweisformen"
        type: CUI.FormButton
        name: "conceptSeeAlso"
        icon: new CUI.Icon(class: "fa-info")
        text: cdata.conceptSeeAlso
        # onClick: (evt,button) =>
        #   window.open cdata.conceptURI, "_blank"
        onRender : (_this) =>
          if cdata.conceptSeeAlso == ''
            _this.hide()
      }
      {
        form:
          label: "Verknüpfte URI"
        type: CUI.FormButton
        name: "conceptURI"
        icon: new CUI.Icon(class: "fa-lightbulb-o")
        text: cdata.conceptURI
        onClick: (evt,button) =>
          window.open cdata.conceptURI, "_blank"
        onRender : (_this) =>
          if cdata.conceptURI == ''
            _this.hide()
      }
    )
    return fields


  #######################################################################
  # renders the "result" in original form (outside popover)
  __renderButtonByData: (cdata) ->

    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new CUI.EmptyLabel(text: $$("custom.data.type.ubhdgnd.edit.no_gnd")).DOM
      when "invalid"
        return new CUI.EmptyLabel(text: $$("custom.data.type.ubhdgnd.edit.no_valid_gnd")).DOM

    # if status is ok
    conceptURI = CUI.parseLocation(cdata.conceptURI).url

    # if conceptURI .... ... patch abwarten

    tt_text = $$("custom.data.type.ubhdgnd.url.tooltip", name: cdata.conceptName)

    # output Button with Name of picked Entry and Url to the Source
    return new CUI.ButtonHref
      appearance: "link"
      href: cdata.conceptURI
      target: "_blank"
      tooltip:
        markdown: true
        # placement: "n"
        content: (tooltip) =>
          if @getCustomMaskSettings().show_infopopup?.value
            return $$("custom.data.type.ubhdgnd.url.tooltip", name: cdata.conceptName)
          # download infos
          console.log(tooltip)
          @__getAuthoritiesClient().infoBox(cdata.conceptURI)
            .then (html) ->
              tooltip.DOM.innerHTML = html
              tooltip.DOM.style.maxWidth = '40%'
              tooltip.DOM.style.height = '500px'
            .catch (err) -> console.warn(new Error(err))
          return new CUI.Label(icon: "spinner", text: "lade Informationen")
      text: cdata.conceptName
    .DOM



  #######################################################################
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []
    (custom_settings.gnd_types_enabled_default?.value or []).forEach (gndClass) =>
      tags.push "✓ #{$$("custom.data.type.ubhdgnd.config.option.schema.gnd_types_enabled_default.value.#{gndClass}")}"
    (custom_settings.gnd_types_overridable?.value or []).forEach (gndClass) =>
      tags.push "✓ #{$$("custom.data.type.ubhdgnd.config.option.schema.gnd_types_overridable.value.#{gndClass}")}"
    withSubTypes = !! custom_settings.enable_subtype_search_default?.value
    tags.push "#{if withSubTypes then "✓ " else "✗ "} #{$$("custom.data.type.ubhdgnd.modal.form.enable_subtype_search.label")}"
    return tags


CustomDataType.register(CustomDataTypeUBHDGND)

# vim: sw=2 et
