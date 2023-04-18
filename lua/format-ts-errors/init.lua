local M = {}

M.format_object_type = function(o)
  o = vim.fn.substitute(o, "; ", ";", "g")
  o = vim.fn.substitute(o, ";", ";\n", "g")
  o = vim.fn.substitute(o, "{ ", "{\n", "g")

  -- indent
  o = vim.fn.split(o, "\n")
  local obj = ""
  local level = 0
  for _, line in ipairs(o) do
    if line:find("}") then
      level = level - 1
    end
    local spaces = ("  "):rep(level)
    obj = obj .. spaces .. line .. "\n"
    if line:find("{") then
      level = level + 1
    end
  end
  return obj
end

M[2322] = function(msg)
  -- "Object literal may only specify known properties, and 'third' does not exist in type '{ second: { str: string; int: number; }; }'."
  ---@diagnostic disable-next-line: unused-local
  local _start, _end, key, deep =
    msg:find("Object.*and '(.-)' does not exist in type '(.*)'.")

  msg:find("Object.*and '(.-)' does not exist in type '(.*)'.")
  if key and deep then
    local obj = M.format_object_type(deep)
    return (
      "Object literal may only specify known properties, and"
      .. ("\n\n  %s"):format(key)
      .. "\n\ndoes not exist in type"
      .. ("\n\n%s"):format(obj)
      .. "\n"
    )
  end
  return msg
end

M[2741] = function(msg)
  -- Property 'first' is missing in type '{}' but required in type 'Deep'.
  ---@diagnostic disable-next-line: unused-local
  local _start, _end, needle, a, b =
    msg:find("Property '(.-)' is missing in type '(.-)' but required in type '(.*)'.")
  if needle and a and b then
    return (
      "Property"
      .. ("\n\n  %s"):format(needle)
      .. "\n\nis missing in type"
      .. ("\n\n%s"):format(M.format_object_type(a))
      .. "\nbut required in type"
      .. ("\n\n%s"):format(M.format_object_type(b))
      .. "\n"
    )
  end
  return msg
end

return M
