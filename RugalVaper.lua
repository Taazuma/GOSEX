local neutral = 300
local friend = myHero.team
local foe = neutral - friend

local mathhuge = math.huge
local mathsqrt = math.sqrt
local mathpow = math.pow
local mathmax = math.max
local mathfloor = math.floor

local HKITEM = {[ITEM_1] = HK_ITEM_1,[ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3,[ITEM_4] = HK_ITEM_4,[ITEM_5] = HK_ITEM_5,[ITEM_6] = HK_ITEM_6,[ITEM_7] = HK_ITEM_7}
local HKSPELL = {[SUMMONER_1] = HK_SUMMONER_1,[SUMMONER_2] = HK_SUMMONER_2,}

local function Ready(slot)
	return myHero:GetSpellData(slot).currentCd == 0
end

local function IsUp(slot)
    return Game.CanUseSpell(slot) == 0
end

local function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function GetDistance(Pos1, Pos2)
	return mathsqrt(GetDistanceSqr(Pos1, Pos2))
end

local function GetDistance2D(p1,p2)
    local p2 = p2 or myHero
    return  mathsqrt(mathpow((p2.x - p1.x),2) + mathpow((p2.y - p1.y),2))
end

local function GetMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"	
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR]     then return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    elseif _G.gsoSDK then
        return _G.gsoSDK.Orbwalker:UOL_GetMode()
    else
        return GOS.GetMode()
    end
end

local function GetTarget(range) 
    local target = nil 
    if _G.EOWLoaded then 
        target = EOW:GetTarget(range) 
    elseif _G.SDK and _G.SDK.Orbwalker then 
        target = _G.SDK.TargetSelector:GetTarget(range) 
    else 
        target = GOS:GetTarget(range) 
    end 
    return target 
end

