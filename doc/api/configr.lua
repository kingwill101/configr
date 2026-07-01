---@meta _
---Generated LuaLS annotations for configr.
---Do not execute this file; add it to LuaLS as a library.
---Generator: lualike.docs
---Schema: 1
---Package version: 1.0.0

---@class context
---Default plugin context table with system information.
---
---@field platform? string # Operating system (linux, macos, windows, etc.).
---@field architecture? string # CPU architecture (x86_64, aarch64, etc.).
---@field hostname? string # System hostname.
---@field os? table # Operating system details.
---@field os.name? string # OS name (linux, macos, windows).
---@field os.version? string # OS version string (e.g. Linux kernel, Darwin version).
---@field os.family? string # OS family (debian, redhat, arch, darwin, windows).
---@field os.distribution? string # Distribution ID (ubuntu, manjaro, rhel) or OS name on non-Linux.
---@field os.distributionVersion? string # Distribution version (VERSION_ID from os-release) or kernel version.
---@field os.kernel? string # Kernel version string from uname -r.
---@field user? table # Current user information.
---@field user.username? string # Username.
---@field user.home? string # Home directory.
---@field user.shell? string # Default shell.
---@field env? table # Common environment variables.
---@field configr? table # Configr runtime configuration.
---@field configr.version? string # Configr version.
---@field configr.cacheDir? string # Cache directory.
---@field configr.backupDir? string # Backup directory.

---@class block
---Block data table passed to execute() and rollback() callbacks.
---
---@field id string # Unique block instance identifier.
---@field source? string # Source path (may be empty).
---@field destination? string # Destination path (may be empty).
---@field properties? table # Block-specific configuration property key-value pairs.

---@class registerBlock.callbacks
---Callback table passed to registerBlock().
---
---@field execute fun(block:block):nil # Required. Called when the block is executed. Receives a block table.
---@field rollback? fun(block:block):nil # Optional. Called when the block is rolled back. Receives a block table.
---@field commands? {[string]:fun(...)} # Optional. Table of scoped command name → handler mappings.

---Gets the value of an environment variable.
---@param name string # The name of the environment variable.
---@return string? # string\|nil
function getEnv(name) end

---Gets a variable from the current configuration context.
---@param name string # The variable name to look up.
---@return any # any
function getVariable(name) end

---Sets a variable in the global configuration context.
---@param name string # The variable name.
---@param value any # The value to assign.
function setVariable(name, value) end

---Expands Configr variable references ($var) in a string.
---@param str string # String containing $variable references.
---@return string # string
function expandVariables(str) end

---Logs an info-level message to the Configr logger.
---@param message string # The message to log.
function logInfo(message) end

---Logs a warning-level message to the Configr logger.
---@param message string # The message to log.
function logWarning(message) end

---Logs an error-level message to the Configr logger.
---@param message string # The message to log.
function logError(message) end

---Logs a debug-level message to the Configr logger.
---@param message string # The message to log.
function logDebug(message) end

---Checks whether a file exists at the given path.
---@param path string # Path to check.
---@return boolean # boolean
function fileExists(path) end

---Reads the entire contents of a file as a string.
---@param path string # Path to the file.
---@return string # string
function readFile(path) end

---Writes string content to a file, replacing existing content.
---@param path string # Destination file path.
---@param content string # Content to write.
function writeFile(path, content) end

---Appends string content to the end of a file.
---@param path string # Destination file path.
---@param content string # Content to append.
function appendFile(path, content) end

---Runs a shell command through Configr’s process backend.
---@param command string # Command string to execute.
---@return number # integer
function runCommand(command) end

---Returns the Configr cache directory path.
---@return string # string
function configrCacheDir() end

---Returns the Configr backup directory path.
---@return string # string
function configrBackupDir() end

---Emits a status update event to the Configr event bus.
---@param moduleId string # The module or block identifier.
---@param level string # Severity level: "info", "warning", "error", or "debug".
---@param message string # The status message.
function emitStatusUpdate(moduleId, level, message) end

---Registers a Lua-defined action block type with callbacks.
---@param blockType string # The block type name (e.g. "notify").
---@param callbacks registerBlock.callbacks # Callback table. See "registerBlock.callbacks" table schema for field types.
function registerBlock(blockType, callbacks) end

---Returns a value from the default plugin context table by key.
---@param key string # Context key ("platform", "architecture", "hostname", "os" (table), "user" (table), "env" (table), "configr" (table)).
---@return any # any
function getContext(key) end

---Asserts that a file exists.
---@param path string # Path to the file.
function assertFileExists(path) end

---Asserts that a file does not exist.
---@param path string # Path to the file.
function assertFileNotExists(path) end

---Asserts that a file contains the given substring.
---@param path string # Path to the file.
---@param pattern string # Substring to search for.
function assertFileContains(path, pattern) end

---Asserts that a file does not contain the given substring.
---@param path string # Path to the file.
---@param pattern string # Substring to search for.
function assertFileNotContains(path, pattern) end

---Asserts that a directory exists.
---@param path string # Path to the directory.
function assertDirExists(path) end

---Asserts that a directory does not exist.
---@param path string # Path to the directory.
function assertDirNotExists(path) end

---Creates a directory recursively (like mkdir -p).
---@param path string # Directory path to create.
function makeDir(path) end

---Removes a directory tree (like rm -rf).
---@param path string # Directory path to remove.
function removeTree(path) end

---Returns the OS temporary directory path.
---@return string # string
function tempDir() end

---Returns the OS name (linux, macos, windows, etc).
---@return string # string
function osName() end

