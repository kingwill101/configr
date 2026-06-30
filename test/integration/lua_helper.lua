local M = {}

function M.assertFileExists(path)
  local f = io.open(path, 'r')
  if not f then
    io.stderr:write('ASSERT FAILED: file does not exist: ' .. path .. '\n')
    os.exit(1)
  end
  f:close()
end

function M.assertFileNotExists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    io.stderr:write('ASSERT FAILED: file exists but should not: ' .. path .. '\n')
    os.exit(1)
  end
end

function M.assertFileContains(path, pattern)
  local f = io.open(path, 'r')
  if not f then
    io.stderr:write('ASSERT FAILED: file does not exist: ' .. path .. '\n')
    os.exit(1)
  end
  local content = f:read('*a')
  f:close()
  if not content:find(pattern) then
    io.stderr:write('ASSERT FAILED: file does not contain pattern "' .. pattern .. '": ' .. path .. '\n')
    os.exit(1)
  end
end

function M.assertFileNotContains(path, pattern)
  local f = io.open(path, 'r')
  if not f then
    io.stderr:write('ASSERT FAILED: file does not exist: ' .. path .. '\n')
    os.exit(1)
  end
  local content = f:read('*a')
  f:close()
  if content:find(pattern) then
    io.stderr:write('ASSERT FAILED: file contains forbidden pattern "' .. pattern .. '": ' .. path .. '\n')
    os.exit(1)
  end
end

function M.assertDirExists(path)
  local f = io.open(path, 'r')
  if not f then
    io.stderr:write('ASSERT FAILED: directory does not exist: ' .. path .. '\n')
    os.exit(1)
  end
  f:close()
end

function M.assertDirNotExists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    io.stderr:write('ASSERT FAILED: directory exists but should not: ' .. path .. '\n')
    os.exit(1)
  end
end

function M.run(cmd, ...)
  local args = table.pack(...)
  local full = cmd
  for i = 1, args.n do
    full = full .. ' ' .. tostring(args[i])
  end
  local ok, _, code = os.execute(full)
  if not ok or code ~= 0 then
    io.stderr:write('ASSERT FAILED: command failed (exit ' .. tostring(code) .. '): ' .. full .. '\n')
    os.exit(1)
  end
end

function M.assertExitCode(cmd, expected)
  local ok, _, code = os.execute(cmd)
  local actual = ok and (code or 0) or -1
  if actual ~= expected then
    io.stderr:write('ASSERT FAILED: expected exit code ' .. tostring(expected) .. ' but got ' .. tostring(actual) .. ': ' .. cmd .. '\n')
    os.exit(1)
  end
end

return M
