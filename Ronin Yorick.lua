require "DamageLib"
require "HPred"
class "Ronin"
local isEvading 				= ExtLibEvade and ExtLibEvade.Evading
local _atan 						= math.atan2
local _pi 							= math.pi
local _max 							= math.max
local _min 							= math.min
local _abs 							= math.abs
local _sqrt 						= math.sqrt
local _find 						= string.find
local _sub 							= string.sub
local _len 							= string.len
local _huge 						= math.huge
local _insert						= table.insert
local LocalGameLatency				= Game.Latency
local LocalGameTimer 				= Game.Timer
local charName 						= myHero.charName
local isAioLoaded 					= false
local LocalGameHeroCount 			= Game.HeroCount;
local LocalGameHero 				= Game.Hero;
local LocalGameMinionCount 			= Game.MinionCount;
local LocalGameMinion 				= Game.Minion;
local LocalGameTurretCount 			= Game.TurretCount;
local LocalGameTurret 				= Game.Turret;
local LocalGameWardCount 			= Game.WardCount;
local LocalGameWard 				= Game.Ward;
local LocalGameObjectCount 			= Game.ObjectCount;
local LocalGameObject				= Game.Object;
local LocalGameMissileCount 		= Game.MissileCount;
local LocalGameMissile				= Game.Missile;
local LocalGameParticleCount		= Game.ParticleCount;
local LocalGameParticle				= Game.Particle;
local LocalGameCampCount			= Game.CampCount;
local LocalGameCamp					= Game.Camp;
local isEvading 					= ExtLibEvade and ExtLibEvade.Evading
local _targetedMissiles = {}
local _activeSkillshots = {}
print("Ronin Yorick Loaded")

Callback.Add("Load", function() Ronin:OnLoad() end)

function Ronin:OnLoad()
self:myMenu()
self:mySpells()
self.SpellsLoaded = false
Callback.Add("Tick", function() self:OnTick() end)
--Callback.Add("Draw", function() self:OnDraw() end)
end

function Ronin:mySpells()
self.Q = { range = 75, width = myHero:GetSpellData(_Q).width, delay = myHero:GetSpellData(_Q).delay, speed = myHero:GetSpellData(_Q).speed}
self.W = { range = 600, width = myHero:GetSpellData(_W).width, collision = false, myHero:GetSpellData(_W).delay, speed = myHero:GetSpellData(_W).speed }
self.E = { range = 700, width = myHero:GetSpellData(_E).width, delay = myHero:GetSpellData(_E), speed = myHero:GetSpellData(_E).speed }
self.R = { range = 600, width = myHero:GetSpellData(_R).width, delay = myHero:GetSpellData(_R).delay, speed = myHero:GetSpellData(_R).speed }
end

