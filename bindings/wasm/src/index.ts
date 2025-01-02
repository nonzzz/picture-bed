// base64
declare const zigIni: string

let wasm: typeof import('./zig-ini.wasm')

const TextEncode = new TextEncoder()

export function format(input: string): string {
  if (!wasm) {
    loadWASM()
  }
  const memoryView = new Uint8Array(wasm.memory.buffer)
  const { written } = TextEncode.encodeInto(input, memoryView)
  const outputPtr = wasm.format(0, written, memoryView.byteLength)

  // Ensure the buffer is not detached before accessing it
  if (outputPtr === null) {
    throw new Error('Failed to format input')
  }

  const output = new TextDecoder().decode(new Uint8Array(wasm.memory.buffer, 0, outputPtr))
  return output
}

function loadWASM() {
  if (wasm) {
    return
  }
  const bytes = Uint8Array.from(atob(zigIni), (x) => x.charCodeAt(0))
  const compiled = new WebAssembly.Module(bytes)
  wasm = new WebAssembly.Instance(compiled).exports as typeof wasm
}
