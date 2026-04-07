-- NvChad UI overrides: ayu_dark with 10-group syntax highlighting.
--
-- All colors from ayu_dark's palette, optimized for:
--   - CVD safety (mild red-green color blindness)
--   - Visual hierarchy (fg dimmer than accents, constants below fg)
--   - No italic
--
--  1. Keywords       #FF7733 orange     6. Self/builtins  #39BAE6 cyan
--  2. Functions      #E6C54C gold       7. Properties     #80DDB8 mint
--  3. Strings        #AAD94C green      8. Parameters     #D2A6FF purple
--  4. Types+Modules  #59C2FF blue       9. Decorators     #E6C08A beige
--  5. Constants      #C4B070 muted gold 10. Operators      #CC7832 dark orange

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "ayu_dark",

  changed_themes = {
    ayu_dark = {
      base_16 = {
        base05 = "#B8B5AC", -- fg (dimmed so accents pop above ground)
        base06 = "#E6E1CF",
        base07 = "#D9D7CE",
        base08 = "#B8B5AC", -- identifier bucket (same as fg, override individually)
        base09 = "#C4B070", -- constants/numbers (muted gold, below fg brightness)
        base0A = "#59C2FF", -- types/tags (entity blue)
        base0B = "#AAD94C", -- strings (ayu native green)
        base0C = "#80DDB8", -- regex/escape (mint)
        base0D = "#E6C54C", -- functions (gold, 22deg  from keyword orange)
        base0E = "#FF7733", -- keywords (orange, the anchor)
        base0F = "#887799", -- punctuation/brackets (quiet scaffolding)
      },
      base_30 = {
        red = "#F07178",
        baby_pink = "#ff949b",
        pink = "#ff8087",
        green = "#AAD94C",
        vibrant_green = "#b9e75b",
        blue = "#59C2FF",
        nord_blue = "#73D0FF",
        yellow = "#C4B070",
        sun = "#E6C54C",
        purple = "#D2A6FF",
        dark_purple = "#A37ACC",
        teal = "#80DDB8",
        orange = "#FF7733",
        cyan = "#39BAE6",
        pmenu_bg = "#FF7733",
      },
      polish_hl = {
        treesitter = {
          ["@function"] = { fg = "#E6C54C" },
          ["@variable.parameter"] = { fg = "#D2A6FF" },
          ["@constructor"] = { fg = "#59C2FF" },
          ["@tag.attribute"] = { fg = "#80DDB8" },
          ["@tag.delimiter"] = { fg = "#887799" },
        },
      },
    },
  },

  hl_override = {
    -- 1. Keywords (orange #FF7733 -- the anchor color)
    ["@keyword"] = { fg = "#FF7733" },
    ["@keyword.function"] = { fg = "#FF7733" },
    ["@keyword.return"] = { fg = "#FF7733" },
    ["@keyword.operator"] = { fg = "#FF7733" },
    ["@keyword.conditional"] = { fg = "#FF7733" },
    ["@keyword.conditional.ternary"] = { fg = "#FF7733" },
    ["@keyword.repeat"] = { fg = "#FF7733" },
    ["@keyword.exception"] = { fg = "#FF7733" },
    ["@keyword.storage"] = { fg = "#FF7733" },
    ["@keyword.directive"] = { fg = "#E6C08A" },
    ["@keyword.directive.define"] = { fg = "#E6C08A" },

    -- 2. Functions (gold #E6C54C -- warm but 22deg  from keyword orange)
    ["@function"] = { fg = "#E6C54C" },
    ["@function.builtin"] = { fg = "#E6C54C" },
    ["@function.call"] = { fg = "#E6C54C" },
    ["@function.method"] = { fg = "#E6C54C" },
    ["@function.method.call"] = { fg = "#E6C54C" },
    ["@function.macro"] = { fg = "#E6C08A" },

    -- 3. Strings (ayu native green #AAD94C)
    ["@string"] = { fg = "#AAD94C" },
    ["@string.regex"] = { fg = "#80DDB8" },
    ["@string.escape"] = { fg = "#80DDB8" },

    -- 4. Types + Modules (entity blue #59C2FF)
    ["@type.builtin"] = { fg = "#59C2FF" },
    ["@module"] = { fg = "#59C2FF" },
    ["@attribute"] = { fg = "#E6C08A" },

    -- 5. Constants/Numbers (muted gold #C4B070 -- below fg brightness)
    ["@constant"] = { fg = "#C4B070" },
    ["@constant.builtin"] = { fg = "#C4B070" },
    ["@constant.macro"] = { fg = "#C4B070" },
    ["@number"] = { fg = "#C4B070" },
    ["@number.float"] = { fg = "#C4B070" },

    -- 6. Self/Builtins (cyan #39BAE6)
    ["@variable.builtin"] = { fg = "#39BAE6" },

    -- 7. Properties/Fields (mint #80DDB8)
    ["@variable.member"] = { fg = "#80DDB8" },
    ["@variable.member.key"] = { fg = "#80DDB8" },
    ["@property"] = { fg = "#80DDB8" },
    ["@tag.attribute"] = { fg = "#80DDB8" },

    -- 8. Parameters (purple #D2A6FF)
    ["@variable.parameter"] = { fg = "#D2A6FF" },

    -- 10. Operators (dark orange #CC7832 -- quiet scaffolding)
    ["@operator"] = { fg = "#CC7832" },
    ["@punctuation.bracket"] = { fg = "#887799" },
    ["@punctuation.delimiter"] = { fg = "#887799" },
    ["@punctuation.special"] = { fg = "#887799" },

    -- Variables (fg, no special color)
    ["@variable"] = { fg = "#B8B5AC" },

    -- Tags (blue, type-adjacent)
    ["@tag"] = { fg = "#59C2FF" },
    ["@tag.delimiter"] = { fg = "#887799" },

    -- Constructors (blue, type-adjacent)
    ["@constructor"] = { fg = "#59C2FF" },

    -- Characters (constants cluster)
    ["@character"] = { fg = "#C4B070" },

    -- Annotations (beige, decorators cluster)
    ["@annotation"] = { fg = "#E6C08A" },

    -- Vim syntax groups (LSP semantic token fallbacks)
    Function = { fg = "#E6C54C" },
    String = { fg = "#AAD94C" },
    Keyword = { fg = "#FF7733" },
    Type = { fg = "#59C2FF" },
    Constant = { fg = "#C4B070" },
    Number = { fg = "#C4B070" },
    Boolean = { fg = "#C4B070" },
    Operator = { fg = "#CC7832" },
    Identifier = { fg = "#B8B5AC" },
    PreProc = { fg = "#E6C08A" },
    Include = { fg = "#59C2FF" },
    Define = { fg = "#E6C08A" },
    Macro = { fg = "#E6C08A" },
    Special = { fg = "#80DDB8" },
    Delimiter = { fg = "#887799" },
    Statement = { fg = "#FF7733" },
    Conditional = { fg = "#FF7733" },
    Repeat = { fg = "#FF7733" },
    Structure = { fg = "#59C2FF" },
    StorageClass = { fg = "#FF7733" },
    Exception = { fg = "#FF7733" },
    Label = { fg = "#59C2FF" },
    Tag = { fg = "#59C2FF" },
    SpecialChar = { fg = "#80DDB8" },
  },

  hl_add = {
    -- LSP semantic tokens
    ["@lsp.type.function"] = { fg = "#E6C54C" },
    ["@lsp.type.method"] = { fg = "#E6C54C" },
    ["@lsp.type.macro"] = { fg = "#E6C08A" },
    ["@lsp.type.type"] = { fg = "#59C2FF" },
    ["@lsp.type.class"] = { fg = "#59C2FF" },
    ["@lsp.type.struct"] = { fg = "#59C2FF" },
    ["@lsp.type.interface"] = { fg = "#59C2FF" },
    ["@lsp.type.enum"] = { fg = "#59C2FF" },
    ["@lsp.type.enumMember"] = { fg = "#C4B070" },
    ["@lsp.type.typeParameter"] = { fg = "#59C2FF" },
    ["@lsp.type.namespace"] = { fg = "#59C2FF" },
    ["@lsp.type.parameter"] = { fg = "#D2A6FF" },
    ["@lsp.type.property"] = { fg = "#80DDB8" },
    -- Empty: don't let LSP flatten all variables to fg.
    -- Treesitter's @variable.parameter, @variable.member, @variable.builtin
    -- are more specific and should show through. LSP's @lsp.type.parameter,
    -- @lsp.type.property etc. still win at priority 125 for their specific types.
    ["@lsp.type.variable"] = {},
    ["@lsp.type.comment"] = {},
    ["@lsp.type.keyword"] = { fg = "#FF7733" },
    ["@lsp.type.operator"] = { fg = "#CC7832" },
    ["@lsp.type.number"] = { fg = "#C4B070" },
    ["@lsp.type.string"] = { fg = "#AAD94C" },
    ["@lsp.type.decorator"] = { fg = "#E6C08A" },
    ["@lsp.type.lifetime"] = { fg = "#D2A6FF" },
    ["@lsp.type.selfKeyword"] = { fg = "#39BAE6" },
    ["@lsp.type.selfTypeKeyword"] = { fg = "#39BAE6" },
    ["@lsp.type.builtinType"] = { fg = "#59C2FF" },
    ["@lsp.type.formatSpecifier"] = { fg = "#80DDB8" },

    ["@lsp.mod.deprecated"] = { strikethrough = true },
    ["@lsp.mod.deactivated"] = { fg = "#3d4046" },

    -- Treesitter groups missing from base46 integrations
    ["@boolean"] = { fg = "#C4B070" },
    ["@module.builtin"] = { fg = "#59C2FF" },
    ["@string.special"] = { fg = "#80DDB8" },
    ["@string.special.symbol"] = { fg = "#80DDB8" },
    ["@string.special.url"] = { fg = "#59C2FF", underline = true },
    ["@string.documentation"] = { fg = "#5C6773" },
    ["@attribute.builtin"] = { fg = "#E6C08A" },
    ["@keyword.import"] = { fg = "#59C2FF" },
    ["@keyword.coroutine"] = { fg = "#FF7733" },
    ["@keyword.type"] = { fg = "#FF7733" },
    ["@keyword.modifier"] = { fg = "#FF7733" },
    ["@label"] = { fg = "#59C2FF" },
    ["@type"] = { fg = "#59C2FF" },
    ["@type.definition"] = { fg = "#59C2FF" },
    ["@string.regexp"] = { fg = "#80DDB8" },
    ["@diff.plus"] = { fg = "#AAD94C" },
    ["@diff.minus"] = { fg = "#F07178" },
    ["@diff.delta"] = { fg = "#59C2FF" },
  },
}

return M
