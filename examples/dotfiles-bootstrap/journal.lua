-- journal.lua — provides a "journal" action block for audit trails
name = "journal_plugin"
description = "Logs configr operations with timestamps to a journal file"
version = "1.0.0"

local function timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

registerBlock("journal", {
  execute = function(block)
    local action  = getVariable("action") or "unknown"
    local target  = getVariable("target") or "unspecified"
    local status  = getVariable("status") or "ok"
    local dir     = configrCacheDir()
    local file    = dir .. "/journal.csv"
    local line    = string.format("%s,%s,%s,%s\n", timestamp(), action, target, status)
    appendFile(file, line)
    emitStatusUpdate(block.id, "info", "journal: " .. action .. " " .. target)
  end,
  rollback = function(block)
    local dir  = configrCacheDir()
    local file = dir .. "/journal.csv"
    appendFile(file, string.format("%s,rollback,%s,pending\n", timestamp(), block.id))
  end,
})
