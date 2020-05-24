
local new = typesys.new

local _API_STATUS_PENDING = 1
local _API_STATUS_EXECUTING = 2
local _API_STATUS_DEAD = 3

------- [代码区段开始] API接口类 --------->
IGameAPI = typesys.def.IGameAPI {
    __pool_capacity = -1,
    __strong_pool = true,
    status = 0,
    post_time = 0,
}

function IGameAPI:execute()
    assert(false)
end

function IGameAPI:getReturn()
    assert(false)
end
------- [代码区段结束] API接口类 ---------<

local function _getAPIToken(self)
    return self.__id
end

--[[
API调度器接口描述，作为API实现的访问入口，负责隐藏API实现和执行的细节
--]]
GameAPIDispatcher = typesys.def.GameAPIDispatcher {__super = IScriptAPIDispatcher,
    __pool_capacity = -1,
    __strong_pool = true,
    weak__script_sys = ScriptSystem,
    _api_map = typesys.map, -- 示例中无限存储，实际中应该要设计销毁机制
    _api_token_list = typesys.array,
    _time = 0, -- 记录时间
}

function GameAPIDispatcher:__ctor(script_sys)
    self._script_sys = script_sys
    self._api_map = new(typesys.map, type(0), IGameAPI)
    self._api_token_list = new(typesys.array, type(0))
end

function GameAPIDispatcher:__dtor()
end

function GameAPIDispatcher:tick(time, delta_time)
    self._time = time

    local api_map = self._api_map
    local api_token_list = self._api_token_list
    for i=1, api_token_list:size() do
        local api_token = api_token_list:get(i)
        local api_obj = api_map:get(api_token)
        if nil ~= api_obj then
            api_obj.status = _API_STATUS_EXECUTING
            api_obj:execute()
            api_obj.status = _API_STATUS_DEAD

            self._script_sys:sendSig_API(api_token)
        end
    end

    api_token_list:clear()
end

function GameAPIDispatcher:postAPI(api_name, api_class, ...)
    -- 先缓存api，api通过tick来按顺序执行
    local api_obj = new(api_class, ...)
    local api_token = _getAPIToken(api_obj)
    self._api_map:set(api_token, api_obj)
    self._api_token_list:pushBack(api_token)

    api_obj.status = _API_STATUS_PENDING
    api_obj.post_time = self._time
    return api_token
end

function GameAPIDispatcher:apiIsPending(api_token)
    local api_obj = self._api_map:get(api_token)
	return nil ~= api_obj and _API_STATUS_PENDING == api_obj.status
end
function GameAPIDispatcher:apiIsExecuting(api_token)
	local api_obj = self._api_map:get(api_token)
    return nil ~= api_obj and _API_STATUS_EXECUTING == api_obj.status
end
function GameAPIDispatcher:apiIsDead(api_token)
	local api_obj = self._api_map:get(api_token)
    return nil == api_obj or _API_STATUS_DEAD == api_obj.status
end
function GameAPIDispatcher:apiDiedOfInterruption(api_token)
	return false -- 示例API没有打断
end
function GameAPIDispatcher:apiGetReturn(api_token)
	local api_obj = self._api_map:get(api_token)
    if nil ~= api_obj then
        return api_obj:getReturn()
    end
    return nil
end
function GameAPIDispatcher:apiGetTimeSpent(api_token)
	local api_obj = self._api_map:get(api_token)
    if nil ~= api_obj then
        return self._time - api_obj.post_time
    end
    return -1
end
function GameAPIDispatcher:apiAbort(api_token)
	-- 示例API没有打断
end


