local fiber = require('fiber')
local status = require('vshard.consts').BUCKET

local KEY = 'vshard.call_context'

local function get()
    return fiber.self().storage[KEY]
end

local function new(mode, bucket_id)
    local active = true
    local context = {mode = mode}
    function context:contains(candidate_id)
        if not active then
            error('vshard call context is no longer active')
        end
        if mode == 'bucket' then
            return candidate_id == bucket_id
        end
        local bucket = box.space._bucket:get{candidate_id}
        return bucket ~= nil and (bucket.status == status.ACTIVE or
                                  bucket.status == status.PINNED)
    end
    function context:bucket_ids(max_count)
        if not active then
            error('vshard call context is no longer active')
        end
        if type(max_count) ~= 'number' or max_count < 1 or
           max_count % 1 ~= 0 then
            error('bucket_ids requires a positive integer bound')
        end
        if mode == 'bucket' then
            return {bucket_id}
        end
        local result = {}
        for _, state in ipairs({status.ACTIVE, status.PINNED}) do
            for _, bucket in box.space._bucket.index.status:pairs(
                    {state}, {iterator = 'EQ'}) do
                if #result == max_count then
                    error('vshard call context bucket bound exceeded')
                end
                result[#result + 1] = bucket.id
            end
        end
        return result
    end
    function context:_deactivate()
        active = false
    end
    return context
end

local function enter(context)
    local storage = fiber.self().storage
    local previous = storage[KEY]
    storage[KEY] = context
    return previous
end

local function leave(context, previous)
    context:_deactivate()
    fiber.self().storage[KEY] = previous
end

return {
    get = get,
    new = new,
    enter = enter,
    leave = leave,
}
