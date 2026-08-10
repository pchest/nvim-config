-- Copy file path to clipboard
vim.api.nvim_create_user_command("CopyPath", function(context)
  local full_path = vim.fn.glob("%:p")

  local file_path = nil
  if context["args"] == "nameonly" then
    file_path = vim.fn.fnamemodify(full_path, ":t")
  end

  -- get the file path relative to project root
  if context["args"] == "relative" then
    local project_marker = { ".git", "pyproject.toml" }
    local project_root = vim.fs.root(0, project_marker)
    if project_root == nil then
      vim.print("can not find project root")
      return
    end

    file_path = vim.fn.substitute(full_path, project_root, "<project-root>", "g")
  end

  if context["args"] == "absolute" then
    file_path = full_path
  end

  vim.fn.setreg("+", file_path)
  vim.print("Filepath copied to clipboard!")
end, {
  bang = false,
  nargs = 1,
  force = true,
  desc = "Copy current file path to clipboard",
  complete = function()
    return { "nameonly", "relative", "absolute" }
  end,
})

-- Count words in the current LaTeX file using texcount, ignoring math,
-- markup, comments, and the preamble (unlike the statusline word count).
vim.api.nvim_create_user_command("TeXCount", function()
  if vim.fn.executable("texcount") == 0 then
    vim.api.nvim_echo({ { "texcount not found in PATH" } }, true, { err = true })
    return
  end

  local file_path = vim.fn.expand("%:p")
  if file_path == "" then
    vim.api.nvim_echo({ { "TeXCount: buffer has no file on disk" } }, true, { err = true })
    return
  end

  if vim.bo.modified then
    vim.print("TeXCount: counting the last saved version (buffer has unsaved changes)")
  end

  -- -0 gives a terse, single-line summary; -sum folds captions/headers into
  -- the total. We parse the "Words in text" figure from the full output.
  vim.system({ "texcount", "-brief", file_path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = string.format("TeXCount failed: %s", (result.stderr or ""):gsub("%s+$", ""))
        vim.api.nvim_echo({ { msg } }, true, { err = true })
        return
      end

      -- -brief output looks like: "722+9+12 (1/0/0/0) File: <path>"
      -- where the first number is words in text.
      local words = result.stdout:match("^(%d+)")
      if words then
        vim.print(string.format("Words in text: %s", words))
      else
        vim.print(result.stdout:gsub("%s+$", ""))
      end
    end)
  end)
end, {
  desc = "Count words in text of current LaTeX file (via texcount, ignores math/markup)",
  force = true,
})

-- JSON format part of or the whole file
vim.api.nvim_create_user_command("JSONFormat", function(context)
  local range = context["range"]
  local line1 = context["line1"]
  local line2 = context["line2"]

  if range == 0 then
    -- the command is invoked without range, then we assume whole buffer
    local cmd_str = string.format("%s,%s!python -m json.tool", line1, line2)
    vim.fn.execute(cmd_str)
  elseif range == 2 then
    -- the command is invoked with some range
    local cmd_str = string.format("%s,%s!python -m json.tool", line1, line2)
    vim.fn.execute(cmd_str)
  else
    local msg = string.format("unsupported range: %s", range)
    vim.api.nvim_echo({ { msg } }, true, { err = true })
  end
end, {
  desc = "Format JSON string",
  range = "%",
})
