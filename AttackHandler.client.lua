local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local PlayerIsAttackingEvent = RemoteEvents.PlayerIsAttackingEvent
local PlayerIsChargingEvent = RemoteEvents.PlayerIsChargingEvent

local player = PlayersService.LocalPlayer
local mouse = player:GetMouse()

local function onMouseButtonDown()
    PlayerIsChargingEvent:FireServer()
end

local function onMouseButtonUp()
    PlayerIsAttackingEvent:FireServer()
end

mouse.Button1Down:Connect(onMouseButtonDown)
mouse.Button1Up:Connect(onMouseButtonUp)