local function EnableOrb(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif _G.SDK and _G.SDK.Orbwalker then
		_G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end

local function CalcPhysicalDamage(source, target, amount)
    local ArmorPenPercent = source.armorPenPercent
    local ArmorPenFlat = (0.4 + target.levelData.lvl / 30) * source.armorPen
    local BonusArmorPen = source.bonusArmorPenPercent
    local armor = target.armor
    local bonusArmor = target.bonusArmor
    local value = 100 / (100 + (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat)
    if armor < 0 then
        value = 2 - 100 / (100 - armor)
    elseif (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat < 0 then
        value = 1
    end
    return value * amount
  end

local function CalcMagicalDamage(source, target, amount)
    local mr = target.magicResist
    local value = 100 / (100 + (mr * source.magicPenPercent) - source.magicPen)  
    if mr < 0 then
        value = 2 - 100 / (100 - mr)
    elseif (mr * source.magicPenPercent) - source.magicPen < 0 then
        value = 1
    end
    return value * amount
end

local function ClosestHero(range,team)
    local bestHero = nil
    local closest = math.huge
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if GetDistance(hero.pos) < range and hero.team == team and not hero.dead then
            local Distance = GetDistance(hero.pos, mousePos)
            if Distance < closest then
                bestHero = hero
                closest = Distance
            end
        end
    end
    return bestHero
end

local function ClosestMinion(range,team)
    local bestMinion = nil
    local closest = math.huge
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if GetDistance(minion.pos) < range and minion.team == team and not minion.dead then
            local Distance = GetDistance(minion.pos, mousePos)
            if Distance < closest then
                bestMinion = minion
                closest = Distance
            end
        end
    end
    return bestMinion
end

local function GetClearMinion(range)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if GetDistance(minion.pos) < range and not minion.dead and (minion.team == neutral or minion.team == foe) then
            return minion
        end
    end
end

local function Hp(source)
    local source = source or myHero
    return source.health/source.maxHealth * 100
end

local function Mp(source)
    local source = source or myHero
    return source.mana/source.maxMana * 100
end

local function ClosestInjuredHero(range,team,life,includeMe)
    local includeMe = includeMe or true
    local life = life or 101
    local bestHero = nil
    local closest = math.huge
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if GetDistance(hero.pos) < range and hero.team == team and not hero.dead and Hp(hero) < life then
            if includeMe == false and hero.isMe then return end
            local Distance = GetDistance(hero.pos, mousePos)
            if Distance < closest then
                bestHero = hero
                closest = Distance
            end
        end
    end
    return bestHero
end

local function HeroesAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or foe
    local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team == team and not hero.dead and GetDistance(pos, hero.pos) < range then
			Count = Count + 1
		end
	end
	return Count
end

local function BuffByType(wich,time)
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == wich and buff.duration > time then 
			return true
		end
	end
	return false
end

local function ExistSpell(spellname)
    if myHero:GetSpellData(SUMMONER_1).name == spellname or myHero:GetSpellData(SUMMONER_2).name == spellname then
        return true
    end
    return false
end

local function SummonerSlot(spellname)
    if myHero:GetSpellData(SUMMONER_1).name == spellname then
        return SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name == spellname then
        return SUMMONER_2
    end
end

class "Ahri"

function Ahri:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Ahri:LoadSpells()
    Q = { Range = 880, Delay = 0.25, Width = 100, Speed = 2500}
    W = { Range = 700}
    E = { Range = 975, Delay = 0.25, Width = 60, Speed = 1550}
    R = { Range = 0}
end

function Ahri:LoadMenu()
	Ahri = MenuElement({type = MENU, id = "Ahri", name = "Rugal Vaper - Ahri"})
    
    Ahri:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Ahri:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Ahri.Combo:MenuElement({id = "Q", name = "Q - Orb of Deception", value = true})
    Ahri.Combo:MenuElement({id = "W", name = "W - Fox-Fire", value = true})
    Ahri.Combo:MenuElement({id = "E", name = "E - Charm", value = true})
    
    Ahri:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Ahri.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Ahri.Harass:MenuElement({id = "Q", name = "Q - Orb of Deception", value = true})
    Ahri.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    Ahri.Harass:MenuElement({id = "W", name = "W - Fox-Fire", value = true})
    Ahri.Harass:MenuElement({id = "E", name = "E - Charm", value = true})
    Ahri.Harass:MenuElement({id = "AE", name = "Auto E", value = true})
    
    Ahri:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Ahri.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Ahri.Clear:MenuElement({id = "Q", name = "Q - Orb of Deception", value = true})
    Ahri.Clear:MenuElement({id = "W", name = "W - Fox-Fire", value = true})
    Ahri.Clear:MenuElement({id = "E", name = "E - Charm", value = true})

    Ahri:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Ahri.Flee:MenuElement({id = "Q", name = "Q - Orb of Deception", value = true})
    Ahri.Flee:MenuElement({id = "E", name = "E - Charm", value = true})
    
    Ahri:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Ahri.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Ahri.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Ahri.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Ahri.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Ahri.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Ahri.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Ahri.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Ahri.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Ahri.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Ahri.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Ahri.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Ahri.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Ahri.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Ahri:Tick()
    if not Ahri.Enable:Value() then return end
    if Ahri.Harass.T:Value() then
        local Etarget = GetTarget(E.Range)
        if Etarget and Ahri.Harass.AE:Value() then
            self:CastE(Etarget,2)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Ahri.Harass.AQ:Value() then
            self:CastQ(Qtarget,2)
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Etarget = GetTarget(E.Range) 
        if Etarget and Ahri.Combo.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Ahri.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and Ahri.Combo.W:Value() then
            self:CastW()
        end
    end
    if mode == "Harass" and Ahri.Harass.T:Value() then
        local Etarget = GetTarget(E.Range) 
        if Etarget and Ahri.Harass.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Ahri.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and Ahri.Harass.W:Value() then
            self:CastW()
        end
    end
    if mode == "Clear" and Ahri.Clear.T:Value() then
        local Etarget = GetClearMinion(E.Range)
        if Etarget and Ahri.Clear.E:Value() then
            self:CastEMinion(Etarget)
        end
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Ahri.Clear.Q:Value() then
            self:CastQMinion(Qtarget)
        end
        local Wtarget = GetClearMinion(W.Range)
        if Wtarget and Ahri.Clear.W:Value() then
            self:CastW()
        end
    end
    if mode == "Flee" then
        local Etarget = ClosestHero(E.Range,foe)
        if Etarget and Ahri.Flee.E:Value() then
            self:CastE(Etarget)
        end
        if Ahri.Flee.Q:Value() then
            self:FleeQ()
        end
    end
end

function Ahri:CastQ(target,precision)
    local precision = precision or 1
	if Ready(_Q) and IsUp(_Q) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, Q.Range, Q.Delay, Q.Speed, Q.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= Q.Range then
                EnableOrb(false)
                Control.CastSpell(HK_Q, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Ahri:CastE(target,precision)
    local precision = precision or 1
	if Ready(_E) and IsUp(_E) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, E.Range, E.Delay, E.Speed, E.Width, true, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= E.Range then
                EnableOrb(false)
                Control.CastSpell(HK_E, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Ahri:CastQMinion(target)
	if Ready(_Q) and IsUp(_Q) then
        if target then
            local pred = target:GetPrediction(Q.Speed, Q.Delay)
            Control.CastSpell(HK_Q, pred)
        end
    end
end

function Ahri:CastEMinion(target)
	if Ready(_E) and IsUp(_E) then
        if target then
            local pred = target:GetPrediction(E.Speed, E.Delay)
            if target:GetCollision(E.Width, E.Speed, E.Delay) <= 1 then
                Control.CastSpell(HK_E, pred)
            end
        end
    end
end

function Ahri:CastW()
	if Ready(_W) and IsUp(_W) then
        EnableOrb(false)
        Control.CastSpell(HK_W)
        EnableOrb(true)
    end
end

function Ahri:FleeQ()
	if Ready(_Q) and IsUp(_Q) then
        local flee = myHero.pos:Extend(Game.cursorPos(), -200)
        EnableOrb(false)
        Control.CastSpell(HK_Q, flee)
        EnableOrb(true)
    end
end

function Ahri:Draw()
    if not Ahri.Enable:Value() then return end
    local target = GetTarget(2000)
    if Ahri.dead then return end
    if Ahri.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Ahri.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
    if Ahri.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    local textPos = myHero.pos:To2D()
    if Ahri.Draw.Harass.Text:Value() then
        local size = Ahri.Draw.Harass.Size:Value()
	    local xPos = Ahri.Draw.Harass.xPos:Value()
	    local yPos = Ahri.Draw.Harass.yPos:Value()
        if Ahri.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Ahri.Draw.Clear.Text:Value() then
        local size = Ahri.Draw.Clear.Size:Value()
	    local xPos = Ahri.Draw.Clear.xPos:Value()
	    local yPos = Ahri.Draw.Clear.yPos:Value()
        if Ahri.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "DrMundo"

function DrMundo:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function DrMundo:LoadSpells()
    Q = { Range = 975, Delay = 0.25, Width = 60, Speed = 1850}
    W = { Range = 325}
    E = { Range = 300}
    R = { Range = 0}
end

function DrMundo:LoadMenu()
	DrMundo = MenuElement({type = MENU, id = "DrMundo", name = "Rugal Vaper - Dr. Mundo"})
    
    DrMundo:MenuElement({id = "Enable", name = "Enable Hero", value = true})
    
    DrMundo:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    DrMundo.Combo:MenuElement({id = "Q", name = "Q - Infected Cleaver", value = true})
    DrMundo.Combo:MenuElement({id = "W", name = "W - Burning Agony", value = true})
    DrMundo.Combo:MenuElement({id = "E", name = "E - Masochism", value = true})
    
    DrMundo:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    DrMundo.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    DrMundo.Harass:MenuElement({id = "Q", name = "Q - Infected Cleaver", value = true})
    DrMundo.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    DrMundo.Harass:MenuElement({id = "W", name = "W - Burning Agony", value = true})
    DrMundo.Harass:MenuElement({id = "E", name = "E - Masochism", value = true})
    
    DrMundo:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    DrMundo.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    DrMundo.Clear:MenuElement({id = "Q", name = "Q - Infected Cleaver", value = true})
    DrMundo.Clear:MenuElement({id = "W", name = "W - Burning Agony", value = true})
    DrMundo.Clear:MenuElement({id = "E", name = "E - Masochism", value = true})

    DrMundo:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    DrMundo.Flee:MenuElement({id = "Q", name = "Q - Infected Cleaver", value = true})
    
    DrMundo:MenuElement({type = MENU, id = "Lifesaver", name = "Life Saver"})
    DrMundo.Lifesaver:MenuElement({id = "R", name = "R - Sadism", value = true})
    DrMundo.Lifesaver:MenuElement({id = "HP", name = "Health % to Life Saver", value = 15, min = 0, max = 100})
    
    DrMundo:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    DrMundo.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    DrMundo.Draw:MenuElement({id = "W", name = "W Range", value = true})
    DrMundo.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    DrMundo.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    DrMundo.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    DrMundo.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    DrMundo.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    DrMundo.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    DrMundo.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    DrMundo.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    DrMundo.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    DrMundo.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
    DrMundo.Draw:MenuElement({id = "Lasthit", name = "Lasthit Status", type = MENU})
    DrMundo.Draw.Lasthit:MenuElement({id = "Text", name = "Text Enabled", value = true})
    DrMundo.Draw.Lasthit:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    DrMundo.Draw.Lasthit:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    DrMundo.Draw.Lasthit:MenuElement({id = "yPos", name = "Text Y Position", value = -120, min = -1000, max = 1000, step = 10})
end

function DrMundo:Tick()
    if not DrMundo.Enable:Value() then return end
    if Hp() < DrMundo.Lifesaver.HP:Value() and HeroesAround(1500,myHero.pos) ~= 0 and DrMundo.Lifesaver.R:Value() then
        self:CastR()
    end
    if DrMundo.Harass.T:Value() then
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and DrMundo.Harass.AQ:Value() then
            self:CastQ(Qtarget,2)
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and DrMundo.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and DrMundo.Combo.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and DrMundo.Combo.E:Value() then
            self:CastE()
        end
    end
    if mode == "Harass" and DrMundo.Harass.T:Value() then
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and DrMundo.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and DrMundo.Harass.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and DrMundo.Harass.E:Value() then
            self:CastE()
        end
    end
    if mode == "Clear" and DrMundo.Clear.T:Value() then
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and DrMundo.Clear.Q:Value() then
            self:CastQMinion(Qtarget)
        end
        local Wtarget = GetClearMinion(W.Range)
        if Wtarget and DrMundo.Clear.W:Value() then
            self:CastW()
        end
        local Etarget = GetClearMinion(E.Range)
        if Etarget and DrMundo.Clear.E:Value() then
            self:CastE()
        end
    end
    if mode == "Flee" then
        local Qtarget = ClosestHero(Q.Range,foe)
        if Qtarget and DrMundo.Flee.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
end

function DrMundo:CastQ(target,precision)
    local precision = precision or 1
	if Ready(_Q) and IsUp(_Q) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, Q.Range, Q.Delay, Q.Speed, Q.Width, true, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= Q.Range then
                EnableOrb(false)
                Control.CastSpell(HK_Q, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function DrMundo:CastQMinion(target)
	if Ready(_Q) and IsUp(_Q) then
        if target then
            local pred = target:GetPrediction(Q.Speed, Q.Delay)
            if target:GetCollision(Q.Width, Q.Speed, Q.Delay) <= 1 then
                Control.CastSpell(HK_Q, pred)
            end
        end
    end
end

function DrMundo:CastW()
	if Ready(_W) and IsUp(_W) and myHero:GetSpellData(_W).toggleState ~= 2 then
        EnableOrb(false)
        Control.CastSpell(HK_W)
        EnableOrb(true)
    end
end

function DrMundo:CastE()
	if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E)
        EnableOrb(true)
    end
end

function DrMundo:CastR()
	if Ready(_R) and IsUp(_R) then
        EnableOrb(false)
        Control.CastSpell(HK_R)
        EnableOrb(true)
    end
end

function DrMundo:Draw()
    if not DrMundo.Enable:Value() then return end
    local target = GetTarget(2000)
    if DrMundo.dead then return end
    if DrMundo.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if DrMundo.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
    local textPos = myHero.pos:To2D()
    if DrMundo.Draw.Harass.Text:Value() then
        local size = DrMundo.Draw.Harass.Size:Value()
	    local xPos = DrMundo.Draw.Harass.xPos:Value()
	    local yPos = DrMundo.Draw.Harass.yPos:Value()
        if DrMundo.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if DrMundo.Draw.Clear.Text:Value() then
        local size = DrMundo.Draw.Clear.Size:Value()
	    local xPos = DrMundo.Draw.Clear.xPos:Value()
	    local yPos = DrMundo.Draw.Clear.yPos:Value()
        if DrMundo.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Hecarim"

function Hecarim:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Hecarim:LoadSpells()
    Q = { Range = 350}
    W = { Range = 575}
    E = { Range = 800}
    R = { Range = 1000, Delay = 0.01, Speed = 1100, Width = 230}
end

function Hecarim:LoadMenu()
	Hecarim = MenuElement({type = MENU, id = "Hecarim", name = "Rugal Vaper - Hecarim"})
    
    Hecarim:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Hecarim:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Hecarim.Combo:MenuElement({id = "Q", name = "Q - Rampage", value = true})
    Hecarim.Combo:MenuElement({id = "W", name = "W - Spirit of Dread", value = true})
    Hecarim.Combo:MenuElement({id = "E", name = "E - Devastating Charge", value = true})
    Hecarim.Combo:MenuElement({id = "R", name = "R - Onslaught of Shadows", value = true})
    
    Hecarim:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Hecarim.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Hecarim.Harass:MenuElement({id = "Q", name = "Q - Rampage", value = true})
    Hecarim.Harass:MenuElement({id = "W", name = "W - Spirit of Dread", value = true})
    Hecarim.Harass:MenuElement({id = "E", name = "E - Devastating Charge", value = true})
    Hecarim.Harass:MenuElement({id = "R", name = "R - Onslaught of Shadows", value = true})
    
    Hecarim:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Hecarim.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Hecarim.Clear:MenuElement({id = "Q", name = "Q - Rampage", value = true})
    Hecarim.Clear:MenuElement({id = "W", name = "W - Spirit of Dread", value = true})

    Hecarim:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Hecarim.Flee:MenuElement({id = "E", name = "E - Devastating Charge", value = true})
    
    Hecarim:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Hecarim.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Hecarim.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Hecarim.Draw:MenuElement({id = "R", name = "R Range", value = true})
    Hecarim.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Hecarim.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Hecarim.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Hecarim.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Hecarim.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Hecarim.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Hecarim.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Hecarim.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Hecarim.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Hecarim.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Hecarim:Tick()
    if not Hecarim.Enable:Value() then return end
    local mode = GetMode()
    if mode == "Combo" then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and Hecarim.Combo.R:Value() then
            self:CastR(Rtarget)
        end
        local Wtarget = GetTarget(W.Range)
        if Wtarget and Hecarim.Combo.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range)
        if Etarget and Hecarim.Combo.E:Value() then
            self:CastE()
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Hecarim.Combo.Q:Value() then
            self:CastQ()
        end
    end
    if mode == "Harass" and Hecarim.Harass.T:Value() then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and Hecarim.Harass.R:Value() then
            self:CastR(Rtarget)
        end
        local Wtarget = GetTarget(W.Range)
        if Wtarget and Hecarim.Harass.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range)
        if Etarget and Hecarim.Harass.E:Value() then
            self:CastE()
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Hecarim.Harass.Q:Value() then
            self:CastQ()
        end
    end
    if mode == "Clear" and Hecarim.Clear.T:Value() then
        local Etarget = GetClearMinion(W.Range)
        if Etarget and Hecarim.Clear.W:Value() then
            self:CastW()
        end
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Hecarim.Clear.Q:Value() then
            self:CastQ()
        end
    end
    if mode == "Flee" then
        if Hecarim.Flee.E:Value() then
            self:CastE()
        end
    end
end

function Hecarim:CastR(target,precision)
    local precision = precision or 1
	if Ready(_R) and IsUp(_R) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= R.Range then
                EnableOrb(false)
                Control.CastSpell(HK_R, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Hecarim:CastQ()
	if Ready(_Q) and IsUp(_Q) then
        EnableOrb(false)
        Control.CastSpell(HK_Q)
        EnableOrb(true)
    end
end

function Hecarim:CastW()
    if Ready(_W) and IsUp(_W) then
        EnableOrb(false)
        Control.CastSpell(HK_W)
        EnableOrb(true)
    end
end

function Hecarim:CastE()
    if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E)
        EnableOrb(true)
    end
end

function Hecarim:Draw()
    if not Hecarim.Enable:Value() then return end
    local target = GetTarget(2000)
    if Hecarim.dead then return end
    if Hecarim.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Hecarim.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
    if Hecarim.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 255, 000, 000)) end
    local textPos = myHero.pos:To2D()
    if Hecarim.Draw.Harass.Text:Value() then
        local size = Hecarim.Draw.Harass.Size:Value()
	    local xPos = Hecarim.Draw.Harass.xPos:Value()
	    local yPos = Hecarim.Draw.Harass.yPos:Value()
        if Hecarim.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Hecarim.Draw.Clear.Text:Value() then
        local size = Hecarim.Draw.Clear.Size:Value()
	    local xPos = Hecarim.Draw.Clear.xPos:Value()
	    local yPos = Hecarim.Draw.Clear.yPos:Value()
        if Hecarim.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Jayce"

function Jayce:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Jayce:LoadSpells()
    Q = { Range = 1175, Delay = 0.25, Width = 75, Speed = 1450}
    W = { Range = myHero.range}
    E = { Range = 650}
    EQ = { Range = 1970, Delay = 0.25, Width = 105, Speed = 2350}
    Q2 = { Range = 600}
    W2 = { Range = 285}
    E2 = { Range = 240}
    R = { Range = 0}
end

function Jayce:LoadMenu()
	Jayce = MenuElement({type = MENU, id = "Jayce", name = "Rugal Vaper - Jayce"})
    
    Jayce:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Jayce:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Jayce.Combo:MenuElement({id = "Q", name = "Q - Shock Blast", value = true})
    Jayce.Combo:MenuElement({id = "W", name = "W - Hyper Charge", value = true})
    Jayce.Combo:MenuElement({id = "EQ", name = "E - Acceleration Gate", value = true})
    Jayce.Combo:MenuElement({id = "Q2", name = "Q - To the Skies!", value = true})
    Jayce.Combo:MenuElement({id = "W2", name = "W - Lightning Field", value = true})
    Jayce.Combo:MenuElement({id = "E2", name = "E - Thundering Blow", value = true})
    
    Jayce:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Jayce.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Jayce.Harass:MenuElement({id = "Q", name = "Q - Shock Blast", value = true})
    Jayce.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    Jayce.Harass:MenuElement({id = "W", name = "W - Hyper Charge", value = true})
    Jayce.Harass:MenuElement({id = "EQ", name = "E - Acceleration Gate", value = true})
    Jayce.Harass:MenuElement({id = "AEQ", name = "Auto E", value = true})
    Jayce.Harass:MenuElement({id = "Q2", name = "Q - To the Skies!", value = true})
    Jayce.Harass:MenuElement({id = "W2", name = "W - Lightning Field", value = true})
    Jayce.Harass:MenuElement({id = "E2", name = "E - Thundering Blow", value = true})
    
    Jayce:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Jayce.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Jayce.Clear:MenuElement({id = "Q", name = "Q - Shock Blast", value = true})
    Jayce.Clear:MenuElement({id = "W", name = "W - Hyper Charge", value = true})
    Jayce.Clear:MenuElement({id = "EQ", name = "E - Acceleration Gate", value = true})
    Jayce.Clear:MenuElement({id = "Q2", name = "Q - To the Skies!", value = true})
    Jayce.Clear:MenuElement({id = "W2", name = "W - Lightning Field", value = true})
    Jayce.Clear:MenuElement({id = "E2", name = "E - Thundering Blow", value = true})

    Jayce:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Jayce.Flee:MenuElement({id = "E", name = "E - Acceleration Gate", value = true})
    Jayce.Flee:MenuElement({id = "E2", name = "E - Thundering Blow", value = true})
    
    Jayce:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Jayce.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Jayce.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Jayce.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Jayce.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Jayce.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Jayce.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Jayce.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Jayce.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Jayce.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Jayce.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Jayce.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Jayce.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Jayce.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Jayce:Tick()
    if not Jayce.Enable:Value() then return end
    local form = self:CurrentForm()
    if Jayce.Harass.T:Value() then
        if form == "Ranged" then
            local EQtarget = GetTarget(EQ.Range)
            if EQtarget and Jayce.Harass.AEQ:Value() then
                self:CastEQ(EQtarget,2)
            end
            local Qtarget = GetTarget(Q.Range)
            if Qtarget and Jayce.Harass.AQ:Value() then
                self:CastQ(Qtarget,2)
            end
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        if form == "Ranged" then
            local EQtarget = GetTarget(EQ.Range)
            if EQtarget and Jayce.Combo.EQ:Value() then
                self:CastEQ(EQtarget)
            end
            local Qtarget = GetTarget(Q.Range)
            if Qtarget and Jayce.Combo.Q:Value() then
                self:CastQ(Qtarget)
            end
            local Wtarget = GetTarget(W.Range) 
            if Wtarget and Jayce.Combo.W:Value() then
                self:CastW()
            end
        else
            local Wtarget = GetTarget(W2.Range) 
            if Wtarget and Jayce.Combo.W2:Value() then
                self:CastW()
            end
            local Etarget = GetTarget(E2.Range)
            if Etarget and Jayce.Combo.E2:Value() then
                self:CastE2(Etarget)
            end
            local Qtarget = GetTarget(Q2.Range)
            if Qtarget and Jayce.Combo.Q2:Value() then
                self:CastQ2(Qtarget)
            end
        end
    end
    if mode == "Harass" and Jayce.Harass.T:Value() then
        if form == "Ranged" then
            local EQtarget = GetTarget(EQ.Range)
            if EQtarget and Jayce.Harass.EQ:Value() then
                self:CastEQ(EQtarget)
            end
            local Qtarget = GetTarget(Q.Range)
            if Qtarget and Jayce.Harass.Q:Value() then
                self:CastQ(Qtarget)
            end
            local Wtarget = GetTarget(W.Range) 
            if Wtarget and Jayce.Harass.W:Value() then
                self:CastW()
            end
        else
            local Wtarget = GetTarget(W2.Range) 
            if Wtarget and Jayce.Harass.W2:Value() then
                self:CastW()
            end
            local Etarget = GetTarget(E2.Range)
            if Etarget and Jayce.Harass.E2:Value() then
                self:CastE2(Etarget)
            end
            local Qtarget = GetTarget(Q2.Range)
            if Qtarget and Jayce.Harass.Q2:Value() then
                self:CastQ2(Qtarget)
            end
        end
    end
    if mode == "Clear" and Jayce.Clear.T:Value() then
        if form == "Ranged" then
            local EQtarget = GetClearMinion(EQ.Range)
            if EQtarget and Jayce.Clear.EQ:Value() then
                self:CastEQ(EQtarget)
            end
            local Qtarget = GetClearMinion(Q.Range)
            if Qtarget and Jayce.Clear.Q:Value() then
                self:CastQ(Qtarget)
            end
            local Wtarget = GetClearMinion(W.Range) 
            if Wtarget and Jayce.Clear.W:Value() then
                self:CastW()
            end
        else
            local Wtarget = GetClearMinion(W2.Range) 
            if Wtarget and Jayce.Clear.W2:Value() then
                self:CastW()
            end
            local Etarget = GetClearMinion(E2.Range)
            if Etarget and Jayce.Clear.E2:Value() then
                self:CastE2(Etarget)
            end
            local Qtarget = GetClearMinion(Q2.Range)
            if Qtarget and Jayce.Clear.Q2:Value() then
                self:CastQ2(Qtarget)
            end
        end
    end
    if mode == "Flee" then
        if form == "Ranged" then
            if Jayce.Flee.E:Value() then
                local fleeE = myHero.pos:Extend(Game.cursorPos(), 200)
                self:CastE(fleeE)
            end
        else
            local Etarget = ClosestHero(E2.Range,foe)
            if Etarget and Jayce.Flee.E2:Value() then
                self:CastE2(Etarget)
            end
        end
    end
end

function Jayce:CurrentForm()
    if myHero.range >= 350 then
        return "Ranged"
    else
        return "Melee"
    end
end

function Jayce:CastQ(target,precision)
    local precision = precision or 1
	if Ready(_Q) and IsUp(_Q) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, Q.Range, Q.Delay, Q.Speed, Q.Width, true, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= Q.Range then
                EnableOrb(false)
                Control.CastSpell(HK_Q, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

local lastE = os.clock()
function Jayce:CastEQ(target,precision)
    local precision = precision or 1
    if target then
        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, EQ.Range, EQ.Delay, EQ.Speed, EQ.Width, true, nil)
        if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= EQ.Range then
            EnableOrb(false)
            local Evector = myHero.pos:Extended(target.pos, 200)
            if Ready(_E) and IsUp(_E) and Ready(_Q) and IsUp(_Q) then
                self:CastE(Evector)
                lastE = os.clock()
            end
            if os.clock() - lastE <= 1 then
                Control.CastSpell(HK_Q, aimPosition)
            end
            EnableOrb(true)
        end
    end
end

function Jayce:CastQ2(target)
	if Ready(_Q) and IsUp(_Q) then
        EnableOrb(false)
        Control.CastSpell(HK_Q,target)
        EnableOrb(true)
    end
end

function Jayce:CastW()
	if Ready(_W) and IsUp(_W) then
        EnableOrb(false)
        Control.CastSpell(HK_W)
        EnableOrb(true)
    end
end

function Jayce:CastE(pos)
	if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E,pos)
        EnableOrb(true)
    end
