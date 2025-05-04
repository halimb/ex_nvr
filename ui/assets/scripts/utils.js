import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { defu } from 'defu';
import tailwindcss from "tailwindcss";
import autoprefixer from "autoprefixer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const baseDir = path.resolve(__dirname, '..');

export async function loadConfigFile(filePath, context = {}) {
  if (!fs.existsSync(filePath)) return {};
  const mod = await import(`file://${filePath}`);
  const resolved = mod.default || mod;

  return typeof resolved === 'function' ? resolved(context) : resolved;
}

export async function resolveConfig(command='build') {
  const overrideDir = process.env.PLUGIN_PATHS
  const baseVite = await loadConfigFile(
    path.join(baseDir, 'vite.config.js'),
    { command }
  );
  const baseTwind = await loadConfigFile(
    path.join(baseDir, 'tailwind.config.cjs'),
    { command }
  );

  let overrideVite = {}, overrideTwind = {};
  if (overrideDir && typeof overrideDir === 'string') {
    const assetsDir = path.join(overrideDir, 'assets');
    const maybe = name => path.join(assetsDir, name);

    overrideVite = await loadConfigFile(maybe('vite.config.js'), { command });
    overrideTwind = await loadConfigFile(maybe('tailwind.config.js'), { command });
  }

  const viteConfig = defu(overrideVite, baseVite);
  const tailwindConfig = defu(overrideTwind, baseTwind);

  viteConfig.css ??= {};
  viteConfig.css.postcss ??= {};
  viteConfig.css.postcss.plugins = [
    tailwindcss(tailwindConfig),
    autoprefixer()
  ];

  return viteConfig;
}
