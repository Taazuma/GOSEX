require "DamageLib"
require "HPred"
class "Ronin"
--Thanks to DamnedNoob
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
print("Ronin Tune Loaded")

Callback.Add("Load", function() Ronin:OnLoad() end)

function Ronin:OnLoad()
self:myMenu()
self:mySpells()
self.SpellsLoaded = false
Callback.Add("Tick", function() self:OnTick() end)
--Callback.Add("Draw", function() self:OnDraw() end)
end

function Ronin:mySpells()
self.Q = { range = 1125, width = myHero:GetSpellData(_Q).width, delay = 0.15, speed = myHero:GetSpellData(_Q).speed}
self.W = { range = 50, width = myHero:GetSpellData(_W).width, collision = false, delay = 0.10, speed = myHero:GetSpellData(_W).speed }
self.E = { range = 425, width = myHero:GetSpellData(_E).width, delay = 0.15, speed = myHero:GetSpellData(_E).speed }
self.R = { range = 2500, width = myHero:GetSpellData(_R).width, delay = 0.15, speed = math.huge }
end

function Ronin:myMenu()
self.Ronin = MenuElement({id = "Ronin", name = "Ronin Tune", type = MENU, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/champion/Nocturne.png"})
self.Ronin:MenuElement({id = "Combo", name = "Combo", type = MENU, leftIcon = 
    "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/passive/Nocturne_UmbraBlades.png"})
self.Ronin:MenuElement({id = "Clears", name = "Clear", type = MENU, leftIcon = 
    ""})

-- Combo
self.Ronin.Combo:MenuElement({id = "ComboOption", name = "Combo Settings", type = MENU})
self.Ronin.Combo.ComboOption:MenuElement({id = "firstc", name = "R - E - W - Q", value = false, type = MENU})
self.Ronin.Combo.ComboOption:MenuElement({id = "twoc", name = "R - E - Q", value = false, type = MENU})
self.Ronin.Combo.ComboOption:MenuElement({id = "threec", name = "R - Q - E", value = true, type = MENU})
self.Ronin.Combo:MenuElement({id = "quse", name = "Use Q", type = MENU, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneDuskbringer.png"})
self.Ronin.Combo:MenuElement({id = "wuse", name = "W Settings", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneShroudofDarkness.png"})
self.Ronin.Combo.wuse:MenuElement({id = "spells", name = "Use W for Spells to block", type = MENU})
self.Ronin.Combo.wuse.spells:MenuElement({id = "wblock", name = "Use W Spell block", value = true})
self.Ronin.Combo:MenuElement({id = "euse", name = "Use E", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneUnspeakableHorror.png"})
self.Ronin.Combo:MenuElement({id = "ruse", name = "Use Normal R", leftIcon = 
    "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneParanoia.png"})

-- Clear
self.Ronin.Clears:MenuElement({id = "quse", name = "Use Q", value = true, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneDuskbringer.png"})
self.Ronin.Clears:MenuElement({id = "euse", name = "Use E", value = false, leftIcon = "https://ddragon.leagueoflegends.com/cdn/8.17.1/img/spell/NocturneUnspeakableHorror.png"})
self.Ronin.Clears:MenuElement({id = "usemana", name = "Mana Usage", value = 50, min = 0, max =      100, step = 1, leftIcon = "http://i.epvpimg.com/IxTxcab.png"})
self.Ronin.Clears:MenuElement({id = "sliderminion", name = "Minions", value = 2, min = 0, max =      10, step = 1})
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

--Full Credits to DamnedNoob kappa
function Ronin:LoadBlockSpells()
for i = 1, LocalGameHeroCount(i) do
  local t = LocalGameHero(i)
  if t and t.isEnemy then		
    for slot = 0, 3 do
      local enemy = t
      local spellName = enemy:GetSpellData(slot).name
      if slot == 0 then
        self.Ronin.Combo.quse.spells:MenuElement({ id = spellName, name = enemy.charName.."- Q", value = true })
      end
      if slot == 1 then
        self.Ronin.Combo.quse.spells:MenuElement({ id = spellName, name = enemy.charName.."- W", value = true })
      end
      if slot == 2 then
        self.Ronin.Combo.quse.spells:MenuElement({ id = spellName, name = enemy.charName.."- E", value = true })
      end
      if slot == 3 then
        self.Ronin.Combo.quse.spells:MenuElement({ id = spellName, name = enemy.charName.."- R", value = true })
      end			
    end
  end
end
end

function Ronin:OnTick()

if myHero.dead or Game.IsChatOpen() == true or IsRecalling or InShop then return end

Orb:GetMode()
  self.target = self:GetTarget(800)
if not self.SpellsLoaded then --Credits to DamnedNoob
  self:LoadBlockSpells()
  self.SpellsLoaded = true
end
--Credits to DamnedNoob
if self:IsReadyToCast(_W) and self.Ronin.Combo.wuse.spells.wblock:Value() and self.SpellsLoaded == true then
  for i = 1, #self:GetEnemyHeroesInRange(myHero.pos, 2000) do
    local current = self:GetEnemyHeroesInRange(myHero.pos, 2000)[i]
    if current then
      if current.activeSpell and current.activeSpell.valid and
        (current.activeSpell.target == myHero.handle or 
          self:GetDistance(current.activeSpell.placementPos, myHero.pos) <= myHero.boundingRadius * 2 + current.activeSpell.width) and not 
          _find(current.activeSpell.name:lower(), "attack") then
        for j = 0, 3 do
          local spell = current:GetSpellData(j)
          if self.Ronin.Combo.wuse.spells[spell.name] and self.Ronin.Combo.wuse.spells[spell.name]:Value() and spell.name == current.activeSpell.name then
            local startPos = current.activeSpell.startPos
            local placementPos = current.activeSpell.placementPos
            local width = 0
            if current.activeSpell.width > 0 then
              width = current.activeSpell.width
            else
              width = 100
            end
            local distance = self:GetDistance(myHero.pos, placementPos)											
            if current.activeSpell.target == myHero.handle then
              Control.CastSpell(HK_W)
              return
            else
              if distance <= width * 2 + myHero.boundingRadius then
                Control.CastSpell(HK_W)
                break
              end
            end							
          end
        end
      end
    end
  end
end
--Combo onTick
if Orb.combo and self.target ~= nil and not isEvading then
  self:Combo(self.target)
elseif Orb.laneClear or Orb.jungleClear and not isEvading then
  self:Clear()
end
end

function Ronin:Combo(target)
if self.target == nil then return end
  if self.RoninCombo.ComboOption.firstc:Value() then
    --R Normal
    if self:IsReadyToCast(_R) and self.Ronin.Combo.ruse:Value() then
      Control.CastSpell(HK_R)
      Control.CastSpell(HK_R, self.target)
    end
    --E
    if self:IsReadyToCast(_E) and self:IsValid(self.target, myHero.pos, self.E.range) and self.Ronin.Combo.euse:Value() then
      Control.CastSpell(HK_E, self.target)
    end
    --W
    if self:IsReadyToCast(_W) and not self:IsValid(self.target, myHero.pos, 500) and self.Ronin.Combo.wuse:Value() then
      Control.CastSpell(HK_W)
    end
    --Q
    local hitRate, aimPosition = HPred:GetImmobileTarget(myHero.pos, self.Q.range, self.Q.delay, self.Q.speed, self.Q.width, self.Q.collision, 1, nil)
    if self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    elseif self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    end
  elseif self.RoninCombo.ComboOption.twoc:Value() then
        --R Normal
    if self:IsReadyToCast(_R) and self.Ronin.Combo.ruse:Value() then
      Control.CastSpell(HK_R)
      Control.CastSpell(HK_R, self.target)
    end
    if self:IsReadyToCast(_E) and self:IsValid(self.target, myHero.pos, self.E.range) and self.Ronin.Combo.euse:Value() then
      Control.CastSpell(HK_E, self.target)
    end
    if self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    elseif self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    end
  elseif self.RoninCombo.ComboOption.threec:Value() then
    if self:IsReadyToCast(_R) and self.Ronin.Combo.ruse:Value() then
      Control.CastSpell(HK_R)
      Control.CastSpell(HK_R, self.target)
    end
    if self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    elseif self:IsReadyToCast(_Q) and self:IsValid(self.target, myHero.pos, self.Q.range) and self.Ronin.Combo.quse:Value() then
      Control.CastSpell(HK_Q, aimPosition)
    end
    if self:IsReadyToCast(_E) and self:IsValid(self.target, myHero.pos, self.E.range) and self.Ronin.Combo.euse:Value() then
      Control.CastSpell(HK_E, self.target)
    end
    --
  end
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

if qMinion ~= nil and self:IsReadyToCast(_E) and self.Ronin.Clears.euse:Value() and
    self:GetManaPercent(myHero) > self.Ronin.Clears.usemana:Value() then
    Control.CastSpell(HK_E, qMinion)
end
if qMinion ~= nil and self:IsReadyToCast(_Q) and self.Ronin.Clears.quse:Value() and
  self:GetManaPercent(myHero) > self.Ronin.Clears.usemana:Value() then
  Control.CastSpell(HK_Q, qMinion)
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