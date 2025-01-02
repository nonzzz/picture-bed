const { format } = require('./dist')

const r = format(
  `first_line_vars = abce...f ; hello world~
# comment variant
name = 'single quote string literal' ; inline comment (It's not standard)
description = "double quote string literal"# inline comment (It's not standard)
`,
  { quoteStyle: 'single', commentStyle: 'semi' }
)

console.log(r)
