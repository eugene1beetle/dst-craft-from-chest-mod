--Thanks rezecib!
-- local function CheckDlcEnabled(dlc)
--     -- if the constant doesn't even exist, then they can't have the DLC
--     if not GLOBAL.rawget(GLOBAL, dlc) then
--         return false
--     end
--     GLOBAL.assert(GLOBAL.rawget(GLOBAL, "IsDLCEnabled"), "Old version of game, please update (IsDLCEnabled function missing)")
--     return GLOBAL.IsDLCEnabled(GLOBAL[dlc])
-- end

-- local DLCROG = CheckDlcEnabled("REIGN_OF_GIANTS")
-- local CSW = CheckDlcEnabled("CAPY_DLC")
-- local HML = CheckDlcEnabled("PORKLAND_DLC")
-- PrefabFiles = {
-- 	"newctnr_classified",
-- }

local _G = GLOBAL
local STRINGS = _G.STRINGS
--local debug = _G.debug
--local dumptable = _G.dumptable

local DeBuG = GetModConfigData("debug")
local range = GetModConfigData("range")
local inv_first = GetModConfigData("is_inv_first")
local keep_one_item = GetModConfigData("keep_one_item")
-- local c = { r = 0, g = 0.3, b = 0 }

local Builder = _G.require 'components/builder'
local BuilderReplica = _G.require 'components/builder_replica'
local ContainerReplica = _G.require 'components/container_replica'
local Container = _G.require 'components/container'
-- local Highlight = _G.require 'components/highlight'
local IngredientUI = _G.require 'widgets/ingredientui'
local RecipePopup = _G.require 'widgets/recipepopup'
local json = _G.json
local pcall = _G.pcall
-- local TabGroup = _G.require 'widgets/tabgroup'
-- local CraftSlot = _G.require 'widgets/craftslot'

-- local highlit = {}-- tracking what is highlighted
local consumedChests = {}
local nearbyChests = {}
local validChests = {}

local TEASER_SCALE_TEXT = 1
local TEASER_SCALE_BTN = 1.5
local TEASER_TEXT_WIDTH = 64 * 3 + 24
local TEASER_BTN_WIDTH = TEASER_TEXT_WIDTH / TEASER_SCALE_BTN
local TEXT_WIDTH = 64 * 3 + 30
require("constants")
-- local CONTROL_ACCEPT = _G.CONTROL_ACCEPT

-- local function isTable(t)
--     return type(t) == 'table'
-- end

-- local containers = _G.require("containers")

local function debugPrint(...)
    local arg = { ... }
    if DeBuG then
        for k, v in pairs(arg) do
            print(v)
        end
    end
end

function ContainerReplica:Has(prefab, amount)
    if self.inst.components.container ~= nil then
        return self.inst.components.container:Has(prefab, amount)
    elseif self.classified ~= nil then
        if self.inst.replica.equippable ~= nil then
            return self.classified:Has(prefab, amount)
        end
        local _amount = 0
        if _G.ThePlayer.player_classified then
            _amount = _G.ThePlayer.player_classified._itemTable[prefab] or 0
        end
        if _amount ~= 0 then
            return _amount > 0, _amount
        else
            return self.classified:Has(prefab, amount)
        end
    elseif _G.ThePlayer.player_classified ~= nil then
        -- local found = _G.ThePlayer.player_classified.chestFound
        local _amount = _G.ThePlayer.player_classified._itemTable[prefab] or 0
        -- debugPrint("###found", found, amount)
        return _amount > 0, _amount
    else
        debugPrint("### the player_classified is nil")
        return amount <= 0, 0
    end
end




-- local function unhighlight(highlit)
--     while #highlit > 0 do
--         local v = table.remove(highlit)
--         if v and v.components.highlight then
--             v.components.highlight:UnHighlight()
--         end
--     end
-- end

-- local function highlight(insts, highlit)
--     for k, v in pairs(insts) do
--         if not v.components.highlight then
--             v:AddComponent('highlight')
--         end
--         if v.components.highlight then
--             v.components.highlight:Highlight(c.r, c.g, c.b)
--             table.insert(highlit, v)
--         end
--     end
-- end

-- given the list of instances, return the list of instances of chest
-- local function filterChest(inst)
--     local chest = {}
--     for k, v in pairs(inst) do
--         if (v and v.replica.container and v.replica.container.type) then
--             -- as cooker and backpack are considered as containers as well
--             -- regex to match ['chest', 'chester']
--             if string.find(v.replica.container.type, 'chest') ~= nil then
--                 table.insert(chest, v)
--             end
--         end
--     end
--     return chest
-- end

AddPrefabPostInitAny(function(inst)
    -- compatible cellar
    if(inst.prefab == "cellar") then
        inst:AddTag("chest")
    end
    if inst.components.container and (inst:HasTag("chest") or inst:HasTag("fridge") or inst:HasTag("saltbox")) then
        table.insert(validChests, inst)
    end
end)

local function clearInvalidChests()
    local i = 1
    while i <= #validChests do
        if not validChests[i]:IsValid() or not (validChests[i]:HasTag("chest") or validChests[i]:HasTag("fridge") or validChests[i]:HasTag("saltbox")) or validChests[i].components.container == nil then
            table.remove(validChests, i)
        else
            i = i + 1
        end
    end
end

local function filterChestInRange(player, chests, dist)
    local chest = {}
    for _, v in pairs(chests) do
        if v:GetPosition():DistSq(player:GetPosition()) <= dist * dist then
            table.insert(chest, v)
        end
    end
    return chest
end

-- given the player, return the chests close to the player
local function getNearbyChest(player, dist)
    if _G.TheNet:GetIsClient() then
        return "isClient"
    end
    clearInvalidChests()
    if range == -1 then
        return validChests
    end
    if dist == nil then
        dist = range
    end
    if not player then
        return {}
    end
    return filterChestInRange(player, validChests, dist)
    -- local x, y, z = player.Transform:GetWorldPosition()
    -- local inst = _G.TheSim:FindEntities(x, y, z, dist, {}, { 'NOBLOCK', 'player', 'FX' }) or {}
    -- return filterChest(inst)
end


