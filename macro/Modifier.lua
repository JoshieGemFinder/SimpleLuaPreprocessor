
local Tokens <const> = require('macro.TokenProducer').Tokens
local Stream <const> = require('macro.Stream')
local Reconstruct <const> = require('macro.Reconstructor').ReconstructList

local ID_DEFINE <const> = 0
local ID_EVAL <const> = 1
local ID_FUNC <const> = 2
local ID_RAW <const> = 3

local DEFINE <const> = "@def"
local EVAL <const> = "@eval"
local FUNC <const> = "@func"
local RAW_DEFINE <const> = "@raw"

local ENUM <const> = "@enum"

local COMMENT <const> = "@comment"

local DELETE <const> = "@del"

local constant_token <const> = "constant"

local function identifyWordTokenType(word)
    if word == "and" or word == "not" or word == "or" then
        return Tokens.OPERATOR
    end

    if word == "nil" or word == "true" or word == "false" then
        return constant_token
    end

    -- if word == "break" or word == "do" or word == "else" or word == "elseif" or word == "end" or word == "for" or word == "function" or word == "goto" or word == "if" or word == "in" or word == "local" or word == "repeat" or word == "return" or word == "then" or word == "until" or word == "while" then
    --     return "keyword"
    -- end

    return "other"
end

--converts a parsed string into a lua-readable string
local function reparseString(str)

    str = string.gsub(str, "\\", [[\\]])

    local delim = '"'
    if string.match(str, '"') ~= nil then
        if string.match(str, "'") ~= nil then
            str = string.gsub(str, '"', '\\"')
        else
            delim = "'"
        end
    end

    str = string.gsub(str, "\n", [[\n]])
    str = string.gsub(str, "\r", [[\r]])
    str = string.gsub(str, "\t", [[\t]])
    str = string.gsub(str, "\v", [[\v]])
    str = string.gsub(str, "\b", [[\b]])
    str = string.gsub(str, "\a", [[\a]])

    
    --a catch for everything else, excluding spaces
    str = string.gsub(str, "[^ %g]", function(a) return "\\" .. string.format("%03d",string.byte(a)) end)

    return delim .. str .. delim
end

local function table_insert(self, ...)
    local len <const> = select("#", ...)
    local k <const> = #self
    local args = {...}
    for i=1,len do
        -- self[k + i] = args[i]
        table.insert(self, args[i])
    end

    return len
end


local function isConstant(token, tokenType)

    if tokenType == Tokens.WORD then
        local wordType <const> = identifyWordTokenType(token)
        
        return wordType == Tokens.OPERATOR or wordType == constant_token
    end

    return tokenType == Tokens.OPERATOR or tokenType == Tokens.STRING or tokenType == Tokens.STRING_MULTILINE
        or tokenType == Tokens.NUMBER or (tokenType == Tokens.BRACKET and (token == "(" or token == ")"))
        or tokenType == Tokens.LINEFEED
end

local function isGroupConstant(group, modifier)
    local macros <const> = modifier.macros
    for i=1,#group do
        local tkn <const> = group[i]

        local token <const>, tokenType <const> = tkn[1], tkn[2]


        --TODO: Proper Parsing for e.g brackets
        if not isConstant(token, tokenType) then
            local macro <const> = macros[token]
            if macro ~= nil then
                local const = isGroupConstant(modifier:GetContentTokens(macro), modifier)
                return const
            else
                return false
            end
        end
    end
    return true
end

local function evalTokens(tokens)
    -- print("Eval: ", Reconstruct(tokens))
    local eval = table.pack(pcall(load("return " .. Reconstruct(tokens))))
    local success = eval[1]

    if not success then --error in eval
        return tokens
    end

    local outTokens = {}
    for i=2,eval.n do
        local token = eval[i]
        local tokenType = Tokens.RAW

        local _type <const> = type(token)
        if _type == 'number' then
            tokenType = Tokens.NUMBER
        elseif _type == 'string' then
            token = reparseString(token)
            tokenType = Tokens.STRING
        elseif _type == 'table' then -- can't return tables, try unpacking them!
            return tokens
        end

        table.insert(outTokens, {token, tokenType})
    end

    return outTokens
