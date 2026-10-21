return function(deps)
    local LocalPlayer = deps.LocalPlayer
    local Connections = deps.Connections
    local Flags = deps.Flags
    local RunService = deps.RunService
    local UserInputService = deps.UserInputService
    local VirtualUser = deps.VirtualUser
    local Lighting = deps.Lighting
    local CoreGui = deps.CoreGui
    local WindUI = deps.WindUI
    local onFpsBlackLabelCreated = deps.onFpsBlackLabelCreated

    local origLighting = { GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd }
    local origAtmosphere = {}
    pcall(function()
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then
            origAtmosphere.Density = atmo.Density
            origAtmosphere.Haze = atmo.Haze
            origAtmosphere.Glare = atmo.Glare
        end
    end)
    local blackScreenGui = nil
    local fpsBlackLabel = nil

    local fpsGen = { effects = 0, meshes = 0 }
    local FPS_CHUNK_SIZE = 100
    local FPS_CHUNK_DELAY = 0.05

    local M = {}

    local function processInChunks(key, list, fn)
        fpsGen[key] = (fpsGen[key] or 0) + 1
        local gen = fpsGen[key]
        local n = #list
        for i = 1, n, FPS_CHUNK_SIZE do
            if gen ~= fpsGen[key] then return false end
            local last = math.min(i + FPS_CHUNK_SIZE - 1, n)
            for j = i, last do
                pcall(fn, list[j])
            end
            if last < n then
                task.wait(FPS_CHUNK_DELAY)
            end
        end
        return true
    end

    function M.bypassGameAFK()
        pcall(function()
            local afk = LocalPlayer:WaitForChild("PlayerScripts", 5) and LocalPlayer.PlayerScripts:FindFirstChild("AFK")
            if afk then
                afk.Disabled = true
                afk:Destroy()
            end
        end)
        pcall(function()
            if not Connections.AFKWatcher then
                Connections.AFKWatcher = LocalPlayer.PlayerScripts.ChildAdded:Connect(function(child)
                    if child.Name == "AFK" and child:IsA("LocalScript") then
                        child.Disabled = true
                        child:Destroy()
                    end
                end)
            end
        end)
        pcall(function()
            local idledConns = getconnections and getconnections(LocalPlayer.Idled)
            if idledConns then
                for _, conn in ipairs(idledConns) do
                    if conn.Disable then conn:Disable() elseif conn.Disconnect then conn:Disconnect() end
                end
            end
        end)
    end

    function M.triggerAntiAFK()
        M.bypassGameAFK()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        pcall(function()
            UserInputService.InputBegan:Fire({
                UserInputType = Enum.UserInputType.MouseButton1,
                UserInputState = Enum.UserInputState.Begin,
                Position = Vector3.new(0, 0, 0),
            }, false)
        end)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function() hum:Move(Vector3.new(0, 0, 0)) end)
            end
        end
    end

    function M.setupAutoReconnect()
        pcall(function()
            local GuiService = game:GetService("GuiService")
            local TeleportService = game:GetService("TeleportService")
            if not Connections.AutoReconnect then
                Connections.AutoReconnect = GuiService.ErrorMessageChanged:Connect(function()
                    task.wait(1.5)
                    while true do
                        pcall(function()
                            TeleportService:Teleport(game.PlaceId, LocalPlayer)
                        end)
                        task.wait(5)
                    end
                end)
            end
        end)
    end

    function M.enableAntiDetection()
        pcall(function()
            local mt = getrawmetatable(game)
            if mt then
                local oldNamecall = mt.__namecall
                local oldIndex = mt.__index
                if setreadonly then setreadonly(mt, false) end
                if make_readonly then make_readonly(mt, false) end

                mt.__namecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if method == "FindFirstChild" or method == "FindFirstChildOfClass" then
                        local firstArg = ...
                        if firstArg and type(firstArg) == "string" then
                            local lower = firstArg:lower()
                            if lower:find("exploit") or lower:find("cheat") or lower:find("hack")
                                or lower:find("inject") or lower:find("executor") or lower:find("script")
                                or lower:find("real") or lower:find("synapse") or lower:find("krnl") then
                                return nil
                            end
                        end
                    end
                    if method == "GetService" then
                        local firstArg = ...
                        if firstArg and type(firstArg) == "string" then
                            local lower = firstArg:lower()
                            if lower:find("coregui") then
                                if not checkcaller() then
                                    return oldNamecall(self, ...)
                                end
                            end
                        end
                    end
                    if method == "HttpGet" or method == "HttpGetAsync" then
                        if not checkcaller() then
                            return oldNamecall(self, ...)
                        end
                    end
                    return oldNamecall(self, ...)
                end)

                mt.__index = newcclosure(function(self, key)
                    if type(key) == "string" then
                        local lower = key:lower()
                        if lower == "gethui" or lower == "getexecutorname" or lower == "identifyexecutor"
                            or lower == "getnamecallmethod" or lower == "hookmetamethod" then
                            if not checkcaller() then
                                return nil
                            end
                        end
                    end
                    return oldIndex(self, key)
                end)

                if setreadonly then setreadonly(mt, true) end
                if make_readonly then make_readonly(mt, true) end
            end
        end)
    end

    function M.fpsDisableEffects(enable)
        pcall(function()
            local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmo then
                atmo.Density = enable and 0 or (origAtmosphere.Density or 0.173)
                atmo.Haze = enable and 0 or (origAtmosphere.Haze or 0)
                atmo.Glare = enable and 0 or (origAtmosphere.Glare or 0)
            end
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("SunRaysEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then
                    e.Enabled = not enable
                end
            end
            Lighting.GlobalShadows = not enable and origLighting.GlobalShadows or false
            Lighting.FogEnd = enable and 9e9 or origLighting.FogEnd
        end)
        pcall(function()
            local t = workspace:FindFirstChildOfClass("Terrain")
            if t then t.WaterWaveSize = enable and 0 or 0.15 t.WaterWaveSpeed = enable and 0 or 10 end
            workspace.GlobalWind = enable and Vector3.zero or Vector3.new(2, 0, 1)
        end)
        local list = workspace:GetDescendants()
        processInChunks("effects", list, function(d)
            if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                d.Enabled = not enable
            elseif d:IsA("Clouds") then
                d.Enabled = not enable
            end
        end)
    end

    function M.toggleHideMeshes(enable)
        pcall(function()
            local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmo then
                atmo.Density = enable and 0 or (origAtmosphere.Density or 0.173)
                atmo.Haze = enable and 0 or (origAtmosphere.Haze or 0)
                atmo.Glare = enable and 0 or (origAtmosphere.Glare or 0)
            end
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("SunRaysEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then
                    e.Enabled = not enable
                end
            end
            Lighting.GlobalShadows = not enable and origLighting.GlobalShadows or false
            Lighting.FogEnd = enable and 9e9 or origLighting.FogEnd
        end)
        pcall(function()
            local t = workspace:FindFirstChildOfClass("Terrain")
            if t then t.WaterWaveSize = enable and 0 or 0.15 t.WaterWaveSpeed = enable and 0 or 10 end
            workspace.GlobalWind = enable and Vector3.zero or Vector3.new(2, 0, 1)
        end)
        local char = LocalPlayer.Character
        local list = workspace:GetDescendants()
        processInChunks("meshes", list, function(d)
            if d:IsA("BasePart") then
                local isChar = char and d:IsDescendantOf(char)
                if not isChar then
                    d.LocalTransparencyModifier = enable and 1 or 0
                end
            elseif d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency = enable and 1 or 0
            elseif d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Clouds") then
                d.Enabled = not enable
            end
        end)
        if enable then
            if not Connections.AntiRender then
                Connections.AntiRender = workspace.DescendantAdded:Connect(function(desc)
                    if not Flags.FPSPotato then return end
                    if desc:IsA("BillboardGui") or desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
                        desc.Enabled = false
                    elseif desc:IsA("BasePart") then
                        local myC = LocalPlayer.Character
                        if not myC or not desc:IsDescendantOf(myC) then
                            desc.LocalTransparencyModifier = 1
                        end
                    end
                end)
            end
        else
            if Connections.AntiRender then
                pcall(function() Connections.AntiRender:Disconnect() end)
                Connections.AntiRender = nil
            end
        end
    end

    function M.toggleBlackScreen(enable)
        pcall(function() RunService:Set3dRenderingEnabled(not enable) end)
        if enable then
            if not blackScreenGui then
                blackScreenGui = Instance.new("ScreenGui")
                blackScreenGui.Name = "Roox_BlackoutScreen"
                blackScreenGui.IgnoreGuiInset = true
                blackScreenGui.DisplayOrder = -10
                blackScreenGui.ResetOnSpawn = false

                local bg = Instance.new("Frame")
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
                bg.BorderSizePixel = 0
                bg.Parent = blackScreenGui

                local info = Instance.new("Frame")
                info.Size = UDim2.new(0, 400, 0, 145)
                info.AnchorPoint = Vector2.new(0.5, 0.5)
                info.Position = UDim2.new(0.5, 0, 0.5, 0)
                info.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                info.BackgroundTransparency = 0.1
                Instance.new("UICorner", info).CornerRadius = UDim.new(0, 12)
                info.Parent = bg

                local t1 = Instance.new("TextLabel")
                t1.Size = UDim2.new(1, 0, 0, 32)
                t1.Position = UDim2.new(0, 0, 0, 10)
                t1.BackgroundTransparency = 1
                t1.Text = "ULTRA FPS BOOST ACTIVE"
                t1.TextColor3 = Color3.fromRGB(0, 255, 160)
                t1.Font = Enum.Font.GothamBold
                t1.TextSize = 15
                t1.Parent = info

                local t2 = Instance.new("TextLabel")
                t2.Size = UDim2.new(1, -20, 0, 28)
                t2.Position = UDim2.new(0, 10, 0, 40)
                t2.BackgroundTransparency = 1
                t2.Text = "3D rendering fully disabled to save CPU/GPU & maximize FPS while AFK."
                t2.TextColor3 = Color3.fromRGB(180, 180, 190)
                t2.Font = Enum.Font.Gotham
                t2.TextSize = 11
                t2.TextWrapped = true
                t2.Parent = info

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0, 200, 0, 30)
                btn.AnchorPoint = Vector2.new(0.5, 1)
                btn.Position = UDim2.new(0.5, 0, 1, -38)
                btn.BackgroundColor3 = Color3.fromRGB(35, 140, 90)
                btn.Text = "Restore Normal Render"
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 12
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
                btn.MouseButton1Click:Connect(function()
                    M.toggleBlackScreen(false)
                    if Flags.FPSBlackScreen then Flags.FPSBlackScreen = false end
                    WindUI:Notify({ Title = "RooxHub • FPS Boost", Content = "3D rendering restored to normal.", Duration = 2 })
                end)
                btn.Parent = info

                fpsBlackLabel = Instance.new("TextLabel")
                fpsBlackLabel.Size = UDim2.new(1, 0, 0, 24)
                fpsBlackLabel.AnchorPoint = Vector2.new(0.5, 1)
                fpsBlackLabel.Position = UDim2.new(0.5, 0, 1, -6)
                fpsBlackLabel.BackgroundTransparency = 1
                fpsBlackLabel.Text = "-- FPS"
                fpsBlackLabel.TextColor3 = Color3.fromRGB(0, 255, 160)
                fpsBlackLabel.Font = Enum.Font.GothamBold
                fpsBlackLabel.TextSize = 18
                fpsBlackLabel.Parent = info

                if onFpsBlackLabelCreated then
                    onFpsBlackLabelCreated(fpsBlackLabel)
                end

                pcall(function() blackScreenGui.Parent = CoreGui end)
                if not blackScreenGui.Parent then
                    blackScreenGui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
                end
            else
                blackScreenGui.Enabled = true
            end
        else
            if blackScreenGui then blackScreenGui.Enabled = false end
        end
    end

    return M
end
