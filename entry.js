const mods = {
    CustomDataTypeGNDUBHD: require('./src/webfrontend/CustomDataTypeGNDUBHD'),
    UbhdAuthoritiesClient: require('@ubhd/authorities-client'),
}

Object.assign(window, mods)
