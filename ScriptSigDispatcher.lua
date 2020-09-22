
local new = typesys.new

local function _friendCall(self, func_name, ...)
	return self[func_name](self, ...)
end

--[[
脚本信号调度器，负责存储脚本所关注的各类信号逻辑，执行派发信号的逻辑
因为脚本是以sleep方式来等待信号的，那么一个脚本只可能在一次sleep里等待一个信号逻辑
信号逻辑分为
	1. API信号
	2. 计时信号
	3. 条件信号
	4. 事件信号
--]]
ScriptSigDispatcher = typesys.def.ScriptSigDispatcher {__super = IScriptSigDispatcher,
	__pool_capacity = -1,
	__strong_pool = true,
	weak__script_manager = IScriptManager,
	_script_listen_map = typesys.map, -- bug:强引用管理，但是创建却不是在本类
	_sigs_cache = typesys.map, 
}

function ScriptSigDispatcher:__ctor()
	self._script_listen_map = new(typesys.map, type(0), IScriptSigLogic, true) -- weak ref
	self._sigs_cache = new(typesys.map, type(""), type(true))
end

function ScriptSigDispatcher:__dtor()
	
end

local temp_script_listen_map = {} -- 临时table
-- tick的逻辑已经保证了触发_scriptOnSig（执行离开本对象）时，已经完成了对_script_sig_logic和_sigs_cache的使用
function ScriptSigDispatcher:tick(time, delta_time)
	local sigs_set = self._sigs_cache

	assert(nil == next(temp_script_listen_map)) -- 确保临时table为空

	local script_manager = self._script_manager
	local script_listen_map = self._script_listen_map

	-- 找到需要触发信号的脚本
	for script_token, sig_logic in script_listen_map:pairs() do
		local script = _friendCall(script_manager, "_getScriptListeningSig", script_token)

		if nil ~= script then
			local triggered = false
			if sig_logic:checkTimeOut(time, delta_time) then
				sig_logic.is_time_out = true
				triggered = true
			elseif sig_logic:check(sigs_set) then
				triggered = true
			end
			if triggered then
				-- 信号逻辑触发成功，先将脚本移除
				script_listen_map:set(script_token, nil)
				-- 将需要触发信号的脚本记录到临时table中
				temp_script_listen_map[script] = sig_logic
			end
		else
			-- 脚本已经不存在了
			script_listen_map:set(script_token, nil)
		end
	end

	-- 清空信号缓存
	self._sigs_cache:clear()

	-- 遍历触发信号
	for script, sig_logic in pairs(temp_script_listen_map) do
		-- 将触发信号的脚本从临时table中移除
		temp_script_listen_map[script] = nil 
		-- 触发信号
		_friendCall(script_manager, "_scriptOnSig", script, sig_logic)
	end
end

-- 发送信号
function ScriptSigDispatcher:sendSig(sig)
	-- 先缓存信号，信号通过tick来派发
	self._sigs_cache:set(sig, true)
end

------- [代码区段开始] 提供给ScriptManager使用的函数 --------->
function ScriptSigDispatcher:_setScriptManager(script_manager)
	self._script_manager = script_manager
end
-- 监听信号
function ScriptSigDispatcher:_listenSig(script_token, sig_logic)
	self._script_listen_map:set(script_token, sig_logic)
end

-- 取消监听
function ScriptSigDispatcher:_unlistenSig(script_token)
	self._script_listen_map:set(script_token, nil)
end
------- [代码区段结束] 提供给ScriptManager使用的函数 ---------<



