import process from 'node:process'
import * as esbuild from 'esbuild'

const isDev = process.argv.includes('--dev')

await esbuild.build({
  entryPoints: ['renderer.src.js'],
  bundle: true,
  outfile: 'renderer.js',
  platform: 'browser',
  minify: !isDev,
  sourcemap: isDev ? 'inline' : false,
  logLevel: 'info'
})