function Ronin:myMenu()
self.Ronin = MenuElement({id = "Ronin", name = "Ronin Yorick", type = MENU, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/champion/Yorick.png"})
self.Ronin:MenuElement({id = "Combo", name = "Combo", type = MENU, leftIcon = 
    "http://i.epvpimg.com/RHvqdab.png"})
self.Ronin:MenuElement({id = "Clears", name = "Clear", type = MENU, leftIcon = 
    "http://i.epvpimg.com/kASKcab.png"})

-- Combo
self.Ronin.Combo:MenuElement({id = "quse", name = "Use Q", leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/YorickQ.png"})
self.Ronin.Combo:MenuElement({id = "wuse", name = "Use W", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/YorickW.png"})
self.Ronin.Combo:MenuElement({id = "euse", name = "Use E", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/YorickE.png"})
self.Ronin.Combo:MenuElement({id = "ruse", name = "Use R default", leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/YorickR.png"})
self.Ronin.Combo:MenuElement({id = "wrin", name = "Use W-R Insec", leftIcon = "http://i.epvpimg.com/8rRreab.png"})

-- Clear
self.Ronin.Clears:MenuElement({id = "quse", name = "Use Q", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/YorickQ.png"})
self.Ronin.Clears:MenuElement({id = "sliderminion", name = "Minions", value = 1, min = 0, max =      10, step = 1})
end

function Ronin:GetTarget(range)
if _G.EOWLoaded then
  return EOW:GetTarget(range, EOW.ap_dec, myHero.pos)
elseif _G.SDK and _G.SDK.TargetSelector then
  return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
elseif _G.GOS then
  return GOS:GetTarget(range, "AP")
end
end

function HPred:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
local target
local aimPosition
for i = 1, LocalGameHeroCount() do
  local t = LocalGameHero(i)
  if t and self:CanTarget(t) and self:IsInRange(source, t.pos, range) then
    local immobileTime = self:GetImmobileTime(t)
    
    local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
    if immobileTime - interceptTime > timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
      target = t
      aimPosition = t.pos
      return target, aimPosition
    end
  end
end
end

function Ronin:IsReadyToCast(slot)
return Game.CanUseSpell(slot) == 0
end

function Ronin:IsValid(unit, pos, range)
return self:GetDistance(unit.pos, pos) <= range and unit.health > 0 and unit.isTargetable and unit.visible
end

function Ronin:GetDistanceSqr(p1, p2)
  local dx = p1.x - p2.x
  local dz = p1.z - p2.z
  return (dx * dx + dz * dz)
end

function Ronin:GetDistance(p1, p2)
  return _sqrt(self:GetDistanceSqr(p1, p2))
end

function Ronin:GetDistance2D(p1,p2)
  return _sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

function Ronin:GetHpPercent(unit)
  return unit.health / unit.maxHealth * 100
end

function Ronin:GetManaPercent(unit)
return unit.mana / unit.maxMana * 100
end

function Ronin:InFountain(unit)
if type(unit) ~= "userdata" then error("{InFountain}: bad argument #1 (userdata expected, got "..type(unit)..")") end
local range = Game.mapID() == SUMMONERS_RIFT and 1100 or 750
return unit.visible and unit.pos:DistanceTo(fountain)-unit.boundingRadius <= range
end

function Ronin:InShop(unit)
if type(unit) ~= "userdata" then error("{InShop}: bad argument #1 (userdata expected, got "..type(unit)..")") end
local range = Game.mapID() == SUMMONERS_RIFT and 1000 or 750
return unit.visible and unit.pos:DistanceTo(fountain)-unit.boundingRadius <= range
end

function Ronin:AngleBetween(p1, p2)
local theta = p1:Polar() - p2:Polar()
if theta < 0 then
  theta = theta + 360
end
if theta > 180 then
  theta = 360 - theta
end
return theta
end

function Ronin:IsFacing(unit, target)
if type(unit) ~= "userdata" then error("{IsFacing}: bad argument #1 (userdata expected, got "..type(unit)..")") end
if type(target) ~= "userdata" then error("{IsFacing}: bad argument #2 (userdata expected, got "..type(target)..")") end
return AngleBetween(unit.dir, target.pos-unit.pos) < 90
end

function Ronin:IsOnScreen(pos)
if type(pos) ~= "userdata" then error("{IsOnScreen}: bad argument #1 (vector expected, got "..type(pos)..")") end
local p = pos.pos2D
local res = Game.Resolution()
return p.x > 0 and p.y > 0 and p.x <= res.x and p.y <= res.y
end

function Ronin:UnderEnemyTurret(unit)
      for i = 1, Game.TurretCount() do
          local turret = Game.Turret(i)
          local range = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
          if turret.valid and turret.isEnemy and unit.pos:DistanceTo(turret.pos) <= range then
              return true
          end
      end
      return false
end

function Ronin:Ready(spell)
return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana
end

local _EnemyHeroes
function Ronin:GetEnemyHeroes()
  if #_EnemyHeroes > 0 then return _EnemyHeroes end
  _EnemyHeroes = {}
  for i = 1, LocalGameHeroCount() do
    local unit = LocalGameHero(i)
    if unit and unit.isEnemy then
        _insert(_EnemyHeroes, unit)
    end
end
return _EnemyHeroes
end

function Ronin:GetEnemyHeroesInRange(pos, range)
local _EnemyHeroes = {}
  for i = 1, LocalGameHeroCount() do
    local unit = LocalGameHero(i)
    if unit and unit.isEnemy and self:IsValid(unit, pos, range) then
      _insert(_EnemyHeroes, unit)
    end
  end
  return _EnemyHeroes
end

function Ronin:GetAllyHeroesInRange(pos, range)
local _AllyHeroes = {}	
  for i = 1, LocalGameHeroCount() do
    local unit = LocalGameHero(i)
    if unit and unit.isAlly and self:IsValid(unit, pos, range) then
      _insert(_AllyHeroes, unit)
    end
  end
  return _AllyHeroes
end

function Ronin:GetItemSlot(unit, id)
for i = ITEM_1, ITEM_7 do
  if unit:GetItemData(unit).itemID == id then
    return i
  end
end
return 0 -- 
end

-- Thank you Sikaka Amazing HPred Logic
--Will return the valid target who has the highest hit chance and meets all conditions (minHitChance, whitelist check, etc)
function HPred:GetUnreliableTarget(source, range, delay, speed, radius, checkCollision, minimumHitChance, whitelist)
local _validTargets = {}
for i = 1, Game.HeroCount() do
  local t = Game.Hero(i)
  if self:CanTarget(t) and (not whitelist or whitelist[t.charName]) then			
    local hitChance, aimPosition = self:GetHitchance(source, t, range, delay, speed, radius, checkCollision)		
    if hitChance >= minimumHitChance then
      _validTargets[t.charName] = {["hitChance"] = hitChance, ["aimPosition"] = aimPosition}
    end
  end
end

local rHitChance = 0
local rAimPosition
for targetName, targetData in pairs(_validTargets) do
  if targetData.hitChance > rHitChance then
    rHitChance = targetData.hitChance
    rAimPosition = targetData.aimPosition
  end		
end

if rHitChance >= minimumHitChance then
  return rHitChance, rAimPosition
end	
end

function Ronin:IsRecalling()
for K, Buff in pairs(GetBuffs(myHero)) do
  if Buff.name == "recall" and Buff.duration > 0 then
    return true
  end
end
return false
end

function Ronin:OnTick()

if myHero.dead or Game.IsChatOpen() == true or IsRecalling or InShop then return end

--combo, clear tick
if Orb.combo and self.target ~= nil and not isEvading then
  self:Combo(self.target)
elseif Orb.laneClear or Orb.jungleClear and not isEvading then
  self:Clear()
end
end

function Ronin:Combo(target)
if self.target == nil then return end
  local hitRate, aimPosition = HPred:GetImmobileTarget(myHero.pos, self.W.range, self.W.delay, self.W.speed,  self.W.width, self.W.collision, 1, nil)
  local hitRate2, aimPosition2 = HPred:GetImmobileTarget(myHero.pos, self.E.range, self.E.delay, self.E.speed,  self.E.width, self.E.collision, 1, nil)
    -- E --
  if self:IsOnScreen() and self:IsReadyToCast(_E) and self:IsValid(self.E.range - 5, self.target) and self.Ronin.Combo.euse:Value() then
      Control.CastSpell(HK_E, aimPosition2)
  end
    -- W -  R insec
  if self:IsOnScreen() and self:IsReadyToCast(_W) and self:IsValid(self.W.range - 5, self.target) and self.Ronin.Combo.wrin:Value() and self:IsReadyToCast(_R) then
    Control.CastSpell(HK_W, aimPosition)
    Control.CastSpell(HK_R, aimPosition)
      -- W --
  elseif self:IsOnScreen() and self:IsReadyToCast(_W) and self:IsValid(self.W.range, self.target) and self.Ronin.Combo.wuse:Value() then
    Control.CastSpell(HK_W, aimPosition)
  end
  -- R
  if self:IsOnScreen() and self:IsReadyToCast(_R) and self:IsValid(self.R.range, self.target) and self.Ronin.Combo.ruse:Value() then
    Control.CastSpell(HK_R, self.target)
  end
  -- Q --
if self:IsOnScreen() and self:IsReadyToCast(_Q) and self:IsValid(self.Q.range, self.target) and self.Ronin.Combo.quse:Value() then
  Control.KeyUp(HK_Q)
end
    --
end

function Ronin:Clear()

local qMinion

if Game.MinionCount() > self.Ronin.Clears.sliderminion:Value() then
  for i = 0, Game.MinionCount() do
    local m = Game.Minion(i)
    if m and m.isEnemy and m.valid and not m.dead then
      if self:GetDistance2D(myHero.pos:To2D(), m.pos:To2D()) < self.Q.range then
        qMinion = m
        break
      end
    end
  end
end
if qMinion ~= nil and self:IsReadyToCast(_Q) and self.Ronin.Clears.quse:Value() then
  Control.CastSpell(HK_Q)
end
end
--------------------------------------------------------------------------------------------------------------------------------------------------
class "Orb"

function Orb:GetMode()

self.combo, self.harass, self.lastHit, self.laneClear, self.jungleClear, self.canMove, self.canAttack = nil,nil,nil,nil,nil,nil,nil

  
if _G.EOWLoaded then

  local mode = EOW:Mode()

  self.combo = mode == 1
  self.harass = mode == 2
    self.lastHit = mode == 3
    self.laneClear = mode == 4
    self.jungleClear = mode == 4

  self.canmove = EOW:CanMove()
  self.canattack = EOW:CanAttack()
elseif _G.SDK then

  self.combo = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
  self.harass = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
    self.lastHit = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT]
    self.laneClear = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR]
    self.jungleClear = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR]

  self.canmove = _G.SDK.Orbwalker:CanMove(myHero)
  self.canattack = _G.SDK.Orbwalker:CanAttack(myHero)
elseif _G.GOS then

  local mode = GOS:GetMode()

  self.combo = mode == "Combo"
  self.harass = mode == "Harass"
    self.lastHit = mode == "Lasthit"
    self.laneClear = mode == "Clear"
    self.jungleClear = mode == "Clear"

  self.canMove = GOS:CanMove()
  self.canAttack = GOS:CanAttack()	
end
end

function Orb:Disable(bool)

if _G.SDK then
  _G.SDK.Orbwalker:SetMovement(not bool)
  _G.SDK.Orbwalker:SetAttack(not bool)
elseif _G.EOWLoaded then
  EOW:SetAttacks(not bool)
  EOW:SetMovements(not bool)
elseif _G.GOS then
  GOS.BlockMovement = bool
  GOS.BlockAttack = bool
end
end

function Orb:DisableAttacks(bool)

if _G.SDK then
  _G.SDK.Orbwalker:SetAttack(not bool)
elseif _G.EOWLoaded then
  EOW:SetAttacks(not bool)
elseif _G.GOS then
  GOS.BlockAttack = bool
end
end

function Orb:DisableMovement(bool)

if _G.SDK then
  _G.SDK.Orbwalker:SetMovement(not bool)
elseif _G.EOWLoaded then
  EOW:SetMovements(not bool)
elseif _G.GOS then
  GOS.BlockMovement = bool
end
end