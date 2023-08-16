
local Tokens <const> = require('macro.TokenProducer').Tokens

local CONSTANT <const> = "constant"
local KEYWORD <const> = "keyword"

local function identifyWordTokenType(word)
    if word == "and" or word == "not" or word == "or" then
        return Tokens.OPERATOR
    end

    if word == "nil" or word == "true" or word == "false" then
        return CONSTANT
    end

    if word == "break" or word == "do" or word == "else" or word == "elseif" or word == "end" or word == "for" or word == "function" or word == "goto" or word == "if" or word == "in" or word == "local" or word == "repeat" or word == "return" or word == "then" or word == "until" or word == "while" or word == "<const>" then
        return KEYWORD
    end

    return "other"
end

local BRACKET_OPENING <const> = "opening"
local BRACKET_CLOSING <const> = "closing"

local function identifyBracketType(bracket)
    if word == "{" or word == "(" or word == "[" then
        return BRACKET_OPENING
    end

    if word == "}" or word == ")" or word == "]" then
        return BRACKET_CLOSING
    end

    return Tokens.BRACKET
end

local function isLinefeed(tkn)
    local t <const> = tkn[1]
    return t == Tokens.LINEFEED or t == Tokens.EOF
end

local function formatToken(token, tokenType, currTkn, prevTkn)
    -- local prevToken <const> = prevTkn ~= nil and prevTkn[1]
    -- local prevTokenType <const> = prevTkn ~= nil and prevTkn[2]

    if tokenType == Tokens.OPERATOR then
        if prevTkn ~= nil and prevTkn[2] == Tokens.OPERATOR then
            return token .. " "
        end
        return " " .. token .. " "
    elseif tokenType == Tokens.WORD or tokenType == Tokens.SPECIAL_KEYWORD then

        local wordType = identifyWordTokenType(token)

        if wordType == Tokens.OPERATOR then
            currTkn[2] = Tokens.OPERATOR
            if prevTkn ~= nil and prevTkn[2] == Tokens.OPERATOR then
                return token .. " "
            end
            return " " .. token .. " "
        end

        if prevTkn ~= nil then
            local prevToken <const> = prevTkn[1]
            local prevTokenType <const> = prevTkn[2]

            if prevTokenType == Tokens.WORD then
                return " " .. token
            elseif prevTokenType == Tokens.BRACKET and identifyBracketType(prevToken) == BRACKET_CLOSING then
                return " " .. token
            end
        end
    elseif tokenType == Tokens.DELIMITER then
        return token .. " "
    elseif tokenType == Tokens.LINEFEED then
        return "\r\n"
    elseif prevTkn ~= nil then
        if tokenType == Tokens.COMMENT and not isLinefeed(prevTkn) then
            return " " .. token

        elseif prevTkn[2] == Tokens.COMMENT then
            return "\r\n" .. token
        end
    end
    return token
end

local function normalizeTokenList(token_list)

    if type(token_list) == 'function' then
        -- print("Token Stream!")
        local token_stream = token_list
        token_list = {stream = token_stream, n = 0}
        setmetatable(token_list, {
            __index = function(self, index)
                if math.type(index) ~= 'integer' or index < 1 then
                    return nil
                end
                local n = rawget(self, "n")
                if n < index then
                    local stream = rawget(self, "stream")
                    for i=n+1,index do
                        -- print("Reading from stream", i)
                        rawset(self, i, stream())
                    end
                    rawset(self, "n", index)
                end
                return rawget(self, index)
            end
        })
    end

    return token_list
end

local function reconstructList(token_list, output_function)
    token_list = normalizeTokenList(token_list)

    local out;
    local n = 1

    if output_function == nil then
        out = {}
        output_function = function(data)
            out[n] = data
        end
    end
    
    local prevToken = nil
    local currToken = token_list[n]

    while currToken ~= nil and currToken[1] ~= Tokens.EOF do
        output_function(formatToken(currToken[1], currToken[2], currToken, prevToken))
        n = n + 1

        prevToken = currToken
        currToken = token_list[n]
        if currToken == nil or currToken[1] == Tokens.EOF then break end
    end

    if out ~= nil then
        return table.concat(out, "")
    end
end


local function reconstructStream(input_function, output_function)
    if input_function == nil or output_function == nil then
        error("Missing input/output function!")
    end
    
    local prevToken = nil
    local currToken = nil
    
    local closed = false

    return function()
        if closed then
            error("Reconstructor already ended!")
        end

        if currToken == nil then
            currToken = input_function()
        end
        
        if currToken[1] == Tokens.EOF then
            closed = true
            return true
        end

        while currToken ~= nil and currToken[1] ~= Tokens.EOF do
            output_function(formatToken(currToken[1], currToken[2], currToken, prevToken))
    
            prevToken = currToken
            currToken = input_function()
            if currToken == nil then break end
            if currToken[1] == Tokens.EOF then
                closed = true
                break
            end
        end

        return closed
    end
end

return {ReconstructList = reconstructList, ReconstructStream = reconstructStream}