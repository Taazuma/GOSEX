--if myHero.charName ~= "Akali" then return end

require("DamageLib")

print("Cazza's Akali Loaded.")
print("new Changes by Taazuma.")

local TickH, TickL = 0, 0

local _AllyHeroes

local Item_HK = {
	    [ITEM_1] = HK_ITEM_1,
	    [ITEM_2] = HK_ITEM_2,
	    [ITEM_3] = HK_ITEM_3,
	    [ITEM_4] = HK_ITEM_4,
	    [ITEM_5] = HK_ITEM_5,
	    [ITEM_6] = HK_ITEM_6,
	}

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

-------------------------------------------------AKALI-----------------------------------------------------------------

local Config = MenuElement({type = MENU, name = "Akali", id = "Akali", leftIcon = "http://ddragon.leagueoflegends.com/cdn/6.24.1/img/champion/Akali.png"})

-- COMBO

Config:MenuElement({type = MENU, name = "Combo Settings", id = "Combo"})

Config.Combo:MenuElement({type = MENU, name = "Mark of the Assassin (Q)", id = "Q", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliMota.png"})
Config.Combo.Q:MenuElement({name = "Enabled", id = "Enabled", value = true})

Config.Combo:MenuElement({type = MENU, name = "Twilight Shroud (W)", id = "W", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliSmokeBomb.png"})
Config.Combo.W:MenuElement({name = "Enabled", id = "Enabled", value = true})

Config.Combo:MenuElement({type = MENU, name = "Crescent Slash (E)", id = "E", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliShadowSwipe.png"})
Config.Combo.E:MenuElement({name = "Enabled", id = "Enabled", value = true})

Config.Combo:MenuElement({type = MENU, name = "Shadow Dance (R)", id = "R", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliShadowDance.png"})
Config.Combo.R:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Combo:MenuElement({type = MENU, name = "Ignite to kill?", id = "Ignite" , leftIcon = "http://i.imgur.com/c5Aoc9v.jpg"})
Config.Combo.Ignite:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Combo.R:MenuElement({name = "Turret Check", id = "Turret", value = true})
Config.Combo.R:MenuElement({type = MENU, name = "GapClose Settings", id = "GapClose"})
Config.Combo.R.GapClose:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Combo.R.GapClose:MenuElement({name = "Min. R Stacks", id = "Stacks", value = 1, min = 0, max = 3, step = 1})
Config.Combo.R.GapClose:MenuElement({name = "Max. Enemies Around Target", id = "Enemies", value = 0, min = 0, max = 4, step = 1})

-- HARASS

Config:MenuElement({type = MENU, name = "Harass Settings", id = "Harass"})

Config.Harass:MenuElement({type = MENU, name = "Mark of the Assassin (Q)", id = "Q", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliMota.png"})
Config.Harass.Q:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Harass.Q:MenuElement({type = MENU, name = "Auto Q Settings", id = "Auto"})
Config.Harass.Q.Auto:MenuElement({name = "Enabled", id = "Enabled", value = false})
Config.Harass.Q.Auto:MenuElement({name = "Energy Manager", id = "Energy", value = 100, min = 0, max = 200, step = 5})
Config.Harass.Q.Auto:MenuElement({type = MENU, name = "White List", id = "WhiteList"})
for _, Enemy in pairs(GetEnemyHeroes()) do
        Config.Harass.Q.Auto.WhiteList:MenuElement({name = Enemy.charName, id = Enemy.charName, value = true})
end

Config.Harass:MenuElement({type = MENU, name = "Crescent Slash (E)", id = "E", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliShadowSwipe.png"})
Config.Harass.E:MenuElement({name = "Enabled", id = "Enabled", value = true})

Config.Harass:MenuElement({name = "Energy Manager", id = "Energy", value = 100, min = 0, max = 200, step = 5})

	-- Clear
Config.Clears:MenuElement({id = "Clears", name = "Clear", type = MENU})
Config.Clears:MenuElement({id = "quse", name = "Use [Q]", value = true, leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliMota.png"})
Config.Clears:MenuElement({id = "quse", name = "Use [E]", value = true, leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliShadowSwipe.png"})
Config.Clears:MenuElement({id = "usemana", name = "Usage", value = 25, min = 0, max =      100, step = 1})
Config.Clears:MenuElement({id = "sliderminion", name = "Minions", value = 3, min = 0, max =      10, step = 1})

-- LASTHIT

Config:MenuElement({type = MENU, name = "Last Hit Settings", id = "LastHit"})

Config.LastHit:MenuElement({type = MENU, name = "Mark of the Assassin (Q)", id = "Q", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliMota.png"})
Config.LastHit.Q:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.LastHit.Q:MenuElement({type = MENU, name = "Auto Q Settings", id = "Auto"})
Config.LastHit.Q.Auto:MenuElement({name = "Enabled", id = "Enabled", value = false})
Config.LastHit.Q.Auto:MenuElement({name = "Energy Manager", id = "Energy", value = 100, min = 0, max = 200, step = 5})

Config.LastHit:MenuElement({type = MENU, name = "Crescent Slash (E)", id = "E", leftIcon = "http://static.lolskill.net/img/abilities/64/AkaliShadowSwipe.png"})
Config.LastHit.E:MenuElement({name = "Enabled", id = "Enabled", value = true})

Config.LastHit:MenuElement({name = "Energy Manager", id = "Energy", value = 100, min = 0, max = 200, step = 5})

-- KEYS

Config:MenuElement({type = MENU, name = "Key Settings", id = "Key"})

Config.Key:MenuElement({id = "Combo", name = "Combo", key = 32})
Config.Key:MenuElement({id = "Harass", name = "Harass", key = string.byte("C")})
Config.Key:MenuElement({id = "Flee", name = "Flee", key = string.byte("A")})
Config.Key:MenuElement({id = "LastHit", name = "Last Hit", key = string.byte("X")})
Config.Key:MenuElement({id = "Clears", name = "Farm/Clears", key = string.byte("V")})
Config.Key:MenuElement({id = "HarassAuto", name = "Auto Harass Q", key = string.byte("T")})
Config.Key:MenuElement({id = "LastHitAuto", name = "Auto LastHit Q", key = string.byte("G")})

-- ITEMS

Config:MenuElement({type = MENU, id = "Items", name = "Item Settings"})

Config.Items:MenuElement({type = MENU, id = "useGun", name = "Hextech Gunblade", leftIcon = "http://i.imgur.com/MOImtq7.jpg"})
Config.Items.useGun:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Items:MenuElement({type = MENU, id = "useCut", name = "Bilgewater Cutlass", leftIcon = "http://i.imgur.com/2gXYWvs.png"})
Config.Items.useCut:MenuElement({name = "Enabled", id = "Enabled", value = true})
Config.Items:MenuElement({type = MENU, id = "Zhonya", name = "Use Zhonya", leftIcon = "http://i.imgur.com/YdsxCnx.png"})
Config.Items.Zhonya:MenuElement({name = "Enabled", id = "Enabled", value = true})

-- DRAW

Config:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})

Config.Draw:MenuElement({id = "DrawQ", name = "Draw Q (Green)", value = true})
Config.Draw:MenuElement({id = "DrawE", name = "Draw E (Blue)", value = false})
Config.Draw:MenuElement({id = "DrawR", name = "Draw R (Red)", value = false})

--------------------------------------------------------------------------------

function aGetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(i).itemID == id then
      return i
    end
  end
  return 0 --
end
function OnTick()
			local Zhonya = aGetItemSlot(myHero,3157)
			local myHpPC=(myHero.health/myHero.maxHealth)*100
			local zhonyaPC=20
      if Orb.laneClear or Orb.jungleClear then
      Clear()
      end
				if Zhonya >= 1 and Config.Items.Zhonya.Enabled:Value() and CanUseSpell(Zhonya) and myHpPC<=zhonyaPC then
                Control.CastSpell(Item_HK[Zhonya])
            end
        SwitchHarass()
        SwitchLastHit()
        if not myHero.dead then
                local target = GetTarget(3000)
                if target then
                        Combo(target)
                        Harass(target)
                        AutoHarass()
                end
                LastHit()
                AutoLastHit()
				Flee()
        end
end

function MinionForGap(target)
        local ClosestMinion, NearestDistance = nil, 0

        for _, Minion in pairs(GetMinions()) do
                if Minion.isEnemy and not Minion.dead then
                        if myHero.pos:DistanceTo(Minion.pos) <= GetRange(_R) and target and target.pos:DistanceTo(Minion.pos) <= GetRange(_R) then
                                if NearestDistance < myHero.pos:DistanceTo(Minion.pos) then
                                        NearestDistance = myHero.pos:DistanceTo(Minion.pos)
                    ClosestMinion = Minion
                                end
                        end
                end
        end
    return ClosestMinion
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


function Combo(target)
        if Config.Key.Combo:Value() then
				if Config.Combo.E.Enabled:Value() and Ready(_E) and IsValidTarget(target, GetRange(_W), false, myHero.pos) then
                            Control.CastSpell(HK_E)
						end
                if Config.Combo.Q.Enabled:Value() and CanUseSpell(myHero, _Q ) and IsValidTarget(target, GetRange(_Q), false, myHero.pos) then
                            Control.CastSpell(HK_Q, target.pos)
                        end
				if Config.Combo.W.Enabled:Value() and Ready(_W) then
							Control.CastSpell(HK_W)
						end
				if Config.Combo.Ignite.Enabled:Value() and myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
					iTarget = GetTarget(600)
					if iTarget and (iTarget.health+iTarget.shieldAD) <= (50+20*myHero.levelData.lvl) then
						Control.CastSpell(HK_SUMMONER_1, target)
						end
				elseif Config.Combo.Ignite.Enabled:Value() and myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
					iTarget = GetTarget(600)
					if iTarget and (iTarget.health+iTarget.shieldAD) <= (50+20*myHero.levelData.lvl) then
						Control.CastSpell(HK_SUMMONER_2, target)
						end
					end
				local gun = aGetItemSlot(myHero,3146)
				local CutBlade = aGetItemSlot(myHero,3144)
				if gun >= 1 and GetDistance(myHero.pos,target.pos) <= 690 + 25 and Config.Items.useGun.Enabled:Value() then
					if CanUseSpell(gun) then
						Control.CastSpell(Item_HK[gun],target.pos)
						end
					end
				if CutBlade >= 1 and GetDistance(myHero.pos,target.pos) <= 690 + 25 and Config.Items.useCut.Enabled:Value() then
					if CanUseSpell(CutBlade) then
						Control.CastSpell(Item_HK[CutBlade],target.pos)
						end
					end
                if Config.Combo.R.Enabled:Value() and Ready(_R) and IsValidTarget(target, GetRange(_R), false, myHero.pos) then
                                if Config.Combo.R.Turret:Value() then
                                        if not UnderEnemyTurret(target) then
                                                Control.CastSpell(HK_R, target.pos)
                        end
                                else
                                        Control.CastSpell(HK_R, target.pos)
                        end
                        if Config.Combo.R.GapClose.Enabled:Value() and Ready(_R) and IsValidTarget(target, GetRange(_R) * 2 + 100, false, myHero.pos) then
                                if myHero.pos:DistanceTo(target.pos) > GetRange(_R) then
                                        if MinionForGap(target) ~= nil and myHero:GetSpellData(_R).ammo > Config.Combo.R.GapClose.Stacks:Value() and CountEnemiesInRange(target, 950) <= Config.Combo.R.GapClose.Enemies:Value() then
                                                if Config.Combo.R.Turret:Value() then
                                                    if not UnderEnemyTurret(target) then
                                                            Control.CastSpell(HK_R, MinionForGap(target).pos)
                        end
                                            else
                                                    Control.CastSpell(HK_R, MinionForGap(target).pos)
                        end
					end
                end                
            end
        end
    end
end

function Clear()
  	        for _, minion in pairs(GetMinions()) do
		if minion and minion.isEnemy and not minion.dead and GetDistance(myHero.pos, minion.pos) <= GetRange(_Q) then
                if Config.Key.Clears:Value() and myHero.mana >= Config.Clears.usemana:Value() then
                    if Config.Clears.quse.Enabled:Value() and Ready(_Q) and IsValidTarget(minion, GetRange(_Q), false, myHero.pos) and getdmg("Q", minion, myHero) > minion.health then
                                    Control.CastSpell(HK_Q, minion.pos)
                end
                    if Config.Clears.euse.Enabled:Value() and Ready(_E) and IsValidTarget(minion, GetRange(_E), false, myHero.pos) and minion > Config.Clears.sliderminion:Value() then
                                    Control.CastSpell(HK_E)
                end
			end
		end
	end
end

function Flee()
        if Config.Key.Flee:Value() then
			if Ready(_W) then
				Control.CastSpell(HK_W)
				end
		end
end
		
function Harass(target)
        if Config.Key.Harass:Value() and myHero.mana >= Config.Harass.Energy:Value() then
                if Config.Harass.Q.Enabled:Value() and Ready(_Q) and IsValidTarget(target, GetRange(_Q), false, myHero.pos) then
                                Control.CastSpell(HK_Q, target.pos)
                        end
                if Config.Harass.E.Enabled:Value() and Ready(_E) and IsValidTarget(target, GetRange(_E), false, myHero.pos) then
                                Control.CastSpell(HK_E)
                        end
        end
end

function LastHit()
        for _, minion in pairs(GetMinions()) do
		if minion and minion.isEnemy and not minion.dead and GetDistance(myHero.pos, minion.pos) <= GetRange(_Q) then
                if Config.Key.LastHit:Value() and myHero.mana >= Config.LastHit.Energy:Value() then
                    if Config.LastHit.Q.Enabled:Value() and Ready(_Q) and IsValidTarget(minion, GetRange(_Q), false, myHero.pos) and getdmg("Q", minion, myHero) > minion.health then
                                    Control.CastSpell(HK_Q, minion.pos)
                end
                    if Config.LastHit.E.Enabled:Value() and Ready(_E) and IsValidTarget(minion, GetRange(_E), false, myHero.pos) and getdmg("E", minion, myHero) > minion.health then
                                    Control.CastSpell(HK_E)
                end
			end
		end
	end
end

function AutoHarass()
        if Config.Harass.Q.Auto.Enabled:Value() and myHero.mana > Config.Harass.Q.Auto.Energy:Value() then
                for _, Enemy in pairs(GetEnemyHeroes()) do
                        if Config.Harass.Q.Auto.WhiteList[Enemy.charName]:Value() and Ready(_Q) and IsValidTarget(Enemy, GetRange(_Q), false, myHero.pos) then
                                    Control.CastSpell(HK_Q, Enemy.pos)
                        end
                end
        end
end

function AutoLastHit()
        if Config.LastHit.Q.Auto.Enabled:Value() and myHero.mana > Config.LastHit.Q.Auto.Energy:Value() then
                for _, Minion in pairs(GetMinions()) do
				if Minion and Minion.isEnemy and not Minion.dead and GetDistance(myHero.pos, Minion.pos) <= GetRange(_Q) then
                        if Ready(_Q) and IsValidTarget(Minion, GetRange(_Q), false, myHero.pos) and getdmg("Q", Minion, myHero) > Minion.health then
                                    Control.CastSpell(HK_Q, Minion.pos)
							end
                        end
                end
        end
end

function SwitchHarass()
        if Config.Key.HarassAuto:Value() and Game.IsChatOpen() == false then
                if TickH+200 < GetTickCount() then
                        if Config.Harass.Q.Auto.Enabled:Value() == true then
                                Config.Harass.Q.Auto.Enabled:Value(false)
                        elseif Config.Harass.Q.Auto.Enabled:Value() == false then
                                Config.Harass.Q.Auto.Enabled:Value(true)
                        end
                        TickH = GetTickCount()
                end
        end
end

function SwitchLastHit()
        if Config.Key.LastHitAuto:Value() and Game.IsChatOpen() == false then
                if TickL+200 < GetTickCount() then
                        if Config.LastHit.Q.Auto.Enabled:Value() == true then
                                Config.LastHit.Q.Auto.Enabled:Value(false)
                        elseif Config.LastHit.Q.Auto.Enabled:Value() == false then
                                Config.LastHit.Q.Auto.Enabled:Value(true)
                        end
                        TickL = GetTickCount()
                end
        end
end

function OnDraw()
        local ColorGrey = Draw.Color(255, 153, 153, 153)

        if Config.Harass.Q.Auto.Enabled:Value() then
            Draw.Text("Auto Harass [Q]: On", 16 ,myHero.pos2D.x-55, myHero.pos2D.y+0)
        else
            --Draw.Text("Auto Harass [Q]: Off", 16 ,myHero.pos2D.x-55, myHero.pos2D.y+0, ColorGrey)
        end
        if Config.LastHit.Q.Auto.Enabled:Value() then
            Draw.Text("Auto LastHit [Q]: On", 16 ,myHero.pos2D.x-55, myHero.pos2D.y+17)
        else
            --Draw.Text("Auto LastHit [Q]: Off", 16 ,myHero.pos2D.x-55, myHero.pos2D.y+17, ColorGrey)
        end
		if Config.Draw.DrawQ:Value() then
			Draw.Circle(myHero.pos, GetRange(_Q), 1, Draw.Color(255, 0, 255, 0))
		end
		if Config.Draw.DrawE:Value() then
			Draw.Circle(myHero.pos, GetRange(_E), 1, Draw.Color(255, 0, 0, 255))
		end
		if Config.Draw.DrawR:Value() then
			Draw.Circle(myHero.pos, GetRange(_R), 1, Draw.Color(255, 255, 0, 0))
		end	
end
