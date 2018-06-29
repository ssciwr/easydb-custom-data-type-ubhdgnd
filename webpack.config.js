const webpack = require('webpack')
const {UglifyJsPlugin} = webpack.optimize

const library = (process.env.PLUGIN_NAME_CAMELCASE || 'CustomDataTypeUBHDGND')

module.exports = {
    output: {
        path: __dirname + "/build/webfrontend",
        library,
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
            compress: {warnings: false, keep_fnames: true},
            mangle: {keep_classnames: true, keep_fnames: true}
        })
    ]
};
