local Flask     = RegisterMod("Flask", 1)
local nipvar    = Isaac.GetEntityVariantByName("Nip")
local nipid     = Isaac.GetEntityTypeByName("Nip")
local fbatid    = Isaac.GetEntityTypeByName("Fake Battery")
local fbatvar   = Isaac.GetEntityVariantByName("Fake Battery")
local flaskitem = Isaac.GetItemIdByName("Flask")
local json = require("json")

Flask.internal_charge = 0
Flask.max_charge = 2
Flask.floor_nips = {}
Flask.floor_fbats = {}
Flask.pickup_distance = 20
Flask.cur_room = nil
Flask.cur_floor = nil
Flask.cur_room_entities = {}
Flask.pickedup = false
Flask.pickedup_changed = false
Flask.clear = false
Flask.seed = nil

function Flask:new_run()
  Isaac.DebugString("New run detected")
  self.internal_charge = 0
  self.floor_nips = {}
  self.floor_fbats = {}
  self.cur_room = nil
  self.cur_floor = nil
  self.cur_room_entities = {}
  self.pickedup = false
  self.pickedup_changed = false
  self.clear = false
end

function Flask:new_floor()
  Isaac.DebugString("new floor")
  self.floor_nips = {}
  self.floor_fbats = {}
  self:on_new_room()
end

function Flask:on_use()
  self:change_charge(-2)
end

function Flask:save()
  local data = "SEED\n" .. self.seed .. "\nFLOOR\n" .. self.cur_floor .. "\nCHARGE\n" .. self.internal_charge .. "\nNIPS\n" .. self.encode(self.floor_nips) .. "FAKEBATTERIES\n" .. self.encode(self.floor_fbats)
  self:SaveData(data)
end

function Flask.encode(table)
  local retstring = ""
  for key, value in pairs(table) do
    if next(value, nil) ~= nil then
      retstring = retstring .. "ROOM\n" .. key .. "\n"
      for i=1,#value do
        retstring = retstring .. "POS\n" .. value[i].x .. "\n" .. value[i].y .. "\n"
      end
    end
  end
  return retstring
end

function Flask:load()
  local curtable = nil
  local linehandler = nil
  local cur_room = nil
  local pos_storage = nil
  for line in self:LoadData():gmatch("[^\r\n]+") do
    if line == "NIPS" then
      curtable = self.floor_nips
    elseif line == "FAKEBATTERIES" then
      curtable = self.floor_fbats
    elseif line == "ROOM" then
      linehandler = "ROOM"
    elseif line == "POS" then
      linehandler = "POS"
    elseif line == "CHARGE" then
      linehandler = "CHARGE"
    elseif line == "SEED" then
      linehandler = "SEED"
    elseif line == "FLOOR" then
      linehandler = "FLOOR"
    else
      if linehandler == "ROOM" then
        curtable[tonumber(line)] = {}
        cur_room = tonumber(line)
      elseif linehandler == "POS" then
        if pos_storage == nil then
          pos_storage = {}
          pos_storage.x = tonumber(line)
        else
          pos_storage.y = tonumber(line)
          table.insert(curtable[cur_room], pos_storage)
          pos_storage = nil
        end
      elseif linehandler == "CHARGE" then
        self.internal_charge = tonumber(line)
      elseif linehandler == "SEED" then
        self.seed = tonumber(seed)
      end
    end
  end
end

function Flask:change_charge( num )
  local player = Isaac.GetPlayer(0)
  local newcharge = self.internal_charge + num
  if newcharge > self.max_charge then
    self.internal_charge = self.max_charge
  elseif newcharge < 0 then
    self.internal_charge = 0
  else
    self.internal_charge = self.internal_charge + num
  end
  self:update_charge()
end

function Flask:update_charge()
  local player = Isaac.GetPlayer(0)
  player:SetActiveCharge(self.internal_charge)
end

function Flask:post_update()
  local player = Isaac.GetPlayer(0)
  if player:GetActiveItem() == flaskitem then
    if not self.pickedup then
      self.pickedup_changed = true
    end
    self.pickedup = true
  else
    if self.pickedup then
      self.pickedup_changed = true
    end
    self.pickedup = false
  end
  if player:GetActiveItem() == flaskitem and player:GetActiveCharge() ~= self.internal_charge then
    self:update_charge()
  end
  local room = Game():GetRoom()
  local roomseed = room:GetSpawnSeed()
  if self.cur_room ~= roomseed then
    self:on_new_room(roomseed)
  elseif room:IsClear() then
    self:save()
  end
  local level = Game():GetLevel()
  if self.cur_floor ~= level:GetStage() then
    self.cur_floor = level:GetStage()
    self:new_floor()
  end
  local ents = Isaac.GetRoomEntities()
  for i=1,#ents do
    if not self.cur_room_entities[ents[i]] then
      if self.pickedup and ents[i].Type == 5 and ents[i].Variant == 90 then
        local pos = ents[i].Position
        ents[i]:Remove()
        Isaac.Spawn(fbatid, fbatvar, 0, pos, Vector(0,0), player)
      elseif not self.pickedup and ents[i].Type == fbatid and ents[i].Variant == fbatvar then
        local pos = ents[i].Position
        ents[i]:Remove()
        Isaac.Spawn(5, 90, 0, pos, Vector(0,0), player)
        self:is_registered(self.floor_fbats, pos, true)
      end
      self.cur_room_entities[ents[i]] = true
    end
  end

  self.pickedup_changed = false
