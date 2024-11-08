---@class Settings
---@field add_markdown boolean add markdown ticks before and after formatted objects
---@field start_indent_level integer how many indents in front of formatted object

---@type Settings
local DEFAULTS = {
  add_markdown = false,
  start_indent_level = 1,
}

local M = {
  ---@type Settings
  _settings = DEFAULTS,
}

M.setup = function(opts)
  M._settings = vim.tbl_extend("force", DEFAULTS, opts or {})
end

---@param o string e.g. {someinlinebrackets;likethis;}
---@return string,string[] # return indented pretty type def, e.g.:
--- {
---   someinlinebrackets;
---   likethis;
--- }
M.format_object_type = function(o)
  o = vim.fn.substitute(o, "; ", ";", "g")
  o = vim.fn.substitute(o, ";", ";\n", "g")
  o = vim.fn.substitute(o, "{ ", "{\n", "g")

  -- indent
  o = vim.fn.split(o, "\n")
  local lines = {}
  local level = M._settings.start_indent_level
  for _, line in ipairs(o) do
    -- just a closing, unindent this iteration
    if not line:find("{") and line:find("}") then
      level = level - 1
    end

    local spaces = ("  "):rep(level)
    table.insert(lines, spaces .. line)

    -- just an opening, indent next iteration
    if line:find("{") and not line:find("}") then
      level = level + 1
    end
  end

  local formatted = table.concat(lines, "\n")

  -- Single item -------------------------------------------------------------
  if #lines == 1 then
    -- Surround in backticks, even when no markdown requested
    if M._settings.add_markdown then
      return ("`%s`\n"):format(formatted), lines
    end
    -- Surround in single quote like original
    return ("'%s'\n"):format(formatted), lines
  end

  -- Multiline ---------------------------------------------------------------
  -- add markdown fencing?
  if M._settings.add_markdown then
    -- ensure fenced code is also surrounded by newlines
    return ("\n```typescript\n%s\n```\n"):format(formatted), lines
  end
  --- don't add markdown fencing
  return formatted, lines
end

M.line_parsers = {

  -- Property 'public_token' is missing in type '{}' but required in type 'ItemPublicTokenExchangeRequest'.
  threepat = function(line)
    ---@diagnostic disable-next-line: unused-local
    local found, _ei, p1, prop, p2, ours, p3, theirs =
      line:find("(%S.-) '(.-)' (.- type) '(.-)' (.- type) '(.-)'.")
    if found then
      return (
        ("%s\n%s"):format(p1, M.format_object_type(prop))
        .. ("%s\n%s"):format(p2, M.format_object_type(ours))
        .. ("%s\n%s"):format(p3, M.format_object_type(theirs))
      )
    end
    return ""
  end,

  -- 1. Argument of type '{}' is not assignable to parameter of type 'ItemPublicTokenExchangeRequest'.
  -- 2. Type 'string' is not assignable to type 'undefined'
  twopat = function(line)
    ---@diagnostic disable-next-line: unused-local
    local found, _ei, p1, ours, p2, theirs =
      line:find("(%S.-) '(.-)' (.- type) '(.-)'.")
    if found then
      return (
        ("%s\n%s"):format(p1, M.format_object_type(ours))
        .. ("%s\n%s"):format(p2, M.format_object_type(theirs))
      )
    end
    return ""
  end,

  -- Type '{}' is missing the following properties from type 'LinkTokenCreateRequest': client_name, language, country_codes, user
  missing_named_properties = function(line)
    ---@diagnostic disable-next-line: unused-local
    local found, _ei, p1, ours, p2, theirs =
      line:find("(%S.-) '(.-)' (.- type) '(.-)'")
    if found then
      ---@diagnostic disable-next-line: unused-local
      local _sj, _ej, named_csv = line:find(": ([^:]*)$")
      local missing_keys = ""
      for _, key in ipairs(vim.fn.split(named_csv, ", ")) do
        missing_keys = missing_keys .. (" • %s\n"):format(key)
      end

      return (
        ("%s\n%s"):format(p1, M.format_object_type(ours))
        .. ("%s\n%s"):format(p2, M.format_object_type(theirs))
        .. missing_keys
      )
    end
    return ""
  end,
}

M.format_lines = function(msg, matchers)
  local result = ""
  local lines = vim.fn.split(msg, "\n")
  for _, line in ipairs(lines) do
    local matcher_result = ""
    for _, matcher in ipairs(matchers) do
      if matcher_result:len() == 0 then
        matcher_result = M.line_parsers[matcher](line)
        if matcher_result:len() > 0 then
          result = result .. matcher_result
        end
      end
    end
    -- no match, return default
    if matcher_result:len() == 0 then
      result = result .. line .. "\n"
    end
  end
  return result
end

M[2322] = function(msg)
  -- "Type 'string' is not assignable to type 'undefined'"
  -- Type '<T extends Record<string, string>>(table: string, calcEngine: string | undefined, tab: string | undefined, predicate: ((row: T) => boolean) | undefined) => Record<string, string>[]' is not assignable to type '<T extends Record<string, string>>(table: string, calcEngine?: string | undefined, tab?: string | undefined, predicate?: ((row: T) => boolean) | undefined) => T[]'.
  return M.format_lines(msg, { "twopat" })
end

M[2353] = function(msg)
  -- Object literal may only specify known properties, and 'third' does not exist in type '{ second: { str: string; int: number; }; }'.
  return M.format_lines(msg, { "twopat" })
end

M[2345] = function(msg)
  -- Property 'public_token' is missing in type '{}' but required in type 'ItemPublicTokenExchangeRequest'.
  -- Argument of type '{}' is not assignable to parameter of type 'ItemPublicTokenExchangeRequest'.
  return M.format_lines(msg, { "threepat", "twopat" })
end

M[2739] = function(msg)
  -- Type '{}' is missing the following properties from type 'LinkTokenCreateRequest': client_name, language, country_codes, user
  return M.format_lines(msg, { "missing_named_properties" })
end

M[2740] = function(msg)
  -- Type '{}' is missing the following properties from type 'LinkTokenCreateRequest': client_name, language, country_codes, user
  return M.format_lines(msg, { "missing_named_properties" })
end

M[2741] = function(msg)
  -- @TODO format this like 2345
  -- Property 'first' is missing in type '{}' but required in type 'Deep'.
  ---@diagnostic disable-next-line: unused-local
  local _start, _end, needle, a, b = msg:find(
    "Property '(.-)' is missing in type '(.-)' but required in type '(.*)'."
  )
  if needle and a and b then
    local second, lines2 = M.format_object_type(b)
    local last = (
      #lines2 > 1 and "but required in type\n%s" or "but required in type %s"
    ):format(second)
    return table.concat({
      ("Property '%s' is missing in type"):format(needle),
      ("%s"):format(M.format_object_type(a)),
      last,
    }, "\n")
  end
  return msg
end

M[7053] = function(msg)
  -- Element implicitly has an 'any' type because expression of type 'any' can't be used to index type '{}'.
  -- No index signature with a parameter of type 'string' was found on type '{ "ask.shop_visit_hour_2": string; "ask.shop_visit_hour_1": string; "ask.shop_visit_day_1": string; "ask.shop_visit_day_2": string; "ask.tel": string; "ask.contact_hour": string; "ask.method": string; ... 5 more ...; "ask.shop_id": string; }'.
  return M.format_lines(msg, { "threepat", "twopat" })
end

return M
