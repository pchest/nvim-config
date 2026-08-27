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

-- Preview an image file inline (e.g. a plot saved by ggsave) with image.nvim.
--   :Img                -> newest image in the default Graphs dir
--   :Img <dir>          -> newest image in that directory
--   :Img <path-to-img>  -> that specific file
local img_default_dir = vim.fn.expand("~/")

local function newest_image_in(dir)
  local files = {}
  for _, ext in ipairs({ "png", "jpg", "jpeg", "gif", "webp" }) do
    vim.list_extend(files, vim.fn.glob(dir .. "*." .. ext, true, true))
  end
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  return files[1]
end

vim.api.nvim_create_user_command("Img", function(context)
  local ok, image = pcall(require, "image")
  if not ok then
    vim.api.nvim_echo({ { "image.nvim is not available", "ErrorMsg" } }, true, {})
    return
  end

  local arg = context["args"]
  local target
  if arg == nil or arg == "" then
    target = img_default_dir
  else
    target = vim.fn.fnamemodify(vim.fn.expand(arg), ":p")
  end

  -- If the target is a directory, resolve to its most recently modified image
  local path = target
  if vim.fn.isdirectory(target) == 1 then
    path = newest_image_in(target)
    if path == nil then
      vim.api.nvim_echo({ { "No images found in " .. target, "ErrorMsg" } }, true, {})
      return
    end
  end

  if vim.fn.filereadable(path) == 0 then
    vim.api.nvim_echo({ { "File not readable: " .. path, "ErrorMsg" } }, true, {})
    return
  end

  -- Open a throwaway scratch buffer in a vertical split to host the image
  vim.cmd("vsplit")
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].bufhidden = "wipe"

  vim.schedule(function()
    local img = image.from_file(path, { window = win, buffer = buf, x = 0, y = 0 })
    img:render()
    vim.api.nvim_echo({ { "Previewing " .. path } }, false, {})
  end)
end, {
  nargs = "?",
  complete = "file",
  force = true,
  desc = "Preview an image file inline with image.nvim (defaults to newest plot)",
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
