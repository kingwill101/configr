local tmp = tempDir()
local f = io.open(tmp .. '/test_src', 'w')
f:write('Hello, {{ name }}!\n')
f:close()
