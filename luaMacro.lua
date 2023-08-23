
do
    local ver = _G._VERSION:match("Lua (%d+%.%d+)")
    if ver ~= "5.4" then
        print("\27[33mWarning! This script was designed to run on Lua 5.4. You may experience bugs or errors.\27[0m")
    end
end

_G._PREPROCESSOR_VERSION = "1.1.1"

--wacky OS compatibility
do
    local sep = package.config:sub(1, 1)
    if sep == "/" then
        _G.PATH_SEPARATORS = '/'
    elseif sep == '\\' then
        _G.PATH_SEPARATORS = '/\\'
    else
        _G.PATH_SEPARATORS = sep
    end

    _G._FILENAME_MATCH = '[^'.._G.PATH_SEPARATORS..']+$'
end

-- adjust the path so that this script can see and require from the macro package
local path = arg[0]:gsub(_G._FILENAME_MATCH,'')
_G.path = path
package.path = package.path .. ';' .. path .. '?.lua;'..path .. 'macro/?.lua'

local macro_args = require 'macroargs'

-- TODO implement this properly, don't want to sacrifice readability just yet
-- local dumpTokens = macro_args.switches['p'] == true


local input_file = io.open(macro_args.input, "r") --not rb, that messes up the newlines
local output_file = io.open(macro_args.output, "wb")


local TokenProducer = require 'macro.TokenProducer'
local Stream = require 'macro.Stream'
local Modifier = require 'macro.Modifier'

local ReconstructStream = require('macro.Reconstructor').ReconstructStream

local producer = TokenProducer.new(input_file)

local parsedTokenStream = Stream.new()

local parser = Modifier.new(producer, parsedTokenStream, macro_args.switches)

local reconstructor = ReconstructStream(function()
    return parsedTokenStream:Read()
end, function(data)
    output_file:write(data)
end)
local finished = false

while not producer.closed do
    local written = parser:ParseToken()
    if written then
        finished = reconstructor()
        -- local tokens, n <const> = parsedTokenStream:ReadAll()
        -- for i=1,n do
        --     local token <const> = tokens[i]
        --     print(token[1], token[2])
        -- end
    end
    -- print(producer:ReadToken())
end

if not finished then reconstructor() end

input_file:close()
output_file:close()