end

function Jayce:CastE2(target)
	if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E,target)
        EnableOrb(true)
    end
end

function Jayce:Draw()
    if not Jayce.Enable:Value() then return end
    local target = GetTarget(2000)
    if Jayce.dead then return end
    local form = self:CurrentForm()
    if form == "Ranged" then
        if Jayce.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
        if Jayce.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
        if Jayce.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    else
        if Jayce.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q2.Range, 3,  Draw.Color(255, 000, 000, 255)) end
        if Jayce.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W2.Range, 3,  Draw.Color(255, 000, 255, 000)) end
        if Jayce.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E2.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    end
    local textPos = myHero.pos:To2D()
    if Jayce.Draw.Harass.Text:Value() then
        local size = Jayce.Draw.Harass.Size:Value()
	    local xPos = Jayce.Draw.Harass.xPos:Value()
	    local yPos = Jayce.Draw.Harass.yPos:Value()
        if Jayce.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Jayce.Draw.Clear.Text:Value() then
        local size = Jayce.Draw.Clear.Size:Value()
	    local xPos = Jayce.Draw.Clear.xPos:Value()
	    local yPos = Jayce.Draw.Clear.yPos:Value()
        if Jayce.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Soraka"

function Soraka:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Soraka:LoadSpells()
    Q = { Range = 800, Delay = 0.25, Width = 235, Speed = 1150}
    W = { Range = 550}
    E = { Range = 925, Delay = 0.25, Width = 300, Speed = mathhuge}
    R = { Range = 25000}
end

function Soraka:LoadMenu()
	Soraka = MenuElement({type = MENU, id = "Soraka", name = "Rugal Vaper - Soraka"})
    
    Soraka:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Soraka:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Soraka.Combo:MenuElement({id = "Q", name = "Q - Starcall", value = true})
    Soraka.Combo:MenuElement({id = "E", name = "E - Equinox", value = true})
    
    Soraka:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Soraka.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Soraka.Harass:MenuElement({id = "Q", name = "Q - Starcall", value = true})
    Soraka.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    Soraka.Harass:MenuElement({id = "E", name = "E - Equinox", value = true})
    Soraka.Harass:MenuElement({id = "AE", name = "Auto E", value = true})
    
    Soraka:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Soraka.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Soraka.Clear:MenuElement({id = "Q", name = "Q - Starcall", value = true})

    Soraka:MenuElement({type = MENU, id = "Lifesaver", name = "Life Saver"})
    Soraka.Lifesaver:MenuElement({id = "W", name = "W - Astral Infusion", value = true})
    Soraka.Lifesaver:MenuElement({id = "WHP", name = "Health % to Life Saver", value = 80, min = 0, max = 100})
    Soraka.Lifesaver:MenuElement({id = "SHP", name = "Soraka Health % to Life Saver", value = 40, min = 5, max = 100})
    Soraka.Lifesaver:MenuElement({id = "R", name = "R - Wish", value = true})
    Soraka.Lifesaver:MenuElement({id = "HP", name = "Health % to Life Saver", value = 8, min = 0, max = 100})
    
    Soraka:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Soraka.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Soraka.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Soraka.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Soraka.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Soraka.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Soraka.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Soraka.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Soraka.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Soraka.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Soraka.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Soraka.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Soraka.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Soraka.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Soraka:Tick()
    if not Soraka.Enable:Value() then return end
    local Wtarget = ClosestInjuredHero(W.Range,friend,Soraka.Lifesaver.WHP:Value(),false)
    if Wtarget and not Wtarget.isMe and HeroesAround(1500,Wtarget.pos) ~= 0 and Soraka.Lifesaver.W:Value() and Hp() > Soraka.Lifesaver.SHP:Value() then
        self:CastW(Wtarget)
    end
    local Rtarget = ClosestInjuredHero(R.Range,friend,Soraka.Lifesaver.HP:Value(),true)
    if Rtarget and HeroesAround(1500,Rtarget.pos) ~= 0 and Soraka.Lifesaver.R:Value() then
        self:CastR()
    end
    if Soraka.Harass.T:Value() then
        local Etarget = GetTarget(E.Range)
        if Etarget and Soraka.Harass.AE:Value() then
            self:CastE(Etarget,2)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Soraka.Harass.AQ:Value() then
            self:CastQ(Qtarget,2)
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Etarget = GetTarget(E.Range) 
        if Etarget and Soraka.Combo.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Soraka.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Harass" and Soraka.Harass.T:Value() then
        local Etarget = GetTarget(E.Range) 
        if Etarget and Soraka.Harass.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Soraka.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Clear" and Soraka.Clear.T:Value() then
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Soraka.Clear.Q:Value() then
            self:CastQMinion(Qtarget)
        end
    end
end

function Soraka:CastQ(target,precision)
    local precision = precision or 1
	if Ready(_Q) and IsUp(_Q) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, Q.Range, Q.Delay, Q.Speed, Q.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= Q.Range then
                EnableOrb(false)
                Control.CastSpell(HK_Q, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Soraka:CastE(target,precision)
    local precision = precision or 1
	if Ready(_E) and IsUp(_E) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, E.Range, E.Delay, E.Speed, E.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= E.Range then
                EnableOrb(false)
                Control.CastSpell(HK_E, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Soraka:CastQMinion(target)
	if Ready(_Q) and IsUp(_Q) then
        if target then
            local pred = target:GetPrediction(Q.Speed, Q.Delay)
            Control.CastSpell(HK_Q, pred)
        end
    end
end

function Soraka:CastR()
	if Ready(_R) and IsUp(_R) then
        EnableOrb(false)
        Control.CastSpell(HK_R)
        EnableOrb(true)
    end
end

function Soraka:CastW(target)
	if Ready(_W) and IsUp(_W) then
        EnableOrb(false)
        Control.CastSpell(HK_W,target)
        EnableOrb(true)
    end
end

function Soraka:Draw()
    if not Soraka.Enable:Value() then return end
    local target = GetTarget(2000)
    if Soraka.dead then return end
    if Soraka.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Soraka.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
    if Soraka.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    local textPos = myHero.pos:To2D()
    if Soraka.Draw.Harass.Text:Value() then
        local size = Soraka.Draw.Harass.Size:Value()
	    local xPos = Soraka.Draw.Harass.xPos:Value()
	    local yPos = Soraka.Draw.Harass.yPos:Value()
        if Soraka.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Soraka.Draw.Clear.Text:Value() then
        local size = Soraka.Draw.Clear.Size:Value()
	    local xPos = Soraka.Draw.Clear.xPos:Value()
	    local yPos = Soraka.Draw.Clear.yPos:Value()
        if Soraka.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Tryndamere"

function Tryndamere:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Tryndamere:LoadSpells()
    Q = { Range = 0}
    W = { Range = 850}
    E = { Range = 660, Delay = 0.01, Width = 225, Speed = 1300}
    R = { Range = 0}
end

function Tryndamere:LoadMenu()
	Tryndamere = MenuElement({type = MENU, id = "Tryndamere", name = "Rugal Vaper - Tryndamere"})
    
    Tryndamere:MenuElement({id = "Enable", name = "Enable Hero", value = true})
    
    Tryndamere:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Tryndamere.Combo:MenuElement({id = "W", name = "W - Mocking Shout", value = true})
    Tryndamere.Combo:MenuElement({id = "E", name = "E - Spinning Slash", value = true})
    
    Tryndamere:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Tryndamere.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Tryndamere.Harass:MenuElement({id = "W", name = "W - Mocking Shout", value = true})
    Tryndamere.Harass:MenuElement({id = "E", name = "E - Spinning Slash", value = true})
    
    Tryndamere:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Tryndamere.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Tryndamere.Clear:MenuElement({id = "E", name = "E - Spinning Slash", value = true})

    Tryndamere:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Tryndamere.Flee:MenuElement({id = "E", name = "E - Spinning Slash", value = true})
    
    Tryndamere:MenuElement({type = MENU, id = "Lifesaver", name = "Life Saver"})
    Tryndamere.Lifesaver:MenuElement({id = "Q", name = "Q - Bloodlust", value = true})
    Tryndamere.Lifesaver:MenuElement({id = "QHP", name = "Health % to Life Saver", value = 15, min = 0, max = 100})
    Tryndamere.Lifesaver:MenuElement({id = "R", name = "R - Undying Rage", value = true})
    Tryndamere.Lifesaver:MenuElement({id = "HP", name = "Health % to Life Saver", value = 8, min = 0, max = 100})
    
    Tryndamere:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Tryndamere.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Tryndamere.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Tryndamere.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Tryndamere.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Tryndamere.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Tryndamere.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Tryndamere.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Tryndamere.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Tryndamere.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Tryndamere.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Tryndamere.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Tryndamere.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
    Tryndamere.Draw:MenuElement({id = "Lasthit", name = "Lasthit Status", type = MENU})
    Tryndamere.Draw.Lasthit:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Tryndamere.Draw.Lasthit:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Tryndamere.Draw.Lasthit:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Tryndamere.Draw.Lasthit:MenuElement({id = "yPos", name = "Text Y Position", value = -120, min = -1000, max = 1000, step = 10})
end

function Tryndamere:Tick()
    if not Tryndamere.Enable:Value() then return end
    if Hp() < Tryndamere.Lifesaver.QHP:Value() and HeroesAround(1500,myHero.pos) ~= 0 and Tryndamere.Lifesaver.Q:Value() then
        self:CastQ()
    end
    if Hp() < Tryndamere.Lifesaver.HP:Value() and HeroesAround(1500,myHero.pos) ~= 0 and Tryndamere.Lifesaver.R:Value() then
        self:CastR()
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and Tryndamere.Combo.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Tryndamere.Combo.E:Value() then
            self:CastE(Etarget)
        end
    end
    if mode == "Harass" and Tryndamere.Harass.T:Value() then
        local Wtarget = GetTarget(W.Range) 
        if Wtarget and Tryndamere.Harass.W:Value() then
            self:CastW()
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Tryndamere.Harass.E:Value() then
            self:CastE(Etarget)
        end
    end
    if mode == "Clear" and Tryndamere.Clear.T:Value() then
        local Etarget = GetClearMinion(E.Range)
        if Etarget and Tryndamere.Clear.E:Value() then
            self:CastE(Etarget)
        end
    end
    if mode == "Flee" then
        if Tryndamere.Flee.E:Value() then
            self:FleeE()
        end
    end
end

function Tryndamere:CastW()
	if Ready(_W) and IsUp(_W) then
        EnableOrb(false)
        Control.CastSpell(HK_W)
        EnableOrb(true)
    end
end

function Tryndamere:FleeE()
	if Ready(_E) and IsUp(_E) then
        local flee = myHero.pos:Extend(Game.cursorPos(), E.Range)
        EnableOrb(false)
        Control.CastSpell(HK_E,flee)
        EnableOrb(true)
    end
end

function Tryndamere:CastE(target,precision)
    local precision = precision or 1
	if Ready(_E) and IsUp(_E) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, E.Range, E.Delay, E.Speed, E.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= E.Range then
                EnableOrb(false)
                Control.CastSpell(HK_E, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Tryndamere:CastR()
	if Ready(_R) and IsUp(_R) then
        EnableOrb(false)
        Control.CastSpell(HK_R)
        EnableOrb(true)
    end
end

function Tryndamere:CastQ()
	if Ready(_Q) and IsUp(_Q) then
        EnableOrb(false)
        Control.CastSpell(HK_Q)
        EnableOrb(true)
    end
end

function Tryndamere:Draw()
    if not Tryndamere.Enable:Value() then return end
    local target = GetTarget(2000)
    if Tryndamere.dead then return end
    if Tryndamere.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 000, 255, 000)) end
    if Tryndamere.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    local textPos = myHero.pos:To2D()
    if Tryndamere.Draw.Harass.Text:Value() then
        local size = Tryndamere.Draw.Harass.Size:Value()
	    local xPos = Tryndamere.Draw.Harass.xPos:Value()
	    local yPos = Tryndamere.Draw.Harass.yPos:Value()
        if Tryndamere.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Tryndamere.Draw.Clear.Text:Value() then
        local size = Tryndamere.Draw.Clear.Size:Value()
	    local xPos = Tryndamere.Draw.Clear.xPos:Value()
	    local yPos = Tryndamere.Draw.Clear.yPos:Value()
        if Tryndamere.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Vladimir"

function Vladimir:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Vladimir:LoadSpells()
    Q = { Range = 600}
    E = { Range = 600}
    R = { Range = 700, Delay = 0.4, Speed = mathhuge, Width = 350}
end

function Vladimir:LoadMenu()
	Vladimir = MenuElement({type = MENU, id = "Vladimir", name = "Rugal Vaper - Vladimir"})
    
    Vladimir:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Vladimir:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Vladimir.Combo:MenuElement({id = "Q", name = "Q - Transfusion", value = true})
    Vladimir.Combo:MenuElement({id = "E", name = "E - Tides of Blood", value = true})
    Vladimir.Combo:MenuElement({id = "R", name = "R - Hemoplague", value = true})
    Vladimir.Combo:MenuElement({id = "X", name = "R Enemies", value = 2, min = 1, max = 5})
    
    Vladimir:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Vladimir.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Vladimir.Harass:MenuElement({id = "Q", name = "Q - Transfusion", value = true})
    Vladimir.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    Vladimir.Harass:MenuElement({id = "E", name = "E - Tides of Blood", value = true})
    Vladimir.Harass:MenuElement({id = "R", name = "R - Hemoplague", value = true})
    Vladimir.Harass:MenuElement({id = "X", name = "R Enemies", value = 2, min = 1, max = 5})
    
    Vladimir:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Vladimir.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Vladimir.Clear:MenuElement({id = "Q", name = "Q - Transfusion", value = true})
    Vladimir.Clear:MenuElement({id = "E", name = "E - Tides of Blood", value = true})
    
    Vladimir:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Vladimir.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Vladimir.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Vladimir.Draw:MenuElement({id = "R", name = "R Range", value = true})
    Vladimir.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Vladimir.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Vladimir.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Vladimir.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Vladimir.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Vladimir.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Vladimir.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Vladimir.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Vladimir.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Vladimir.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Vladimir:Tick()
    if not Vladimir.Enable:Value() then return end
    if Vladimir.Harass.T:Value() then
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Vladimir.Harass.AQ:Value() then
            self:CastQ(Qtarget)
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and HeroesAround(R.Width,Rtarget.pos,foe) >= Vladimir.Combo.X:Value() and Vladimir.Combo.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Vladimir.Combo.E:Value() then
            if Etarget:GetCollision(100, mathhuge, 0) == 0 then
                self:CastE()
            end
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Vladimir.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Harass" and Vladimir.Harass.T:Value() then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and HeroesAround(R.Width,Rtarget.pos,foe) >= Vladimir.Harass.X:Value() and Vladimir.Harass.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Vladimir.Harass.E:Value() then
            if Etarget:GetCollision(100, mathhuge, 0) == 0 then
                self:CastE()
            end
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Vladimir.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Clear" and Vladimir.Clear.T:Value() then
        local Etarget = GetClearMinion(E.Range)
        if Etarget and Vladimir.Clear.E:Value() then
            self:CastE()
        end
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Vladimir.Clear.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
end

function Vladimir:CastR(target,precision)
    local precision = precision or 1
	if Ready(_R) and IsUp(_R) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= R.Range then
                EnableOrb(false)
                Control.CastSpell(HK_R, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Vladimir:CastQ(target)
	if Ready(_Q) and IsUp(_Q) then
        EnableOrb(false)
        Control.CastSpell(HK_Q,target)
        EnableOrb(true)
    end
end

function Vladimir:CastE()
    if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E)
        EnableOrb(true)
    end
end

function Vladimir:Draw()
    if not Vladimir.Enable:Value() then return end
    local target = GetTarget(2000)
    if Vladimir.dead then return end
    if Vladimir.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Vladimir.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    if Vladimir.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 255, 000, 000)) end
    local textPos = myHero.pos:To2D()
    if Vladimir.Draw.Harass.Text:Value() then
        local size = Vladimir.Draw.Harass.Size:Value()
	    local xPos = Vladimir.Draw.Harass.xPos:Value()
	    local yPos = Vladimir.Draw.Harass.yPos:Value()
        if Vladimir.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Vladimir.Draw.Clear.Text:Value() then
        local size = Vladimir.Draw.Clear.Size:Value()
	    local xPos = Vladimir.Draw.Clear.xPos:Value()
	    local yPos = Vladimir.Draw.Clear.yPos:Value()
        if Vladimir.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Warwick"

