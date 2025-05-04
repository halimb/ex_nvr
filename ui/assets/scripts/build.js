import fs from 'fs';
import path from 'path';
import { Command } from 'commander';
import { baseDir, resolveConfig } from './utils.js';
import { build as viteBuild } from 'vite';


async function main() {
  const program = new Command();
  program
    .argument('[mode]', '"default" or "server"', 'default')
    .parse(process.argv);

  const [mode = 'default'] = program.args;
  const config = await resolveConfig();

  await viteBuild(  {
    configFile: false,
    root: baseDir,
    ...config
  })

  if (mode === 'server') {
    fs.writeFileSync(
      path.resolve(baseDir, '../priv/vue/package.json'),
      JSON.stringify({ type: 'module' }, null, 2),
      'utf8'
    );
  }

  console.log('✅ Build complete!');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
