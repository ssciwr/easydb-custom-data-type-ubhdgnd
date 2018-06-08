AuthoritiesClient = require("@ubhd/authorities-client")

class OptionsTreeConfigPlugin extends BaseConfigPlugin
  @buildOptionsField: (optionsOpts, choices, hierarchy) ->
    buildOption = (choice) ->
      option =
        text: $$("custom.data.type.ubhdgnd.config.option.schema.search.gnd_types.#{choice.trim()}")
        value: choice
      ancestors = hierarchy.ancestors choice.trim()
      if ancestors.length > 0
        marginLeft = ancestors.length * 16
        option.attr =
          style: "margin-left: #{marginLeft}px"
      option

    optionsOpts.onInit = (optionsField) ->
      optionsField._options.forEach (option) ->
        descendants = hierarchy.descendants option.value.trim()
        if descendants.length > 0
          callOnDescendants = (functionName) ->
            for descendant in descendants
              for opt, idx in optionsField.__options
                if opt.value.trim() == descendant
                  optionsField.__checkboxes[idx][functionName]()
                  break
          option.onActivate = () -> callOnDescendants('activate')
          option.onDeactivate = () -> callOnDescendants('deactivate')
    optionsOpts.options = choices.map buildOption
    optionsOpts

  getFieldDefFromParm: (baseConfig, pname, def, parent_def) ->
    if def.plugin_type != "options-tree"
      return
    else
      console.log baseConfig
      hierarchy = new AuthoritiesClient.utils.Hierarchy(AuthoritiesClient.data.gndHierarchy)
      opts =
        type: CUI.Options
        undo_and_changed_support: false
        min_checked: 1
        name: pname
        horizontal: false
        form:
          label: $$(baseConfig.locaKey("parameter") + "." + pname + ".label")
    return @constructor.buildOptionsField(opts, def.choices, hierarchy)


CUI.ready ->
  BaseConfig.registerPlugin(new OptionsTreeConfigPlugin())
