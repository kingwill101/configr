local tmp = tempDir()
local f = io.open(tmp .. '/configr_copy_source.txt', 'w')
f:write('copy test content\n')
f:close()
