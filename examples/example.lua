-- Run during protection with -sf; this script does not run in the output EXE.
local core = myvmp.core()
local input = assert(core:inputFile(), "An input executable is required")
local compiled_architectures = 0

-- Change global project settings at top level, before compilation starts.
-- Preserve existing flags when enabling packing.
core:setOptions(core:options() | ProjectOption.Pack)

print("Input: " .. core:inputFileName())
print("Output: " .. core:outputFileName())
print("Format: " .. input:format())

for i = 1, input:count() do
    local arch = input:item(i)
    print("Architecture: " .. arch:name())
    print("Image base: 0x" .. tostring(arch:imageBase()))

    -- The native wrapper of a .NET input may not have a function list.
    local functions = arch:functions()
    if functions then
        print("Selected functions: " .. functions:count())
    end
end

-- Callback names must be global. Obtain the current view inside each callback.
function OnBeforeCompilation()
    local arch = assert(core:outputArchitecture(), "No current output architecture")
    compiled_architectures = compiled_architectures + 1
    print("Compiling: " .. arch:name())

    local functions = arch:functions()
    if functions then
        for i = 1, functions:count() do
            local fn = functions:item(i)
            print("Selected: " .. fn:name() .. " at 0x" .. tostring(fn:address()))
        end
    end
end

function OnBeforeSaveFile()
    print("Saving architecture")
end

-- This callback is specific to the native PE packing path.
function OnBeforePackFile()
    print("Packing native PE data")
end

function OnAfterSaveFile()
    print("Architecture saved")
end

function OnAfterCompilation()
    -- The output has been finalized. Architecture callback counts can vary.
    print("Compiled architecture views: " .. compiled_architectures)
    print("Example completed: " .. core:outputFileName())
end