function Warwick:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Warwick:LoadSpells()
    Q = { Range = 350}
    E = { Range = 375}
    R = { Range = 0, Delay = 0.1, Speed = 1800, Width = 45}
end

function Warwick:LoadMenu()
	Warwick = MenuElement({type = MENU, id = "Warwick", name = "Rugal Vaper - Warwick"})
    
    Warwick:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Warwick:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Warwick.Combo:MenuElement({id = "Q", name = "Q - Jaws of the Beast", value = true})
    Warwick.Combo:MenuElement({id = "E", name = "E - Primal Howl", value = true})
    Warwick.Combo:MenuElement({id = "R", name = "R - Infinite Duress", value = true})
    
    Warwick:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Warwick.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Warwick.Harass:MenuElement({id = "Q", name = "Q - Jaws of the Beast", value = true})
    Warwick.Harass:MenuElement({id = "E", name = "E - Primal Howl", value = true})
    Warwick.Harass:MenuElement({id = "R", name = "R - Infinite Duress", value = true})
    
    Warwick:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Warwick.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Warwick.Clear:MenuElement({id = "Q", name = "Q - Jaws of the Beast", value = true})

    Warwick:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Warwick.Flee:MenuElement({id = "E", name = "E - Primal Howl", value = true})
    
    Warwick:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Warwick.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Warwick.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Warwick.Draw:MenuElement({id = "R", name = "R Range", value = true})
    Warwick.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Warwick.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Warwick.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Warwick.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Warwick.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Warwick.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Warwick.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Warwick.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Warwick.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Warwick.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Warwick:Tick()
    if not Warwick.Enable:Value() then return end
    self:Rrange()
    local mode = GetMode()
    if mode == "Combo" then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and Warwick.Combo.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Warwick.Combo.E:Value() then
            self:CastE()
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Warwick.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Harass" and Warwick.Harass.T:Value() then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and Warwick.Harass.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Warwick.Harass.E:Value() then
            self:CastE()
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Warwick.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Clear" and Warwick.Clear.T:Value() then
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Warwick.Clear.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Flee" then
        local Etarget = ClosestHero(E.Range,foe) 
        if Etarget and Warwick.Flee.E:Value() then
            self:CastE()
        end
    end
end

function Warwick:CastR(target,precision)
    local precision = precision or 1
	if Ready(_R) and IsUp(_R) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= R.Range then
                EnableOrb(false)
                Control.CastSpell(HK_R, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Warwick:Rrange()
    R.Range = myHero.ms * 2.50 - 275
end

function Warwick:CastQ(target)
	if Ready(_Q) and IsUp(_Q) then
        EnableOrb(false)
        Control.CastSpell(HK_Q,target)
        EnableOrb(true)
    end
end

function Warwick:CastE()
    if Ready(_E) and IsUp(_E) then
        EnableOrb(false)
        Control.CastSpell(HK_E)
        EnableOrb(true)
    end
end

function Warwick:Draw()
    if not Warwick.Enable:Value() then return end
    local target = GetTarget(2000)
    if Warwick.dead then return end
    if Warwick.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Warwick.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    if Warwick.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 255, 000, 000)) end
    local textPos = myHero.pos:To2D()
    if Warwick.Draw.Harass.Text:Value() then
        local size = Warwick.Draw.Harass.Size:Value()
	    local xPos = Warwick.Draw.Harass.xPos:Value()
	    local yPos = Warwick.Draw.Harass.yPos:Value()
        if Warwick.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Warwick.Draw.Clear.Text:Value() then
        local size = Warwick.Draw.Clear.Size:Value()
	    local xPos = Warwick.Draw.Clear.xPos:Value()
	    local yPos = Warwick.Draw.Clear.yPos:Value()
        if Warwick.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Zyra"

function Zyra:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Zyra:LoadSpells()
    Q = { Range = 800, Delay = 0.625, Speed = mathhuge, Width = 100}
    W = { Range = 850}
    E = { Range = 1100, Delay = 0.25, Speed = 1150, Width = 70}
    R = { Range = 700, Delay = 1.775, Speed = mathhuge, Width = 575}
end

function Zyra:LoadMenu()
	Zyra = MenuElement({type = MENU, id = "Zyra", name = "Rugal Vaper - Zyra"})
    
    Zyra:MenuElement({id = "Enable", name = "Enable Hero", value = true})

    Zyra:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Zyra.Combo:MenuElement({id = "Q", name = "Q - Deadly Spines", value = true})
    Zyra.Combo:MenuElement({id = "E", name = "E - Grasping Roots", value = true})
    Zyra.Combo:MenuElement({id = "R", name = "R - Stranglethorns", value = true})
    Zyra.Combo:MenuElement({id = "X", name = "R Enemies", value = 2, min = 1, max = 5})
    
    Zyra:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Zyra.Harass:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("S"), toggle = true, value = true})
    Zyra.Harass:MenuElement({id = "Q", name = "Q - Deadly Spines", value = true})
    Zyra.Harass:MenuElement({id = "AQ", name = "Auto Q", value = true})
    Zyra.Harass:MenuElement({id = "E", name = "E - Grasping Roots", value = true})
    Zyra.Harass:MenuElement({id = "AE", name = "Auto E", value = true})
    Zyra.Harass:MenuElement({id = "R", name = "R - Stranglethorns", value = true})
    Zyra.Harass:MenuElement({id = "X", name = "R Enemies", value = 2, min = 1, max = 5})
    
    Zyra:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Zyra.Clear:MenuElement({id = "T", name = "Toggle Spells", key = string.byte("A"), toggle = true, value = true})
    Zyra.Clear:MenuElement({id = "Q", name = "Q - Deadly Spines", value = true})
    Zyra.Clear:MenuElement({id = "E", name = "E - Grasping Roots", value = true})

    Zyra:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Zyra.Flee:MenuElement({id = "E", name = "E - Grasping Roots", value = true})
    
    Zyra:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    Zyra.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Zyra.Draw:MenuElement({id = "E", name = "E Range", value = true})
    Zyra.Draw:MenuElement({id = "R", name = "R Range", value = true})
    Zyra.Draw:MenuElement({id = "Harass", name = "Harass Status", type = MENU})
    Zyra.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Zyra.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Zyra.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Zyra.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})
    Zyra.Draw:MenuElement({id = "Clear", name = "Clear Status", type = MENU})
    Zyra.Draw.Clear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    Zyra.Draw.Clear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    Zyra.Draw.Clear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    Zyra.Draw.Clear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})
end

function Zyra:Tick()
    if not Zyra.Enable:Value() then return end
    if Zyra.Harass.T:Value() then
        local Etarget = GetTarget(E.Range)
        if Etarget and Zyra.Harass.AE:Value() then
            self:CastE(Etarget,2)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Zyra.Harass.AQ:Value() then
            self:CastQ(Qtarget,2)
        end
    end
    local mode = GetMode()
    if mode == "Combo" then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and HeroesAround(R.Width,Rtarget.pos,foe) >= Zyra.Combo.X:Value() and Zyra.Combo.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Zyra.Combo.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Zyra.Combo.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Harass" and Zyra.Harass.T:Value() then
        local Rtarget = GetTarget(R.Range)
        if Rtarget and HeroesAround(R.Width,Rtarget.pos,foe) >= Zyra.Harass.X:Value() and Zyra.Harass.R:Value() then
            self:CastR(Rtarget)
        end
        local Etarget = GetTarget(E.Range) 
        if Etarget and Zyra.Harass.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetTarget(Q.Range)
        if Qtarget and Zyra.Harass.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Clear" and Zyra.Clear.T:Value() then
        local Etarget = GetClearMinion(E.Range)
        if Etarget and Zyra.Clear.E:Value() then
            self:CastE(Etarget)
        end
        local Qtarget = GetClearMinion(Q.Range)
        if Qtarget and Zyra.Clear.Q:Value() then
            self:CastQ(Qtarget)
        end
    end
    if mode == "Flee" then
        local Etarget = ClosestHero(E.Range,foe) 
        if Etarget and Zyra.Flee.E:Value() then
            self:CastE(Etarget)
        end
    end
end

