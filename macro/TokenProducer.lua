
--string.byte("AZaz09@_", 1, -1)
local byte_A <const> = 65
local byte_Z <const> = 90
local byte_a <const> = 97
local byte_z <const> = 122
local byte_0 <const> = 48
local byte_9 <const> = 57
local byte_at <const> = 64
local byte_underscore <const> = 95


local byte_X <const> = 88
local byte_x <const> = 120

local pattern_alphanum = "[A-Za-z0-9_]+"

--string.byte("\r\n \t", 1, -1)
local byte_ANSIr <const> = 13
local byte_ANSIn <const> = 10
local byte_space <const> = 32
local byte_tab <const> = 9

--string.byte("<=>+-*/^%&|~#", 1, -1)
local byte_lt <const> = 60
local byte_eq <const> = 61
local byte_gt <const> = 62
local byte_plus <const> = 43
local byte_minus <const> = 45
local byte_asterisk <const> = 42
local byte_slash <const> = 47
local byte_caret <const> = 94

local byte_percent <const> = 37

local byte_amp <const> = 38
local byte_pipe <const> = 124
local byte_tilde <const> = 126

local byte_hashtag <const> = 35


local byte_double_quote <const> = 34 -- "
local byte_single_quote <const> = 39 -- '

--string.byte("(){}[]", 1, -1)
local byte_open_bracket <const> = 40
local byte_close_bracket <const> = 41
local byte_open_curly_bracket <const> = 123
local byte_close_curly_bracket <const> = 125
local byte_open_square_bracket <const> = 91
local byte_close_square_bracket <const> = 93

local byte_period <const> = 46 -- .
local byte_comma <const> = 44 -- ,
local byte_semicolon <const> = 59 -- ;
local byte_colon <const> = 58 -- :


local byte_exclaimation <const> = 33 -- !

local byte_backslash <const> = 92 -- \


local const <const> = {string.byte("<const>", 1, -1)}
local function isConstToken(arr, index)
    for i=1,#const do
        if arr[index + i - 1] ~= const[i] then
            return false
        end
    end
    return true
end


local function isAlpha(byte)
    return (byte_A <= byte and byte <= byte_Z)
        or (byte_a <= byte and byte <= byte_z)
end

local function isNum(byte)
    return (byte_0 <= byte and byte <= byte_9)
end

local function isAlphaNum(byte)
    return isAlpha(byte)
        or isNum(byte)
        or byte == byte_underscore

        -- or byte == byte_at
end

local function isWhitespace(byte)
    return byte == byte_space or byte == byte_tab or byte == byte_ANSIn or byte == byte_ANSIr
end

local function isOperatorSymbol(byte)
    return byte == byte_lt or byte == byte_eq or byte == byte_gt
        or byte == byte_plus or byte == byte_minus or byte == byte_asterisk
        or byte == byte_slash or byte == byte_caret or byte == byte_percent
        or byte == byte_amp or byte == byte_pipe or byte == byte_tilde
        or byte == byte_hashtag
end

local function isBracket(byte)
    return byte == byte_open_bracket or byte == byte_close_bracket
        or byte == byte_open_curly_bracket or byte == byte_close_curly_bracket
        or byte == byte_open_square_bracket or byte == byte_close_square_bracket
end

local function findUnescapedEndQuote(str, quote)
    local escapeCount = 0
    --skip first char
    for i=2, #str do
        local char <const> = str:sub(i,i)
        if char == '\\' then
            escapeCount = escapeCount + 1
        elseif char == quote then
            if escapeCount % 2 == 0 then
                return i
            else escapeCount = 0 end
        else
            escapeCount = 0
        end
    end
    return nil
end

local TokenProducer = {}
TokenProducer.metatable = {__index = TokenProducer, __metatable = nil}