end

local Modifier = {}
Modifier.metatable = {__index = Modifier, __metatable = function() return nil end}


function Modifier.new(producer, output, switches)

    local modifier = {}

    modifier.producer = producer
    modifier.input = Stream.new({
        producer = producer,
        Read = function(self)
            if self:Remaining() <= 0 then
                -- local n <const> = self.n + 1
                -- self.n = n
                -- self.pos = n
                -- return {self.producer:ReadToken()}
                self:Write({self.producer:ReadToken()})
            end
            return self:_read()
        end
    })
    modifier.output = output
    modifier.state = 0

    --strip comments
    modifier.strip = switches ~= nil and switches['s'] == true

    ---Macros in the form {Triggering Token = {type = "replacement/raw/function", content = <content to replace the triggering token with>}}
    modifier.macros = {}
    
    setmetatable(modifier, Modifier.metatable)

    return modifier
end

function Modifier:GetModifiedTokens(token)
    
    local macro <const> = self.macros[token]

    if macro == nil then
        return nil
    end

    return self:GetContentTokens(macro)
end

function Modifier:GetContentTokens(macro)
    
    local type <const> = macro.type

    if type == ID_DEFINE or type == ID_RAW then
        return table.unpack(macro.content)
    elseif type == ID_EVAL or type == ID_FUNC then
        return table.unpack(self:HandleEval(macro))
    end

    error("Invalid macro type: " .. tostring(type))
    
end

--reads tokens until the next occurance of end_token (the end_token is not returned)
function Modifier:ReadUntilToken(end_token, bypass_macros, allow_escaping)
    if bypass_macros ~= true then bypass_macros = false end
    if allow_escaping ~= true then allow_escaping = false end
    local tokens <const> = {}
    local n = 0

    local producer <const> = self.producer
    while not producer.closed do
        local token, tokenType = producer:ReadToken()

        if token == end_token then
            if allow_escaping and tokens[n][1] == [[\]] then
                tokens[n] = nil
                n = n - 1
            else
                return tokens, n
            end
        end

        local macro <const> = self.macros[token]
        if bypass_macros or macro == nil then
            n = n + 1
            tokens[n] = {token, tokenType}
        else
            local c = table_insert(tokens, self:GetContentTokens(macro))
            n = n + c
        end
    end

    error("Invalid Syntax!")
end

-- function Modifier:ReadUntilType(end_type)
--     
-- end

--- reads from a starting `(` to it's closing `)`, does not include the closing `)`
--- **assumes the first bracket has already been read**
function Modifier:ReadBrackets(strict) -- strict: brackets can only be on one line and only contain <word>s
    if strict ~= true then strict = false end

    local bracketIndent = 1

    
    local tokens <const> = {}
    local n = 0

    --a "group" is a list of tokens that's a function tokens split by delimiters 
    --[[
        e.g:
        (a + b, d + e) becomes
        group: {
            {a, +, b},
            {d, +, e}
        }

        (a * (b + c), d + e(f, g, h * i)) becomes
        group: {
            {a, *, {b, +, c}},
            {d, +, e, {{f}, {g}, {h, *, i}}}
        }
    ]]

    -- TODO make groups properly
    -- local groups <const> = {}
    -- local groupStack = {}

    local currentGroup = {}
    local groups <const> = {}

    local squareIndex = 0

    local producer <const> = self.producer
    local input <const> = self.input
    while not producer.closed do
        local tkn <const> = input:Read()
        local token <const> = tkn[1]
        
        local macro <const> = self.macros[token]
        if macro ~= nil then
            input:UnshiftAll(self:GetContentTokens(macro))
        else
            local tokenType <const> = tkn[2]

            if strict and not (tokenType == Tokens.WORD or tokenType == Tokens.DELIMITER or token == ")") then
                error("Strict Brackets cannot accept tokens of type " .. tokenType)
            end

            if token == "(" then
                bracketIndent = bracketIndent + 1
            elseif token == ")" then
                bracketIndent = bracketIndent - 1
                if bracketIndent < 1 then
                    table.insert(groups, currentGroup)
                    return tokens, n, groups
                end
            -- elseif token == "[" or token == "]" or token == "{" or token == "}" then
            --     error("Tables are not supported inside an @eval!")
            elseif token == "{" or token == "}" then
                error("Tables are not supported inside an @eval!")
    
            elseif token == "[" then
                squareIndex = squareIndex + 1
            elseif token == "]" then
                squareIndex = squareIndex - 1
            end
    
            --ignore newlines
            if tokenType ~= Tokens.LINEFEED then
                
                --basic group stuff
                -- if bracketIndent == 1 then
                    if squareIndex <= 0 and tokenType == Tokens.DELIMITER then
                        table.insert(groups, currentGroup)
                        currentGroup = {}
                    else
                        table.insert(currentGroup, tkn)
                    end
                -- end
    
                n = n + 1
                tokens[n] = tkn
            elseif strict then
                error("Strict Brackets must be only one line!")
            end
        end
    end

    --if syntax is wrong we won't get a closing bracket
    error("Invalid Syntax!")