-- return: contains (T/F) total (num) qualifyChests (list of chest contains the item)
local function findFromChests(chests, item)
    if chests == "isClient" then
        if _G.TheNet:GetIsClient() and _G.ThePlayer.player_classified then
            -- SendModRPCToServer(MOD_RPC["bychest"]["updateItem"], item)
            local _amount = _G.ThePlayer.player_classified._itemTable[item] or 0
            return _amount > 0, _amount, {}
        end
    end
    if not (chests and item) then
        return false, 0, {}
    end
    local qualifyChests = {}
    local total = 0
    local contains = false

    for k, v in pairs(chests) do
        local found, n = v.replica.container:Has(item, 1)
        -- print("###found?:", found, n)
        if found then
            contains = true
            total = total + n
            table.insert(qualifyChests, v);
        end
    end
    return contains, total, qualifyChests
end

local function findFromNearbyChests(player, item)
    if not (player and item) then
        return false, 0, {}
    end
    local chests = getNearbyChest(player)
    return findFromChests(chests, item)
end

-- return: whether it is enough to fullfill the amt requirement, and the amt not fulfilled.
local function removeFromNearbyChests(player, item, amt)
    if not (player and item and amt ~= nil) then
        debugPrint('removeFromNearbyChests: player | item | amt missing!')
        return false, amt
    end
    debugPrint('removeFromNearbyChests', player, item, amt)

    consumedChests = {}-- clear consumed chests
    local chests = getNearbyChest(player, range + 3)-- extend the range a little bit, avoid error caused by slight player movement
    local numItemsFound = 0
    for k, v in pairs(chests) do
        local container = v.components.container
        found, num_found = container:Has(item, 1)
        if found then
            if keep_one_item then
                num_found = num_found - 1
            end
            numItemsFound = numItemsFound + num_found
            table.insert(consumedChests, v)
            if (amt > num_found) then
                -- not enough
                container:ConsumeByName(item, num_found)
                amt = amt - num_found
            else
                container:ConsumeByName(item, amt)
                amt = 0
                break
            end
        end
    end
    debugPrint('Found ' .. numItemsFound .. ' ' .. item .. ' from ' .. #consumedChests .. ' chests')
    if amt == 0 then
        return true, 0
    else
        return false, amt
    end
end

local function playerConsumeByName(player, item, amt)
    if not (player and item and amt) then
        return false
    end
    local inventory = player.components.inventory
    if inv_first then
        found_inv, num_in_inv = inventory:Has(item, 1)
        if amt <= num_in_inv then
            -- there are more resources available in inv then needed
            inventory:ConsumeByName(item, amt)
            return true
        end
        inventory:ConsumeByName(item, num_in_inv)
        amt = amt - num_in_inv
        debugPrint('Found ' .. num_in_inv .. ' in inventory, take ' .. amt .. 'from chests')
        removeFromNearbyChests(player, item, amt)
        return true
    else
        done, remain = removeFromNearbyChests(player, item, amt)
        if not done then
            inventory:ConsumeByName(item, remain)
        end
        return true
    end
end

local function playerGetByName(player, item, amt)
    debugPrint('playerGetByName ' .. item)
    if not (player and item and amt and amt ~= 0) then
        debugPrint('playerGetByName: player | item | amt missing!')
        return {}
    end

    local items = {}

    local function addToItems(another_item)
        for k, v in pairs(another_item) do
            if items[k] == nil then
                items[k] = v
            else
                items[k] = items[k] + v
            end
        end
    end

    local function tryGetFromContainer(volume)
        found, num = volume:Has(item, 1)
        if found then
            if num >= amt then
                -- there is more than necessary
                addToItems(volume:GetItemByName(item, amt))
                amt = 0
                return true
            else
                -- it's not enough
                addToItems(volume:GetItemByName(item, num))
                amt = amt - num
                return false
            end
        end
        return false
    end

    local inventory = player.components.inventory
    local chests = getNearbyChest(player)

    if inv_first then
        -- get ingredients from inventory first
        if tryGetFromContainer(inventory) then
            return items
        end
        for k, v in pairs(chests) do
            local container = v.components.container
            if tryGetFromContainer(container) then
                return items
            end
        end
    else
        -- get ingredients from chests first
        for k, v in pairs(chests) do
            local container = v.components.container
            if tryGetFromContainer(container) then
                return items
            end
        end
        tryGetFromContainer(inventory)
        return items
    end
    return items
end


-- local function setFound(inst, item, amount)
--     -- inst._found:set(found)
--     inst._itype:set(item)
--     inst._amount:set(amount)
-- end


-- local function amountDirty(inst)
--     inst._itemTable[inst._itype:value()] = inst._amount:value()
-- end


local function updateItem(player, item)
    -- debugPrint("####the player and item", player, item)
    if player.player_classified ~= nil then
        player.player_classified:allItemUpdate()
    end
    -- local chests = getNearbyChest(_G.ThePlayer)
    -- local found, amount = findFromChests(chests, item)
    -- if _G.ThePlayer.player_classified ~= nil then
    --     _G.ThePlayer.player_classified:setFound(item, amount)
    -- else
    --     debugPrint("### none player_classified")
    -- end
end

local function itemDirty(inst, data)
    debugPrint("!!!!!!!!!item dirty here")
    updateItem(_G.ThePlayer, data.item)
end

AddModRPCHandler("bychest", "updateItem", updateItem)

-- local function chestChange(inst)
--     inst._chest:set(not inst._chest:value())
-- end

-- local function chestDirty(inst)
--     if _G.TheNet:GetIsClient() then
--         -- debugPrint("trigger this!!!!!!!!!!!!")
--         _G.ThePlayer:PushEvent("stacksizechange")
--     end
-- end

local function findAllFromChest(chests)
    if not chests or #chests == 0 then
        return {}
    end
    local items = {}
    for k, v in pairs(chests) do
        if v.components.container then
            local prefabs = {}
            for _, i in pairs(v.components.container.slots) do prefabs[i.prefab] = true end
            for t, _ in pairs(prefabs) do
                local found, amount = v.components.container:Has(t, 1)
                local updated_amount = (items[t] or 0) + amount
                if keep_one_item and updated_amount > 0 then
                    updated_amount = updated_amount - 1
                end
                items[t] = updated_amount
                -- debugPrint("findAllFromChest: "..t.prefab.." "..amount)
            end
        end
    end
    return items
end

local function allItemUpdate(inst)
    local chests = getNearbyChest(inst._parent)
    local items = findAllFromChest(chests)
    -- debugPrint("allItemUpdate:"..tostring(chests).." "..#items)
    local r, result = pcall(json.encode, items)
    if not r then debugPrint("编码失败:", items) end
    if result then
        inst._items:set(result)
    end
end

local function itemsDirty(inst)
    -- if _G.TheNet.GetIsClient() then
        debugPrint("itemsDirty:"..inst._items:value())
    -- end
    local r, result = pcall(json.decode, inst._items:value())
    if not r then debugPrint("解码失败:", inst._items:value()) end
    if result then
        inst._itemTable = result
    end
    if _G.TheNet:GetIsClient() then
        inst._parent:PushEvent("stacksizechange")
    end
end

AddPrefabPostInit("player_classified", function(inst)
	-- if TheNet:GetIsServer() then
		-- inst._found = _G.net_bool(inst.GUID, "_found")
        -- inst._found:set(false)
        -- inst._itype = _G.net_string(inst.GUID, "_itype")
        -- inst._itype:set("0")
        -- inst._amount = _G.net_shortint(inst.GUID, "_amount", "amountDirty")
        -- inst._amount:set(0)
        inst._itemTable = {}
        inst._items = _G.net_string(inst.GUID, "_items", "itemsDirty")
        inst._items:set("")
        inst:ListenForEvent("itemsDirty", itemsDirty)
        -- inst:ListenForEvent("amountDirty", amountDirty)
        -- inst:ListenForEvent("itemget", itemDirty)
        -- inst:ListenForEvent("itemlose", itemDirty)
        -- inst._chest = _G.net_bool(inst.GUID, "_chest", "chestDirty")
        -- inst._chest:set(true)
        -- inst:ListenForEvent("chestDirty", chestDirty)

        -- inst.setFound = setFound
        -- inst.chestChange = chestChange
        inst.allItemUpdate = allItemUpdate
        if _G.TheWorld.ismastersim then
            inst.smashtask = inst:DoPeriodicTask(.5, allItemUpdate)
        end
	-- end
end)

-- local function tryconsume(self, v, amount)
--     if v.components.stackable == nil then
--         self:RemoveItem(v):Remove()
--         return 1
--     elseif v.components.stackable.stacksize > amount then
--         v.components.stackable:SetStackSize(v.components.stackable.stacksize - amount)
--         return amount
--     else
--         amount = v.components.stackable.stacksize
--         self:RemoveItem(v, true):Remove()
--         return amount
--     end
--     --shouldn't be possible?
--     return 0
-- end


-- function Container:ConsumeByName(item, amount)
--     if amount <= 0 then
--         return
--     end

--     local temp = amount

--     for k, v in pairs(self.slots) do
--         if v.prefab == item then
--             amount = amount - tryconsume(self, v, amount)
--             if amount <= 0 then
--                 return
--             end
--         end
--     end
-- end


-- detect if the number of chests around the player changes.
-- If true, push event stacksizechange
-- TODO: find a better event to push than "stacksizechange"
local _oldCmpChestsNum = 0
local _newCmpChestsNum = 0
local function compareValidChests(player)
    _newCmpChestsNum = table.getn(getNearbyChest(player))
    if (_oldCmpChestsNum ~= _newCmpChestsNum) then
        _oldCmpChestsNum = _newCmpChestsNum
        debugPrint('Chest number changed!')
        player:PushEvent("stacksizechange")
        -- if player.player_classified ~= nil then
        --     player.player_classified:chestChange()
        -- end
    end
end

-- override original function
-- Support DS, RoG. SW not tested
-- to unhighlight chest when tabgroup are deselected
-- function TabGroup:DeselectAll(...)
--     for k, v in ipairs(self.tabs) do
--         v:Deselect()
--     end
--     self.selected = nil --DST
--     unhighlight(highlit)
-- end

----------------------------------------------------------
---------------Override Builder functions (DS, RoG)-------
-- to test if canbuild with the material from chest
-- function Builder:CanBuild(recname)
--     if self.freebuildmode then
--         return true
--     end

--     local player = self.inst
--     local chests = getNearbyChest(player)
--     -- local recipe = _G.GetRecipe(recname)
--     local recipe = _G.GetValidRecipe(recname) --DST
--     if recipe then
--         for ik, iv in pairs(recipe.ingredients) do
--             -- local amt = math.max(1, _G.RoundUp(iv.amount * self.ingredientmod))
--             local amt = math.max(1, _G.RoundBiasedUp(iv.amount * self.ingredientmod))
--             found, num_found = findFromChests(chests, iv.type)
--             has, num_hold = player.components.inventory:Has(iv.type, amt)
--             if (amt > num_found + num_hold) then
--                 return false
--             end
--         end
--         return true
--     end
--     return false
-- end

--[[function BuilderReplica:CanBuild(recipename)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:CanBuild(recipename)
    elseif self.classified ~= nil then
        local recipe = _G.GetValidRecipe(recipename)
        if recipe == nil then
            return false
        elseif not self.classified.isfreebuildmode:value() then
            local player = self.inst
            local chests = getNearbyChest(player)
            -- if recipename == "researchlab" then debugPrint("########Start") end
            for i, v in pairs(recipe.ingredients) do
                local amt = math.max(1, _G.RoundBiasedUp(v.amount * self:IngredientMod()))
                found, num_found = findFromChests(chests, v.type)
                -- if recipename == "researchlab" then debugPrint("###find from chest", v.type, found, num_found) end
                has, num_hold = player.replica.inventory:Has(v.type, amt)
                if (amt > num_found + num_hold) then
                    return false
                end
            end
            -- if recipename == "researchlab" then debugPrint("########End") end
        end
        for i, v in pairs(recipe.character_ingredients) do
            if not self:HasCharacterIngredient(v) then
                return false
            end
        end
        for i, v in pairs(recipe.tech_ingredients) do
            if not self:HasTechIngredient(v) then
                return false
            end
        end
        return true
    else
        return false
    end
end

function Builder:CanBuild(recname)
    local player = self.inst
    local chests = getNearbyChest(player)
    local recipe = _G.GetValidRecipe(recname)
    if recipe == nil then
        return false
    elseif not self.freebuildmode then
        for i, v in pairs(recipe.ingredients) do
            local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod))
            found, num_found = findFromChests(chests, v.type)
            has, num_hold = player.components.inventory:Has(v.type, amt)
            if (amt > num_found + num_hold) then
                return false
            end
        end
    end
    for i, v in pairs(recipe.character_ingredients) do
        if not self:HasCharacterIngredient(v) then
            return false
        end
    end
    for i, v in pairs(recipe.tech_ingredients) do
        if not self:HasTechIngredient(v) then
            return false
        end
    end
    return true
end]]