local Tokens = {
    LINEFEED = "<lf>",
    EOF = "<eof>",

    NUMBER = "number",
    WORD = "word",
    STRING = "string",
    MULTILINE_STRING = "string_multiline",

    OPERATOR = "operator",
    BRACKET = "bracket",
    
    PERIOD = "period",
    DELIMITER = "delimiter",
    
    SPECIAL_KEYWORD = "special_keyword",

    COMMENT = "comment",
    MULTILINE_COMMENT = "comment_multiline",

    VARARGS = "varargs",

    MACRO = "macro",
    SPECIAL = "special",
    RAW = "raw",
    UNKNOWN = "unknown"
}

TokenProducer.Tokens = Tokens


local ERR_CLOSED <const> = "This TokenProducer is closed!"

function TokenProducer.new(file)
    local producer = {}
    producer.file = file
    producer.lines = file:lines()
    producer.lineIndexDebug = 0

    producer.currentLine = nil
    producer.currentLineBytes = nil

    producer.linePos = 0
    producer.closed = false

    setmetatable(producer, TokenProducer.metatable)

    return producer
end

-- current lines and columns
function TokenProducer:GetPositionString()
    return tostring(self.lineIndexDebug + 1) .. ":" .. tostring(self.linePos)
end

function TokenProducer:ReadLine()
    if self.closed then error(ERR_CLOSED) end
    self.linePos = self.linePos + 1
    local line = self.currentLine:sub(self.linePos)
    self.linePos = #self.currentLine
    return line
end

function TokenProducer:AssertLine()
    if self.currentLine == nil then
        local line = self.lines()
        if line == nil then
            return false
        end
        self.currentLine = line
        self.currentLineBytes = {line:byte(1, -1)}
    end
    return true
end

function TokenProducer:NextLine()
    if self.closed then error(ERR_CLOSED) end
    local line = self.lines()
    if line == nil then
        return false
    end
    self.currentLine = line
    self.currentLineBytes = {line:byte(1, -1)}
    self.linePos = 0
    self.lineIndexDebug = self.lineIndexDebug + 1
    return true
end

function TokenProducer:Close()
    self.closed = true
    
    self.file = nil
    self.lines = nil
    self.currentLine = nil
    self.currentLineBytes = nil
    self.linePos = nil
end


function TokenProducer:ReadMultiline()
    local line = self.currentLine

    local errPos = self:GetPositionString()

    local n = 1
    local stringLines = {}

    while line ~= nil do
        local i, j = string.find(line, "]]", self.linePos)

        if j ~= nil then
            stringLines[n] = string.sub(line, self.linePos, j)
            self.linePos = j
            return table.concat(stringLines, "\r\n")
        end
        
        stringLines[n] = string.sub(line, self.linePos, -1)
        n = n + 1

        self:NextLine()
        line = self.currentLine
    end

    self:Close()
    error("Missing closing ]] for the [[ at " .. errPos)
end

