
local Stream = {}
Stream.metatable = {__index = Stream, __metatable = nil}

function Stream.new(obj)
    local stream = obj or {} --so stuff like :Read can be overridden

    stream.n = 0
    stream.data = {}
    stream.pos = 0
    
    stream.un = 0 --unshifted n
    stream.udata = {} --unshifted data

    setmetatable(stream, Stream.metatable)

    return stream
end

--- Returns a boolean indicating if it was successful or not
function Stream:_write(obj)
    local n = self.n + 1
    self.n = n

    self.data[n] = obj
    return true
end

--- so :Write() can be overridden 
function Stream:Write(obj)
    return self:_write(obj)
end

function Stream:WriteAll(...)
    local n = select("#", ...)
    local args = {...}
    for i=1,n do
        self:Write(args[i])
    end
    return n > 0
end

function Stream:_unshift(obj)
    local un = self.un + 1
    self.un = un

    self.udata[un] = obj
end

--- so :Unshift() can be overridden 
function Stream:Unshift(obj)
    return self:_unshift(obj)
end

function Stream:UnshiftAll(...)
    local n = select("#", ...)
    local args = {...}
    for i=n,1,-1 do
        self:Unshift(args[i])
    end
    return n > 0
end

function Stream:_read()
    --handle any unshifted data
    local un <const> = self.un
    if un > 0 then
        local data = self.udata[un]
        self.udata[un] = nil
        self.un = un - 1
        return data
    end

    --handle normal data
    local pos = self.pos + 1
    if pos > self.n then
        return nil
    end

    self.pos = pos

    local data = self.data[pos]
    self.data[pos] = nil

    return data
end

--- so :Read() can be overridden 
function Stream:Read()
    return self:_read()
end

function Stream:ReadAll()
    local datas = {}
    local n = 0
    -- print("ReadAll:", self.un, self.n - self.pos)
    while self:Remaining() > 0 do
        n = n + 1
        datas[n] = self:Read()
    end
    return datas, n
end

function Stream:Remaining()
    return self.un + (self.n - self.pos)
end


--gets the next piece of data without consuming it
function Stream:_next()
    --handle any unshifted data
    local un <const> = self.un
    if un > 0 then
        local data = self.udata[un]
        self.udata[un] = nil
        return data
    end

    --handle normal data
    local pos = self.pos + 1
    if pos > self.n then
        return nil
    end

    return self.data[pos]
end

function Stream:Next()
    return self:_next()
end


return Stream