function Zyra:CastR(target,precision)
    local precision = precision or 1
	if Ready(_R) and IsUp(_R) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, R.Range, R.Delay, R.Speed, R.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= R.Range then
                EnableOrb(false)
                Control.CastSpell(HK_R, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Zyra:CastQ(target,precision)
    local precision = precision or 1
	if Ready(_Q) and IsUp(_Q) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, Q.Range, Q.Delay, Q.Speed, Q.Width, false, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= Q.Range then
                EnableOrb(false)
                Control.CastSpell(HK_Q, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Zyra:CastE(target,precision)
    local precision = precision or 1
	if Ready(_E) and IsUp(_E) then
        if target and HPred:CanTarget(target) then
            local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, target, E.Range, E.Delay, E.Speed, E.Width, true, nil)
            if hitChance and hitChance >= precision and HPred:GetDistance(myHero.pos, aimPosition) <= E.Range then
                EnableOrb(false)
                Control.CastSpell(HK_E, aimPosition)
                EnableOrb(true)
            end
        end
    end
end

function Zyra:Draw()
    if not Zyra.Enable:Value() then return end
    local target = GetTarget(2000)
    if Zyra.dead then return end
    if Zyra.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 000, 255)) end
    if Zyra.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 255, 255, 000)) end
    if Zyra.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 255, 000, 000)) end
    local textPos = myHero.pos:To2D()
    if Zyra.Draw.Harass.Text:Value() then
        local size = Zyra.Draw.Harass.Size:Value()
	    local xPos = Zyra.Draw.Harass.xPos:Value()
	    local yPos = Zyra.Draw.Harass.yPos:Value()
        if Zyra.Harass.T:Value() then
		    Draw.Text("HARASS ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("HARASS OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if Zyra.Draw.Clear.Text:Value() then
        local size = Zyra.Draw.Clear.Size:Value()
	    local xPos = Zyra.Draw.Clear.xPos:Value()
	    local yPos = Zyra.Draw.Clear.yPos:Value()
        if Zyra.Clear.T:Value() then
		    Draw.Text("CLEAR ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
	    else
            Draw.Text("CLEAR OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
end

class "Utility"

function Utility:__init()
	self:Menu()
	Callback.Add("Tick", function() self:Tick() end)
end

function Utility:Menu()
    Vaper = MenuElement({type = MENU, id = "Vaper", name = "Rugal Vaper - Activator"})

    Vaper:MenuElement({id = "Enable", name = "Enable Activator", value = true})

    Vaper:MenuElement({type = MENU, id = "Potion", name = "Potion"})
    Vaper.Potion:MenuElement({id = "CorruptingPotion", name = "Corrupting Potion", value = true})
    Vaper.Potion:MenuElement({id = "HP1", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "MP1", name = "Mana % to Potion", value = 25, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "HealthPotion", name = "Health Potion", value = true})
    Vaper.Potion:MenuElement({id = "HP2", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "HuntersPotion", name = "Hunter's Potion", value = true})
    Vaper.Potion:MenuElement({id = "HP3", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "MP3", name = "Mana % to Potion", value = 25, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "RefillablePotion", name = "Refillable Potion", value = true})
    Vaper.Potion:MenuElement({id = "HP4", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "ManaPotion", name = "Mana Potion", value = true})
    Vaper.Potion:MenuElement({id = "MP5", name = "Mana % to Potion", value = 25, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "PilferedHealthPotion", name = "Pilfered Health Potion", value = true})
    Vaper.Potion:MenuElement({id = "HP6", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "TotalBiscuitofEverlastingWill", name = "Total Biscuit of Everlasting Will", value = true})
    Vaper.Potion:MenuElement({id = "HP7", name = "Health % to Potion", value = 60, min = 0, max = 100})
    Vaper.Potion:MenuElement({id = "MP7", name = "Mana % to Potion", value = 25, min = 0, max = 100})
    
    Vaper:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Vaper.Combo:MenuElement({id = "Ignite", name = "Ignite", value = true})
    Vaper.Combo:MenuElement({id = "Smite", name = "Smite", value = true})
    Vaper.Combo:MenuElement({id = "Exhaust", name = "Exhaust", value = true})
    Vaper.Combo:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Combo:MenuElement({id = "BilgewaterCutlass", name = "Bilgewater Cutlass", value = true})
    Vaper.Combo:MenuElement({id = "Tiamat", name = "Tiamat", value = true})
    Vaper.Combo:MenuElement({id = "BladeoftheRuinedKing", name = "Blade of the Ruined King", value = true})
    Vaper.Combo:MenuElement({id = "HextechGLP800", name = "Hextech GLP-800", value = true})
    Vaper.Combo:MenuElement({id = "HextechGunblade", name = "Hextech Gunblade", value = true})
    Vaper.Combo:MenuElement({id = "HextechProtobelt01", name = "Hextech Protobelt-01", value = true})
    Vaper.Combo:MenuElement({id = "RanduinsOmen", name = "Randuin's Omen", value = true})
    Vaper.Combo:MenuElement({id = "RavenousHydra", name = "Ravenous Hydra", value = true})
    Vaper.Combo:MenuElement({id = "Spellbinder", name = "Spellbinder", value = true})
    Vaper.Combo:MenuElement({id = "TitanicHydra", name = "Titanic Hydra", value = true})

    Vaper:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Vaper.Harass:MenuElement({id = "Ignite", name = "Ignite", value = true})
    Vaper.Harass:MenuElement({id = "Smite", name = "Smite", value = true})
    Vaper.Harass:MenuElement({id = "Exhaust", name = "Exhaust", value = true})
    Vaper.Harass:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Harass:MenuElement({id = "BilgewaterCutlass", name = "Bilgewater Cutlass", value = true})
    Vaper.Harass:MenuElement({id = "Tiamat", name = "Tiamat", value = true})
    Vaper.Harass:MenuElement({id = "BladeoftheRuinedKing", name = "Blade of the Ruined King", value = true})
    Vaper.Harass:MenuElement({id = "HextechGLP800", name = "Hextech GLP-800", value = true})
    Vaper.Harass:MenuElement({id = "HextechGunblade", name = "Hextech Gunblade", value = true})
    Vaper.Harass:MenuElement({id = "HextechProtobelt01", name = "Hextech Protobelt-01", value = true})
    Vaper.Harass:MenuElement({id = "RanduinsOmen", name = "Randuin's Omen", value = true})
    Vaper.Harass:MenuElement({id = "RavenousHydra", name = "Ravenous Hydra", value = true})
    Vaper.Harass:MenuElement({id = "Spellbinder", name = "Spellbinder", value = true})
    Vaper.Harass:MenuElement({id = "TitanicHydra", name = "Titanic Hydra", value = true})

    Vaper:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Vaper.Clear:MenuElement({id = "Tiamat", name = "Tiamat", value = true})
    Vaper.Clear:MenuElement({id = "HextechGLP800", name = "Hextech GLP-800", value = true})
    Vaper.Clear:MenuElement({id = "HextechProtobelt01", name = "Hextech Protobelt-01", value = true})
    Vaper.Clear:MenuElement({id = "RavenousHydra", name = "Ravenous Hydra", value = true})
    Vaper.Clear:MenuElement({id = "TitanicHydra", name = "Titanic Hydra", value = true})

    Vaper:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Vaper.Flee:MenuElement({id = "Exhaust", name = "Exhaust", value = true})
    Vaper.Flee:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Flee:MenuElement({id = "BilgewaterCutlass", name = "Bilgewater Cutlass", value = true})
    Vaper.Flee:MenuElement({id = "BladeoftheRuinedKing", name = "Blade of the Ruined King", value = true})
    Vaper.Flee:MenuElement({id = "HextechGLP800", name = "Hextech GLP-800", value = true})
    Vaper.Flee:MenuElement({id = "HextechGunblade", name = "Hextech Gunblade", value = true})
    Vaper.Flee:MenuElement({id = "HextechProtobelt01", name = "Hextech Protobelt-01", value = true})
    Vaper.Flee:MenuElement({id = "RanduinsOmen", name = "Randuin's Omen", value = true})
    Vaper.Flee:MenuElement({id = "RighteousGlory", name = "Righteous Glory", value = true})
    Vaper.Flee:MenuElement({id = "TwinShadows", name = "Twin Shadows", value = true})
    Vaper.Flee:MenuElement({id = "YoumuusGhostblade", name = "Youmuu's Ghostblade", value = true})

    Vaper:MenuElement({type = MENU, id = "Shield", name = "Shield"})
    Vaper.Shield:MenuElement({id = "Barrier", name = "Barrier", value = true})
    Vaper.Shield:MenuElement({id = "HPS1", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Shield:MenuElement({id = "Stopwatch", name = "Stopwatch", value = true})
    Vaper.Shield:MenuElement({id = "HP1", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = "GargoyleStoneplate", name = "Gargoyle Stoneplate", value = true})
    Vaper.Shield:MenuElement({id = "HP2", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = "LocketoftheIronSolari", name = "Locket of the Iron Solari", value = true})
    Vaper.Shield:MenuElement({id = "HP3", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = "SeraphsEmbrace", name = "Seraph's Embrace", value = true})
    Vaper.Shield:MenuElement({id = "HP4", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = "WoogletsWitchcap", name = "Wooglet's Witchcap", value = true})
    Vaper.Shield:MenuElement({id = "HP5", name = "Health % to Shield", value = 15, min = 0, max = 100})
    Vaper.Shield:MenuElement({id = "ZhonyasHourglass", name = "Zhonya's Hourglass", value = true})
    Vaper.Shield:MenuElement({id = "HP6", name = "Health % to Shield", value = 15, min = 0, max = 100})

    Vaper:MenuElement({type = MENU, id = "Heal", name = "Heal"})
    Vaper.Heal:MenuElement({id = "Heal", name = "Heal", value = true})
    Vaper.Heal:MenuElement({id = "HPS1", name = "Health % to Heal", value = 15, min = 0, max = 100})
    Vaper.Heal:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Heal:MenuElement({id = "Redemption", name = "Redemption", value = true})
    Vaper.Heal:MenuElement({id = "HP1", name = "Health % to Heal", value = 15, min = 0, max = 100})

    Vaper:MenuElement({type = MENU, id = "Auto", name = "Auto"})
    Vaper.Auto:MenuElement({id = "Ignite", name = "Ignite", value = true})

    Vaper:MenuElement({type = MENU, id = "Cleanse", name = "Cleanse"})
    Vaper.Cleanse:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
    Vaper.Cleanse:MenuElement({id = "DS1", name = "Duration to Cleanse", value = 1, min = .1, max = 5, step = .1})
    Vaper.Cleanse:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Cleanse:MenuElement({id = "QuicksilverSash", name = "Quicksilver Sash", value = true})
    Vaper.Cleanse:MenuElement({id = "D1", name = "Duration to Cleanse", value = 1, min = .1, max = 5, step = .1})
    Vaper.Cleanse:MenuElement({id = "MercurialScimitar", name = "Mercurial Scimitar", value = true})
    Vaper.Cleanse:MenuElement({id = "D2", name = "Duration to Cleanse", value = 1, min = .1, max = 5, step = .1})
    Vaper.Cleanse:MenuElement({id = "MikaelsCrucible", name = "Mikael's Crucible", value = true})
    Vaper.Cleanse:MenuElement({id = "D3", name = "Duration to Cleanse", value = 1, min = .1, max = 5, step = .1})
    Vaper.Cleanse:MenuElement({id = " ", name = " ", type = SPACE})
    Vaper.Cleanse:MenuElement({id = "Stun", name = "Stun", value = true})
    Vaper.Cleanse:MenuElement({id = "Root", name = "Root", value = true})
    Vaper.Cleanse:MenuElement({id = "Taunt", name = "Taunt", value = true})
    Vaper.Cleanse:MenuElement({id = "Fear", name = "Fear", value = true})
    Vaper.Cleanse:MenuElement({id = "Charm", name = "Charm", value = true})
    Vaper.Cleanse:MenuElement({id = "Silence", name = "Silence", value = true})
    Vaper.Cleanse:MenuElement({id = "Slow", name = "Slow", value = true})
    Vaper.Cleanse:MenuElement({id = "Blind", name = "Blind", value = true})
    Vaper.Cleanse:MenuElement({id = "Disarm", name = "Disarm", value = true})
    Vaper.Cleanse:MenuElement({id = "Sleep", name = "Sleep", value = true})
    Vaper.Cleanse:MenuElement({id = "Nearsight", name = "Nearsight", value = true})
    Vaper.Cleanse:MenuElement({id = "Suppression", name = "Suppression", value = true})
end

function Utility:Tick()
    if not Vaper.Enable:Value() then return end
    self:Auto()
    self:Cleanse()
    self:Shield()
    self:Heal()
    local mode = GetMode()
    if mode == "Combo" then
        self:Combo()
    end
    if mode == "Harass" then
        self:Harass()
    end
    if mode == "Clear" then
        self:Clear()
    end
    if mode == "Flee" then
        self:Flee()
    end
end

function Utility:Auto()
    local ExistIgnite = ExistSpell("SummonerDot")
    local IgniteSlot = SummonerSlot("SummonerDot")
    local IgniteDamage = 70 + 20 * myHero.levelData.lvl
    local IgniteTarget = ClosestHero(600,foe)
    if ExistIgnite and Ready(IgniteSlot) and IgniteTarget and Vaper.Auto.Ignite:Value() then
        if IgniteDamage > IgniteTarget.health then
            Control.CastSpell(HKSPELL[IgniteSlot], IgniteTarget)
        end
    end
end

function Utility:Combo()
    local PostAttack = myHero.attackData.state == STATE_WINDDOWN
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local BilgewaterCutlass = items[3144]
    local Tiamat = items[3077]
    local BladeoftheRuinedKing = items[3153]
    local HextechGLP800 = items[3030]
    local HextechGunblade = items[3146]
    local HextechProtobelt01 = items[3152]
    local RanduinsOmen = items[3143]
    local RavenousHydra = items[3074]
    local Spellbinder = items[3907]
    local TitanicHydra = items[3748]
    
    local BilgewaterCutlassTarget = GetTarget(550)
    if BilgewaterCutlass and Ready(BilgewaterCutlass) and BilgewaterCutlassTarget and Vaper.Combo.BilgewaterCutlass:Value() then
        Control.CastSpell(HKITEM[BilgewaterCutlass], BilgewaterCutlassTarget)
    end
    local TiamatTarget = GetTarget(400)
    if Tiamat and Ready(Tiamat) and TiamatTarget and Vaper.Combo.Tiamat:Value() and PostAttack then
        Control.CastSpell(HKITEM[Tiamat], TiamatTarget)
    end
    local BladeoftheRuinedKingTarget = GetTarget(550)
    if BladeoftheRuinedKing and Ready(BladeoftheRuinedKing) and BladeoftheRuinedKingTarget and Vaper.Combo.BladeoftheRuinedKing:Value() then
        Control.CastSpell(HKITEM[BladeoftheRuinedKing], BladeoftheRuinedKingTarget)
    end
    local HextechGLP800Target = GetTarget(700)
    if HextechGLP800 and Ready(HextechGLP800) and HextechGLP800Target and Vaper.Combo.HextechGLP800:Value() then
        Control.CastSpell(HKITEM[HextechGLP800], HextechGLP800Target)
    end
    local HextechGunbladeTarget = GetTarget(700)
    if HextechGunblade and Ready(HextechGunblade) and HextechGunbladeTarget and Vaper.Combo.HextechGunblade:Value() then
        Control.CastSpell(HKITEM[HextechGunblade], HextechGunbladeTarget)
    end
    local HextechProtobelt01Target = GetTarget(700)
    if HextechProtobelt01 and Ready(HextechProtobelt01) and HextechProtobelt01Target and Vaper.Combo.HextechProtobelt01:Value() then
        Control.CastSpell(HKITEM[HextechProtobelt01], HextechProtobelt01Target)
    end
    local RanduinsOmenTarget = GetTarget(500)
    if RanduinsOmen and Ready(RanduinsOmen) and RanduinsOmenTarget and Vaper.Combo.RanduinsOmen:Value() then
        Control.CastSpell(HKITEM[RanduinsOmen])
    end
    local RavenousHydraTarget = GetTarget(400)
    if RavenousHydra and Ready(RavenousHydra) and RavenousHydraTarget and Vaper.Combo.RavenousHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[RavenousHydra], RavenousHydraTarget)
    end
    local SpellbinderTarget = GetTarget(900)
    if Spellbinder and Ready(Spellbinder) and SpellbinderTarget and Vaper.Combo.Spellbinder:Value() then
        Control.CastSpell(HKITEM[Spellbinder])
    end
    local TitanicHydraTarget = GetTarget(400)
    if TitanicHydra and Ready(TitanicHydra) and TitanicHydraTarget and Vaper.Combo.TitanicHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[TitanicHydra], TitanicHydraTarget)
    end

    local ExistIgnite = ExistSpell("SummonerDot")
    local IgniteSlot = SummonerSlot("SummonerDot")
    local IgniteTarget = GetTarget(600)
    if ExistIgnite and Ready(IgniteSlot) and IgniteTarget and Vaper.Combo.Ignite:Value() then
        Control.CastSpell(HKSPELL[IgniteSlot], IgniteTarget)
    end
    local ExistExhaust = ExistSpell("SummonerExhaust")
    local ExhaustSlot = SummonerSlot("SummonerExhaust")
    local ExhaustTarget = GetTarget(650)
    if ExistExhaust and Ready(ExhaustSlot) and ExhaustTarget and Vaper.Combo.Exhaust:Value() then
        Control.CastSpell(HKSPELL[ExhaustSlot], ExhaustTarget)
    end
    local ExistSmite = ExistSpell("S5_SummonerSmitePlayerGanker") or ExistSpell("S5_SummonerSmiteDuel")
    local SmiteSlot = SummonerSlot("S5_SummonerSmitePlayerGanker") or SummonerSlot("S5_SummonerSmiteDuel")
    local SmiteTarget = GetTarget(500 + myHero.boundingRadius)
    if ExistSmite and Ready(SmiteSlot) and IsUp(SmiteSlot) and SmiteTarget and Vaper.Combo.Smite:Value() then
        Control.CastSpell(HKSPELL[SmiteSlot], SmiteTarget)
    end
end

function Utility:Harass()
    local PostAttack = myHero.attackData.state == STATE_WINDDOWN
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local BilgewaterCutlass = items[3144]
    local Tiamat = items[3077]
    local BladeoftheRuinedKing = items[3153]
    local HextechGLP800 = items[3030]
    local HextechGunblade = items[3146]
    local HextechProtobelt01 = items[3152]
    local RanduinsOmen = items[3143]
    local RavenousHydra = items[3074]
    local Spellbinder = items[3907]
    local TitanicHydra = items[3748]
    
    local BilgewaterCutlassTarget = GetTarget(550)
    if BilgewaterCutlass and Ready(BilgewaterCutlass) and BilgewaterCutlassTarget and Vaper.Harass.BilgewaterCutlass:Value() then
        Control.CastSpell(HKITEM[BilgewaterCutlass], BilgewaterCutlassTarget)
    end
    local TiamatTarget = GetTarget(400)
    if Tiamat and Ready(Tiamat) and TiamatTarget and Vaper.Harass.Tiamat:Value() and PostAttack then
        Control.CastSpell(HKITEM[Tiamat], TiamatTarget)
    end
    local BladeoftheRuinedKingTarget = GetTarget(550)
    if BladeoftheRuinedKing and Ready(BladeoftheRuinedKing) and BladeoftheRuinedKingTarget and Vaper.Harass.BladeoftheRuinedKing:Value() then
        Control.CastSpell(HKITEM[BladeoftheRuinedKing], BladeoftheRuinedKingTarget)
    end
    local HextechGLP800Target = GetTarget(700)
    if HextechGLP800 and Ready(HextechGLP800) and HextechGLP800Target and Vaper.Harass.HextechGLP800:Value() then
        Control.CastSpell(HKITEM[HextechGLP800], HextechGLP800Target)
    end
    local HextechGunbladeTarget = GetTarget(700)
    if HextechGunblade and Ready(HextechGunblade) and HextechGunbladeTarget and Vaper.Harass.HextechGunblade:Value() then
        Control.CastSpell(HKITEM[HextechGunblade], HextechGunbladeTarget)
    end
    local HextechProtobelt01Target = GetTarget(700)
    if HextechProtobelt01 and Ready(HextechProtobelt01) and HextechProtobelt01Target and Vaper.Harass.HextechProtobelt01:Value() then
        Control.CastSpell(HKITEM[HextechProtobelt01], HextechProtobelt01Target)
    end
    local RanduinsOmenTarget = GetTarget(500)
    if RanduinsOmen and Ready(RanduinsOmen) and RanduinsOmenTarget and Vaper.Harass.RanduinsOmen:Value() then
        Control.CastSpell(HKITEM[RanduinsOmen])
    end
    local RavenousHydraTarget = GetTarget(400)
    if RavenousHydra and Ready(RavenousHydra) and RavenousHydraTarget and Vaper.Harass.RavenousHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[RavenousHydra], RavenousHydraTarget)
    end
    local SpellbinderTarget = GetTarget(900)
    if Spellbinder and Ready(Spellbinder) and SpellbinderTarget and Vaper.Harass.Spellbinder:Value() then
        Control.CastSpell(HKITEM[Spellbinder])
    end
    local TitanicHydraTarget = GetTarget(400)
    if TitanicHydra and Ready(TitanicHydra) and TitanicHydraTarget and Vaper.Harass.TitanicHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[TitanicHydra], TitanicHydraTarget)
    end

    local ExistIgnite = ExistSpell("SummonerDot")
    local IgniteSlot = SummonerSlot("SummonerDot")
    local IgniteTarget = GetTarget(600)
    if ExistIgnite and Ready(IgniteSlot) and IgniteTarget and Vaper.Harass.Ignite:Value() then
        Control.CastSpell(HKSPELL[IgniteSlot], IgniteTarget)
    end
    local ExistExhaust = ExistSpell("SummonerExhaust")
    local ExhaustSlot = SummonerSlot("SummonerExhaust")
    local ExhaustTarget = GetTarget(650)
    if ExistExhaust and Ready(ExhaustSlot) and ExhaustTarget and Vaper.Harass.Exhaust:Value() then
        Control.CastSpell(HKSPELL[ExhaustSlot], ExhaustTarget)
    end
    local ExistSmite = ExistSpell("S5_SummonerSmitePlayerGanker") or ExistSpell("S5_SummonerSmiteDuel")
    local SmiteSlot = SummonerSlot("S5_SummonerSmitePlayerGanker") or SummonerSlot("S5_SummonerSmiteDuel")
    local SmiteTarget = GetTarget(500 + myHero.boundingRadius)
    if ExistSmite and Ready(SmiteSlot) and IsUp(SmiteSlot) and SmiteTarget and Vaper.Harass.Smite:Value() then
        Control.CastSpell(HKSPELL[SmiteSlot], SmiteTarget)
    end
end

function Utility:Clear()
    local PostAttack = myHero.attackData.state == STATE_WINDDOWN
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Tiamat = items[3077]
    local HextechGLP800 = items[3030]
    local HextechProtobelt01 = items[3152]
    local RavenousHydra = items[3074]
    local TitanicHydra = items[3748]

    local TiamatTarget = GetClearMinion(400)
    if Tiamat and Ready(Tiamat) and TiamatTarget and Vaper.Clear.Tiamat:Value() and PostAttack then
        Control.CastSpell(HKITEM[Tiamat], TiamatTarget)
    end
    local HextechGLP800Target = GetClearMinion(700)
    if HextechGLP800 and Ready(HextechGLP800) and HextechGLP800Target and Vaper.Clear.HextechGLP800:Value() then
        Control.CastSpell(HKITEM[HextechGLP800], HextechGLP800Target)
    end
    local HextechProtobelt01Target = GetClearMinion(700)
    if HextechProtobelt01 and Ready(HextechProtobelt01) and HextechProtobelt01Target and Vaper.Clear.HextechProtobelt01:Value() then
        Control.CastSpell(HKITEM[HextechProtobelt01], HextechProtobelt01Target)
    end
    local RavenousHydraTarget = GetClearMinion(400)
    if RavenousHydra and Ready(RavenousHydra) and RavenousHydraTarget and Vaper.Clear.RavenousHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[RavenousHydra], RavenousHydraTarget)
    end
    local TitanicHydraTarget = GetClearMinion(400)
    if TitanicHydra and Ready(TitanicHydra) and TitanicHydraTarget and Vaper.Clear.TitanicHydra:Value() and PostAttack then
        Control.CastSpell(HKITEM[TitanicHydra], TitanicHydraTarget)
    end
