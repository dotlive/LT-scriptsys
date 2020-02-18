
local function _log(...) print("[ScriptAPIManager]", ...) end
local assert = assert

local new = typesys.new

------- [代码区段开始] API代理 --------->

local _api_proxy_mt = {
	__call = function(proxy, ...)
		-- return api_token
		return proxy.api_manager:_callAPI(proxy.api_name, proxy.api_info, ...)
	end
}

local _built_in_api_proxy_mt = {
	__call = function(proxy, ...)
		return proxy.api(proxy.api_manager, ...)
	end
}

------- [代码区段结束] API代理 ---------<

local _built_in_apis = {} -- 在代码最后面会填充此表格

--[[
管理注册的api接口，负责对其调用进行包装

脚本使用的方式有：
1. 调用API，返回API访问器：						xxx(...) 						-- return api_token
2. API访问器的使用：	 
	1. 查询是否在未执行状态：					apiIsPending(api_token)			-- return true or false
	2. 查询是否在执行状态：						apiIsExecuting(api_token)		-- return true or false
	3. 查询是否在结束状态：						apiIsDead(api_token)			-- return true or false
	4. 查询是否被打断：						apiIsInterrupted(api_token)		-- return true or false
	5. 获取调用结果：							apiGetReturn(api_token)  		-- return result or nil
	6. 查询调用经过了多少时间：					apiGetTimeSpent(api_token)  	-- return time spent
	7. 等待完成（time_out不为正数则无限等待）：	apiWait(api_token, time_out) 	-- return nil
	8. 强制打断：								apiAbort(api_token) 			-- return nil
3. 延迟时间：									delay(time)						-- return nil
4. 等待条件：									waitCondition(condition)		-- return nil
5. 等待信号：									waitSignal(sig_logic)			-- return nil

组合使用方式举例：
apiWait(xxx(...), time_out)
--]]
ScriptAPIManager = typesys.ScriptAPIManager{
	__pool_capacity = -1,
	__strong_pool = true,
	_api_proxy_map = typesys.unmanaged,
	_script_api_space = typesys.unmanaged,
	weak__api_dispatcher = IScriptAPIDispatcher,
}

function ScriptAPIManager:ctor(api_dispatcher)
	self._api_proxy_map = {}
	self._script_api_space = setmetatable({
		-- 如果想要为script提供一些算法或系统函数支持，在此处添加
	}, {__index = self._api_proxy_map, __newindex = function() error("read only") end})

	self._api_dispatcher = api_dispatcher

	self:_registerBuiltInAPI()
end

function ScriptAPIManager:getAPISpace()
	return self._script_api_space
end

-- 通过此接口注册的API，将通过API调度器进行调度管理
function ScriptAPIManager:registerAPI(api_map)
	local api_proxy_map = self._api_proxy_map

	for api_name, api_info in pairs(api_map) do
		assert(nil == _built_in_apis[api_name]) -- 禁止使用内建api名
		api_proxy_map[api_name] = setmetatable({api_manager = self, api_name = api_name, api_info = api_info}, _api_proxy_mt)
	end
end

-- 通过此接口注册的API，将被直接调用，请慎用
--[[
api_map创建方式示例：
local AssistAPI = {}
function AssistAPI.xxx()

end
function AssistAPI.yyy()
	
end
--]]
function ScriptAPIManager:registerAssistAPI(api_map)
	local api_proxy_map = self._api_proxy_map

	for api_name, api in pairs(api_map) do
		assert(nil == _built_in_apis[api_name]) -- 禁止使用内建api名
		if "function" == type(api) then
			api_proxy_map[api_name] = api
		end
	end
end

function ScriptAPIManager:_registerBuiltInAPI()
	local api_proxy_map = self._api_proxy_map

	for api_name, api in pairs(_built_in_apis) do
		api_proxy_map[api_name] = setmetatable({api_manager = self, api = api}, _built_in_api_proxy_mt)
	end
end

-- return api_token
function ScriptAPIManager:_callAPI(api_name, api_info, ... )
	return self._api_dispatcher:postAPI(api_name, api_info, ...)
end

------- [代码区段开始] 内建API --------->
-- 内建API必须要以_built_in_作为前缀，以便注册时能够遍历到
function ScriptAPIManager:_built_in_apiIsPending(api_token)
	return self._api_dispatcher:apiIsPending(api_token)
end
function ScriptAPIManager:_built_in_apiIsExecuting(api_token)
	return self._api_dispatcher:apiIsExecuting(api_token)
end
function ScriptAPIManager:_built_in_apiIsDead(api_token)
	return self._api_dispatcher:apiIsDead(api_token)
end
function ScriptAPIManager:_built_in_apiIsInterrupted(api_token)
	return self._api_dispatcher:apiIsInterrupted(api_token)
end
function ScriptAPIManager:_built_in_apiGetReturn(api_token)
	return self._api_dispatcher:apiGetReturn(api_token)
end
function ScriptAPIManager:_built_in_apiGetTimeSpent(api_token)
	return self._api_dispatcher:apiGetTimeSpent(api_token)
end
function ScriptAPIManager:_built_in_apiWait(api_token, time_out)
	-- todo
end
function ScriptAPIManager:_built_in_apiAbort(api_token)
	self._api_dispatcher:apiAbort(api_token)
end
function ScriptAPIManager:_built_in_delay()
	-- todo
end
function ScriptAPIManager:_built_in_waitCondition()
	-- todo
end
function ScriptAPIManager:_built_in_waitSignal()
	-- todo
end

-- 注册内建API
for k, v in pairs(ScriptAPIManager) do
	if "function" == type(v) then
		local api_name = k:match("^_built_in_(.+)")
		if api_name then
			_log("built in api:", api_name)
			_built_in_apis[api_name] = v
		end
	end
end
------- [代码区段结束] 内建API --------->
