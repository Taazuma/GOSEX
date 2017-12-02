require("DamageLib")

print("Ignite Loaded")

local TickH, TickL = 0, 0

local _AllyHeroes

function GetAllyHeroes()
  if _AllyHeroes then return _AllyHeroes end
  _AllyHeroes = {}
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isAlly then
      table.insert(_AllyHeroes, unit)
    end
  end
  return _AllyHeroes
end

local _EnemyHeroes

function GetEnemyHeroes()
  if _EnemyHeroes then return _EnemyHeroes end
  _EnemyHeroes = {}
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isEnemy then
      table.insert(_EnemyHeroes, unit)
    end
  end
  return _EnemyHeroes
end

function GetPercentHP(unit)
  if type(unit) ~= "userdata" then error("{GetPercentHP}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  return 100*unit.health/unit.maxHealth
end

function GetPercentMP(unit)
  if type(unit) ~= "userdata" then error("{GetPercentMP}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  return 100*unit.mana/unit.maxMana
end

function GetRange(spell)
  return myHero:GetSpellData(spell).range
end

function GetSpeed(spell)
    return myHero:GetSpellData(spell).speed
end

function GetWidth(spell)
    return myHero:GetSpellData(spell).width
end

local function GetBuffs(unit)
  local t = {}
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.count > 0 then
      table.insert(t, buff)
    end
  end
  return t
end
local function GetItemSlot(unit, id)
	  for i = ITEM_1, ITEM_7 do
	    if unit:GetItemData(i).itemID == id then
	      return i
	    end
	  end
	  return 0 
	end

function HasBuff(unit, buffname)
  if type(unit) ~= "userdata" then error("{HasBuff}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  if type(buffname) ~= "string" then error("{HasBuff}: bad argument #2 (string expected, got "..type(buffname)..")") end
  for i, buff in pairs(GetBuffs(unit)) do
    if buff.name == buffname then 
      return true
    end
  end
  return false
end

function GetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(unit).itemID == id then
      return i
    end
  end
  return 0 -- 
end

function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}--
end

function GetMinions(team) --> " " - All | 100 - Ally | 200 - Enemy | 300 - Jungle
    local Minions
    if Minions then return Minions end
    Minions = {}
    for i = 1, Game.MinionCount() do
        local Minion = Game.Minion(i)
        if team then
            if Minion.team == team then
                table.insert(Minions, Minion)
            end
        else
            table.insert(Minions, Minion)
        end
    end
    return Minions
end

function IsImmune(unit)
  if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  for i, buff in pairs(GetBuffs(unit)) do
    if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
      return true
    end
    if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then 
      return true
    end
  end
  return false
end 

function IsValidTarget(unit, range, checkTeam, from)
  local range = range == nil and math.huge or range
  if type(range) ~= "number" then error("{IsValidTarget}: bad argument #2 (number expected, got "..type(range)..")") end
  if type(checkTeam) ~= "nil" and type(checkTeam) ~= "boolean" then error("{IsValidTarget}: bad argument #3 (boolean or nil expected, got "..type(checkTeam)..")") end
  if type(from) ~= "nil" and type(from) ~= "userdata" then error("{IsValidTarget}: bad argument #4 (vector or nil expected, got "..type(from)..")") end
  if unit == nil or not unit.valid or not unit.visible or unit.dead or not unit.isTargetable or IsImmune(unit) or (checkTeam and unit.isAlly) then 
    return false 
  end 
  return unit.pos:DistanceTo(from and from or myHero) < range 
end

function CountAlliesInRange(point, range)
  if type(point) ~= "userdata" then error("{CountAlliesInRange}: bad argument #1 (vector expected, got "..type(point)..")") end
  local range = range == nil and math.huge or range 
  if type(range) ~= "number" then error("{CountAlliesInRange}: bad argument #2 (number expected, got "..type(range)..")") end
  local n = 0
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isAlly and not unit.isMe and IsValidTarget(unit, range, false, point) then
      n = n + 1
    end
  end
  return n
end

function CountEnemiesInRange(point, range)
  if type(point) ~= "userdata" then error("{CountEnemiesInRange}: bad argument #1 (vector expected, got "..type(point)..")") end
  local range = range == nil and math.huge or range 
  if type(range) ~= "number" then error("{CountEnemiesInRange}: bad argument #2 (number expected, got "..type(range)..")") end
  local n = 0
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if IsValidTarget(unit, range, true, point) then
      n = n + 1
    end
  end
  return n
end

local function CanUseSpell(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana
end

local fountain

for i = 1, Game.ObjectCount() do
  local object = Game.Object(i)
  if object.isEnemy or object.type ~= Obj_AI_SpawnPoint then 
    goto continue
  end
  fountain = object
  break
  ::continue::
end

function InFountain(unit)
  if type(unit) ~= "userdata" then error("{InFountain}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  local range = Game.mapID() == SUMMONERS_RIFT and 1100 or 750
  return unit.visible and unit.pos:DistanceTo(fountain)-unit.boundingRadius <= range
end

function InShop(unit)
  if type(unit) ~= "userdata" then error("{InShop}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  local range = Game.mapID() == SUMMONERS_RIFT and 1000 or 750
  return unit.visible and unit.pos:DistanceTo(fountain)-unit.boundingRadius <= range
end

local function AngleBetween(p1, p2)
  local theta = p1:Polar() - p2:Polar()
  if theta < 0 then
    theta = theta + 360
  end
  if theta > 180 then
    theta = 360 - theta
  end
  return theta
end

function IsFacing(unit, target)
  if type(unit) ~= "userdata" then error("{IsFacing}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  if type(target) ~= "userdata" then error("{IsFacing}: bad argument #2 (userdata expected, got "..type(target)..")") end
  return AngleBetween(unit.dir, target.pos-unit.pos) < 90
end

function IsOnScreen(pos)
  if type(pos) ~= "userdata" then error("{IsOnScreen}: bad argument #1 (vector expected, got "..type(pos)..")") end
  local p = pos.pos2D
  local res = Game.Resolution()
  return p.x > 0 and p.y > 0 and p.x <= res.x and p.y <= res.y
end

function UnderEnemyTurret(unit)
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            local range = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
            if turret.valid and turret.isEnemy and unit.pos:DistanceTo(turret.pos) <= range then
                return true
            end
        end
        return false
end

----------------------------------------------------------------------------------------------------------------------

local Config = MenuElement({type = MENU, name = "Ignite KS", id = "Igniten", leftIcon = "https://www.mobafire.com/images/summoner-spell/ignite.png"})

-- IG

Config:MenuElement({type = MENU, name = "Settings", id = "Igi"})

Config.Igi:MenuElement({type = MENU, name = "Ignite to kill?", id = "Ignite" , leftIcon = "https://www.mobafire.com/images/summoner-spell/ignite.png"})
Config.Igi.Ignite:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Igi.Ignite:MenuElement({name = "Enabled Always", id = "always", value = true})
Config.Igi.Ignite:MenuElement({name = "Only on Combo", id = "comboonly", value = false})

----------------------------------------------------------------------------------------------------------------------

function aGetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(i).itemID == id then
      return i
    end
  end
  return 0 --
end

function OnTick()

	if myHero.dead then return end

	Orb:GetMode()

	target = GetTarget(800)

	if Orb.combo and target ~= nil and Config.Igi.Ignite.comboonly:Value() then
		Ignite(target)
	elseif target ~= nil and Config.Igi.Ignite.always:Value() then
		Ignite(target)
	end
end

function GetTarget(range)
        local target, _ = nil, nil
        for i = 1, #GetEnemyHeroes() do
        local Enemy = GetEnemyHeroes()[i]
        if IsValidTarget(Enemy, range, false, myHero.pos) then
            local K = Enemy.health / getdmg("AA", Enemy, myHero)
            if not _ or K < _ then
                target = Enemy
                _ = K
            end
        end
    end
    return target
end
function GetDistance(p1,p2)
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana
end

function Ignite(target)
  if Config.Igi.Ignite.Enabled:Value() and myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
    iTarget = GetTarget(600)
    if iTarget and (iTarget.health+iTarget.shieldAD) <= (50+20*myHero.levelData.lvl) then
      Control.CastSpell(HK_SUMMONER_1, target)
    end
  elseif Config.Igi.Ignite.Enabled:Value() and myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
    iTarget = GetTarget(600)
    if iTarget and (iTarget.health+iTarget.shieldAD) <= (50+20*myHero.levelData.lvl) then
      Control.CastSpell(HK_SUMMONER_2, target)
    end
  end
end


--------------------------------------------------------------------------------------------------------------------------------------------------
--credits to D.noob-senpai

class "Orb"

function Orb:GetMode()

	combo, harass, lastHit, laneClear, jungleClear, canMove, canAttack = nil,nil,nil,nil,nil,nil,nil

		
	if _G.EOWLoaded then

		local mode = EOW:Mode()

		combo = mode == 1
		harass = mode == 2
	    lastHit = mode == 3
	    laneClear = mode == 4
	    jungleClear = mode == 4

		canmove = EOW:CanMove()
		canattack = EOW:CanAttack()
	elseif _G.SDK then

		combo = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
		harass = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
	   	lastHit = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT]
	   	laneClear = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR]
	   	jungleClear = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR]

		canmove = _G.SDK.Orbwalker:CanMove(myHero)
		canattack = _G.SDK.Orbwalker:CanAttack(myHero)
	elseif _G.GOS then

		local mode = GOS:GetMode()

		combo = mode == "Combo"
		harass = mode == "Harass"
	    lastHit = mode == "Lasthit"
	    laneClear = mode == "Clear"
	    jungleClear = mode == "Clear"

		canMove = GOS:CanMove()
		canAttack = GOS:CanAttack()	
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