end

function Flask:on_new_room(room)
  self.cur_room = room
  if self.floor_nips[room] == nil then
    self.floor_nips[room] = {}
  end
  local roomnips = self.floor_nips[room]
  for i=1,#roomnips do
    Isaac.Spawn(nipid, nipvar, 0, Vector(roomnips[i].x, roomnips[i].y), Vector(0, 0), player)
  end
  if self.floor_fbats[room] == nil then
    self.floor_fbats[room] = {}
  end
  local roomfbats = self.floor_fbats[room]
  if self.pickedup then
    for i=1,#roomfbats do
      Isaac.Spawn(fbatid, fbatvar, 0, Vector(roomfbats[i].x, roomfbats[i].y), Vector(0, 0), player)
    end
  else
    for i=1,#roomfbats do
      Isaac.Spawn(5, 90, 0, Vector(roomfbats[i].x, roomfbats[i].y), Vector(0, 0), player)
      self:is_registered(self.floor_fbats, Vector(roomfbats[i].x, roomfbats[i].y), true)
    end
  end
  self.cur_room_entities = {}
end

function Flask:is_registered(list, pos, remove)
  local spawnseed = Game():GetRoom():GetSpawnSeed()
  local inroom = list[spawnseed]
  for i=1,#inroom do
    if pos.X == inroom[i].x and pos.Y == inroom[i].y then
      if remove then
        table.remove(list[spawnseed], i)
      end
      return true
    end
  end
  return false
end

function Flask:on_null_entity_update( npc )
  if npc.Variant == nipvar then
    self:on_nip_update(npc)
  elseif npc.Variant == fbatvar then
    self:on_fakebattery_update(npc)
  end
end

function Flask:on_nip_update(npc)
  local player = Isaac.GetPlayer(0)
  if not self:is_registered(self.floor_nips, npc.Position, false) then
    local spawnseed = Game():GetRoom():GetSpawnSeed()
    local insert = {}
    insert.x = npc.Position.X
    insert.y = npc.Position.Y
    table.insert(self.floor_nips[spawnseed], insert)
    Isaac.DebugString("nip registered at (" .. npc.Position.X .. ", " .. npc.Position.Y .. ")")
  end
  if player:GetActiveItem() == flaskitem and self.internal_charge ~= self.max_charge and npc.Variant == nipvar then
    if player.Position.X > (npc.Position.X - self.pickup_distance) and
       player.Position.X < (npc.Position.X + self.pickup_distance) and
       player.Position.Y > (npc.Position.Y - self.pickup_distance) and
       player.Position.Y < (npc.Position.Y + self.pickup_distance) then
      npc:Remove()
      self:is_registered(self.floor_nips, npc.Position, true)
      self:change_charge(2)
    end
  end
end

function Flask:on_fakebattery_update(npc)
  if not self:is_registered(self.floor_fbats, npc.Position, false) then
    local spawnseed = Game():GetRoom():GetSpawnSeed()
    local insert = {}
    insert.x = npc.Position.X
    insert.y = npc.Position.Y
    table.insert(self.floor_fbats[spawnseed], insert)
    Isaac.DebugString("fakebattery registered at (" .. npc.Position.X .. ", " .. npc.Position.Y .. ")")
  end
end

function Flask:on_init()
  self:load()
  local rng = RNG()
  if self.seed ~= rng:GetSeed() then
    self.seed = rng:GetSeed()
    self:new_run()
  end
end

Flask:AddCallback( ModCallbacks.MC_USE_ITEM, Flask.on_use, flaskitem )
Flask:AddCallback( ModCallbacks.MC_POST_UPDATE, Flask.post_update, -1 )
Flask:AddCallback( ModCallbacks.MC_NPC_UPDATE, Flask.on_null_entity_update, nipid )
Flask:AddCallback( ModCallbacks.MC_POST_PLAYER_INIT, Flask.on_init )
