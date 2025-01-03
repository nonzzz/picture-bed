/* eslint-disable @typescript-eslint/no-require-imports */
import fs from 'fs'
import path from 'path'

const { arch, platform } = process

export type QuoteStyle = 'none' | 'single' | 'dobule'

export type CommentStyle = 'hash' | 'semi'
export interface FormatOptions {
  quoteStyle: QuoteStyle
  commentStyle: CommentStyle
}

export interface NativeBindings {
  format: (input: string, options: CommentStyle) => string
}

let nativeBindings: NativeBindings | null = null

switch (platform) {
  case 'win32':
    break
  case 'darwin': {
    if (fs.existsSync(path.join(__dirname, 'zig-ini.darwin.node'))) {
      nativeBindings = require('./zig-ini.darwin.node') as NativeBindings
      break
    }
    break
  }
  case 'linux':
    break
  default:
    throw new Error(`Unsupported OS: ${platform}, arch: ${arch}`)
}

if (!nativeBindings) {
  throw new Error('Failed to load native bindingss')
}

const { format } = nativeBindings

export { format }
