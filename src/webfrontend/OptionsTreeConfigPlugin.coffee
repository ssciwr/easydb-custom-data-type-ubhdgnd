AuthoritiesClient = require("@ubhd/authorities-client")

class OptionsTreeConfigPlugin extends BaseConfigPlugin
  @buildOptionsField: (optionsOpts, choices, hierarchy, localisationPrefix) ->
    addedAncestors = {}
    trimmedChoices = choices.map (choice) -> choice.trim()
    optionsOpts.options = []
    for choice in choices
      trimmedChoice = choice.trim()
      parentOption = null
      option =
        text: $$("#{localisationPrefix}.#{trimmedChoice}")
        value: choice
      ancestors = hierarchy.ancestors trimmedChoice
      if ancestors.length > 0
        parent = ancestors[0]
        if parent not in trimmedChoices and parent not of addedAncestors
          # the ancestor of this option is not in the choice and
          # has not yet been considered. add a disabled option to keep the
          # grouping
          parentMargin = (ancestors.length - 1) * 16
          addedAncestors[parent] = true
          optionsOpts.options.push {
            text: $$("#{localisationPrefix}.#{parent}")
            value: parent
            disabled: true
            attr:
              style: "margin-left: #{parentMargin}px"
          }
        marginLeft = ancestors.length * 16
        option.attr =
          style: "margin-left: #{marginLeft}px"
      optionsOpts.options.push option

    # Function to register all checkbox activation/deactivation handlers
    # based on the hierarchy
    # during init of the Options field
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
    optionsOpts

  getFieldDefFromParm: (baseConfig, pname, def, parent_def) ->
    if def.plugin_type != "options-tree"
      return
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
    return @constructor.buildOptionsField(opts, def.choices, hierarchy,
      baseConfig.locaKey("option") + "." + pname)


CUI.ready ->
  BaseConfig.registerPlugin(new OptionsTreeConfigPlugin())
