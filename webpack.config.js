const webpack = require('webpack')
const {UglifyJsPlugin} = webpack.optimize

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
    },
    plugins: [
      new UglifyJsPlugin({
        mangle: false,
      })
    ]
};
