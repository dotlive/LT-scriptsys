
require('io')

local sleep_map = {}
local function _sleep(seconds)
    local str = sleep_map[seconds]
    if nil == str then
        str = 'sleep '..seconds
        sleep_map[seconds] = str
    end
    os.execute(str)
end

package.path = package.path ..';../?.lua;../../lua-typesys/Refactory/?.lua'
package.path = package.path ..';../../lua-typesys/Refactory/PlantUML/?.lua'

require("TypeSystemHeader")
require("ScriptSystemHeader")
require("APIDispatcherSample")
require("APISample")

-- 输出UML类图
require("TypesysPlantUML")
local toPlantUMLSucceed = typesys.tools.toPlantUML("scriptsys.puml")
print("to plantuml: "..tostring(toPlantUMLSucceed).."\n")

local new = typesys.new
local gc = typesys.gc
local setRootObject = typesys.setRootObject

-- 初始化
local script_sys = new(ScriptSystem, APIDispatcherSample)
setRootObject(script_sys)

script_sys:registerAPI(APIMapSample)
script_sys:registerAssistAPI(AssistAPIMapSample)

-- 加载
local script_token = script_sys:loadScript("ScriptSample")

-- 执行
script_sys:runScript(script_token)

-- 帧循环
repeat
    print("[main] time: ", g_time)
    -- script_sys:abortScript(script_token)
    script_sys:tick(g_time, g_delta_time)
    -- script_sys:abortScript(script_token)
    g_time = g_time + g_delta_time
    _sleep(1)

    -- 随机触发事件
    local r = math.random(1, 5)
    if 1 == r then
        script_sys:sendSig_Event("event_1")
    elseif 2 == r then
        script_sys:sendSig_Event("event_2")
    end

    gc()
until not script_sys:scriptIsRunning(script_token)

-- 释放
setRootObject(nil)
script_sys = nil



