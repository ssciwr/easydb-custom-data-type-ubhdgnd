var webpack = require('webpack')

module.exports = {
    output: {
        path: __dirname + "/build/webfrontend",
        library: 'CustomDataTypeUBHDGND',
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