end

function Modifier:CreateFuncMacro(id)

    -- print("Eval BEGIN")
    local trigger_token = self.producer:ReadToken()

    local bracket_token = self.producer:ReadToken()
    if bracket_token ~= '(' then
        error("An @eval/@func must follow the syntax @eval foo(bar, baz, ...etc) <code to eval with passed args>")
    end

    local evalArgs, n, groups = self:ReadBrackets(true)

    -- print("Eval tokens:")
    -- for i=1,n do
    --     local token = evalArgs[i]
    --     print(i, token[1], token[2])
    -- end

    -- print("Eval token groups:")
    -- for i, group in ipairs(groups) do
    --     local out = {}
    --     for _, v in ipairs(group) do table.insert(out, v[1]) end
    --     print(tostring(i) .. "\t" .. table.concat(out, " "))
    -- end

    -- print("----------")
    local tokens = self:ReadUntilToken(Tokens.LINEFEED)
    -- for _, tkn in ipairs(tokens) do
    --     print(_, tkn[1], tkn[2])
    -- end
    -- print("----------")

    self.macros[trigger_token] = {type=id, args=groups, content=tokens}

    -- print("Eval END")

end

function Modifier:ParseToken()
    local producer <const> = self.producer
    local stream <const> = self.output

    local token, tokenType = producer:ReadToken()


    if tokenType == Tokens.MACRO then
        if token == DEFINE then
            local trigger_token = producer:ReadToken()

            local tokens, n = self:ReadUntilToken(Tokens.LINEFEED, false, true)
            if n > 1 and tokens[1][1] == "(" and tokens[n][1] == ")" and isGroupConstant(tokens, self) then -- if the group is evaluable, eval
                -- for i=1,n do
                --     local tkn <const> = tokens[i]
                --     local _token, _tokenType <const> = tkn[1], tkn[2]
                --     if _tokenType == Tokens.OPERATOR or _tokenType == Tokens or (_tokenType == Tokens.WORD and identifyWordTokenType(_token) == Tokens.OPERATOR) then
                --         tokens = evalTokens(tokens)
                --         break
                --     end
                -- end
                tokens = evalTokens(tokens)
                n = #tokens
            end

            -- --seperate checks because you might the number of tokens can be adjusted by the eval
            -- if n > 1 and tokens[1][1] ~= "(" and tokens[n][1] ~= ")" and isGroupConstant(tokens, self) then
            --     local contentTokens = {{"(", Tokens.BRACKET}}
            --     for _, tkn in ipairs(tokens) do
            --         table.insert(contentTokens, tkn)
            --     end
            --     table.insert(contentTokens, {")", Tokens.BRACKET})
            --     tokens = contentTokens
            -- end

            self.macros[trigger_token] = {type=ID_DEFINE, content=tokens}
            return false
        elseif token == EVAL then
            self:CreateFuncMacro(ID_EVAL)
            return false
        elseif token == FUNC then
            self:CreateFuncMacro(ID_FUNC)
            return false
        elseif token == RAW_DEFINE then
            local trigger_token = producer:ReadToken()

            local tokens = self:ReadUntilToken(Tokens.LINEFEED, false, true)
            self.macros[trigger_token] = {type=ID_RAW, content=tokens}
            -- self.macros[trigger_token] = {type=ID_RAW, content=(producer:ReadLine()):match("^%s*(.-)%s*$")}
            return false
        elseif token == ENUM then
            local tokens, n = self:ReadUntilToken(Tokens.LINEFEED, false, true)

            local enumStart = 1
            local enumIncrement = 1

            local startIndex = 1
            
            do
                local found = 0
                --look for [start] and [increment]
                for i=1,n do
                    local _token, _tokenType <const> = tokens[i][1], tokens[i][2]
                    if _token == ";" then
                        -- break early if there's a ;
                        break
                    end

                    if _tokenType == Tokens.NUMBER then
                        startIndex = i + 1
                        found = found + 1
                        
                        if found == 1 then
                            enumStart = tonumber(_token)
                        elseif found == 2 then
                            enumIncrement = tonumber(_token)
                            break
                        end
                    end
                end
            end

            local enumVal = enumStart
            for i=startIndex,n do
                local enumToken, enumTokenType <const> = tokens[i][1], tokens[i][2]
                if not (enumTokenType == Tokens.DELIMITER or enumTokenType == Tokens.LINEFEED) then
                    self.macros[enumToken] = {type=ID_DEFINE, content={{tostring(enumVal), Tokens.NUMBER}}}
                    enumVal = enumVal + enumIncrement
                end
            end

            return false
        elseif token == COMMENT then
            producer:ReadLine()
            producer:ReadToken()
            return false
        elseif token == DELETE then
            local tokens, n = self:ReadUntilToken(Tokens.LINEFEED, true, true)

            for i=1,n do
                self.macros[tokens[i][1]] = nil
            end
            return false
        end

        error("Unknown macro " .. token .. "!")
        return false;
    else
        local macro <const> = self.macros[token]

        if macro == nil then
            if self.strip == true and (tokenType == Tokens.COMMENT or tokenType == Tokens.MULTILINE_COMMENT) then
                return false
            end

            stream:Write({token, tokenType})
            return true
        end
        
        return stream:WriteAll(self:GetContentTokens(macro))
    end