-- to keep updating the number of chests as the player move around
--changed the onupdate fn to use the existing one
local old_OnUpdate = Builder.OnUpdate
function Builder:OnUpdate(...)
    compareValidChests(self.inst)
    return old_OnUpdate(self,...)
    --DST part start
    -- if self.EvaluateAutoFixers ~= nil then
    --     self:EvaluateAutoFixers()
    -- end
    --DST part end
end

-- This function is for RoG, base game doesn't have this function'
function Builder:GetIngredients(recname)
    debugPrint('Custom Builder:GetIngredients: ' .. recname)
    -- local recipe = _G.GetRecipe(recname)
    local recipe = _G.GetValidRecipe(recname) --DST
    if recipe then
        local ingredients = {}
        for k, v in pairs(recipe.ingredients) do
            -- local amt = math.max(1, _G.RoundUp(v.amount * self.ingredientmod))
            local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod)) --DST
            -- local items = self.inst.components.inventory:GetItemByName(v.type, amt)
            local items = playerGetByName(self.inst, v.type, amt)
            ingredients[v.type] = items
        end
        return ingredients
    end
end

-- to take ingredients from both inv and chests
-- function Builder:RemoveIngredients(recname_or_ingre)
--     if not isTable(recname_or_ingre) then
--         -- param is a recname, which is base game
--         -- local recipe = _G.GetRecipe(recname_or_ingre)
--         self.inst:PushEvent("consumeingredients", { recipe = recipe })
--         if recipe then
--             for k, v in pairs(recipe.ingredients) do
--                 -- local amt = math.max(1, _G.RoundUp(v.amount * self.ingredientmod))
--                 playerConsumeByName(self.inst, v.type, amt)
--             end
--         end
--     else
--         -- this is RoG version of removeIngredients
--         -- RoG uses another function: getingredients to load all ingredients, so this part
--         -- does not require a lot modification
--         debugPrint('RoG Ver Builder:RemoveIngredients')
--         for item, ents in pairs(recname_or_ingre) do
--             for k, v in pairs(ents) do
--                 for i = 1, v do
--                     -- TODO: change this line
--                     -- Now it can successfully deduct the number of items, but if the item is in
--                     -- the chest, it will not pushevent: "loseitem". Although I didn't see a major
--                     -- effect on that, but better to add it back
--                     self.inst.components.inventory:RemoveItem(k, false):Remove()
--                 end
--             end
--         end
--         self.inst:PushEvent("consumeingredients")
--     end
-- end