function TokenProducer:ReadLineEscapedString(quote)
    -- the end of a line can be escaped with a backslash in a string
    local str = {self.currentLine:sub(self.linePos)}

    while self.currentLineBytes[#self.currentLineBytes] == byte_backslash and self:NextLine() do
        j = findUnescapedEndQuote(self.currentLine)
        if j == nil then
            table.insert(str, self.currentLine)
        else
            self.linePos = j
            table.insert(str, self.currentLine:sub(1, j))
            return table.concat(str, "\n"), Tokens.STRING
        end
    end
end

function TokenProducer:ReadLinefeed()
    if self:NextLine() then
        return Tokens.LINEFEED, Tokens.LINEFEED
    else
        self:Close()
        return Tokens.EOF, Tokens.EOF
    end
end

function TokenProducer:ReadToken()
    if self.closed then error(ERR_CLOSED) end
    if not self:AssertLine() then
        self:Close()
        return Tokens.EOF, Tokens.EOF
    end
    local line = self.currentLine
    if self.linePos >= #line then
        return self:ReadLinefeed()
    end

    -- the C here is almost certainly faster than any lua I could write
    local index = string.find(line, "%S", self.linePos + 1)

    --handle end of line
    if index == nil then
        self.linePos = self.linePos + 1
        return self:ReadLinefeed()
    end
    
    self.linePos = index
    local char = self.currentLineBytes[index]

    --handle numbers
    if isNum(char) then
        local f = false
        local _i, _j;
        if char == byte_0 then
            local nextChar = self.currentLineBytes[index + 1]
            if nextChar == byte_x or nextChar == byte_X then
                -- no periods in hex numbers
                _i, _j = string.find(line, "%dx[0-9a-fA-F]*", index)
                f = true
            end
        end

        if f == false then
            _i, _j = string.find(line, "%d[0-9.]*", index)
        end
        
        self.linePos = _j
        return string.sub(line, _i, _j), Tokens.NUMBER
    end

    --handle words
    if isAlphaNum(char) or char == byte_at or char == byte_exclaimation then
        local _, _j = string.find(line, pattern_alphanum, index)
        self.linePos = _j
        local token = Tokens.WORD
        if char == byte_at then
            token = Tokens.MACRO
        elseif char == byte_exclaimation then
            token = Tokens.SPECIAL
        end

        return string.sub(line, index, _j), token
    end
    
    --handle strings
    if char == byte_double_quote or char == byte_single_quote then
        local quote;
        if char == byte_double_quote then
            quote = '"'
        else
            quote = "'"
        end
        
        local j = findUnescapedEndQuote(line:sub(index), quote)
        if j == nil then
            local errPos <const> = self:GetPositionString()

            if self.currentLineBytes[#self.currentLineBytes] == byte_backslash then
                return self:ReadLineEscapedString(quote)
            end

            self:Close()
            error("Invalid syntax! Missing closing quote at " .. errPos)
        end
        j = (index - 1) + j

        self.linePos = j
        return line:sub(index, j), Tokens.STRING
    end

    local nextChar = self.currentLineBytes[index + 1]

    --handle concat
    if char == byte_period then -- .
        if nextChar == byte_period then -- ..
            if self.currentLineBytes[index + 2] == byte_period then -- ...
                self.linePos = index + 2 --mark the next 2 bytes as read
                return "...", Tokens.VARARGS
            end

            self.linePos = index + 1 --mark the next byte as read
            return "..", Tokens.OPERATOR
        end
        return ".", Tokens.PERIOD
    end

    --handle object functions
    if char == byte_colon then
        --handle goto labels
        if nextChar == byte_colon then
            local _, j = line:find("::", index + 2)
            if j == nil then 
                self:Close()
                error("Invalid syntax! Missing closing :: at " .. self:GetPositionString())
            end
            return line:sub(index, j), Tokens.GOTO_LABEL
        end
        return ":", Tokens.PERIOD
    end

    --handle comments
    if char == byte_minus and nextChar == byte_minus then
        --handle multiline comments
        if self.currentLineBytes[index + 2] == byte_open_square_bracket and self.currentLineBytes[index + 3] == byte_open_square_bracket then
            return self:ReadMultiline(), Tokens.MULTILINE_COMMENT
        end
        self.linePos = #line --skip the rest of this line
        return line:sub(index), Tokens.COMMENT
    end

    local _char = string.char(char)

    --handle operators like + and ==
    if isOperatorSymbol(char) then
        if isConstToken(self.currentLineBytes, index) then
            self.linePos = index + 6 --mark the next 6 byte as read
            return "<const>", Tokens.SPECIAL_KEYWORD
        end
        if isOperatorSymbol(nextChar) then
            self.linePos = index + 1 --mark the next byte as read
            return string.char(char, nextChar), Tokens.OPERATOR
        end
        return _char, Tokens.OPERATOR
    end

    --handle multiline strings
    if char == byte_open_square_bracket and nextChar == byte_open_square_bracket then
        return self:ReadMultiline(), Tokens.MULTILINE_STRING
    end

    if isBracket(char) then
        return _char, Tokens.BRACKET
    end

    if char == byte_comma or char == byte_semicolon then
        return _char, Tokens.DELIMITER
    end

    return _char, Tokens.UNKNOWN
end

function TokenProducer:ReadRealToken()
    local token, tokenType = self:ReadToken()

    while token == Tokens.LINEFEED do
        token, tokenType = self:ReadToken()
    end
    
    return token, tokenType
end

return TokenProducer
