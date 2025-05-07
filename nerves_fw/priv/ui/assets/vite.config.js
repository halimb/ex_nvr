const fs = require("fs")
const path = require("path")
const {nodeResolve} = require('@rollup/plugin-node-resolve');

console.log("RESOLVED: ", path.resolve(__dirname, "./hooks.js"))
module.exports = {
    build: {
        rollupOptions: {
            input: {
                "code-editor": path.resolve(__dirname, "./js/code-editor.js"),
            },
              plugins: [
                nodeResolve({
                  browser: true,
                  extensions: ['.js', '.mjs']
                })
              ]
        },
    },
}
