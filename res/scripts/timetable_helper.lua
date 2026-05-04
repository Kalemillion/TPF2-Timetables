--[[
Module: timetable_helper
Role: Aggregator for small helper modules that provide TF2 API wrappers and utility functions.

Responsibilities:
- Load and initialize helper submodules (core, collections, display, engine).
- Expose a composed `timetableHelper` table used by `timetable` and other modules.

Design notes:
- Each helper module optionally returns an initialization function which accepts the
  `timetableHelper` table and attaches its API. This pattern decouples module loading
  from registration and keeps the composed API testable (submodules can be mocked).
]]

local timetableHelper = {}

-- Required helper modules. Each module may return an initializer function which will
-- receive `timetableHelper` to attach its exported helpers.
local modules = {
    require "helper.core",
    require "helper.collections",
    require "helper.display",
    require "helper.engine",
}

-- Iterate and call initializer functions when present.
for _, init in ipairs(modules) do
    if type(init) == "function" then
        -- Pass the composed helper table so modules can register namespaced helpers.
        init(timetableHelper)
    end
end

return timetableHelper
