const esbuild = require('esbuild')
const fs = require('fs')
const path = require('path')

const wasm = fs.readFileSync(path.join(__dirname, '..', '..', 'zig-out/bindings/wasm/zig-ini.wasm')).toString('base64')
esbuild.buildSync({
  define: {
    zigIni: JSON.stringify(wasm)
  },
  outdir: path.join(__dirname, 'dist'),
  entryPoints: [path.join(__dirname, 'src', 'index.ts')]
})
