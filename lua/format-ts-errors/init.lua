local M = {}

M[2322] = function (msg)
  -- "Object literal may only specify known properties, and 'third' does not exist in type '{ second: { str: string; int: number; }; }'."
  ---@diagnostic disable-next-line: unused-local
  local _start, _end, key, deep =
    msg:find("Object.*and '(.-)' does not exist in type '(.*)'.")
  if key and deep then
    deep = vim.fn.substitute(deep, "; ", ";", "g")
    deep = vim.fn.substitute(deep, ";", ";\n", "g")
    deep = vim.fn.substitute(deep, "{ ", "{\n", "g")
    deep = vim.fn.split(deep, "\n")
    local obj = ""
    local level = 0
    for _, line in ipairs(deep) do
      if line:find("}") then
        level = level - 1
      end
      local spaces = ("  "):rep(level)
      obj = obj .. spaces .. line .. "\n"
      if line:find("{") then
        level = level + 1
      end
    end
    return (
      "Object literal may only specify known properties, and"
      .. ("\n\n  %s"):format(key)
      .. "\n\ndoes not exist in type"
      .. ("\n\n%s\n"):format(obj)
    )
  end
  return msg
end

return M
