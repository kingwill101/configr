-- A Lua plugin that provides a "notify" action block
name = "notify_plugin"
description = "Logs block execution with custom messages and events"
version = "1.0.0"

registerBlock("notify", {
  execute = function(block)
    local msg = getVariable("message") or "Executed block: " .. block.id
    logInfo("notify: " .. msg)
    emitStatusUpdate(block.id, "info", msg)
    setVariable("notify_message", msg)
    writeFile("/tmp/notify.log", msg .. "\n")
  end,
  rollback = function(block)
    logWarning("notify: rolling back " .. block.id)
    emitStatusUpdate(block.id, "warning", "Rolled back: " .. block.id)
  end,
  commands = {
    greet = function(name)
      logInfo("greet: Hello, " .. name .. "!")
    end
  }
})
