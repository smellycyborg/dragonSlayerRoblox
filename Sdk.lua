--[[

- solo player game
- players move through multiple levels to defeat dragons
- dragons will have difficulty and level indicator
- dragon on death drops random sword and gold
- player can pick up dropped items by interacting
- basic fight mechanics for player
- dragons have two types of attack options
- when all dragons defeated player goes to next level

]]

local PlayersService = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local GOLD_PRODUCT_AMOUNT = 100
local WEAPON_DAMAGE_PRODUCT_AMOUNT = 25
local TIME_UNTIL_NEXT_ATTACK = 0.5

local Sdk = {
    _playerData = {},
    _playerDataStore = DataStoreService:GetDataStore("PlayerDataStore"),
    monsters = {},
}

local function spawnSword(position)
    local swords = Assets.Swords:GetChildren()
    local randomIndex = math.random(1, #swords)
    local swordClone = swords[randomIndex]:Clone()
    swordClone.Name = "Sword"
    swordClone.Position = position
    swordClone.Parent = workspace
end

local function destroyMonster(target)
    Sdk.monsters[target] = nil
    target:Destroy()
end

local function destroyMonsterAndSpawnSword(target)
    local targetPosition = target.Position
    spawnSword(targetPosition)
    destroyMonster(target)
end

local function spawnDragons()
    local monstersToSpawn = Sdk.monsterAmount

    local dragons = Assets.Dragons:GetChildren()

    for i = 1, monstersToSpawn do 
        local randomIndex = math.random(1, #dragons)
        local dragonClone = dragons[randomIndex]:Clone()
        dragonClone.Name = "Dragon"
        dragonClone.HumanoidRootPart.Position = Vector3.new(56.299, 3.448, 10.166)
        dragonClone.Parent = workspace

        Sdk.monsters[i] = dragonClone
    end
end

local function startNextLevel(player)
    local playerData = Sdk._playerData[player]
    local currentLevel = playerData.level

    spawnDragons()
end

local function onSwordTouched(otherPart, player)
    local playerData = Sdk._playerData[player]
    local weaponDamage = playerData.weaponDamage
    local target = otherPart.Parent

    local isMonster = Sdk.monsters[target] ~= nil
    if (isMonster) then
        Sdk.monsters[target].health-=weaponDamage
    end

    local monsterHasNoHealth = Sdk.monsters[target].health <= 0
    if (monsterHasNoHealth) then
        destroyMonsterAndSpawnSword(target)
    end

    local noMonstersLeft = Sdk.monsters == nil or #Sdk.monsters == 0
    if (noMonstersLeft) then
        startNextLevel(player)
    end
end

local function onChildAdded(child, player)
    if (child.Name ~= "Sword") then
        return
    end

    Sdk._playerData[player].isEquipped = true

    print("MESSAGE/Info:  player has equipped ", child.Name, ".")

    local playerData = Sdk._playerData[player]
    local isAttacking = playerData.isAttacking

    child.Handle.Touched:Connect(function(otherPart)
        if (not isAttacking) then
            return
        end

        onSwordTouched(otherPart, player)
    end)
end

local function onChildRemoved(child, player)
    if (child.Name ~= "Sword") then
        return
    end

    Sdk._playerData[player].isEquipped = false

    print("MESSAGE/Info:  player has unequipped ", child.Name, ".")
end

local function cloneSword(player)
    local classicSwordClone = Assets.Swords.ClassicSword:Clone()
    classicSwordClone.Name = "Sword"
    classicSwordClone.Parent = player.Backpack
end

local function onCharacterAdded(character)
    local player = PlayersService:GetPlayerFromCharacter(character)
    cloneSword(player)
    startNextLevel(player)

    character.ChildAdded:Connect(function(child)
        onChildAdded(child, player)
    end)

    character.ChildRemoved:Connect(function(child)
        onChildRemoved(child, player)
    end)

    local sword = character:FindFirstChild("Sword")
    if not sword then
        return
    end

    sword.Touched:Connect(function(otherPart)
        onSwordTouched(otherPart, player)
    end)
end

local function onCharacterRemoving(character)

end

local function createPlayerData()
    local playerData = {}

    playerData.level = 1
    playerData.gold = 0
    playerData.weaponDamage = 25
    playerData.isAttacking = false
    playerData.isEquipped = false

    return playerData
end

local function onPlayerAdded(player)
    local playerData

    local success, data = pcall(function()
        return Sdk._playerDataStore:GetAsync(player.UserId)
    end)

    if (not success) then
        playerData = createPlayerData()
    else
        if (data ~= nil) then
            playerData = data
        else
            playerData = createPlayerData()
        end
    end

    Sdk._playerData[player] = playerData

    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(onCharacterRemoving)
end

local function onPlayerRemoving(player)
    local playerData = Sdk._playerData[player]

    local success, err = pcall(function()
        return Sdk._playerDataStore:SetAsync(player.UserId, playerData)
    end)

    if (not success) then
        warn(err)
    end

    Sdk._playerData[player] = nil
end

local function onPromptPurchaseFinished(player, productId, purchaseSuccess)
    if (not purchaseSuccess) then
        return
    end

    local isGold = productId == nil
    local isWeaponDamage = productId == nil

    local key, amount

    if (isGold) then
        key = "gold"
        amount = GOLD_PRODUCT_AMOUNT
    elseif (isWeaponDamage) then
        key = "weaponDamage"
        amount = WEAPON_DAMAGE_PRODUCT_AMOUNT
    end

    Sdk:IncrementValue(player, key, amount)
end

local function onPromptPurchaseEvent(player, productId)
    MarketplaceService:PromptProductPurchase(player, productId)
end

local function checkActionStatus(player)
    local playerData = Sdk._playerData[player]
    local isEquipped = playerData.isEquipped
    if (not isEquipped) then
        return false
    end

    local isAttacking = playerData.isAttacking
    if (isAttacking) then
        return false
    end

    return true
end

local function onPlayerIsChargingEvent(player)
    local playerData = Sdk._playerData[player]
    
    local canAttack = checkActionStatus(player)
    if (not canAttack) then
        return
    end

    local Sword = player.Character:FindFirstChild("Sword")
    if (not Sword) then
        return
    end

    local character = player.Character
    local humanoid = character.Humanoid
    local animator = humanoid.Animator

    local chargingAnimation = Sword.Animations.ChargeAnim
    chargingAnimationLoader = animator:LoadAnimation(chargingAnimation)

    chargingAnimationLoader:Play()
end

local function onPlayerIsAttackingEvent(player)
    local playerData = Sdk._playerData[player]

    local canAttack = checkActionStatus(player)
    if (not canAttack) then
        return
    end

    local Sword = player.Character:FindFirstChild("Sword")
    if (not Sword) then
        return
    end

    local character = player.Character
    local humanoid = character.Humanoid
    local animator = humanoid.Animator

    local attackAnimations = {
        [1] = Sword.Animations.SlashAnim,
        [2] = Sword.Animations.StabAnim,
    }

    local randomIndex = math.random(1, #attackAnimations)
    local randomAttackAnimation = attackAnimations[randomIndex]
    local attackAnimationLoader = animator:LoadAnimation(randomAttackAnimation)

    chargingAnimationLoader:Stop()
    attackAnimationLoader:Play()

    Sdk._playerData[player].isAttacking = true

    print("MESSAGE/Info:  Player is attacking.")

    task.wait(TIME_UNTIL_NEXT_ATTACK)

    Sdk._playerData[player].isAttacking = false
end

local function onDealDamageFunction(player, target)
    local playerData = Sdk._playerData[player]
    local weaponDamage = playerData.weaponDamage

    local monster = Sdk.monsters[target]
    monster.health-=weaponDamage

    return weaponDamage
end

function Sdk.init(options)

    -- gameplay options
    Sdk.levelAmount = options.levelAmount
    Sdk.monsterAmount = options.monsterAmount
    Sdk.monsterHealth = options.monsterHealth
    Sdk.monsterDamage = options.monsterDamage

    -- remotes
    local RemoteEvents = Instance.new("Folder", ReplicatedStorage)
    RemoteEvents.Name = "RemoteEvents"
    local RemoteFunctions = Instance.new("Folder", ReplicatedStorage)
    RemoteFunctions.Name = "RemoteFunctions"

    local promptPurchaseEvent = Instance.new("RemoteEvent", RemoteEvents)
    promptPurchaseEvent.Name = "PromptPurchaseEvent"
    local playerIsChargingEvent = Instance.new("RemoteEvent", RemoteEvents)
    playerIsChargingEvent.Name = "PlayerIsChargingEvent"
    local playerIsAttackingEvent = Instance.new("RemoteEvent", RemoteEvents)
    playerIsAttackingEvent.Name = "PlayerIsAttackingEvent"
    local dealDamageFunction = Instance.new("RemoteFunction", RemoteFunctions)
    dealDamageFunction.Name = "DealDamageFunction"

    Assets = script.Parent.Assets
    Assets.Parent = ReplicatedStorage
    local AttackHandler = script.Parent.AttackHandler
    AttackHandler.Parent = StarterPlayer.StarterCharacterScripts

    -- bindings
    promptPurchaseEvent.OnServerEvent:Connect(onPromptPurchaseEvent)
    playerIsChargingEvent.OnServerEvent:Connect(onPlayerIsChargingEvent)
    playerIsAttackingEvent.OnServerEvent:Connect(onPlayerIsAttackingEvent)
    dealDamageFunction.OnServerInvoke = onDealDamageFunction
    MarketplaceService.PromptPurchaseFinished:Connect(onPromptPurchaseFinished)
    PlayersService.PlayerAdded:Connect(onPlayerAdded)
    PlayersService.PlayerRemoving:Connect(onPlayerRemoving)

end

function Sdk:IncrementValue(player, key, amount)
    self._playerData[player][key]+=amount
end

return Sdk
