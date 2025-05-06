import {Command} from 'commander';
import {createServer} from 'vite';
import {resolveConfig, baseDir} from './utils.js';
import path from 'path';
import fs from 'fs';

async function main() {
    const program = new Command();
    program
        .option('-c, --config [dir]', 'extra config folder (will look in `<dir>/assets`)', '')
        .parse(process.argv);

    const config = await resolveConfig('dev');
    symLinkPluginAssets()

    transformBuildOptions(config)
    console.log(config.build.rollupOptions)
    const server = await createServer({
        ...config,
        configFile: false,
        root: baseDir,
        logLevel: 'warn',
        server: {
            host: true,
            fs: {
                allow: [
                    baseDir,
                    path.resolve(process.env.PLUGIN_PATHS)
                ],
                strict: false
            }
        }
    });

    await server.listen();
    watchPluginAssets(server)
    // await new Promise(() => setTimeout(() => {}, 1000000));
}

function transformBuildOptions(config) {
    const pluginDir = process.env.PLUGIN_PATHS
    const pluginAssetsDir = path.resolve(pluginDir, 'assets');
    const destDir = path.resolve(baseDir, 'plugins');

    const input = Object.entries(config.build.rollupOptions.input).map(([key, originalPath]) => {
        const newPath = originalPath.replace(pluginAssetsDir, destDir)
        return [key, newPath]
    })

    config.build.rollupOptions.input = Object.fromEntries(input)
}

function symLinkPluginAssets() {
    const pluginDir = process.env.PLUGIN_PATHS
    const pluginAssetsDir = path.resolve(pluginDir, 'assets');
    const destDir = path.resolve(baseDir, 'plugins');

    console.log({
        pluginDir,
        pluginAssetsDir,
        destDir,
    })
    if (!pluginAssetsDir || fs.existsSync(destDir)) {
        return
    }


    fs.symlinkSync(pluginAssetsDir, destDir, 'dir')
}

function watchPluginAssets(viteServer) {
    const pluginDir = process.env.PLUGIN_PATHS
    const pluginAssetsDir = path.resolve(pluginDir, 'assets');

    if (!pluginAssetsDir || typeof pluginAssetsDir !== 'string') {
        return
    }

    viteServer.watcher.add(pluginAssetsDir);
    console.log("Watching for changes in", pluginAssetsDir);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
