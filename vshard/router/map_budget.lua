local function prepare(args, remaining, position)
    if position == nil then
        return args
    end
    assert(type(position) == 'number' and position >= 1 and
           position % 1 == 0)
    local result = {}
    for key, value in pairs(args or {}) do
        result[key] = value
    end
    result[position] = remaining
    return result
end

return {prepare = prepare}
