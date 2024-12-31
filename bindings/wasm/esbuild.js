const esbuild = require('esbuild')
const fs = require('fs')

const wasm = fs.readFileSync('./zig-ini.wasm').toString('base64')
esbuild.buildSync({
  define: {
    zigIni: JSON.stringify(wasm)
  },
  outdir: 'dist',
  entryPoints: ['src/index.ts']
})