-- DST part start
function Builder:RemoveIngredients(ingredients, recname)
    debugPrint('Custom Builder:RemoveIngredients: ',ingredients,recname)
    -- local recipe = _G.GetValidRecipe(recname)
    local recipe = _G.AllRecipes[recname]
    if recipe then
        for k, v in pairs(recipe.ingredients) do
            local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod))
            playerConsumeByName(self.inst, v.type, amt)
        end
    end

    -- local recipe = AllRecipes[recname]
    if recipe then
        for k,v in pairs(recipe.character_ingredients) do
            if v.type == _G.CHARACTER_INGREDIENT.HEALTH then
                --Don't die from crafting!
                local delta = math.min(math.max(0, self.inst.components.health.currenthealth - 1), v.amount)
                self.inst:PushEvent("consumehealthcost")
                self.inst.components.health:DoDelta(-delta, false, "builder", true, nil, true)
            elseif v.type == _G.CHARACTER_INGREDIENT.MAX_HEALTH then
                self.inst:PushEvent("consumehealthcost")
                self.inst.components.health:DeltaPenalty(v.amount)
            elseif v.type == _G.CHARACTER_INGREDIENT.SANITY then
                self.inst.components.sanity:DoDelta(-v.amount)
            elseif v.type == _G.CHARACTER_INGREDIENT.MAX_SANITY then
                --[[
                    Because we don't have any maxsanity restoring items we want to be more careful
                    with how we remove max sanity. Because of that, this is not handled here.
                    Removal of sanity is actually managed by the entity that is created.
                    See maxwell's pet leash on spawn and pet on death functions for examples.
                --]]
            end
        end
    end
    self.inst:PushEvent("consumeingredients")
end

--need to use HasIngredients to check if the items are in the chest now

function Builder:HasIngredients(recipe)
    debugPrint('Custom Builder:HasIngredients: ',recipe)
    if type(recipe) == "string" then 
        recipe = _G.GetValidRecipe(recipe)
    end
    if recipe ~= nil then
        if self.freebuildmode then
            return true
        end
        local chests = getNearbyChest(self.inst)
        for i, v in ipairs(recipe.ingredients) do
            local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod))
            found, num_found = findFromChests(chests, v.type)
            has, num_hold = self.inst.components.inventory:Has(v.type, amt)
            if recipe.name == "pickaxe" then
            end
            if (amt > num_found + num_hold) then
                return false
            end
        end
        for i, v in ipairs(recipe.character_ingredients) do
            if not self:HasCharacterIngredient(v) then
                return false
            end
        end
        for i, v in ipairs(recipe.tech_ingredients) do
            if not self:HasTechIngredient(v) then
                return false
            end
        end
        return true
    end

    return false
end

