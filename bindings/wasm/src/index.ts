// base64
declare const zigIni: string

let wasm: typeof import('./zig-ini.wasm')

const TextEncode = new TextEncoder()

export type QuoteStyle = 'none' | 'single' | 'dobule'

export type CommentStyle = 'hash' | 'semi'
export interface FormatOptions {
  quoteStyle: QuoteStyle
  commentStyle: CommentStyle
}

const defaultOptions = {
  quoteStyle: 'dobule',
  commentStyle: 'hash'
} satisfies FormatOptions

function toSnakeCase(str: string): string {
  return str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)
}

export function format(input: string, options?: FormatOptions): string {
  if (!wasm) {
    loadWASM()
  }
  options = { ...defaultOptions, ...options }

  const parsedOptions = Object.entries(options).reduce((acc, [key, value]) => {
    return { ...acc, [toSnakeCase(key)]: value }
  }, {})

  const memoryView = new Uint8Array(wasm.memory.buffer)
  const { written } = TextEncode.encodeInto(input, memoryView)

  const { written: optionsWritten } = TextEncode.encodeInto(JSON.stringify(parsedOptions), memoryView.subarray(written + 8))

  const outputPtr = wasm.format(0, written, written + 8, optionsWritten)

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
