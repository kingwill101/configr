local tmp = tempDir()
local f = io.open(tmp .. '/configr_move_source.txt', 'w')
f:write('move test content\n')
f:close()