function BuilderReplica:HasIngredients(recipe)
    debugPrint('Custom BuilderReplica:HasIngredients: ',recipe)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:HasIngredients(recipe)
    elseif self.classified ~= nil then
        if type(recipe) == "string" then 
            recipe = _G.GetValidRecipe(recipe)
        end
        if recipe ~= nil then
            if self.classified.isfreebuildmode:value() then
                return true
            end
            local chests = getNearbyChest(self.inst)
            for i, v in ipairs(recipe.ingredients) do
                local amt = math.max(1, _G.RoundBiasedUp(v.amount * self:IngredientMod()))
                found, num_found = findFromChests(chests, v.type)
                -- if recipename == "researchlab" then debugPrint("###find from chest", v.type, found, num_found) end
                has, num_hold = self.inst.replica.inventory:Has(v.type, amt)
                if recipe.name == "pickaxe" then
                end
                if (amt > num_found + num_hold) then
                    return false
                end
            end
            for i, v in ipairs(recipe.character_ingredients) do
                if not self:HasCharacterIngredient(v) then
                    return false
                end
            end
            for i, v in ipairs(recipe.tech_ingredients) do
                if not self:HasTechIngredient(v) then
                    return false
                end
            end
            return true
        end
    end

    return false
end

local function DoAddClassPostConstruct(classdef, postfn)
    local constructor = classdef._ctor
    classdef._ctor = function (self, ...)
        constructor(self, ...)
        postfn(self, ...)
    end
end

--Bullshit adding of postinit fn because of Tropical Experience that is always just overwritting functions...
--Don't really know of a more elegant way of doing it while still having a high priority for better compability with other mods
if GLOBAL.KnownModIndex:IsModEnabledAny("workshop-1505270912") then
    --We need to use SimPostInit as we need to change it on the client and server
    AddSimPostInit(function()
        --We add a manual ClassPostConstruct to the replica, which will take place after the other ClassPostConstructs
        DoAddClassPostConstruct(require("components/builder_replica"),function(self)
            function self:HasIngredients(recipe)
                debugPrint('Custom BuilderReplica:HasIngredients: ',recipe)
                if self.inst.components.builder ~= nil then
                    return self.inst.components.builder:HasIngredients(recipe)
                elseif self.classified ~= nil then
                    if type(recipe) == "string" then 
                        recipe = _G.GetValidRecipe(recipe)
                    end
                    if recipe ~= nil then
                        if self.classified.isfreebuildmode:value() then
                            return true
                        end
                        local chests = getNearbyChest(self.inst)
                        for i, v in ipairs(recipe.ingredients) do
                            if v.type == "oinc" and self.GetMoney then
                                if self:GetMoney(self.inst.replica.inventory) >= v.amount then
                                    return true
                                end
                            end
                            local amt = math.max(1, _G.RoundBiasedUp(v.amount * self:IngredientMod()))
                            found, num_found = findFromChests(chests, v.type)
                            -- if recipename == "researchlab" then debugPrint("###find from chest", v.type, found, num_found) end
                            has, num_hold = self.inst.replica.inventory:Has(v.type, amt)
                            if recipe.name == "pickaxe" then
                            end
                            if (amt > num_found + num_hold) then
                                return false
                            end
                        end
                        for i, v in ipairs(recipe.character_ingredients) do
                            if not self:HasCharacterIngredient(v) then
                                return false
                            end
                        end
                        for i, v in ipairs(recipe.tech_ingredients) do
                            if not self:HasTechIngredient(v) then
                                return false
                            end
                        end
                        return true
                    end
                end

                return false
            end

        end)

        for i,modname in ipairs(_G.ModManager.enabledmods) do
            if modname == "workshop-1505270912" then
                local mod = _G.ModManager:GetMod(modname)
                local modfns = mod.postinitfns["ComponentPostInit"]["builder"]
                if modfns then
                    --Add a new postinitfn after the TE one which overwrites the overwritten CanBuild function
                    table.insert(modfns,function(self) 
                        function self:CanBuild(recipe_name) -- deprecated, use HasIngredients instead
                            return self:HasIngredients(_G.GetValidRecipe(recipe_name))
                        end
                        function self:HasIngredients(recipe)
                            debugPrint('Custom Builder:HasIngredients: ',recipe)
                            if type(recipe) == "string" then 
                                recipe = _G.GetValidRecipe(recipe)
                            end
                            if recipe ~= nil then
                                if self.freebuildmode then
                                    return true
                                end
                                local chests = getNearbyChest(self.inst)
                                for i, v in ipairs(recipe.ingredients) do
                                    if v.type == "oinc" and self.GetMoney then
                                        if self:GetMoney(self.inst.components.inventory) >= v.amount then
                                            return true
                                        end
                                    end
                                    local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod))
                                    found, num_found = findFromChests(chests, v.type)
                                    has, num_hold = self.inst.components.inventory:Has(v.type, amt)
                                    if recipe.name == "pickaxe" then
                                    end
                                    if (amt > num_found + num_hold) then
                                        return false
                                    end
                                end
                                for i, v in ipairs(recipe.character_ingredients) do
                                    if not self:HasCharacterIngredient(v) then
                                        return false
                                    end
                                end
                                for i, v in ipairs(recipe.tech_ingredients) do
                                    if not self:HasTechIngredient(v) then
                                        return false
                                    end
                                end
                                return true
                            end

                            return false
                        end
                        function self:RemoveIngredients(ingredients, recname)
                            debugPrint('Custom Builder:RemoveIngredients: ',ingredients,recname)
                            -- local recipe = _G.GetValidRecipe(recname)
                            local recipe = _G.AllRecipes[recname]
                            if recipe then
                                for k, v in pairs(recipe.ingredients) do
                                    local amt = math.max(1, _G.RoundBiasedUp(v.amount * self.ingredientmod))
                                    playerConsumeByName(self.inst, v.type, amt)
                                end
                            end

                            -- local recipe = AllRecipes[recname]
                            if recipe then
                                for k,v in pairs(recipe.character_ingredients) do
                                    if v.type == _G.CHARACTER_INGREDIENT.HEALTH then
                                        --Don't die from crafting!
                                        local delta = math.min(math.max(0, self.inst.components.health.currenthealth - 1), v.amount)
                                        self.inst:PushEvent("consumehealthcost")
                                        self.inst.components.health:DoDelta(-delta, false, "builder", true, nil, true)
                                    elseif v.type == _G.CHARACTER_INGREDIENT.MAX_HEALTH then
                                        self.inst:PushEvent("consumehealthcost")
                                        self.inst.components.health:DeltaPenalty(v.amount)
                                    elseif v.type == _G.CHARACTER_INGREDIENT.SANITY then
                                        self.inst.components.sanity:DoDelta(-v.amount)
                                    elseif v.type == _G.CHARACTER_INGREDIENT.MAX_SANITY then
                                        --[[
                                            Because we don't have any maxsanity restoring items we want to be more careful
                                            with how we remove max sanity. Because of that, this is not handled here.
                                            Removal of sanity is actually managed by the entity that is created.
                                            See maxwell's pet leash on spawn and pet on death functions for examples.
                                        --]]
                                    end
                                end
                            end
                            self.inst:PushEvent("consumeingredients")
                        end
                    end)
                end
            end
        end
    end)
