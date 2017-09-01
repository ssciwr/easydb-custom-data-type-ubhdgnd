var webpack = require('webpack')

module.exports = {
    entry: "./build/webfrontend/custom-data-type-gnd.raw.js",
    // devtool: 'source-map',
    output: {
        path: __dirname + "/build/webfrontend",
        filename: "custom-data-type-gnd.js",
        library: 'CustomDataTypeGND',
        // libraryTarget: "window",
    },
    module: {
        rules: [
            {
                test: /\.coffee$/,
                use: 'coffee-loader',
            }
        ]
    }
};