end

function Utility:Flee()
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local BilgewaterCutlass = items[3144]
    local BladeoftheRuinedKing = items[3153]
    local HextechGLP800 = items[3030]
    local HextechGunblade = items[3146]
    local HextechProtobelt01 = items[3152]
    local RanduinsOmen = items[3143]
    local RighteousGlory = items[3800]
    local ShurelyasReverie = items[2056]
    local TwinShadows = items[3905]
    local YoumuusGhostblade = items[3142]

    local BilgewaterCutlassTarget = ClosestHero(550,foe)
    if BilgewaterCutlass and Ready(BilgewaterCutlass) and BilgewaterCutlassTarget and Vaper.Flee.BilgewaterCutlass:Value() then
        Control.CastSpell(HKITEM[BilgewaterCutlass], BilgewaterCutlassTarget)
    end
    local BladeoftheRuinedKingTarget = ClosestHero(550,foe)
    if BladeoftheRuinedKing and Ready(BladeoftheRuinedKing) and BladeoftheRuinedKingTarget and Vaper.Flee.BladeoftheRuinedKing:Value() then
        Control.CastSpell(HKITEM[BladeoftheRuinedKing], BladeoftheRuinedKingTarget)
    end
    local HextechGLP800Target = ClosestHero(700,foe)
    if HextechGLP800 and Ready(HextechGLP800) and HextechGLP800Target and Vaper.Flee.HextechGLP800:Value() then
        Control.CastSpell(HKITEM[HextechGLP800], HextechGLP800Target)
    end
    local HextechGunbladeTarget = ClosestHero(700,foe)
    if HextechGunblade and Ready(HextechGunblade) and HextechGunbladeTarget and Vaper.Flee.HextechGunblade:Value() then
        Control.CastSpell(HKITEM[HextechGunblade], HextechGunbladeTarget)
    end
    if HextechProtobelt01 and Ready(HextechProtobelt01) and Vaper.Flee.HextechProtobelt01:Value() then
        Control.CastSpell(HKITEM[HextechProtobelt01], Game.cursorPos())
    end
    local RanduinsOmenTarget = ClosestHero(500,foe)
    if RanduinsOmen and Ready(RanduinsOmen) and RanduinsOmenTarget and Vaper.Flee.RanduinsOmen:Value() then
        Control.CastSpell(HKITEM[RanduinsOmen])
    end
    if RighteousGlory and Ready(RighteousGlory) and Vaper.Flee.RighteousGlory:Value() then
        Control.CastSpell(HKITEM[RighteousGlory])
    end
    local TwinShadowsTarget = ClosestHero(1500,foe)
    if TwinShadows and Ready(TwinShadows) and TwinShadowsTarget and Vaper.Flee.TwinShadows:Value() then
        Control.CastSpell(HKITEM[TwinShadows])
    end
    if YoumuusGhostblade and Ready(YoumuusGhostblade) and Vaper.Flee.YoumuusGhostblade:Value() then
        Control.CastSpell(HKITEM[YoumuusGhostblade])
    end

    local ExistExhaust = ExistSpell("SummonerExhaust")
    local ExhaustSlot = SummonerSlot("SummonerExhaust")
    local ExhaustTarget = GetTarget(650)
    if ExistExhaust and Ready(ExhaustSlot) and ExhaustTarget and Vaper.Flee.Exhaust:Value() then
        Control.CastSpell(HKSPELL[ExhaustSlot], ExhaustTarget)
    end
end

function Utility:Shield()
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Stopwatch = items[2420] or items[2423]
    local GargoyleStoneplate = items[3193]
    local LocketoftheIronSolari = items[3190] or items[3383]
    local SeraphsEmbrace = items[3040] or items[3048]
    local WoogletsWitchcap = items[3090] or items[3385]
    local ZhonyasHourglass = items[3157] or items[3386]

    local StopwatchTarget = ClosestHero(700,foe)
    if Stopwatch and Ready(Stopwatch) and StopwatchTarget and Vaper.Shield.Stopwatch:Value() and Hp() < Vaper.Shield.HP1:Value() then
        Control.CastSpell(HKITEM[Stopwatch])
    end
    local GargoyleStoneplateTarget = ClosestHero(1500,foe)
    if GargoyleStoneplate and Ready(GargoyleStoneplate) and GargoyleStoneplateTarget and Vaper.Shield.GargoyleStoneplate:Value() and Hp() < Vaper.Shield.HP2:Value() then
        Control.CastSpell(HKITEM[GargoyleStoneplate])
    end
    local LocketoftheIronSolariAlly = ClosestInjuredHero(600,friend,Vaper.Shield.HP3:Value(),true)
    if LocketoftheIronSolari and Ready(LocketoftheIronSolari) and LocketoftheIronSolariAlly and HeroesAround(1500,LocketoftheIronSolariAlly.pos) ~= 0 and Vaper.Shield.LocketoftheIronSolari:Value() then
        Control.CastSpell(HKITEM[LocketoftheIronSolari])
    end
    local SeraphsEmbraceTarget = ClosestHero(1500,foe)
    if SeraphsEmbrace and Ready(SeraphsEmbrace) and SeraphsEmbraceTarget and Vaper.Shield.SeraphsEmbrace:Value() and Hp() < Vaper.Shield.HP4:Value() then
        Control.CastSpell(HKITEM[SeraphsEmbrace])
    end
    local WoogletsWitchcapTarget = ClosestHero(700,foe)
    if WoogletsWitchcap and Ready(WoogletsWitchcap) and WoogletsWitchcapTarget and Vaper.Shield.WoogletsWitchcap:Value() and Hp() < Vaper.Shield.HP5:Value() then
        Control.CastSpell(HKITEM[WoogletsWitchcap])
    end
    local ZhonyasHourglassTarget = ClosestHero(700,foe)
    if ZhonyasHourglass and Ready(ZhonyasHourglass) and ZhonyasHourglassTarget and Vaper.Shield.ZhonyasHourglass:Value() and Hp() < Vaper.Shield.HP6:Value() then
        Control.CastSpell(HKITEM[ZhonyasHourglass])
    end

    local ExistBarrier = ExistSpell("SummonerBarrier")
    local BarrierSlot = SummonerSlot("SummonerBarrier")
    local BarrierTarget = ClosestHero(1500,foe)
    if ExistBarrier and Ready(BarrierSlot) and BarrierTarget and Vaper.Shield.Barrier:Value() and Hp() < Vaper.Shield.HPS1:Value() then
        Control.CastSpell(HKSPELL[BarrierSlot])
    end
end

function Utility:Heal()
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local CorruptingPotion = items[2033]
    local HealthPotion = items[2003]
    local HuntersPotion = items[2032]
    local RefillablePotion = items[2031]
    local ManaPotion = items[2004]
    local PilferedHealthPotion = items[2061]
    local TotalBiscuitofEverlastingWill = items[2010]
    local Redemption = items[3107] or items[3382]

    local RedemptionAlly = ClosestInjuredHero(5500,friend,Vaper.Heal.HP1:Value(),true)
    if Redemption and Ready(Redemption) and RedemptionAlly and HeroesAround(1500,RedemptionAlly.pos) ~= 0 and Vaper.Heal.Redemption:Value() then
        Control.CastSpell(HKITEM[Redemption], RedemptionAlly)
    end

    local ExistHeal = ExistSpell("SummonerHeal")
    local HealSlot = SummonerSlot("SummonerHeal")
    local HealTarget = ClosestHero(1500,foe)
    if ExistHeal and Ready(HealSlot) and HealTarget and Vaper.Heal.Heal:Value() and Hp() < Vaper.Heal.HPS1:Value() then
        Control.CastSpell(HKSPELL[HealSlot])
    end

    if BuffByType(13,0.1) then return end

    local CorruptingPotionTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if CorruptingPotion and Ready(CorruptingPotion) and CorruptingPotionTarget and Vaper.Potion.CorruptingPotion:Value() and (Hp() < Vaper.Potion.HP1:Value() or Mp() < Vaper.Potion.MP1:Value()) then
        Control.CastSpell(HKITEM[CorruptingPotion])
    end
    local HealthPotionTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if HealthPotion and Ready(HealthPotion) and HealthPotionTarget and Vaper.Potion.HealthPotion:Value() and Hp() < Vaper.Potion.HP2:Value() then
        Control.CastSpell(HKITEM[HealthPotion])
    end
    local HuntersPotionTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if HuntersPotion and Ready(HuntersPotion) and HuntersPotionTarget and Vaper.Potion.HuntersPotion:Value() and (Hp() < Vaper.Potion.HP3:Value() or Mp() < Vaper.Potion.MP3:Value()) then
        Control.CastSpell(HKITEM[HuntersPotion])
    end
    local RefillablePotionTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if RefillablePotion and Ready(RefillablePotion) and RefillablePotionTarget and Vaper.Potion.RefillablePotion:Value() and Hp() < Vaper.Potion.HP4:Value() then
        Control.CastSpell(HKITEM[RefillablePotion])
    end
    local ManaPotionTarget = ClosestHero(1500,foe)
    if ManaPotion and Ready(ManaPotion) and ManaPotionTarget and Vaper.Potion.ManaPotion:Value() and Mp() < Vaper.Potion.MP5:Value() then
        Control.CastSpell(HKITEM[ManaPotion])
    end
    local PilferedHealthPotionTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if PilferedHealthPotion and Ready(PilferedHealthPotion) and PilferedHealthPotionTarget and Vaper.Potion.PilferedHealthPotion:Value() and Hp() < Vaper.Potion.HP6:Value() then
        Control.CastSpell(HKITEM[PilferedHealthPotion])
    end
    local TotalBiscuitofEverlastingWillTarget = ClosestHero(1500,foe) or ClosestMinion(400,neutral)
    if TotalBiscuitofEverlastingWill and Ready(TotalBiscuitofEverlastingWill) and TotalBiscuitofEverlastingWillTarget and Vaper.Potion.TotalBiscuitofEverlastingWill:Value() and (Hp() < Vaper.Potion.HP7:Value() or Mp() < Vaper.Potion.MP7:Value()) then
        Control.CastSpell(HKITEM[TotalBiscuitofEverlastingWill])
    end