end

-- DST part end
----------------------------------------------------------
---------------End Override Builder functions-------------

--Old override of the recipe tabs
--[[
local function GetHintTextForRecipe(player, recipe)
    local validmachines = {}
    local adjusted_level = _G.deepcopy(recipe.level)

    -- Adjust recipe's level for bonus so that the hint gives the right message
	local tech_bonus = player.replica.builder:GetTechBonuses()
	for k, v in pairs(adjusted_level) do
		adjusted_level[k] = math.max(0, v - (tech_bonus[k] or 0))
	end

    for k, v in pairs(_G.TUNING.PROTOTYPER_TREES) do
        local canbuild = _G.CanPrototypeRecipe(adjusted_level, v)
        if canbuild then
            table.insert(validmachines, {TREE = tostring(k), SCORE = 0})
        end
    end

    if #validmachines > 0 then
        if #validmachines == 1 then
            --There's only once machine is valid. Return that one.
            return validmachines[1].TREE
        end

        --There's more than one machine that gives the valid tech level! We have to find the "lowest" one (taking bonus into account).
        for k,v in pairs(validmachines) do
            for rk,rv in pairs(adjusted_level) do
                local prototyper_level = _G.TUNING.PROTOTYPER_TREES[v.TREE][rk]
                if prototyper_level and (rv > 0 or prototyper_level > 0) then
                    if rv == prototyper_level then
                        --recipe level matches, add 1 to the score
                        v.SCORE = v.SCORE + 1
                    elseif rv < prototyper_level then
                        --recipe level is less than prototyper level, remove 1 per level the prototyper overshot the recipe
                        v.SCORE = v.SCORE - (prototyper_level - rv)
                    end
                end
            end
        end

        table.sort(validmachines, function(a,b) return (a.SCORE) > (b.SCORE) end)

        return validmachines[1].TREE
    end

    return "CANTRESEARCH"
end

function RecipePopup:Refresh()
    local owner = self.owner
    if owner == nil then
        return false
    end

    local recipe = self.recipe
    local builder = owner.replica.builder
    local inventory = owner.replica.inventory

    local knows = builder:KnowsRecipe(recipe.name)
    local buffered = builder:IsBuildBuffered(recipe.name)
    local can_build = buffered or builder:CanBuild(recipe.name)
    local tech_level = builder:GetTechTrees()
    local should_hint = not knows and _G.ShouldHintRecipe(recipe.level, tech_level) and not _G.CanPrototypeRecipe(recipe.level, tech_level)

    self.skins_list = self:GetSkinsList()

    self.skins_options = self:GetSkinOptions() -- In offline mode, this will return the default option and nothing else

    if #self.skins_options == 1 then
        -- No skins available, so use the original version of this popup
        if self.skins_spinner ~= nil then
            self:BuildNoSpinner(self.horizontal)
        end
    else
        --Skins are available, use the spinner version of this popup
        if self.skins_spinner == nil then
            self:BuildWithSpinner(self.horizontal)
        end

        self.skins_spinner.spinner:SetOptions(self.skins_options)
        local last_skin = _G.Profile:GetLastUsedSkinForItem(recipe.name)
        if last_skin then
            self.skins_spinner.spinner:SetSelectedIndex(self:GetIndexForSkin(last_skin) or 1)
        end
    end

    self.name:SetTruncatedString(_G.STRINGS.NAMES[string.upper(self.recipe.product)], TEXT_WIDTH, self.smallfonts and 51 or 41, true)
    self.desc:SetMultilineTruncatedString(_G.STRINGS.RECIPE_DESC[string.upper(self.recipe.product)], 2, TEXT_WIDTH, self.smallfonts and 40 or 33, true)

    for i, v in ipairs(self.ing) do
        v:Kill()
    end

    self.ing = {}

    local num =
        (recipe.ingredients ~= nil and #recipe.ingredients or 0) +
        (recipe.character_ingredients ~= nil and #recipe.character_ingredients or 0) +
        (recipe.tech_ingredients ~= nil and #recipe.tech_ingredients or 0)
    local w = 64
    local div = 10
    local half_div = div * .5
    local offset = 315 --center
    if num > 1 then
        offset = offset - (w *.5 + half_div) * (num - 1)
    end

    local hint_tech_ingredient = nil

    for i, v in ipairs(recipe.tech_ingredients) do
        if v.type:sub(-9) == "_material" then
            local has, level = builder:HasTechIngredient(v)
            local ing = self.contents:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), nil, nil, has, _G.STRINGS.NAMES[string.upper(v.type)], owner, v.type))
            if _G.GetGameModeProperty("icons_use_cc") then
                ing.ing:SetEffect("shaders/ui_cc.ksh")
            end
            if num > 1 and #self.ing > 0 then
                offset = offset + half_div
            end
            ing:SetPosition(_G.Vector3(offset, self.skins_spinner ~= nil and 110 or 80, 0))
            offset = offset + w + half_div
            table.insert(self.ing, ing)
            if not has and hint_tech_ingredient == nil then
                hint_tech_ingredient = v.type:sub(1, -10):upper()
            end
        end
    end

    local total, need, has_chest, num_found_chest, has_inv, num_found_inv
    for i, v in ipairs(recipe.ingredients) do
        -- local has, num_found = inventory:Has(v.type, RoundBiasedUp(v.amount * builder:IngredientMod()))
        local validChestsOfIngredient = {}
        need = _G.RoundBiasedUp(v.amount * builder:IngredientMod())
        has_inv, num_found_inv = owner.replica.inventory:Has(v.type, need)
        has_chest, num_found_chest, validChestsOfIngredient = findFromNearbyChests(owner, v.type)

        total = num_found_chest + num_found_inv
        local ing = self.contents:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount, total, total >= need, _G.STRINGS.NAMES[string.upper(v.type)], owner, v.type))
        if _G.GetGameModeProperty("icons_use_cc") then
            ing.ing:SetEffect("shaders/ui_cc.ksh")
        end
        if num > 1 and #self.ing > 0 then
            offset = offset + half_div
        end
        ing:SetPosition(_G.Vector3(offset, self.skins_spinner ~= nil and 110 or 80, 0))
        offset = offset + w + half_div
        table.insert(self.ing, ing)
    end

    for i, v in ipairs(recipe.character_ingredients) do
        --#BDOIG - does this need to listen for deltas and change while menu is open?
        --V2C: yes, but the entire craft tabs does. (will be added there)
        local has, amount = builder:HasCharacterIngredient(v)
        local ing = self.contents:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount, amount, has, _G.STRINGS.NAMES[string.upper(v.type)], owner, v.type))
        if _G.GetGameModeProperty("icons_use_cc") then
            ing.ing:SetEffect("shaders/ui_cc.ksh")
        end
        if num > 1 and #self.ing > 0 then
            offset = offset + half_div
        end
        ing:SetPosition(_G.Vector3(offset, self.skins_spinner ~= nil and 110 or 80, 0))
        offset = offset + w + half_div
        table.insert(self.ing, ing)
    end

    local equippedBody = inventory:GetEquippedItem(_G.EQUIPSLOTS.BODY)
    local showamulet = equippedBody and equippedBody.prefab == "greenamulet"

    if should_hint or hint_tech_ingredient ~= nil then
        self.button:Hide()

        local str
        if should_hint then
            local hint_text =
            {
                ["SCIENCEMACHINE"] = "NEEDSCIENCEMACHINE",
                ["ALCHEMYMACHINE"] = "NEEDALCHEMYENGINE",
                ["SHADOWMANIPULATOR"] = "NEEDSHADOWMANIPULATOR",
                ["PRESTIHATITATOR"] = "NEEDPRESTIHATITATOR",
                ["CANTRESEARCH"] = "CANTRESEARCH",
                ["ANCIENTALTAR_HIGH"] = "NEEDSANCIENT_FOUR",
            }
            local prototyper_tree = GetHintTextForRecipe(owner, recipe)
            str = _G.STRINGS.UI.CRAFTING[hint_text[prototyper_tree] or ("NEEDS"..prototyper_tree)]
        else
            str = _G.STRINGS.UI.CRAFTING.NEEDSTECH[hint_tech_ingredient]
        end
        self.teaser:SetScale(TEASER_SCALE_TEXT)
        self.teaser:SetMultilineTruncatedString(str, 3, TEASER_TEXT_WIDTH, 38, true)
        self.teaser:Show()
        showamulet = false
    else
        self.teaser:Hide()

        local buttonstr =
            (not (knows or recipe.nounlock) and _G.STRINGS.UI.CRAFTING.PROTOTYPE) or
            (buffered and _G.STRINGS.UI.CRAFTING.PLACE) or
            _G.STRINGS.UI.CRAFTING.TABACTION[recipe.tab.str] or
            _G.STRINGS.UI.CRAFTING.BUILD

        if _G.TheInput:ControllerAttached() then
            self.button:Hide()
            self.teaser:Show()

            if can_build then
                self.teaser:SetScale(TEASER_SCALE_BTN)
                self.teaser:SetTruncatedString(_G.TheInput:GetLocalizedControl(_G.TheInput:GetControllerID(), _G.CONTROL_ACCEPT).." "..buttonstr, TEASER_BTN_WIDTH, 26, true)
            else
                self.teaser:SetScale(TEASER_SCALE_TEXT)
                self.teaser:SetMultilineTruncatedString((_G.STRINGS.UI.CRAFTING.TABNEEDSTUFF or {})[recipe.tab.str] or _G.STRINGS.UI.CRAFTING.NEEDSTUFF, 3, TEASER_TEXT_WIDTH, 38, true)
            end
        else
            self.button:Show()
            if self.skins_spinner ~= nil then
                self.button:SetPosition(320, -155, 0)
            else
                self.button:SetPosition(320, -105, 0)
            end
            self.button:SetScale(1,1,1)

            self.button:SetText(buttonstr)
            if can_build then
                self.button:Enable()
            else
                self.button:Disable()
            end
        end
    end

    if showamulet then
        self.amulet:Show()
    else
        self.amulet:Hide()
    end

    -- update new tags
    if self.skins_spinner then
        self.skins_spinner.spinner:Changed()
    end
