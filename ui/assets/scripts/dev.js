import { Command } from 'commander';
import { createServer } from 'vite';
import { resolveConfig, baseDir } from './utils.js';

async function main() {
  const program = new Command();
  program
    .option('-c, --config [dir]', 'extra config folder (will look in `<dir>/assets`)', '')
    .parse(process.argv);

  const config = await resolveConfig('dev');
  const server = await createServer({
    ...config,
    configFile: false,
    root: baseDir,
    logLevel: 'warn',
    server: {
      host: true
    }
  });

  await server.listen();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
