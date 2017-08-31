var webpack = require('webpack')

module.exports = {
    entry: "./entry.js",
    // devtool: 'source-map',
    output: {
        path: __dirname + "/build/webfrontend",
        filename: "custom-data-type-gnd.js",
        library: 'CustomDataTypeGND',
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