end

]]

-- function CraftSlot:OnLoseFocus()
--     CraftSlot._base.OnLoseFocus(self)
--     unhighlight(highlit)
--     self:Close()
-- end
-- Fix for Hamlet by Vlad Undying <3
-- Thanks for the fix! -- Huan Wang

local INGREDIENTS_SCALE = 0.75
local Widget = require "widgets/widget"
local Image = require "widgets/image"

local GetGameModeProperty = _G.GetGameModeProperty
local EQUIPSLOTS = _G.EQUIPSLOTS
local resolvefilepath = GLOBAL.resolvefilepath
local CRAFTING_ATLAS = "images/crafting_menu.xml"
local RoundBiasedUp = _G.RoundBiasedUp
local CHARACTER_INGREDIENT = _G.CHARACTER_INGREDIENT

--need to change craftingmenu_ingredients as there the amount that is shown is calculated

AddClassPostConstruct("widgets/redux/craftingmenu_ingredients",function(self,owner, max_ingredients_wide, recipe, extra_quantity_scale)
    --local old_SetRecipe = self.SetRecipe
    function self:SetRecipe(recipe,...)
        if self.recipe ~= recipe then
            self.recipe = recipe
        end

        self:KillAllChildren()

        local atlas = resolvefilepath(CRAFTING_ATLAS)

        local owner = self.owner
        local builder = owner.replica.builder
        local inventory = owner.replica.inventory

        self.ingredient_widgets = {}
        local root = self:AddChild(Widget("root"))

        local equippedBody = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
        local showamulet = equippedBody and equippedBody.prefab == "greenamulet"

        local num = (recipe.ingredients ~= nil and #recipe.ingredients or 0)
                    + (recipe.character_ingredients ~= nil and #recipe.character_ingredients or 0)
                    + (recipe.tech_ingredients ~= nil and #recipe.tech_ingredients or 0)
                    + (showamulet and 1 or 0)


        local w = 64
        local div = 10
        local half_div = div * .5
        local offset = 0 --center
        if num > 1 then
            offset = offset - (w *.5 + half_div) * (num - 1)
        end

        self.num_items = num

        local scale = math.min(1, self.max_ingredients_wide / num)
        root:SetScale(scale * INGREDIENTS_SCALE)

        local quant_text_scale = math.max(1, 1/(scale*1.125))
        if self.extra_quantity_scale ~= nil then
            quant_text_scale = quant_text_scale * self.extra_quantity_scale
        end

        self.hint_tech_ingredient = nil

        for i, v in ipairs(recipe.tech_ingredients) do
            if v.type:sub(-9) == "_material" then
                local has, level = builder:HasTechIngredient(v)
                local ing = root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), nil, nil, has, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale))

                if GetGameModeProperty("icons_use_cc") then
                    ing.ing:SetEffect("shaders/ui_cc.ksh")
                end
                if num > 1 and #self.ingredient_widgets > 0 then
                    offset = offset + half_div
                end
                ing:SetPosition(offset, 0)
                offset = offset + w + half_div
                table.insert(self.ingredient_widgets, ing)
                if not has and self.hint_tech_ingredient == nil and not builder:IsFreeBuildMode() then
                    self.hint_tech_ingredient = v.type:sub(1, -10):upper()
                end
            end
        end

        local recipe_data = (self.owner.HUD.controls ~= nil and self.owner.HUD.controls.craftingmenu ~= nil) and owner.HUD.controls.craftingmenu:GetRecipeState(recipe.name) or nil
        local allow_ingredient_crafting = self.hint_tech_ingredient == nil and recipe_data ~= nil and recipe_data.meta.build_state ~= "hint" and recipe_data.meta.build_state ~= "hide"

        --the changes start here, check for the items in the chests in the vincinity
        local total, need, has_chest, num_found_chest, has_inv, num_found_inv
        for i, v in ipairs(recipe.ingredients) do
            --local has, num_found = inventory:Has(v.type, math.max(1, RoundBiasedUp(v.amount * builder:IngredientMod())), true)
            local ingredient_recipe_data = allow_ingredient_crafting and owner.HUD.controls.craftingmenu:GetRecipeState(v.type) or nil

            local validChestsOfIngredient = {}
            need = _G.RoundBiasedUp(v.amount * builder:IngredientMod())
            has_inv, num_found_inv = owner.replica.inventory:Has(v.type, need)
            has_chest, num_found_chest, validChestsOfIngredient = findFromNearbyChests(owner, v.type)

            total = num_found_chest + num_found_inv
            local ing = root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount ~= 0 and v.amount or nil, total, total >= need, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale, ingredient_recipe_data))
            if GetGameModeProperty("icons_use_cc") then
                ing.ing:SetEffect("shaders/ui_cc.ksh")
            end
            if num > 1 and #self.ingredient_widgets > 0 then
                offset = offset + half_div
            end
            ing:SetPosition(offset, 0)
            offset = offset + w + half_div
            table.insert(self.ingredient_widgets, ing)
        end

        for i, v in ipairs(recipe.character_ingredients) do
            --#BDOIG - does this need to listen for deltas and change while menu is open?
            --V2C: yes, but the entire craft tabs does. (will be added there)
            local has, amount = builder:HasCharacterIngredient(v)

            if v.type == CHARACTER_INGREDIENT.HEALTH and owner:HasTag("health_as_oldage") then
                v = Ingredient(CHARACTER_INGREDIENT.OLDAGE, math.ceil(v.amount * TUNING.OLDAGE_HEALTH_SCALE))
            end
            local ing = root:AddChild(IngredientUI(v:GetAtlas(), v:GetImage(), v.amount, amount, has, STRINGS.NAMES[string.upper(v.type)], owner, v.type, quant_text_scale))
            if GetGameModeProperty("icons_use_cc") then
                ing.ing:SetEffect("shaders/ui_cc.ksh")
            end
            if num > 1 and #self.ingredient_widgets > 0 then
                offset = offset + half_div
            end
            ing:SetPosition(offset, 0)
            offset = offset + w + half_div
            table.insert(self.ingredient_widgets, ing)
        end

        if showamulet then
            local amulet_atlas, amulet_img = equippedBody.replica.inventoryitem:GetAtlas(), equippedBody.replica.inventoryitem:GetImage()
            
            local amulet = root:AddChild(IngredientUI(amulet_atlas, amulet_img, 0.2, 0.2, true, STRINGS.GREENAMULET_TOOLTIP, owner, CHARACTER_INGREDIENT.MAX_HEALTH, quant_text_scale))
            amulet:SetPosition(offset + half_div, 0)
            table.insert(self.ingredient_widgets, amulet)

            for _, ing in ipairs(self.ingredient_widgets) do
                local glow = ing:AddChild(Image("images/global_redux.xml", "shop_glow.tex"))
                glow:SetTint(.8, .8, .8, 0.4)
                local len = 3
                local function doscale(start) if start then glow:SetScale(0) glow:ScaleTo(0, 0.5, len/2, doscale) else glow:ScaleTo(.5, 0, len/2) end end
                local function animate_glow() 
                    local t = math.random() * 360
                    glow:RotateTo(t, t-360, 3, animate_glow) 
                    doscale(true)
                end
                animate_glow()
            end

        end
    end   
    if recipe ~= nil then
        self:SetRecipe(recipe)
    end
end)

