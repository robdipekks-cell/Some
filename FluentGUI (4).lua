-- // Fluent GUI Script

local Fluent            = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP   = Players.LocalPlayer
local LPN  = LP.Name

-- =============================================
-- HELPERS
-- =============================================

local function GetMyPlot()
    for _, plot in ipairs(workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren()) do
        local a = plot:FindFirstChild("Assigned")
        if a and a.Value and a.Value.Name == LPN then return plot end
    end
    return nil
end

local function GetPlacements(plot)
    local list = {}
    if not plot then return list end
    local f = plot:FindFirstChild("Placements")
    if not f then return list end
    for i = 1, 50 do
        local p = f:FindFirstChild("Placement"..i)
        if p then table.insert(list, p) end
    end
    return list
end

local function TeleportTo(cf)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cf end
end

local function GoToMyPlot()
    local plot = GetMyPlot()
    if not plot then return end
    local base = plot.PrimaryPart
    if not base then
        for _, v in ipairs(plot:GetDescendants()) do
            if v:IsA("BasePart") then base = v break end
        end
    end
    if base then TeleportTo(base.CFrame * CFrame.new(0, 6, 0)) end
end

-- Manual carry override (set by user in each farm tab input)
local manualCarry = {}   -- [zoneKey] = number

local function GetCarryMax(zoneKey)
    -- Manual override takes priority
    if manualCarry[zoneKey] and manualCarry[zoneKey] > 0 then
        return manualCarry[zoneKey]
    end
    -- Try to read from PlayerStats
    local stats = LP:FindFirstChild("PlayerStats")
    if stats then
        -- Try common paths
        local paths = {"Carry","CarryLimit","MaxCarry"}
        for _, name in ipairs(paths) do
            local c = stats:FindFirstChild(name)
            if c and c.Value and c.Value > 0 then return c.Value end
        end
        -- Deep search any IntValue/NumberValue with "carry" in name
        for _, v in ipairs(stats:GetDescendants()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and string.lower(v.Name):find("carry") then
                if v.Value and v.Value > 0 then return v.Value end
            end
        end
    end
    return 9999 -- fallback: never stop early if we can't read carry
end

-- =============================================
-- FAST GRAB FUNCTION
-- =============================================

local ZONE_ORDER = {
    "CommonZone","UncommonZone","RareZone","ToxicZone",
    "LegendaryZone","MythicalZone","OgZone","SecretZone","ExoticZone",
}

-- Grab a specific hacker by name. zoneKey = nil means search all zones.
-- Returns true on success.
local function GrabByName(hackerName, zoneKey)
    local zonesFolder = workspace:WaitForChild("Map"):WaitForChild("Zones")
    local search = zoneKey and {zoneKey} or ZONE_ORDER

    for _, zk in ipairs(search) do
        local zf = zonesFolder:FindFirstChild(zk)
        if not zf then continue end
        local ct = zf:FindFirstChild("Container")
        if not ct then continue end

        for _, cell in ipairs(ct:GetChildren()) do
            if not string.find(cell.Name, "PrisonCell") then continue end
            local hModel = cell:FindFirstChild(hackerName)
            if not hModel then continue end
            local hRoot  = hModel:FindFirstChild("HumanoidRootPart")
            if not hRoot then continue end
            local unban  = hRoot:FindFirstChild("UnbanPrompt")
            if not unban then continue end

            -- TP 5 below → unban (fast)
            TeleportTo(hRoot.CFrame * CFrame.new(0, -5, 0))
            task.wait(0.15)
            pcall(function() fireproximityprompt(unban) end)
            task.wait(0.6)

            -- Poll HackerDebris fast (max 4s)
            local debrisFolder = workspace:FindFirstChild("HackerDebris")
            local pickup, dRoot = nil, nil
            if debrisFolder then
                for _ = 1, 40 do
                    local dh = debrisFolder:FindFirstChild(hackerName)
                    if dh then
                        dRoot = dh:FindFirstChild("HumanoidRootPart")
                        if dRoot then
                            pickup = dRoot:FindFirstChild("PickupPrompt")
                            if pickup then break end
                        end
                    end
                    task.wait(0.1)
                end
            end

            if pickup and dRoot then
                TeleportTo(dRoot.CFrame * CFrame.new(0, -5, 0))
                task.wait(0.15)
                pcall(function() fireproximityprompt(pickup) end)
                task.wait(0.4)
                return true
            end
            return false -- unban fired but debris never showed
        end
    end
    return false
end

-- Grab ANY hacker in a zone by scanning cells directly (no name list needed)
-- Returns hackerName on success, nil if nothing found
local function GrabAnyInZone(zoneKey)
    local zonesFolder = workspace:WaitForChild("Map"):WaitForChild("Zones")
    local zf = zonesFolder:FindFirstChild(zoneKey)
    if not zf then return nil end
    local ct = zf:FindFirstChild("Container")
    if not ct then return nil end

    for _, cell in ipairs(ct:GetChildren()) do
        if not string.find(cell.Name, "PrisonCell") then continue end
        for _, child in ipairs(cell:GetChildren()) do
            -- Any model inside a PrisonCell that has HumanoidRootPart + UnbanPrompt = jailed hacker
            if not child:IsA("Model") then continue end
            local hRoot = child:FindFirstChild("HumanoidRootPart")
            if not hRoot then continue end
            local unban = hRoot:FindFirstChild("UnbanPrompt")
            if not unban then continue end

            local hackerName = child.Name

            TeleportTo(hRoot.CFrame * CFrame.new(0, -5, 0))
            task.wait(0.15)
            pcall(function() fireproximityprompt(unban) end)
            task.wait(0.6)

            local debrisFolder = workspace:FindFirstChild("HackerDebris")
            local pickup, dRoot = nil, nil
            if debrisFolder then
                for _ = 1, 40 do
                    local dh = debrisFolder:FindFirstChild(hackerName)
                    if dh then
                        dRoot = dh:FindFirstChild("HumanoidRootPart")
                        if dRoot then
                            pickup = dRoot:FindFirstChild("PickupPrompt")
                            if pickup then break end
                        end
                    end
                    task.wait(0.1)
                end
            end

            if pickup and dRoot then
                TeleportTo(dRoot.CFrame * CFrame.new(0, -5, 0))
                task.wait(0.15)
                pcall(function() fireproximityprompt(pickup) end)
                task.wait(0.4)
                return hackerName
            end
        end
    end
    return nil
end

-- Count jailed hackers in a zone
local function CountJailedInZone(zoneKey)
    local zonesFolder = workspace:WaitForChild("Map"):WaitForChild("Zones")
    local zf = zonesFolder:FindFirstChild(zoneKey)
    if not zf then return 0 end
    local ct = zf:FindFirstChild("Container")
    if not ct then return 0 end
    local count = 0
    for _, cell in ipairs(ct:GetChildren()) do
        if not string.find(cell.Name, "PrisonCell") then continue end
        for _, child in ipairs(cell:GetChildren()) do
            if child:IsA("Model") then
                local hRoot = child:FindFirstChild("HumanoidRootPart")
                if hRoot and hRoot:FindFirstChild("UnbanPrompt") then
                    count += 1
                end
            end
        end
    end
    return count
end

-- =============================================
-- WINDOW
-- =============================================

local Window = Fluent:CreateWindow({
    Title       = "Script Hub",
    SubTitle    = "by "..LPN,
    TabWidth    = 130,
    Size        = UDim2.fromOffset(620, 500),
    Acrylic     = true,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

-- =============================================
-- TAB: MAIN
-- =============================================
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local autoCollectOn = false

MainTab:AddToggle("AutoCollect", {
    Title = "Auto Collect", Description = "Claim money from all placements.",
    Default = false,
    Callback = function(state)
        autoCollectOn = state
        if not state then return end
        task.spawn(function()
            while autoCollectOn do
                local plot = GetMyPlot()
                if plot then
                    for _, p in ipairs(GetPlacements(plot)) do
                        local btn = p:FindFirstChild("Button")
                        if btn then pcall(function() ReplicatedStorage.RemoteEvents.Server.ClaimMoney:FireServer(btn) end) end
                    end
                end
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- TAB: UPGRADES
-- =============================================
local UpgradesTab = Window:AddTab({ Title = "Upgrades", Icon = "trending-up" })
local upgradeAmt = 1; local upgradeAllOn = false; local upgradeSingleOn = false
local IGNORED = {Button=true,Podium=true,UpgradeScreen=true}

UpgradesTab:AddInput("UpgrAmt", {
    Title="Upgrade Amount", Default="1", Placeholder="Number...", Numeric=true, Finished=false,
    Callback=function(v) upgradeAmt = tonumber(v) or 1 end,
})

UpgradesTab:AddToggle("UpgradeAll", {
    Title="Upgrade All", Default=false,
    Callback=function(state)
        upgradeAllOn = state
        if not state then return end
        task.spawn(function()
            while upgradeAllOn do
                local plot = GetMyPlot()
                if plot then
                    for _, p in ipairs(GetPlacements(plot)) do
                        pcall(function() ReplicatedStorage.RemoteEvents.Server.Upgrade:InvokeServer(p,"Upgrade",upgradeAmt) end)
                        task.wait(0.05)
                    end
                end
                task.wait(0.5)
            end
        end)
    end,
})

local upgradeMap = {}
local function BuildUpgrOpts()
    local opts = {}; upgradeMap = {}
    local plot = GetMyPlot()
    if not plot then return {"Waiting for plot..."} end
    for _, p in ipairs(GetPlacements(plot)) do
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Model") and not IGNORED[c.Name] then
                local lbl = upgradeMap[c.Name] and (c.Name.." ("..p.Name..")") or c.Name
                upgradeMap[lbl] = p
                table.insert(opts, lbl)
                break
            end
        end
    end
    return #opts > 0 and opts or {"No placements found"}
end

local upgradeOpts = BuildUpgrOpts()
local selUpgrade = upgradeOpts[1]
local UpgrDrop = UpgradesTab:AddDropdown("UpgrDrop", {
    Title="Select Placement", Values=upgradeOpts, Multi=false, Default=upgradeOpts[1],
    Callback=function(v) selUpgrade = v end,
})

UpgradesTab:AddButton({ Title="Refresh List", Callback=function()
    local o = BuildUpgrOpts(); UpgrDrop:SetValues(o); selUpgrade = o[1]
    Fluent:Notify({Title="Refreshed", Content="List updated.", Duration=2})
end})

UpgradesTab:AddToggle("UpgradeSingle", {
    Title="Upgrade (Single)", Default=false,
    Callback=function(state)
        upgradeSingleOn = state
        if not state then return end
        task.spawn(function()
            while upgradeSingleOn do
                local p = upgradeMap[selUpgrade]
                if p and p.Parent then
                    pcall(function() ReplicatedStorage.RemoteEvents.Server.Upgrade:InvokeServer(p,"Upgrade",upgradeAmt) end)
                end
                task.wait(0.3)
            end
        end)
    end,
})

-- =============================================
-- TAB: REBIRTH
-- =============================================
local RebirthTab = Window:AddTab({ Title="Rebirth", Icon="refresh-cw" })
local autoRebirthOn = false
RebirthTab:AddToggle("AutoRebirth", {
    Title="Auto Rebirth", Default=false,
    Callback=function(state)
        autoRebirthOn = state
        if not state then return end
        task.spawn(function()
            while autoRebirthOn do
                pcall(function() ReplicatedStorage.RemoteEvents.Server.RebirthEvent:FireServer() end)
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- TAB: SPEED
-- =============================================
local SpeedTab = Window:AddTab({ Title="Speed", Icon="zap" })
local buySpeedOn = false; local speedAmt = 1
SpeedTab:AddInput("SpeedAmt", {Title="Speed Amount",Default="1",Placeholder="Amount...",Numeric=true,Finished=false,Callback=function(v) speedAmt=tonumber(v) or 1 end})
SpeedTab:AddToggle("BuySpeed", {
    Title="Buy Speed", Default=false,
    Callback=function(state)
        buySpeedOn = state
        if not state then return end
        task.spawn(function()
            while buySpeedOn do
                pcall(function() ReplicatedStorage.RemoteEvents.Server.PurchaseSpeed:FireServer(speedAmt) end)
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- TAB: WEATHER
-- =============================================
local WeatherTab = Window:AddTab({ Title="Weather", Icon="cloud" })
local buyWeatherOn = false; local selWeathers = {}
local wKeys = {["Gold Rain"]="GoldRain",["Diamond Rain"]="DiamondRain",["Lightning"]="Lightning",["Black Hole"]="Blackhole",["Nebula"]="Nebula",["Fire Quake"]="Firequake"}

WeatherTab:AddDropdown("WeatherDrop", {
    Title="Select Weather(s)", Values={"Gold Rain","Diamond Rain","Lightning","Black Hole","Nebula","Fire Quake"},
    Multi=true, Default={}, Callback=function(v) selWeathers=v end,
})
WeatherTab:AddToggle("BuyWeather", {
    Title="Buy Weather", Default=false,
    Callback=function(state)
        buyWeatherOn = state
        if not state then return end
        task.spawn(function()
            while buyWeatherOn do
                for name in pairs(selWeathers) do
                    local k = wKeys[name]
                    if k then pcall(function() ReplicatedStorage.RemoteEvents.Server.PurchaseWeather:FireServer(k) end) end
                end
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- TAB: SPIN
-- =============================================
local SpinTab = Window:AddTab({ Title="Spin", Icon="rotate-cw" })
local autoSpinOn = false
SpinTab:AddToggle("AutoSpin", {
    Title="Auto Spin", Default=false,
    Callback=function(state)
        autoSpinOn = state
        if not state then return end
        task.spawn(function()
            while autoSpinOn do
                pcall(function() ReplicatedStorage.RemoteEvents.Server.ActivateSpin:InvokeServer() end)
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- TAB: CARRY
-- =============================================
local CarryTab = Window:AddTab({ Title="Carry", Icon="package" })
local autoBuyCarryOn = false
CarryTab:AddToggle("AutoBuyCarry", {
    Title="Auto Buy Carry", Default=false,
    Callback=function(state)
        autoBuyCarryOn = state
        if not state then return end
        task.spawn(function()
            while autoBuyCarryOn do
                pcall(function() ReplicatedStorage.RemoteEvents.Server.BuyCarry:FireServer() end)
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- FARM TABS (one per zone)
-- =============================================

HACKER_ZONE = {
    ["Guest 666"]="CommonZone",["John Doe"]="CommonZone",["are17"]="CommonZone",
    ["Jane Doe"]="UncommonZone",["Jenna"]="UncommonZone",["Greg"]="UncommonZone",
    ["ITrapped"]="RareZone",["Vision"]="RareZone",["Luisgamercool23"]="RareZone",
    ["Unseenbones"]="LegendaryZone",["c00lkid"]="LegendaryZone",["DracoSwordMaster"]="LegendaryZone",
    ["Luckymaxer"]="MythicalZone",["Loleris"]="MythicalZone",["1x1x1x1"]="MythicalZone",
    ["Angelic Guest"]="OgZone",["Angelic Jenna"]="OgZone",["Angelic Trapped"]="OgZone",
    ["Angelic Bones"]="OgZone",["Angelic kidd"]="OgZone",["Minish"]="OgZone",
    ["Sleepy"]="ExoticZone",["Devil Hacker"]="ExoticZone",["Green Devil"]="ExoticZone",
    ["Sus Hacker"]="ExoticZone",["Money Machine"]="ExoticZone",["Rich Hacker"]="ExoticZone",["Roblox Hacker"]="ExoticZone",
    ["Tubers93"]=nil,["Angelic Doe"]=nil,["TheC0mmunity"]=nil,["Ellernate"]=nil,
    ["Toxic Jane"]=nil,["Toxic Vision"]=nil,["Toxic Maxer"]=nil,["Toxic Ellernate"]=nil,["Toxic Minish"]=nil,
    ["1010101"]=nil,["Anonymous"]=nil,["Tubers 666"]=nil,["Corrupted Doe"]=nil,["Guest ???"]=nil,
    ["h4ckedkidd"]=nil,["Abyssal Vision"]=nil,["Abyssal Bones"]=nil,["Ignited Guest"]=nil,
    ["Abyssal Jenna"]=nil,["Charged 1x1x1x1"]=nil,["Abyssal Trapped"]=nil,
    ["Chained Ellernate"]=nil,["Virus Lord"]=nil,
}

local ZONE_HACKERS = {
    CommonZone    = {"-- Any in Zone --","Guest 666","John Doe","are17"},
    UncommonZone  = {"-- Any in Zone --","Jane Doe","Jenna","Greg"},
    RareZone      = {"-- Any in Zone --","ITrapped","Vision","Luisgamercool23"},
    ToxicZone     = {"-- Any in Zone --","Toxic Jane","Toxic Vision","Toxic Maxer","Toxic Ellernate","Toxic Minish"},
    LegendaryZone = {"-- Any in Zone --","Unseenbones","c00lkid","DracoSwordMaster"},
    MythicalZone  = {"-- Any in Zone --","Luckymaxer","Loleris","1x1x1x1"},
    OgZone        = {"-- Any in Zone --","Angelic Guest","Angelic Jenna","Angelic Trapped","Angelic Bones","Angelic kidd","Minish"},
    SecretZone    = {"-- Any in Zone --","Tubers93","Angelic Doe","TheC0mmunity","Ellernate"},
    ExclusiveZone = {"-- Any (all zones) --","1010101","Anonymous","Tubers 666","Corrupted Doe","Guest ???","h4ckedkidd",
                     "Abyssal Vision","Abyssal Bones","Ignited Guest","Abyssal Jenna",
                     "Charged 1x1x1x1","Abyssal Trapped","Chained Ellernate","Virus Lord"},
    ExoticZone    = {"-- Any in Zone --","Sleepy","Devil Hacker","Green Devil","Sus Hacker","Money Machine","Rich Hacker","Roblox Hacker"},
}

local FARM_DEFS = {
    {title="Common",    zk="CommonZone"},
    {title="Uncommon",  zk="UncommonZone"},
    {title="Rare",      zk="RareZone"},
    {title="Toxic",     zk="ToxicZone"},
    {title="Legendary", zk="LegendaryZone"},
    {title="Mythical",  zk="MythicalZone"},
    {title="OG",        zk="OgZone"},
    {title="Secret",    zk="SecretZone"},
    {title="Exclusive", zk="ExclusiveZone"},
    {title="Exotic",    zk="ExoticZone"},
}

local CAMERA_ZONES_LIST = {"CommonZone","ExoticZone","LegendaryZone","MythicalZone","OgZone","RareZone","SecretZone","ToxicZone","UncommonZone"}

for _, def in ipairs(FARM_DEFS) do
    local tab = Window:AddTab({ Title = def.title, Icon = "layers" })
    local zk  = def.zk
    local isExclusive = (zk == "ExclusiveZone")
    local autoGetOn = false
    local selHackers = {}  -- multi-select table

    -- Carry override input
    tab:AddInput("CarryInput_"..zk, {
        Title       = "Carry Limit Override",
        Description = "Set manually if auto-detect is wrong. Leave 0 to auto-detect.",
        Default     = "0",
        Placeholder = "0 = auto detect",
        Numeric     = true,
        Finished    = false,
        Callback    = function(v)
            manualCarry[zk] = tonumber(v) or 0
        end,
    })

    -- Multi-select hacker dropdown
    local dropOpts = ZONE_HACKERS[zk] or {"-- Any in Zone --"}
    tab:AddDropdown("HackDrop_"..zk, {
        Title       = "Select Hacker(s)",
        Description = "Multi-select. Pick specific hackers or leave on Any to grab all.",
        Values      = dropOpts,
        Multi       = true,
        Default     = {},
        Callback    = function(v) selHackers = v end,
    })

    tab:AddToggle("AutoGet_"..zk, {
        Title       = "Auto Get",
        Description = "Grab until carry full → go base → repeat. Stops if zone is empty.",
        Default     = false,
        Callback    = function(state)
            autoGetOn = state
            if not state then return end

            task.spawn(function()
                while autoGetOn do
                    local carryMax  = GetCarryMax(zk)
                    local collected = 0

                    -- Decide mode: specific hackers selected vs any
                    local specificList = {}
                    local anyMode = true
                    for name in pairs(selHackers) do
                        if name ~= "-- Any in Zone --" and name ~= "-- Any (all zones) --" then
                            table.insert(specificList, name)
                            anyMode = false
                        end
                    end

                    if not anyMode then
                        -- SPECIFIC HACKER(S) MODE
                        -- Check if any of the targets are jailed first
                        local allGone = false

                        while autoGetOn and collected < carryMax do
                            local grabbedOne = false
                            for _, hName in ipairs(specificList) do
                                if not autoGetOn or collected >= carryMax then break end
                                local targetZone = isExclusive and nil or HACKER_ZONE[hName]
                                if GrabByName(hName, targetZone) then
                                    collected += 1
                                    grabbedOne = true
                                end
                            end

                            if not grabbedOne then
                                -- None of the targets are jailed
                                GoToMyPlot()
                                -- Wait at base until one appears (check every 2s)
                                local found = false
                                while autoGetOn and not found do
                                    for _, hName in ipairs(specificList) do
                                        local tz = isExclusive and nil or HACKER_ZONE[hName]
                                        local search = tz and {tz} or ZONE_ORDER
                                        for _, szk in ipairs(search) do
                                            local zf = workspace.Map.Zones:FindFirstChild(szk)
                                            local ct = zf and zf:FindFirstChild("Container")
                                            if ct then
                                                for _, cell in ipairs(ct:GetChildren()) do
                                                    if string.find(cell.Name,"PrisonCell") and cell:FindFirstChild(hName) then
                                                        local hr = cell[hName]:FindFirstChild("HumanoidRootPart")
                                                        if hr and hr:FindFirstChild("UnbanPrompt") then
                                                            found = true break
                                                        end
                                                    end
                                                end
                                            end
                                            if found then break end
                                        end
                                        if found then break end
                                    end
                                    if not found then task.wait(2) end
                                end
                            end
                        end

                    else
                        -- ANY IN ZONE MODE — scan cells directly
                        if isExclusive then
                            -- Search across all zones
                            local foundAny = false
                            for _, searchZk in ipairs(ZONE_ORDER) do
                                if not autoGetOn or collected >= carryMax then break end
                                for _, hName in ipairs(ZONE_HACKERS["ExclusiveZone"]) do
                                    if hName == "-- Any (all zones) --" then continue end
                                    if not autoGetOn or collected >= carryMax then break end
                                    if GrabByName(hName, nil) then
                                        collected += 1
                                        foundAny = true
                                    end
                                end
                            end
                            if not foundAny then
                                GoToMyPlot()
                                task.wait(2)
                                continue
                            end
                        else
                            -- Scan zone cells directly
                            local totalJailed = CountJailedInZone(zk)
                            if totalJailed == 0 then
                                -- Zone empty → go base and wait
                                GoToMyPlot()
                                local hasJailed = false
                                while autoGetOn and not hasJailed do
                                    if CountJailedInZone(zk) > 0 then hasJailed = true end
                                    if not hasJailed then task.wait(2) end
                                end
                                continue
                            end

                            while autoGetOn and collected < carryMax do
                                local grabbed = GrabAnyInZone(zk)
                                if grabbed then
                                    collected += 1
                                else
                                    -- Zone ran out mid-run
                                    break
                                end
                            end
                        end
                    end

                    -- Return to base if we grabbed anything
                    if collected > 0 then
                        GoToMyPlot()
                        task.wait(1.5)
                    end
                end
            end)
        end,
    })

    -- Camera delete button (only on Common tab)
    if def.title == "Common" then
        tab:AddButton({
            Title="Delete All Cameras",
            Description="Removes all SecurityCamera from every zone's SecurityCameras folder.",
            Callback=function()
                local sc = workspace:FindFirstChild("SecurityCameras")
                if not sc then Fluent:Notify({Title="Error",Content="SecurityCameras not found.",Duration=3}) return end
                local n = 0
                for _, zn in ipairs(CAMERA_ZONES_LIST) do
                    local zf = sc:FindFirstChild(zn)
                    if zf then
                        for _, cam in ipairs(zf:GetChildren()) do
                            if cam.Name == "SecurityCamera" then pcall(function() cam:Destroy() end) n+=1 end
                        end
                    end
                end
                Fluent:Notify({Title="Done",Content="Deleted "..n.." cameras.",Duration=3})
            end,
        })
    end
end

-- =============================================
Window:SelectTab(1)
Fluent:Notify({Title="Loaded", Content="Welcome "..LPN.."!", Duration=4})