end

function Modifier:HandleEval(macro)
    local bracket_token = self.producer:ReadRealToken()

    local errPos <const> = self.producer:GetPositionString()

    if bracket_token ~= "(" then
        error("Missing opening bracket after macro at " .. errPos)
    end

    local macro_groups = macro.args

    local tokens, n, groups = self:ReadBrackets()

    if #macro_groups ~= #groups then
        error("Length difference between macro arguments and passed arguments at " .. errPos)
    end


    local group_indexes = {}
    for i, group in ipairs(macro_groups) do
        group_indexes[group[1][1]] = i
    end


    local input = macro.content

    
    local can_eval = macro.type == ID_EVAL --don't attempt to eval if only @func was defined
    for i, group in ipairs(groups) do
        if not isGroupConstant(group, self) then
            can_eval = false
            break
        end
    end

    local output = {}

    for _, tkn in ipairs(input) do
        local group_index <const> = group_indexes[tkn[1]]
        if group_index ~= nil then
            local prevToken <const> = input[_-1]
            local nextToken <const> = input[_+1]
            local hasBrackets <const> = prevToken ~= nil and nextToken ~= nil and prevToken[1] == "(" and nextToken[1] == ")"

            if not hasBrackets then table.insert(output, {"(", Tokens.BRACKET}) end
            
            for _, v in ipairs(groups[group_index]) do
                table.insert(output, v)
            end
            
            if not hasBrackets then table.insert(output, {")", Tokens.BRACKET}) end
        else
            table.insert(output, tkn)
        end
    end

    -- print()
    -- print("RUNNING EVAL")
    -- print("can_exec", can_eval)


    if can_eval then
        return evalTokens(output)
    end

    -- print("END")
    -- print()

    return output
end

return Modifier