end

function Utility:Cleanse()
    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local QuicksilverSash = items[3140]
    local MercurialScimitar = items[3139]
    local MikaelsCrucible = items[3222]

    local QuicksilverSashTarget = ClosestHero(1500,foe)
    if QuicksilverSash and Ready(QuicksilverSash) and QuicksilverSashTarget and Vaper.Cleanse.QuicksilverSash:Value() then
        if (BuffByType(5,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Stun:Value()) or
            (BuffByType(7,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Silence:Value()) or
            (BuffByType(8,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Taunt:Value()) or
            ((BuffByType(9,Vaper.Cleanse.D1:Value()) or BuffByType(31,Vaper.Cleanse.D1:Value())) and Vaper.Cleanse.Disarm:Value()) or
            (BuffByType(10,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Slow:Value()) or
            (BuffByType(11,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Root:Value()) or
            (BuffByType(18,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Sleep:Value()) or
            (BuffByType(19,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Nearsight:Value()) or
            ((BuffByType(21,Vaper.Cleanse.D1:Value()) or BuffByType(28,Vaper.Cleanse.D1:Value())) and Vaper.Cleanse.Fear:Value()) or
            (BuffByType(22,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Charm:Value()) or
            (BuffByType(24,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Suppression:Value()) or
            (BuffByType(25,Vaper.Cleanse.D1:Value()) and Vaper.Cleanse.Blind:Value()) then
            Control.CastSpell(HKITEM[QuicksilverSash])
        end
    end
    local MercurialScimitarTarget = ClosestHero(1500,foe)
    if MercurialScimitar and Ready(MercurialScimitar) and MercurialScimitarTarget and Vaper.Cleanse.MercurialScimitar:Value() then
        if (BuffByType(5,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Stun:Value()) or
            (BuffByType(7,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Silence:Value()) or
            (BuffByType(8,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Taunt:Value()) or
            ((BuffByType(9,Vaper.Cleanse.D2:Value()) or BuffByType(31,Vaper.Cleanse.D2:Value())) and Vaper.Cleanse.Disarm:Value()) or
            (BuffByType(10,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Slow:Value()) or
            (BuffByType(11,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Root:Value()) or
            (BuffByType(18,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Sleep:Value()) or
            (BuffByType(19,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Nearsight:Value()) or
            ((BuffByType(21,Vaper.Cleanse.D2:Value()) or BuffByType(28,Vaper.Cleanse.D2:Value())) and Vaper.Cleanse.Fear:Value()) or
            (BuffByType(22,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Charm:Value()) or
            (BuffByType(24,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Suppression:Value()) or
            (BuffByType(25,Vaper.Cleanse.D2:Value()) and Vaper.Cleanse.Blind:Value()) then
            Control.CastSpell(HKITEM[MercurialScimitar])
        end
    end
    local MikaelsCrucibleAlly = ClosestInjuredHero(750,friend,101,false)
    if MikaelsCrucible and Ready(MikaelsCrucible) and MikaelsCrucibleAlly and HeroesAround(1500,MikaelsCrucibleAlly.pos) ~= 0 and Vaper.Cleanse.MikaelsCrucible:Value() then
        if (BuffByType(5,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Stun:Value()) or
            (BuffByType(7,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Silence:Value()) or
            (BuffByType(8,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Taunt:Value()) or
            ((BuffByType(9,Vaper.Cleanse.D3:Value()) or BuffByType(31,Vaper.Cleanse.D3:Value())) and Vaper.Cleanse.Disarm:Value()) or
            (BuffByType(10,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Slow:Value()) or
            (BuffByType(11,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Root:Value()) or
            (BuffByType(18,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Sleep:Value()) or
            (BuffByType(19,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Nearsight:Value()) or
            ((BuffByType(21,Vaper.Cleanse.D3:Value()) or BuffByType(28,Vaper.Cleanse.D3:Value())) and Vaper.Cleanse.Fear:Value()) or
            (BuffByType(22,Vaper.Cleanse.D3:Value()) and Vaper.Cleanse.Charm:Value()) then
            Control.CastSpell(HKITEM[MikaelsCrucible], MikaelsCrucibleAlly)
        end
    end

    local ExistCleanse = ExistSpell("SummonerBoost")
    local CleanseSlot = SummonerSlot("SummonerBoost")
    local CleanseTarget = ClosestHero(1500,foe)
    if ExistCleanse and Ready(CleanseSlot) and CleanseTarget and Vaper.Cleanse.Cleanse:Value() then
        if (BuffByType(5,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Stun:Value()) or
            (BuffByType(7,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Silence:Value()) or
            (BuffByType(8,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Taunt:Value()) or
            ((BuffByType(9,Vaper.Cleanse.DS1:Value()) or BuffByType(31,Vaper.Cleanse.DS1:Value())) and Vaper.Cleanse.Disarm:Value()) or
            (BuffByType(10,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Slow:Value()) or
            (BuffByType(11,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Root:Value()) or
            (BuffByType(18,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Sleep:Value()) or
            (BuffByType(19,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Nearsight:Value()) or
            ((BuffByType(21,Vaper.Cleanse.DS1:Value()) or BuffByType(28,Vaper.Cleanse.DS1:Value())) and Vaper.Cleanse.Fear:Value()) or
            (BuffByType(22,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Charm:Value()) or
            (BuffByType(25,Vaper.Cleanse.DS1:Value()) and Vaper.Cleanse.Blind:Value()) then
            Control.CastSpell(HKSPELL[CleanseSlot])
        end      
    end
end

local Heroes = {"Ahri","DrMundo","Hecarim","Jayce","Soraka","Tryndamere","Vladimir","Warwick","Zyra"}
local Heroloaded = false
local ActivatorLoaded = false
Callback.Add("Load", function()
    if table.contains(Heroes, myHero.charName) and Heroloaded == false then
        _G[myHero.charName]()
        Heroloaded = true
    end
    if ActivatorLoaded == false then
        Utility()
        ActivatorLoaded = true
    end
end)

class "HPred"  Callback.Add("Tick", function() HPred:Tick() end)  local _reviveQueryFrequency = 3 local _lastReviveQuery = Game.Timer() local _reviveLookupTable = { ["LifeAura.troy"] = 4, ["ZileanBase_R_Buf.troy"] = 3, ["Aatrox_Base_Passive_Death_Activate"] = 3 }  local _blinkSpellLookupTable = { ["EzrealArcaneShift"] = 475, ["RiftWalk"] = 500, ["EkkoEAttack"] = 0, ["AlphaStrike"] = 0, ["KatarinaE"] = -255, ["KatarinaEDagger"] = { "Katarina_Base_Dagger_Ground_Indicator","Katarina_Skin01_Dagger_Ground_Indicator","Katarina_Skin02_Dagger_Ground_Indicator","Katarina_Skin03_Dagger_Ground_Indicator","Katarina_Skin04_Dagger_Ground_Indicator","Katarina_Skin05_Dagger_Ground_Indicator","Katarina_Skin06_Dagger_Ground_Indicator","Katarina_Skin07_Dagger_Ground_Indicator" ,"Katarina_Skin08_Dagger_Ground_Indicator","Katarina_Skin09_Dagger_Ground_Indicator"  }, }  local _blinkLookupTable = { "global_ss_flash_02.troy", "Lissandra_Base_E_Arrival.troy", "LeBlanc_Base_W_return_activation.troy" }  local _cachedRevives = {}  local _movementHistory = {}  function HPred:Tick() if Game.Timer() - _lastReviveQuery < _reviveQueryFrequency then return end  _lastReviveQuery=Game.Timer() for _, revive in pairs(_cachedRevives) do if Game.Timer() > revive.expireTime + .5 then _cachedRevives[_] = nil end end  for i = 1, Game.ParticleCount() do local particle = Game.Particle(i) if not _cachedRevives[particle.networkID] and  _reviveLookupTable[particle.name] then _cachedRevives[particle.networkID] = {} _cachedRevives[particle.networkID]["expireTime"] = Game.Timer() + _reviveLookupTable[particle.name] local nearestDistance = 500 for i = 1, Game.HeroCount() do local t = Game.Hero(i) local tDistance = self:GetDistance(particle.pos, t.pos) if tDistance < nearestDistance then nearestDistance = nearestDistance _cachedRevives[particle.networkID]["owner"] = t.charName _cachedRevives[particle.networkID]["pos"] = t.pos _cachedRevives[particle.networkID]["isEnemy"] = t.isEnemy end end end end end  function HPred:GetEnemyNexusPosition() if myHero.team == 100 then return Vector(14340, 171.977722167969, 14390); else return Vector(396,182.132507324219,462); end end   function HPred:GetReliableTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision) local target, aimPosition =self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetChannelingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetDashingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius, midDash) if target and aimPosition then return target, aimPosition end  target, aimPosition =self:GetBlinkTarget(source, range, speed, delay, checkCollision, radius) if target and aimPosition then return target, aimPosition end end  function HPred:GetLineTargetCount(source, aimPos, delay, speed, width, targetAllies) local targetCount = 0 for i = 1, Game.HeroCount() do local t = Game.Hero(i) if self:CanTargetALL(t) and ( targetAllies or t.isEnemy) then local predictedPos = self:PredictUnitPosition(t, delay+ self:GetDistance(source, t.pos) / speed) if predictedPos:To2D().onScreen then local proj1, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(source, aimPos, predictedPos) if proj1 and isOnSegment and (self:GetDistanceSqr(predictedPos, proj1) <= (t.boundingRadius + width) ^ 2) then targetCount = targetCount + 1 end end end end return targetCount end  function HPred:GetUnreliableTarget(source, range, delay, speed, radius, checkCollision, minimumHitChance, whitelist) local _validTargets = {} for i = 1, Game.HeroCount() do local t = Game.Hero(i) if self:CanTarget(t) and (not whitelist or whitelist[t.charName]) then local hitChance, aimPosition = self:GetHitchance(source, t, range, delay, speed, radius, checkCollision) if hitChance >= minimumHitChance and aimPosition:To2D().onScreen then _validTargets[t.charName] = {["hitChance"] = hitChance, ["aimPosition"] = aimPosition} end end end  local rHitChance = 0 local rAimPosition for targetName, targetData in pairs(_validTargets) do if targetData.hitChance > rHitChance then rHitChance = targetData.hitChance rAimPosition = targetData.aimPosition end end  if rHitChance >= minimumHitChance then return rHitChance, rAimPosition end end  function HPred:GetHitchance(source, target, range, delay, speed, radius, checkCollision) self:UpdateMovementHistory(target)  local hitChance = 1  local aimPosition = self:PredictUnitPosition(target, delay + self:GetDistance(source, target.pos) / speed) local interceptTime = self:GetSpellInterceptTime(source, aimPosition, delay, speed) local reactionTime = self:PredictReactionTime(target, .1) local origin,movementRadius = self:UnitMovementBounds(target, interceptTime, reactionTime)  if _movementHistory and _movementHistory[target.charName] and Game.Timer() - _movementHistory[target.charName]["ChangedAt"] < .25 then hitChance = 2 end  if not target.pathing or not target.pathing.hasMovePath then hitChance = 2 end  if movementRadius - target.boundingRadius <= radius /2 then hitChance = 3 end  if target.activeSpell and target.activeSpell.valid then if target.activeSpell.startTime + target.activeSpell.windup - Game.Timer() >= delay then hitChance = 4 else hitChance = 3 end end  if self:GetDistance(myHero.pos, aimPosition) >= range then hitChance = -1 end  if hitChance > 0 and checkCollision then if self:CheckMinionCollision(source, aimPosition, delay, speed, radius) then hitChance = -1 end end  return hitChance, aimPosition end  function HPred:PredictReactionTime(unit, minimumReactionTime) local reactionTime = minimumReactionTime  if unit.activeSpell and unit.activeSpell.valid then local windupRemaining = unit.activeSpell.startTime + unit.activeSpell.windup - Game.Timer() if windupRemaining > 0 then reactionTime = windupRemaining end end  local isRecalling, recallDuration = self:GetRecallingData(unit) if isRecalling and recallDuration > .25 then reactionTime = .25 end  return reactionTime end  function HPred:GetDashingTarget(source, range, delay, speed, dashThreshold, checkCollision, radius, midDash)  local target local aimPosition for i = 1, Game.HeroCount() do local t = Game.Hero(i) if t.isEnemy and t.pathing.hasMovePath and t.pathing.isDashing and t.pathing.dashSpeed>500  then local dashEndPosition = t:GetPath(1) if self:GetDistance(source, dashEndPosition) <= range  and dashEndPosition:To2D().onScreen then local dashTimeRemaining = self:GetDistance(t.pos, dashEndPosition) / t.pathing.dashSpeed local skillInterceptTime = self:GetSpellInterceptTime(myHero.pos, dashEndPosition, delay, speed) local deltaInterceptTime =skillInterceptTime - dashTimeRemaining if deltaInterceptTime > 0 and deltaInterceptTime < dashThreshold and (not checkCollision or not self:CheckMinionCollision(source, dashEndPosition, delay, speed, radius)) then target = t aimPosition = dashEndPosition return target, aimPosition end end end end end  function HPred:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for i = 1, Game.HeroCount() do local t = Game.Hero(i) if t.isEnemy and t.pos:To2D().onScreen then local success, timeRemaining = self:HasBuff(t, "zhonyasringshield") if success then local spellInterceptTime = self:GetSpellInterceptTime(myHero.pos, t.pos, delay, speed) local deltaInterceptTime = spellInterceptTime - timeRemaining if spellInterceptTime > timeRemaining and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then target = t aimPosition = t.pos return target, aimPosition end end end end end  function HPred:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for _, revive in pairs(_cachedRevives) do if revive.isEnemy and revive.pos:To2D().onScreen then local interceptTime = self:GetSpellInterceptTime(source, revive.pos, delay, speed) if interceptTime > revive.expireTime - Game.Timer() and interceptTime - revive.expireTime - Game.Timer() < timingAccuracy then target = self:GetEnemyByName(revive.owner) aimPosition = revive.pos return target, aimPosition end end end end  function HPred:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for i = 1, Game.HeroCount() do local t = Game.Hero(i) if t.isEnemy and t.activeSpell and t.activeSpell.valid and _blinkSpellLookupTable[t.activeSpell.name] then local windupRemaining = t.activeSpell.startTime + t.activeSpell.windup - Game.Timer() if windupRemaining > 0 then local endPos local blinkRange = _blinkSpellLookupTable[t.activeSpell.name] if type(blinkRange) == "table" then local target, distance = self:GetNearestParticleByNames(t.pos, blinkRange) if target and distance < 250 then endPos = target.pos end elseif blinkRange > 0 then endPos = Vector(t.activeSpell.placementPos.x, t.activeSpell.placementPos.y, t.activeSpell.placementPos.z) endPos = t.activeSpell.startPos + (endPos- t.activeSpell.startPos):Normalized() * math.min(self:GetDistance(t.activeSpell.startPos,endPos), range) else local blinkTarget = self:GetObjectByHandle(t.activeSpell.target) if blinkTarget then local offsetDirection  if blinkRange == 0 then offsetDirection = (blinkTarget.pos - t.pos):Normalized() elseif blinkRange == -1 then offsetDirection = (t.pos-blinkTarget.pos):Normalized() elseif blinkRange == -255 then if radius > 250 then endPos = blinkTarget.pos end end  if offsetDirection then endPos = blinkTarget.pos - offsetDirection * 150 end  end end  local interceptTime = self:GetSpellInterceptTime(myHero.pos, endPos, delay,speed) local deltaInterceptTime = interceptTime - windupRemaining if self:GetDistance(source, endPos) <= range and endPos:To2D().onScreen and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, endPos, delay, speed, radius)) then target = t aimPosition = endPos return target,aimPosition end end end end end  function HPred:GetBlinkTarget(source, range, speed, delay, checkCollision, radius) local target local aimPosition for i = 1, Game.ParticleCount() do local particle = Game.Particle(i) if particle and _blinkLookupTable[particle.name] and self:GetDistance(source, particle.pos) < range and particle.pos:To2D().onScreen then local pPos = particle.pos for k,v in pairs(self:GetEnemyHeroes()) do local t = v if t and t.isEnemy and self:GetDistance(t.pos, pPos) < t.boundingRadius then if (not checkCollision or not self:CheckMinionCollision(source, pPos, delay, speed, radius)) then target = t aimPosition = pPos return target,aimPosition end end end end end end  function HPred:GetChannelingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for i = 1, Game.HeroCount() do local t = Game.Hero(i) local interceptTime = self:GetSpellInterceptTime(myHero.pos, t.pos, delay, speed) if self:CanTarget(t) and self:GetDistance(source, t.pos) <= range and t.pos:To2D().onScreen and self:IsChannelling(t, interceptTime) and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then target = t aimPosition = t.pos return target, aimPosition end end end  function HPred:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for i = 1, Game.HeroCount() do local t = Game.Hero(i) if self:CanTarget(t) and self:GetDistance(source, t.pos) <= range and t.pos:To2D().onScreen then local immobileTime = self:GetImmobileTime(t)  local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed) if immobileTime - interceptTime > timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then target = t aimPosition = t.pos return target, aimPosition end end end end  function HPred:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius) local target local aimPosition for i = 1, Game.TurretCount() do local turret = Game.Turret(i); if turret.isEnemy and self:GetDistance(source, turret.pos) <= range and turret.pos:To2D().onScreen then local hasBuff, expiresAt = self:HasBuff(turret, "teleport_target") if hasBuff then local interceptPosition = self:GetTeleportOffset(turret.pos,223.31) local deltaInterceptTime = self:GetSpellInterceptTime(source, interceptPosition, delay, speed) - expiresAt if deltaInterceptTime > 0 and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then target = turret aimPosition =interceptPosition return target, aimPosition end end end end  for i = 1, Game.WardCount() do local ward = Game.Ward(i); if ward.isEnemy and self:GetDistance(source, ward.pos) <= range and ward.pos:To2D().onScreen then local hasBuff, expiresAt = self:HasBuff(ward, "teleport_target") if hasBuff then local interceptPosition = self:GetTeleportOffset(ward.pos,100.01) local deltaInterceptTime = self:GetSpellInterceptTime(source, interceptPosition, delay, speed) - expiresAt if deltaInterceptTime > 0 and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then target = ward aimPosition = interceptPosition return target, aimPosition end end end end  for i = 1, Game.MinionCount() do local minion = Game.Minion(i); if minion.isEnemy and self:GetDistance(source, minion.pos) <= range and minion.pos:To2D().onScreen then local hasBuff, expiresAt = self:HasBuff(minion, "teleport_target") if hasBuff then local interceptPosition = self:GetTeleportOffset(minion.pos,143.25) local deltaInterceptTime = self:GetSpellInterceptTime(source, interceptPosition, delay, speed) - expiresAt if deltaInterceptTime > 0 and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then target = minion aimPosition = interceptPosition return target, aimPosition end end end end end  function HPred:GetTargetMS(target) local ms = target.pathing.isDashing and target.pathing.dashSpeed or target.ms return ms end  function HPred:Angle(A, B) local deltaPos = A - B local angle = math.atan2(deltaPos.x, deltaPos.z) *  180 / math.pi if angle < 0 then angle = angle + 360 end return angle end  function HPred:UpdateMovementHistory(unit) if not _movementHistory[unit.charName] then _movementHistory[unit.charName] = {} _movementHistory[unit.charName]["EndPos"] = unit.pathing.endPos _movementHistory[unit.charName]["StartPos"] = unit.pathing.endPos _movementHistory[unit.charName]["PreviousAngle"] = 0 _movementHistory[unit.charName]["ChangedAt"] = Game.Timer() end  if _movementHistory[unit.charName]["EndPos"].x ~=unit.pathing.endPos.x or _movementHistory[unit.charName]["EndPos"].y ~=unit.pathing.endPos.y or _movementHistory[unit.charName]["EndPos"].z ~=unit.pathing.endPos.z then _movementHistory[unit.charName]["PreviousAngle"] = self:Angle(Vector(_movementHistory[unit.charName]["StartPos"].x, _movementHistory[unit.charName]["StartPos"].y, _movementHistory[unit.charName]["StartPos"].z), Vector(_movementHistory[unit.charName]["EndPos"].x, _movementHistory[unit.charName]["EndPos"].y, _movementHistory[unit.charName]["EndPos"].z)) _movementHistory[unit.charName]["EndPos"] = unit.pathing.endPos _movementHistory[unit.charName]["StartPos"] = unit.pos _movementHistory[unit.charName]["ChangedAt"] = Game.Timer() end  end  function HPred:PredictUnitPosition(unit, delay) local predictedPosition = unit.pos local timeRemaining = delay local pathNodes = self:GetPathNodes(unit) for i = 1, #pathNodes -1 do local nodeDistance = self:GetDistance(pathNodes[i], pathNodes[i +1]) local nodeTraversalTime = nodeDistance / self:GetTargetMS(unit)  if timeRemaining > nodeTraversalTime then timeRemaining =  timeRemaining - nodeTraversalTime predictedPosition = pathNodes[i + 1] else local directionVector = (pathNodes[i+1] - pathNodes[i]):Normalized() predictedPosition = pathNodes[i] + directionVector *  self:GetTargetMS(unit) * timeRemaining break; end end return predictedPosition end  function HPred:IsChannelling(target, interceptTime) if target.activeSpell and target.activeSpell.valid and target.activeSpell.isChanneling then return true end end  function HPred:HasBuff(target, buffName, minimumDuration) local duration = minimumDuration if not minimumDuration then duration = 0 end local durationRemaining for i = 1, target.buffCount do local buff = target:GetBuff(i) if buff.duration > duration and buff.name == buffName then durationRemaining = buff.duration return true, durationRemaining end end end  function HPred:GetTeleportOffset(origin, magnitude) local teleportOffset = origin + (self:GetEnemyNexusPosition()- origin):Normalized() * magnitude return teleportOffset end  function HPred:GetSpellInterceptTime(startPos, endPos, delay, speed) local interceptTime = Game.Latency()/2000 + delay + self:GetDistance(startPos, endPos) / speed return interceptTime end  function HPred:CanTarget(target) return target.isEnemy and target.alive and target.visible and target.isTargetable end  function HPred:CanTargetALL(target) return target.alive and target.visible and target.isTargetable end  function HPred:UnitMovementBounds(unit, delay, reactionTime) local startPosition = self:PredictUnitPosition(unit, delay)  local radius = 0 local deltaDelay = delay -reactionTime- self:GetImmobileTime(unit) if (deltaDelay >0) then radius = self:GetTargetMS(unit) * deltaDelay end return startPosition, radius end  function HPred:GetImmobileTime(unit) local duration = 0 for i = 0, unit.buffCount do local buff = unit:GetBuff(i); if buff.count > 0 and buff.duration> duration and (buff.type == 5 or buff.type == 8 or buff.type == 21 or buff.type == 22 or buff.type == 24 or buff.type == 11 or buff.type == 29 or buff.type == 30 or buff.type == 39 ) then duration = buff.duration end end return duration end  function HPred:GetSlowedTime(unit) local duration = 0 for i = 0, unit.buffCount do local buff = unit:GetBuff(i); if buff.count > 0 and buff.duration > duration and buff.type == 10 then duration = buff.duration return duration end end return duration end  function HPred:GetPathNodes(unit) local nodes = {} table.insert(nodes, unit.pos) if unit.pathing.hasMovePath then for i = unit.pathing.pathIndex, unit.pathing.pathCount do path = unit:GetPath(i) table.insert(nodes, path) end end return nodes end  function HPred:GetObjectByHandle(handle) local target for i = 1, Game.HeroCount() do local enemy = Game.Hero(i) if enemy.handle == handle then target = enemy return target end end  for i = 1, Game.MinionCount() do local minion = Game.Minion(i) if minion.handle == handle then target = minion return target end end  for i = 1, Game.WardCount() do local ward = Game.Ward(i); if ward.handle == handle then target = ward return target end end  for i = 1, Game.ParticleCount() do local particle = Game.Particle(i) if particle.handle == handle then target = particle return target end end end function HPred:GetObjectByPosition(position) local target for i = 1, Game.HeroCount() do local enemy = Game.Hero(i) if enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then target = enemy return target end end  for i = 1, Game.MinionCount() do local enemy = Game.Minion(i) if enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then target = enemy return target end end  for i = 1, Game.WardCount() do local enemy = Game.Ward(i); if enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then target = enemy return target end end  for i = 1, Game.ParticleCount() do local enemy = Game.Particle(i) if enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then target = enemy return target end end end  function HPred:GetEnemyHeroByHandle(handle) local target for i = 1, Game.HeroCount() do local enemy = Game.Hero(i) if enemy.handle == handle then target = enemy return target end end end  function HPred:GetNearestParticleByNames(origin, names) local target local distance = math.max for i = 1, Game.ParticleCount() do local particle = Game.Particle(i) local d = self:GetDistance(origin, particle.pos) if d < distance then distance = d target = particle end end return target, distance end  function HPred:GetPathLength(nodes) local result = 0 for i = 1, #nodes -1 do result = result + self:GetDistance(nodes[i], nodes[i + 1]) end return result end  function HPred:CheckMinionCollision(origin, endPos, delay, speed, radius, frequency)  if not frequency then frequency = radius end local directionVector = (endPos - origin):Normalized() local checkCount = self:GetDistance(origin, endPos) / frequency for i = 1, checkCount do local checkPosition = origin + directionVector * i * frequency local checkDelay = delay + self:GetDistance(origin, checkPosition) / speed if self:IsMinionIntersection(checkPosition, radius, checkDelay, radius * 3) then return true end end return false end  function HPred:IsMinionIntersection(location, radius, delay, maxDistance) if not maxDistance then maxDistance = 500 end for i = 1, Game.MinionCount() do local minion = Game.Minion(i) if self:CanTarget(minion) and self:GetDistance(minion.pos, location) < maxDistance then local predictedPosition = self:PredictUnitPosition(minion, delay) if self:GetDistance(location, predictedPosition) <= radius + minion.boundingRadius then return true end end end return false end  function HPred:VectorPointProjectionOnLineSegment(v1, v2, v) assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)") local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y) local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2) local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) } local rS = rL < 0 and 0 or (rL > 1 and 1 or rL) local isOnSegment = rS == rL local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) } return pointSegment, pointLine, isOnSegment end   function HPred:GetRecallingData(unit) for K, Buff in pairs(GetBuffs(unit)) do if Buff.name == "recall" and Buff.duration > 0 then return true, Game.Timer() - Buff.startTime end end return false end  function HPred:GetEnemyByName(name) local target for i = 1, Game.HeroCount() do local enemy = Game.Hero(i) if enemy.isEnemy and enemy.charName == name then target = enemy return target end end end  function HPred:IsPointInArc(source, origin, target, angle, range) local deltaAngle = math.abs(HPred:Angle(origin, target) - HPred:Angle(source, origin)) if deltaAngle < angle and self:GetDistance(origin, target) < range then return true end end  function HPred:GetEnemyHeroes() local _EnemyHeroes = {} for i = 1, Game.HeroCount() do local enemy = Game.Hero(i) if enemy and enemy.isEnemy then table.insert(_EnemyHeroes, enemy) end end return _EnemyHeroes end  function HPred:GetDistanceSqr(p1, p2) return (p1.x - p2.x) ^ 2 + ((p1.z or p1.y) - (p2.z or p2.y)) ^ 2 end  function HPred:GetDistance(p1, p2) return math.sqrt(self:GetDistanceSqr(p1, p2)) end
