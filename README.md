# format-ts-errors.nvim

Make `ts_ls` (the TypeScript LSP) errors a little nicer looking by formatting
objects.

This plugin favors composability and direct API access over doing it for you.

## screenshots

![screenshot 1][screenshot]
![screenshot 2][screenshot2]

## Installation

**Lazy.nvim** add:

```lua
{
    "davidosomething/format-ts-errors.nvim"
}
```

You can configure the output with a setup function, e.g.:

````lua
{
    "davidosomething/format-ts-errors.nvim",
    config = function()
      require("format-ts-errors").setup({
        add_markdown = true, -- wrap output with markdown ```ts ``` markers
        start_indent_level = 0, -- initial indent
      })
    end,
}
````

Then in the lsp setup:

```lua
local lspconfig = require("lspconfig")
lspconfig.tsserver.setup({
  handlers = {
    ["textDocument/publishDiagnostics"] = function(
      _,
      result,
      ctx,
      config
    )
      if result.diagnostics == nil then
        return
      end

      -- ignore some tsserver diagnostics
      local idx = 1
      while idx <= #result.diagnostics do
        local entry = result.diagnostics[idx]

        local formatter = require('format-ts-errors')[entry.code]
        entry.message = formatter and formatter(entry.message) or entry.message

        -- codes: https://github.com/microsoft/TypeScript/blob/main/src/compiler/diagnosticMessages.json
        if entry.code == 80001 then
          -- { message = "File is a CommonJS module; it may be converted to an ES module.", }
          table.remove(result.diagnostics, idx)
        else
          idx = idx + 1
        end
      end

      vim.lsp.diagnostic.on_publish_diagnostics(
        _,
        result,
        ctx,
        config
      )
    end,
  },
})
```

[screenshot]: https://raw.githubusercontent.com/davidosomething/format-ts-errors.nvim/meta/screenshot.png
[screenshot2]: https://raw.githubusercontent.com/davidosomething/format-ts-errors.nvim/meta/screenshot-2.png
