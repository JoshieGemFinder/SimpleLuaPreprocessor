
local switches = {
    -- l = false,
    -- p = false,
    m = false,
    s = false,
    ["?"] = false
}

local function printInfo()

    print("Simple Lua Preprocessor v" .. _G._PREPROCESSOR_VERSION)
    print("Usage: luam [options] input_file [output_file]")
    print("Available options:")
    print("\t-o files\tSearch all ;-delimited files for macros.")
    -- print("\t-p:\t\tPrint tokens, do not reconstruct.")
    print("\t-s\t\tStrip comments.")
    print("\t-?\t\tShow this help menu.")
    print()
    print("\tinput_file\tPath to the file that will be parsed")
    print("\toutput_file\tPath to write the compiled file to.\n\t\t\t  Default: \"<input_file>-compiled.lua\"")

    os.exit()
end

local input_file, output_file;
local i = 0

local function handleSwitch(switch)
    if switches[switch] == nil then
        printInfo()
    end
    switches[switch] = true

    if switch == "?" then
        printInfo()
    end

    if switch == "m" then
        i = i + 1
        local files = arg[i]
        local iterator = string.gmatch(files, "[^" .. _G.PATH_DELIMITER .. "]+")
        local m = {}
        for file in iterator do
            table.insert(m, file)
        end
        switches[switch] = m

        return
    end

    -- if switch == "l" then

    -- end
end

while i < #arg do
    i = i + 1

    local argument = arg[i]

    if #argument == 2 then
        local prefix = argument:sub(1, 1)
        if prefix == "-" or prefix == "/" then
            handleSwitch(argument:sub(2,2))
        end
    elseif input_file == nil then
        input_file = argument
    elseif output_file == nil then
        output_file = argument
    else
        printInfo()
    end
end

if input_file == nil then printInfo() end
if output_file == nil then
    local filename = input_file:match(_G._FILENAME_MATCH)
    local name = filename:gsub("[.][^.]*$", '')
    -- file path + file name + "-compiled.lua" 
    output_file = input_file:gsub(_G._FILENAME_MATCH, '') .. name .. "-compiled.lua"
end

return {input = input_file, output = output_file, switches = switches}