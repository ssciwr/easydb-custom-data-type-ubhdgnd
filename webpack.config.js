var webpack = require('webpack')

module.exports = {
    entry: "./entry.js",
    // devtool: 'source-map',
    output: {
        path: __dirname + "/build/webfrontend",
        filename: "custom-data-type-gnd-ubhd.js",
        library: 'CustomDataTypeGNDUBHD',
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
