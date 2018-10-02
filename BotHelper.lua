require 'Eternal Prediction'


-- tWEETIEbOT bY tWEETIESHY FOR gOs eXTERNAL
-- sPECIAL THANKS TO RMAN,wEEDLE AND sHULEPIN FOR HELPING ME WITH DEBUGGING; 
-- TEACHING ME LUA A BIT AND GIVING ADVICE ABOUT CODING AND THE api
-- tHANKS TO fERETORIX OFC FOR THIS api; I HATE IT. :-P

local ScriptVersion = "v1.1"
local isEvading 				= ExtLibEvade and ExtLibEvade.Evading
-----------  NOT CHANGEABLES ------------

-- Static variables (not changeable)
BOT = nil
Towers = {}
BotOrb = _G.SDK.Orbwalker

Mode_Combo = _G.SDK.ORBWALKER_MODE_COMBO
Mode_Harass = _G.SDK.ORBWALKER_MODE_HARASS
Mode_Flee = _G.SDK.ORBWALKER_MODE_FLEE
Mode_Clear = _G.SDK.ORBWALKER_MODE_LANECLEAR
Mode_Lasthit = _G.SDK.ORBWALKER_MODE_LASTHIT

local lanes = { "bot", "mid", "top" }

-- Init Variables
local AllySide = nil
local EnemySide = nil
local StartPoint = nil
local EnemyStartPoint = nil
local HK_STOP = nil 
local gold = 0 -- Used for validation reasons

-- General Runtime Variables
local lane = 1
local buystance = false
local LastCommandIssued = 0
local EnemysDead = 0
local drawables = {}
local CastStart = false
local GlobalTarget = nil

-- Buying Runtime Variables and Config
local buystate = 0 -- Buystates: 0: No Buy, 1: Attempt to Buy, 2: Opened Buy Window, 3: Selected Item Chapter, 4: Buy Item, 5: Buy failed
local currenthave = 0
local Items = {}
local Leveler = {}


-----------  CHANGEABLES ------------

-- Config Variables
local enabled = true -- Enabled on startup
local MoveRange = 400+myHero.boundingRadius/2
local MinionScanRange = 3000
local MaxSpellRange = 2500
local BuyDistanceToStart = 1000
local TowerDangerZone = 800
local TowerProtectionZone = 700
local HitChanceModifier = 0.25
local TowerSafeZone = 350
local LowHealthPerLevelThreshold = 20
local FleeDistanceMulti = 2.0 -- Used for FleeModeMulti = 1 its a MULTIPLIER of OWN AA Range
local FleeDistancePlain = 600 -- Used for FleeModeMulti = 2 Fixed Range (for example 650 for caitlyn AA range, roughly)
local FleeModeMulti = 1 -- 0 = no Flee, 1 = Flee relative to my AA Range, 2 = Flee regarding on Fixed safety range
local FleeDistanceSingle = 0.8
local FleeModeSingle = 1 -- 0 = no Flee, 1 = Flee relative to my AA Range, 2 = Flee Regarding Enemy AA Range 
local TeamfightEngagingSafety = 0.8 -- AARangeMult

--- Buy Items Config
local ItemsADC = {} --- Item search, ID, (Upgrade) Costs, Final Item
ItemsADC[#ItemsADC+1] = {"wardin",3340,0,nil} 	--- Warding Totem
ItemsADC[#ItemsADC+1] = {"long",1036,350,5} 	--- Long Sword
ItemsADC[#ItemsADC+1] = {"vampiric",1053,550,5}	--- Vampiric Scepter
ItemsADC[#ItemsADC+1] = {"b.f.",1038,1300,5} 	--- B.F. Sword
ItemsADC[#ItemsADC+1] = {"bloodth",3072,1300,nil}--- Bloodthirster
ItemsADC[#ItemsADC+1] = {"boots",1001,300,7}	--- Boots
ItemsADC[#ItemsADC+1] = {"berser",3006,800,nil}	--- Berserkers Greaves
ItemsADC[#ItemsADC+1] = {"zeal",3086,1300,9}	--- Zeal
ItemsADC[#ItemsADC+1] = {"stat",3087,1600,nil}	--- Statikk Shiv
ItemsADC[#ItemsADC+1] = {"b.f.",1038,1300,11}	--- B.F. Sword
ItemsADC[#ItemsADC+1] = {"infin",3031,2400,nil} --- Infinity Edge
ItemsADC[#ItemsADC+1] = {"whisper",3035,1300,14}--- Last Whisper
ItemsADC[#ItemsADC+1] = {"pick",1037,875,14}	--- Pickaxe
ItemsADC[#ItemsADC+1] = {"domini",3036,625,nil} --- Dominiks Regards
ItemsADC[#ItemsADC+1] = {"b.f.",1038,1300,16}	--- B.F Sword
ItemsADC[#ItemsADC+1] = {"angel",3026,1500,nil}	--- Guardian Angel

-- Writing Runtime Variables
local TextsOnKill = {}
TextsOnKill[1] = "WP"
TextsOnKill[2] = "Gj"
TextsOnKill[3] = "GG"

local TextsOnKillThx = {}
TextsOnKillThx[1] = "thx"
TextsOnKillThx[2] = "Gj"
TextsOnKillThx[3] = "WP"

-----------  SCRIPT BEGIN ------------

--- Basic Functions ---

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function GetDistance(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

local function GetDistance2D(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function Orb(value)
	BotOrb:SetMovement(value)
	BotOrb:SetAttack(value)
end

local function t( cond , T , F )
    if cond then return T else return F end
end

function Stop()
		Control.SetCursorPos(myHero.pos)
		PutKey(HK_STOP)
end

function Write(value)    
    value:gsub(".", function(c)   
	PutKey(c:upper():byte()) 
	end)
end

function PutKey(key)
	if key == "." then
		key = 190
	end
	
	--p-rint(key)
	
	if Control.IsKeyDown(key) then Control.KeyUp(key) end
    if Control.KeyDown(key) then
        Control.KeyUp(key)
    end   
end

function PressKey(key, down)
	if key == "." then
		key = 190
	end
	
	--p-rint(key)
	
	if down and not Control.IsKeyDown(key) then
		Control.KeyDown(key)
	end
	
	if not down and Control.IsKeyDown(key) then
		Control.KeyUp(key)
	end   
end

function KeyCombo(ModKey, PressKey)
	Control.KeyDown(ModKey)
	Control.KeyDown(PressKey)
	Control.KeyUp(PressKey)
	Control.KeyUp(ModKey)
end

function Enter()    
    if Control.IsKeyDown(13) then Control.KeyUp(13) end
    Control.KeyDown(13)
    Control.KeyUp(13)    
end

function BreakChannel()
	Control.Move(myHero.pos  + Vector(0,50,0))
end

--- Init ---
function __init()
	if BOT then
		return
	end
	BOT = "loaded"
	LastCommandIssued = Game.Timer()
	
	AllySide = t(myHero.team == 100, "Blue", "Red")
	EnemySide = t(myHero.team == 200, "Blue", "Red")
	StartPoint = t(AllySide == "Blue", Vector(105,33,134), Vector(14576,466,14693))
	EnemyStartPoint = t(AllySide == "Red", Vector(105,33,134), Vector(14576,466,14693))

	InitTowers()
	
	--- Logic here not implemented yet, currently only ADC (build) supported
	Items = ItemsADC
	
	HK_STOP = BotOrb.Menu.Keys.HoldPosButton:Key()
	
	LoadMenu()
	Tweetiebot.Enable:Value(false)
	Callback.Add("Tick", function() Tick() end)
	Callback.Add("Draw", function() GDraw() end)
end

function InitTowers()
	local BotBlue = {{10504,1029,nil},{6919,1483,nil},{4281,1253,nil},{1748,2270,nil},{2177,1807,nil},{105,134,nil}} 
	local MidBlue = {{5846,6396,nil},{5048,4812,nil},{3651,3696,nil},{1748,2270,nil},{2177,1807,nil},{105,134,nil}}
	local TopBlue = {{981,10441,nil},{1512,6699,nil},{1169,4287,nil},{1748,2270,nil},{2177,1807,nil},{105,134,nil}}

	local BotRed = {{13866,4505,nil},{13327,8266,nil},{13624,10572,nil},{13052,12612,nil},{12611,13084,nil},{14576,14693,nil}}
	local MidRed = {{8955,8510,nil},{9767,10113,nil},{11134,11207,nil},{13052,12612,nil},{12611,13084,nil},{14576,14693,nil}}
	local TopRed = {{4318,13875,nil},{7943,13411,nil},{10481,13650,nil},{13052,12612,nil},{12611,13084,nil},{14576,14693,nil}}

	Towers = {Red = {BotRed,MidRed,TopRed}, Blue = {BotBlue,MidBlue,TopBlue}}
end

function LoadMenu()
	Tweetiebot = MenuElement({type = MENU, id = "Tweetiebot", name = "Tweetieshys Simple Bot"})
	--- Version ---
	Tweetiebot:MenuElement({id = "Enable", name = "Enable Bot", key = string.byte("0"), toggle = true, value= true });
	Tweetiebot:MenuElement({id = "Spells", name = "Use Spells", value = false, tooltip = "Use Spells"})
	--Tweetiebot:MenuElement({id = "Talk", name = "Use Chat", value = false, tooltip = "Uses Chat sometimes for Humanlike behaviour. No Flame of course :-P "})
	--Tweetiebot:MenuElement({id = "TalkChance", name = "Talk Chance", value = 30, min = 0, max = 100, step = 1 });
	Tweetiebot:MenuElement({id = "togglelane", name = "Toggle Main Lane", key = string.byte("0"), callback = function(cb) if Control.IsKeyDown(Tweetiebot.togglelane:Key()) then lane = lane%3+1; end; end });
	Tweetiebot:MenuElement({ id = "Keys", name = "Keys Settings", type = MENU });
		Tweetiebot.Keys:MenuElement({id = "Recall", name = "Recall key", key = string.byte("B") , tooltip = "Recall Keybinding"});
		Tweetiebot.Keys:MenuElement({id = "Q", name = "Level Up Q key", key = string.byte("Q") , tooltip = "Level Up Q Key"});
		Tweetiebot.Keys:MenuElement({id = "W", name = "Level Up W key", key = string.byte("W") , tooltip = "Level Up W Key"});
		Tweetiebot.Keys:MenuElement({id = "E", name = "Level Up E key", key = string.byte("E") , tooltip = "Level Up E Key"});
		Tweetiebot.Keys:MenuElement({id = "R", name = "Level Up R key", key = string.byte("R") , tooltip = "Level Up R Key"});
	Tweetiebot:MenuElement({ id = "Autoleveler", name = "Autoleveling", type = MENU, value = false });
		Tweetiebot.Autoleveler:MenuElement({id = "PrioQ", name = "Prioritize Q", value = false});
		Tweetiebot.Autoleveler:MenuElement({id = "PrioW", name = "Prioritize W", value = false});
		Tweetiebot.Autoleveler:MenuElement({id = "PrioE", name = "Prioritize E", value = false});	
end


--- Main Functions ---

function Tick()
	if IsChatOpen or isEvading then -- Deactivate script on chat open, why it is even open?
		return
	end
	
	local send = false
	if  Game.Timer() - LastCommandIssued >= BotOrb.Menu.General.MovementDelay:Value() * 0.001 then
		LastCommandIssued = Game.Timer()
		send = true
	end	
	
	if not send then
		return
	end
	
	if IsInBuyDistance() and myHero.isChanneling then
		BreakChannel()
	end
	
	CheckTowers()
	
	if myHero.dead then
		CheckBuy(send)
		ResetModes(nil)
	end
	
	SetBuyStance()
	
	if buystance then
		CheckBuy(send)
		return
	end
		
	if myHero.dead then
		return
	end

end

function Decisionmaker(send)
	local target = GetTarget(myHero.range*1.3)
		local getEnemyHeros = {}
	local getAllyHeros = {}
	local killtarget
	local AllyEngaging = false
	
	if FleeModeMulti ~= 0 then
		if FleeModeMulti == 1 then
			getEnemyHeros = GetHeros(myHero.pos, myHero.range*FleeDistanceMulti, false)
			getAllyHeros = GetHeros(myHero.pos, myHero.range*FleeDistanceMulti, true)
			killtarget = GetTarget(myHero.range*FleeDistanceMulti)
			
			
		else
			getEnemyHeros = GetHeros(myHero.pos, FleeDistancePlain, false)
			getAllyHeros = GetHeros(myHero.pos, FleeDistancePlain, true)
			killtarget = GetTarget(FleeDistancePlain)
			
		end
	else
		getAllyHeros = GetHeros(myHero.pos, FleeDistancePlain, true)
	end
	
	local EnemyHealth = 0
	for i=1, #getEnemyHeros do
		EnemyHealth = EnemyHealth + getEnemyHeros[i].health/getEnemyHeros[i].maxHealth
	end
			
	local AlliesHealth = 0
	for i=1, #getAllyHeros do
		AlliesHealth = AlliesHealth + getAllyHeros[i].health/getAllyHeros[i].maxHealth
		if killtarget and killtarget.pos:DistanceTo(myHero.pos)+myHero.range*TeamfightEngagingSafety < killtarget.pos:DistanceTo(getAllyHeros[i].pos) then
			AllyEngaging = true
		end
	end
	AlliesHealth = AlliesHealth + myHero.health/myHero.maxHealth
	
	local enemytower = GetNearestEnemyTower(myHero.pos,1100) 
	local attackedbyminions = GetAttackedbyMinions(FleeDistancePlain)
	local ActiveEnemyTower = GetLaneTower(lane, true, true)
	
	--[[
	if myHero.dead or CurText then
		if Tweetiebot.Talk:Value() and attackedbyminions == 0 and not target and not enemytower then
			if BotOrb.Menu.Enabled:Value() then
				BotOrb.Menu.Enabled:Value(false)
			end
			ClearDraw()
			Talk(send)
		end
		return
	end
	]]

	if not BotOrb.Menu.Enabled:Value() then
		BotOrb.Menu.Enabled:Value(true)
		BotOrb:Orbwalk()
	end
					
	--print((#getAllyHeros+1) .. " " .. #getEnemyHeros .. " ")
	
	if (myHero.health < myHero.maxHealth*0.8 or myHero.mana < myHero.maxMana*0.8) and IsInBuyDistance() then
		drawables[2] = {"Wait and Heal Up ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		ResetModes(nil)
	elseif enemytower and enemytower.targetID == myHero.networkID then
		drawables[2] = {"Flee from Tower ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Flee(send,false)
	elseif #getEnemyHeros > #getAllyHeros+1 then
		drawables[2] = {"Flee from Enemies ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Flee(send,false)
	elseif not enemytower and killtarget and #getEnemyHeros < 2 and (killtarget.health < killtarget.maxHealth*0.3 or killtarget.health+myHero.maxHealth*0.25 < myHero.health) then
		drawables[2] = {"Kill Attempt on " .. killtarget.name, 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Combo(killtarget,true)
	elseif myHero.health < myHero.maxHealth*0.35 and not IsInBuyDistance() then
		drawables[2] = {"Flee and Recall ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}	
		Recall(send, true)
	elseif not enemytower and #getAllyHeros > 0 and killtarget and #getEnemyHeros <= #getAllyHeros+1 then
		drawables[2] = {"Teamfighting to " .. killtarget.name, 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Combo(killtarget,true)
	elseif attackedbyminions > 2 and (not target or target and not IsAARange(target)) or attackedbyminions > 5 and myHero.health < myHero.maxHealth*0.7  then
		drawables[2] = {"Flee from Minions" .. attackedbyminions .. " ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Flee(send,false)
	elseif target and FleeModeSingle ~= 0 and (FleeModeSingle == 1 and IsAARangeMult(target, FleeDistanceSingle) or FleeModeSingle == 2 and IsAARangeMultEnemy(target, FleeDistanceSingle)) and target.health > myHero.health then
		drawables[2] = {"Flee from " .. target.name .. " ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Flee(send,true)
	elseif CanAffordNextMajorItem() and not IsInBuyDistance() then
		drawables[2] = {"Recall to Buy Major Item", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}	
		Recall(send, false)
	elseif not enemytower and target and IsAARangeMult(target, 1.1) then
		drawables[2] = {"Harass ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Combo(target,false)
	elseif MinionsInRange(myHero.pos, 1.5) == 0 and ActiveEnemyTower and ActiveEnemyTower:DistanceTo(myHero.pos) < MinionScanRange and MinionsInRangeAbs(ActiveEnemyTower,myHero.team,TowerProtectionZone) > 2 then 
		drawables[2] = {"Attack Tower ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		DestroyTower(send)
	elseif MinionsInRange(myHero.pos, 1.5) == 0 then 
		drawables[2] = {"Walk ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Walk(send)
	elseif MinionsInRange(myHero.pos, 1.5) > 0 then
		drawables[2] = {"Clear ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		Clear(send) 
	else
		drawables[2] = {"???", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		drawables[3] = nil
		drawables[4] = nil
		drawables[5] = nil
	end		
end

function Walk(send)
	if ActiveMode() ~= Mode_Harass then
		Stop()
	end

	ResetModes(Mode_Harass)
	PressKey(HK_TCO,true)
	
	local target = nil
	
	drawables[3] = nil
	drawables[4] = nil
	drawables[5] = nil
	
	if not GoToMinions(send,false) then	
		local NextWayPoint = GetNextWaypoint(myHero.pos,false)
		local NextTower = WaypointToTower(NextWayPoint)
		local OwnMinion = GoToMinions(send,true)
		
		if NextWayPoint[1] == AllySide or NextWayPoint[1] == EnemySide and MinionsInRangeAbs(TowerToVector(NextTower), myHero.team, TowerProtectionZone) > 0 or IsActiveWaypoint(NextWayPoint) == false then
			target = GoToTower(NextWayPoint,false,send)
			drawables[3] = {"Go to next Waypoint", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
		elseif OwnMinion then
			target = OwnMinion
			drawables[3] = {"Go to own Minions", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
		end
		
		if not target and send then
			--drawables[3] = {"No Work to do!???? Welp then wait...", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
			Control.SetCursorPos(myHero.pos)
		elseif target then
			drawables[4] = {myHero.pos:To2D(),target:To2D(), Draw.Color(255, 255, 0, 255)}
		end		
	end
end

function Combo(target, chase)
	if ActiveMode() ~= Mode_Combo then
		Stop()
		PressKey(HK_TCO,true)
	end

	drawables[3] = nil
	drawables[4] = nil
	drawables[5] = nil
	
	if target then
		ResetModes(Mode_Combo)		
		if chase then
			if target.posTo and target.posTo ~= target.pos and EnemyStartPoint:DistanceTo(target.posTo) < EnemyStartPoint:DistanceTo(target.pos) then
				Control.SetCursorPos(myHero.pos:Extended(target.posTo, MoveRange))
				--p-rint("Chase to Flee point")
				drawables[3] = {myHero.pos:To2D(),target.posTo:To2D(), Draw.Color(255, 255, 0, 255)}
				drawables[4] = {"Chase to Flee point", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
			else
				Control.SetCursorPos(target.pos:Extended(EnemyStartPoint.pos, MoveRange))
				--p-rint("Chase to Base")
				drawables[3] = {myHero.pos:To2D(),target.pos:Extended(EnemyStartPoint.pos, MoveRange/2):To2D(), Draw.Color(255, 255, 0, 255)}
				drawables[4] = {"Chase to Base", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
			end
		else
			drawables[4] = {"Harassing " .. target.name, 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
			Control.SetCursorPos(target.pos)
		end
	else
		drawables[4] = {"No Target found ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
		ResetModes(nil)
	end
end

function Clear(send)
	if ActiveMode() ~= Mode_Lasthit and ActiveMode() ~= Mode_Clear then
		Stop()
		PressKey(HK_TCO,false)
	end

	local minion = nil
	local lowminion = GetLowMinionInRange(myHero.pos,1.7)
	local predminion = t(BotOrb.LastHitMinion, BotOrb.LastHitMinion, lowminion)
	local nearminion = GetMinionInRange(myHero.pos,MinionScanRange,false)
	
	minion = t(predminion, predminion, t(BotOrb.AlmostLastHitMinion, BotOrb.AlmostLastHitMinion, nearminion))

	if send  then
		if minion then		
			drawables[3] = {minion.pos, 30, 4, Draw.Color(255, 255, 0, 255)}		
			drawables[5] = {myHero.pos:To2D(),minion.pos:To2D(), t(minion.pos:DistanceTo(myHero.pos) > GetAARangeTo(minion)*0.8, Draw.Color(255, 255, 0, 255), Draw.Color(255, 0, 255, 0))}
			
			local TowerTowardBase = GetNextTowerTowardsBase(lane, nil) -- we dont need a Tower that is alive, its just for position calculating
			
			if minion.pos:DistanceTo(myHero.pos) > GetAARangeTo(minion)*0.9 or GetAARangeTo(minion) > 300 and minion.pos:DistanceTo(myHero.pos) < GetAARangeTo(minion)*0.4 then
				drawables[4] = {"Reposition and Farm", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
				if TowerTowardBase then
					--drawables[5] = {myHero.pos:To2D(),minion.pos:Extended(TowerTowardBase, GetAARangeTo(minion)*0.9):To2D(), Draw.Color(255, 0, 255, 0)}
					local walkpos = minion.pos:Extended(TowerTowardBase, GetAARangeTo(minion)*0.8)
					walkpos = t(walkpos:DistanceTo(myHero.pos) > MoveRange, myHero.pos:Extended(walkpos,MoveRange), walkpos)
					Control.SetCursorPos(t(walkpos:DistanceTo(myHero.pos) > MoveRange, myHero.pos:Extended(walkpos,MoveRange), walkpos))
				else --for strange reasons we dont find a next tower, take base pos
					--drawables[5] = {myHero.pos:To2D(),minion.pos:Extended(myHero.pos, GetAARangeTo(minion)*0.9):To2D(), Draw.Color(255, 0, 255, 0)}
					local walkpos = minion.pos:Extended(StartPoint, GetAARangeTo(minion)*0.8)
					walkpos = t(walkpos:DistanceTo(myHero.pos) > MoveRange, myHero.pos:Extended(walkpos,MoveRange), walkpos)
					Control.SetCursorPos(t(walkpos:DistanceTo(myHero.pos) > MoveRange, myHero.pos:Extended(walkpos,MoveRange), walkpos))
				end
				ResetModes(Mode_Clear)
			else
				drawables[4] = {"Farming ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
				Control.SetCursorPos(myHero.pos)
				ResetModes(Mode_Clear)
			end
		else
			--p-rint ("WHAT")
			DestroyTower() -- should be actually never the case, was there for debug reasons, just to make sure he always does something...
		end
	end
end

function Flee(send, kite)
	if ActiveMode() ~= Mode_Flee and ActiveMode() ~= Mode_Combo then
		Stop()
	end

	if kite then ResetModes(Mode_Combo) else ResetModes(Mode_Flee) end
	PressKey(HK_TCO,true)
	
	drawables[3] = nil
	drawables[4] = nil
	drawables[5] = nil

	local NextWayPoint = GetNextWaypoint(myHero.pos,true)
	local NextTower = WaypointToTower(NextWayPoint)
	
	target = GoToTower(NextWayPoint,true,send)
	drawables[3] = {"Go to next Waypoint", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
	
	if not target and send then
		Control.Move(StartPoint)
	elseif target then
		drawables[4] = {myHero.pos:To2D(),target:To2D(), Draw.Color(255, 255, 0, 255)}
	end	

end

function Recall(send, emergency)

	local NextWayPoint = GetNextWaypoint(myHero.pos,true)
	local NextWayPointVector = WaypointToVector(NextWayPoint)
	
	local PreviousWayPoint = GetNextWaypoint(myHero.pos,false)
	local PreviousVector = WaypointToVector(PreviousWayPoint)
	
	local PreviousVectorSafeRecallPos = PreviousVector:Extended(NextWayPointVector,MoveRange/2)

	UseSummoners(send, emergency)

	if PreviousWayPoint[1] == AllySide and IsActiveWaypoint(PreviousWayPoint) and PreviousVectorSafeRecallPos:DistanceTo(StartPoint) > StartPoint:DistanceTo(myHero.pos) and not IsInBuyDistance() then
		Stop()
		ResetModes(nil)	
		PutKey(Tweetiebot.Keys.Recall:Key())
		ClearDraw()
	elseif NextWayPoint[3] == 3 and not IsActiveWaypoint(NextWayPoint) then
		Control.SetCursorPos(myHero.pos:Extended(StartPoint,MoveRange))
		ResetModes(Mode_Flee)
		Orb(true)
		PressKey(HK_TCO,true)
		drawables[3] = {"Go Home", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
	else
		GoToTower(NextWayPoint,true,send)
		ResetModes(Mode_Flee)
		PressKey(HK_TCO,true)
		drawables[3] = {"Go to next Waypoint", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 60, Draw.Color(255, 255, 0, 0)}
	end
end

function DestroyTower(send)
	if ActiveMode() ~= Mode_Clear then
		Stop()
		PressKey(HK_TCO,false)
	end
	
	ResetModes(Mode_Clear)
	
	drawables[3] = nil
	drawables[4] = nil
	drawables[5] = nil	
	
	--p-rint(tostring(GetAARangeTo(nil)))
	local ActiveEnemyTower = GetLaneTower(lane, true, true)
	if ActiveEnemyTower and send then
		if ActiveEnemyTower:DistanceTo(myHero.pos) > GetAARangeTo(nil) then
			local extendedPos = ActiveEnemyTower:Extended(myHero.pos, GetAARangeTo(nil)*0.9)
			Control.SetCursorPos(t(extendedPos:DistanceTo(myHero.pos) > MoveRange, myHero.pos:Extended(extendedPos,MoveRange), extendedPos))
			drawables[4] = {"Go to destroy Tower ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
		else
			Control.SetCursorPos(myHero.pos)
			drawables[4] = {"Destroy Tower ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
		end
	end
end

function SpellLogic(send)
	
	if myHero.isChanneling then
		if GlobalTarget and myHero:GetSpellData(_R).ammo > 0 then
			Control.SetCursorPos(GlobalTarget.pos)
			Control.CastSpell(HK_R, GlobalTarget.pos)
		end			
		return true
	else
		GlobalTarget = nil
		Orb(true)
	end
	CastStart = false
		
	if Tweetiebot.Spells:Value() and not IsUnderTower(myHero,false) and send then
		UseSpells(send)
	end
	
	if CastStart and not myHero.isChanneling then
		return true
	end

	return false
end

function UseSpells(send)

	local SpellQ = myHero:GetSpellData(_Q)
	local SpellW = myHero:GetSpellData(_W)
	local SpellE = myHero:GetSpellData(_E)
	local SpellR = myHero:GetSpellData(_R)

	local range = t(SpellQ.range < MaxSpellRange, SpellQ.range , 0)
	range = t(SpellQ.range == 0, GetAARangeTo(nil) , range) --and SpellQ.range < MaxSpellRange
	local target = GetNearestEnemy(myHero.pos,range,true)	
	if send and Ready(_Q) and target then	
		if SpellQ.range == 0 then -- no range
			Control.CastSpell(HK_Q)	
			CastStart = true
		else
			local pred = GetPrediction(target,{SpellQ.speed, SpellQ.delay,range})
			local CastPos = t(SpellQ.width, target.pos, pred.castPos)
			if DoesSpellHit(pred) or SpellQ.width == 0 then
				Orb(false)
				Control.SetCursorPos(CastPos)
				Control.CastSpell(HK_Q, CastPos)
				GlobalTarget = target
				CastStart = true
			end
		end
		--p-rint(target.name .. " Q " .. target.pos:DistanceTo(myHero.pos) .. " " .. range)
	end
	
	
	range = t(SpellW.range < MaxSpellRange, SpellW.range , 0)
	range = t(SpellW.range == 0, GetAARangeTo(nil) , range) --and SpellW.range < MaxSpellRange
	local target = GetNearestEnemy(myHero.pos,range,true)	
	if send and Ready(_W) and target then	
		if SpellW.range == 0 then -- no range
			Control.CastSpell(HK_W)	
			CastStart = true
		else
			local pred = GetPrediction(target,{SpellW.speed, SpellW.delay,range})
			local CastPos = t(SpellW.width, target.pos, pred.castPos)
			if DoesSpellHit(pred) or SpellW.width == 0 then
				Orb(false)
				Control.SetCursorPos(CastPos)
				Control.CastSpell(HK_W, CastPos)
				GlobalTarget = target
				CastStart = true
			end
		end
		--p-rint(target.name .. " W " .. target.pos:DistanceTo(myHero.pos) .. " " .. range)
	end
	
	range = t(SpellE.range < MaxSpellRange, SpellE.range, 0)
	range = t(SpellE.range == 0, GetAARangeTo(nil) , range) --and SpellE.range < MaxSpellRange
	local target = GetNearestEnemy(myHero.pos,range,true)	
	if send and Ready(_E) and target then	
		if SpellE.range == 0 then -- no range
			Control.CastSpell(HK_E)	
			CastStart = true
		else
			local pred = GetPrediction(target,{SpellE.speed, SpellE.delay,range})
			local CastPos = t(SpellE.width, target.pos, pred.castPos)
			if DoesSpellHit(pred) or SpellE.width == 0 then
				Orb(false)
				Control.SetCursorPos(CastPos)
				Control.CastSpell(HK_E, CastPos)
				GlobalTarget = target
				CastStart = true
			end
		end
		--p-rint(target.name .. " E " .. target.pos:DistanceTo(myHero.pos) .. " " .. range .. " " .. SpellE.range)
	end
	
	
	range = t(SpellR.range < MaxSpellRange, SpellR.range , MaxSpellRange)
	local target = GetLowEnemy(myHero.pos,range,true)
	if send and Ready(_R) and target and (target.health < target.levelData.lvl*LowHealthPerLevelThreshold or target.health/target.maxHealth < 0.3) then	
		if SpellR.range == 0 then -- no range
			Control.CastSpell(HK_R)	
			CastStart = true
		else			
			Orb(false)
			Control.SetCursorPos(target.pos)
			Control.CastSpell(HK_R, target.pos)
			GlobalTarget = target
			CastStart = true
		end
		--p-rint(target.name .. " R " .. target.pos:DistanceTo(myHero.pos) .. " " .. range)
	end
	
end

function UseSummoners(send, emergency)
	Orb(false)
	local FleePoint = WaypointToVector(GetNextWaypoint(myHero.pos,true))
	if myHero:GetSpellData(4).currentCd == 0 and emergency and send then
		Control.SetCursorPos(myHero.pos:Extended(FleePoint,MoveRange))
		PutKey(HK_SUMMONER_1)
	end
	if myHero:GetSpellData(5).currentCd == 0 and emergency and send then
		Control.SetCursorPos(myHero.pos:Extended(FleePoint,MoveRange))
		PutKey(HK_SUMMONER_2)
	end
	Orb(true)
end

function Buy()
	-- Buy logic	
	if buystate == 5 then
		if myHero.gold >= gold and Items[currenthave+1][3] > 0 then
			print("Buying not successful")
			buystate = 6
			PutKey(27) --  escape
			return
		else
			buystate = 0
			currenthave = currenthave+1
			for k=1, #Items do
				if k > currenthave and myHero.gold > Items[k][3] then
					buystate = 2
					break;
				end
			end
			
		end
		
		if buystate ~= 2 and buystate ~= 6 then
			PutKey(27) --  escape
			buystate = 0
		end
	end
	
	if buystate == 4 then
		gold = myHero.gold
		Enter() -- enter
		Enter() -- enter double
		buystate = 5
	end
	
	if buystate == 3 then
		gold = myHero.gold
		Write(Items[currenthave+1][1])
	if not CurText then
		buystate = 4
		end		
	end
		
	if buystate == 2 then
		SelectSearchFieldBuy()
		buystate = 3
	end
	
	if buystate == 1 then
		PutKey("P")
		buystate = 2
	end
	
	if buystate == 0 then
		for k=1, #Items do
			if k > currenthave then
				if myHero.gold >= Items[k][3] then
					print("buy item " .. Items[k][1])
					buystate = 1
				else
					--p-rint("cant buy item!? "  .. v[1])
					buystate = 6
				end
				break
			end
		end
		
	end
end

function Autolevel()
	-- One level per tick, were not inhuman :-P
	--p-rint("can lvl  " .. tostring(CanLvlR(_R)) .. " " .. tostring(CanLvlR(_Q)) .. " " .. tostring(CanLvlR(_W)) .. " " .. tostring(CanLvlR(_E)))
	if  CanLvlR(_R) then
		LevelSpell("R")
		return
	end
	
	if CanLvl(_Q) and Tweetiebot.Autoleveler.PrioQ:Value() and (myHero.levelData.lvl == 1 or myHero.levelData.lvl > 3) then	
		LevelSpell("Q")
		return
	end
	
	if CanLvl(_W) and Tweetiebot.Autoleveler.PrioW:Value() and (myHero.levelData.lvl == 1 or myHero.levelData.lvl > 3) then
		LevelSpell("W")
		return
	end
	
	if CanLvl(_E) and Tweetiebot.Autoleveler.PrioE:Value() and (myHero.levelData.lvl == 1 or myHero.levelData.lvl > 3) then
		LevelSpell("E")
		return
	end
	
	if myHero:GetSpellData(_Q).level == 0 and CanLvl(_Q) then
		LevelSpell("Q")
		return
	end
	
	if myHero:GetSpellData(_W).level == 0 and CanLvl(_W) then
		LevelSpell("W")
		return
	end
	
	if myHero:GetSpellData(_E).level == 0 and CanLvl(_E) then
		LevelSpell("E")
		return
	end
	
	if CanLvl(_Q) then
		LevelSpell("Q")
		return
	end
	
	if CanLvl(_W) then
		LevelSpell("W")
		return
	end
	
	if CanLvl(_E) then
		LevelSpell("E")
		return
	end
end

--- Not Used ---
function Talk(send)	
	local KilledEnemys = 0
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.dead ~= active and Hero.isEnemy then
			KilledEnemys = KilledEnemys +1
		end
	end
	
	if KilledEnemys - EnemysDead == 1 and math.random(100) <= TalkChance then
		-- Someone was killed
		Chat(TextsOnKill[math.random(#TextsOnKill)])
	end
	
	EnemysDead = KilledEnemys
end


--- Waypoint Functions ---

function GoToTower(WayPoint, flee,  send)
	if WayPoint then
		local TowerPos = WaypointToVector(WayPoint)
		local NextWayPoint  = GetNextWaypoint(TowerPos,flee)
		local v = nil
		if NextWayPoint then 
			v = TowerPos:Extended(WaypointToVector(NextWayPoint), MoveRange)
		else
			v = TowerPos
		end
		
		--p-rint ("walk " ..  tostring(v:DistanceTo(myHero.pos)))
		if v:DistanceTo(myHero.pos) > MoveRange/2 then
			drawables[4] = {"Tower Walk ", 20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
			drawables[5] = {myHero.pos:To2D(),v:To2D(), Draw.Color(255, 0, 255, 0)}
			if send == true then
				Control.SetCursorPos(myHero.pos:Extended(v,MoveRange))
			end
			return v
		end
	end
	return nil
end

function GoToMinions(send, ally)
	if (IsActiveWaypoint({AllySide,lane,5}) or IsActiveWaypoint({AllySide,lane,4}) or IsActiveWaypoint({AllySide,lane,3})) and StartPoint:DistanceTo(myHero.pos) < MinionScanRange then
		return nil --- No Walking to minions in base as long Towers are up)
	end

	local minion = GetMinionInRange(myHero.pos, MinionScanRange,ally) 

	--p-rint(tostring(minion))
	if minion and (minion.pos:DistanceTo(myHero.pos) > GetAARangeTo(minion) or ally and minion.pos:DistanceTo(myHero.pos) > 200) and minion.pos:DistanceTo(StartPoint) > StartPoint:DistanceTo(myHero.pos) then -- and myHero.pos:DistanceTo(GetLaneTower(lane, true, true)) > myHero.pos:DistanceTo(minion.pos)
		local v = myHero.pos:Extended(minion.pos, t(minion.pos:DistanceTo(myHero.pos) > MoveRange, MoveRange, minion.pos:DistanceTo(myHero.pos)))
		drawables[3] = {v, Draw.Color(255, 0, 255, 0)}
		drawables[4] = {"Walk to " .. t(ally, " allied ", " enemy ") .. " Minions" ,20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 90, Draw.Color(255, 0, 255, 0)}
		drawables[5] = {myHero.pos:To2D(),v:To2D(), Draw.Color(255, 0, 255, 0)}
		
		if send == true then
			Control.SetCursorPos(v)
			ChangeMode("harass",true)
		end
		return minion.pos
	end
	return nil
end

function GetNearestAllyTower(pos, alive)
	local near = alive
	for i = 1, Game.TurretCount() do
		local Tower = Game.Turret(i)
		if (alive == nil or not (Tower.dead == alive)) and not Tower.isEnemy and (near == nil or pos:DistanceTo(Tower.pos) < pos:DistanceTo(near.pos)) then
			near = Tower;
		end
	end
	return near
end

function GetLaneTower(lane, enemy, alive)

	local Towers = Towers[t(enemy, EnemySide, AllySide)][lane]
	local foundTower = nil

	for k,x in pairs(Towers) do
		local FoundTowerDistance = 0
		if foundTower then FoundTowerDistance = WaypointToVector(foundTower):DistanceTo(myHero.pos) else FoundTowerDistance = 0 end
		local CurrentTowerDistance = WaypointToVector({t(enemy, EnemySide, AllySide),lane,k}):DistanceTo(myHero.pos)
		if alive and Towers[k][3] or not alive and not Towers[k][3] or alive == nil then
			if not foundTower or CurrentTowerDistance < FoundTowerDistance and CurrentTowerDistance > 300 then
				if not enemy or enemy then --and GetMinionInRange(WaypointToVector({EnemySide,lane,k}),20) then
					if not foundTower or k < foundTower[3] then 
						foundTower = {t(enemy, EnemySide, AllySide),lane,k}		
					end
				end
			end
		end
	end
	
	if foundTower then return WaypointToVector(foundTower) end
	return nil
end

function GetNextTowerTowardsBase(lane, active)
	local Towers = Towers[AllySide][lane]
	local foundTower = nil
	
	for k,x in pairs(Towers) do
		local CurrentTower = {t(enemy, EnemySide, AllySide),lane,k}
		local FoundTowerDistance = 0
		if foundTower then FoundTowerDistance = WaypointToVector(foundTower):DistanceTo(StartPoint) else FoundTowerDistance = 0 end
		local CurrentTowerDistance = WaypointToVector(CurrentTower):DistanceTo(StartPoint)
		if alive and Towers[k][3] or not alive and not Towers[k][3] or alive == nil then
			if CurrentTowerDistance > FoundTowerDistance and StartPoint:DistanceTo(myHero.pos) > CurrentTowerDistance then
				if not foundTower or k < foundTower[3] then 
					foundTower = CurrentTower	
				end
			end
		end
	end
	
	if foundTower then return WaypointToVector(foundTower) end
	return nil
end

function GetNextWaypoint(pos,flee)
	local foundTower = nil
	

	
	for b,n in pairs(Towers) do
		for j=1,#n[lane] do
			if j ~= 4 and j ~= 5 then
				local CurrentTower = {b,lane,j}	
				local CurrentTowerVector = WaypointToVector(CurrentTower)

				if 	b == EnemySide and flee then											
					if 	(not foundTower or CurrentTowerVector:DistanceTo(EnemyStartPoint) < WaypointToVector(foundTower):DistanceTo(EnemyStartPoint)) and
						CurrentTowerVector:DistanceTo(EnemyStartPoint) > EnemyStartPoint:DistanceTo(pos) and
						pos ~= CurrentTowerVector then
						foundTower = CurrentTower
					end
				end
				
				if 	b == AllySide and flee then											
					if 	(not foundTower or CurrentTowerVector:DistanceTo(StartPoint) > WaypointToVector(foundTower):DistanceTo(StartPoint)) and
						CurrentTowerVector:DistanceTo(StartPoint) < StartPoint:DistanceTo(pos) and
						pos ~= CurrentTowerVector then
						foundTower = CurrentTower
					end
				end
				
				if 	b == AllySide and not flee then											
					if 	(not foundTower or CurrentTowerVector:DistanceTo(StartPoint) < WaypointToVector(foundTower):DistanceTo(StartPoint)) and
						CurrentTowerVector:DistanceTo(StartPoint) > StartPoint:DistanceTo(pos) and
						pos ~= CurrentTowerVector then
						foundTower = CurrentTower
					end
				end	
				
				if 	b == EnemySide and not flee then											
					if 	(not foundTower or CurrentTowerVector:DistanceTo(EnemyStartPoint) > WaypointToVector(foundTower):DistanceTo(EnemyStartPoint)) and
						CurrentTowerVector:DistanceTo(EnemyStartPoint) < EnemyStartPoint:DistanceTo(pos) and
						pos ~= CurrentTowerVector then
						foundTower = CurrentTower
					end
				end	
			end
		end	
	end
			
	if pos == WaypointToVector(foundTower) then
		foundTower = nil
	end
	
	return foundTower
end


--- Waypoint Helper ---

function GetAttackedbyMinions(range)
	local count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion.team ~= myHero.team then
			if minion.pos:DistanceTo(myHero.pos) <= range then
				if minion.attackData.target == myHero.handle then
					count = count +1
				end
			end
		end
	end
	return count
end

function MinionsInRange(pos,mult)
	local count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion.team ~= myHero.team and not (minion.team == 300) then
			if  minion.pos:DistanceTo(pos) < GetAARangeTo(minion)*mult then
				count = count +1
			end
		end
	end
	return count
end

function MinionsInRangeAbs(pos,team,range)
	local count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion.team == team then
			if  minion.pos:DistanceTo(pos) < range then
				count = count +1
			end
		end
	end
	return count
end

function GetMinionInRange(pos,range, ally)
	local ActiveEnemyTower = GetLaneTower(lane, true, true)
	local myMinion = nil
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  (not ally and minion.team ~= myHero.team or ally and minion.team == myHero.team) and not (minion.team == 300) then
			if  pos:DistanceTo(minion.pos) < range and (not myMinion or myMinion and minion.pos:DistanceTo(pos) < myMinion.pos:DistanceTo(pos)) then
				if not ActiveEnemyTower or ActiveEnemyTower:DistanceTo(EnemyStartPoint) < minion.pos:DistanceTo(EnemyStartPoint) then -- dont towerdive for minions too far
					myMinion = minion
				end
			end
		end
	end
	return myMinion
end

function GetLowMinionInRange(pos,mult)
	local ActiveEnemyTower = GetLaneTower(lane, true, true)
	local myMinion = nil
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion.team ~= myHero.team and not (minion.team == 300) then
			if  minion.pos:DistanceTo(pos) < GetAARangeTo(minion)*mult and minion.health < CalcPhysicalDamage(myHero, minion, myHero.totalDamage)*1.2 and BotOrb.AlmostLastHitMinion ~= minion then
				if not ActiveEnemyTower or ActiveEnemyTower:DistanceTo(EnemyStartPoint) < minion.pos:DistanceTo(EnemyStartPoint) then -- dont towerdive for minions too far
					myMinion = minion
				end
			end
		end
	end
	return myMinion
end

function CheckTowers()

	for k,x in pairs(Towers) do
		for b = 1, #Towers[k] do
			for n=1, #Towers[k][b] do
				Towers[k][b][n][3] = nil
			
				for i = 1, Game.TurretCount() do
					local Tower = Game.Turret(i)
					if Tower.pos:DistanceTo(Vector(Towers[k][b][n][1],0,Towers[k][b][n][2])) < 600 then
						Towers[k][b][n][3] = Tower
					end
				end
				--local Towerpos = Vector(Towers[k][b][n][1],0, Towers[k][b][n][2]) 
				--Draw.Line(myHero.pos:To2D(),Towerpos:To2D(), Draw.Color(255, 255, 0, 0))
				--Draw.Text(tostring(Towers[k][b][n][3] ~= nil).. " " .. k .. " " .. b .. " " .. n, 20, Towerpos:To2D().x, Towerpos:To2D().y, Draw.Color(255, 0, 255, 0))
			end		
		end
	end	
end

function GetNearestEnemy(pos,range,alive)
	local near = nil
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.dead ~= alive and Hero.isEnemy and Hero.visible and pos:DistanceTo(Hero.pos) < range and (not near or near and pos:DistanceTo(Hero.pos) < pos:DistanceTo(near.pos)) then
			near = Hero
		end
	end
	return near
end

function GetLowEnemy(pos,range,alive)
	local near = nil
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if not (Hero.dead == alive) and Hero.isEnemy and Hero.visible and pos:DistanceTo(Hero.pos) < range and (not near or near and Hero.health < near.health) then
			near = Hero
		end
	end
	return near
end

function GetHeroCount(pos,range,allied)
	local near = 0
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.dead ~= true and Hero.isEnemy ~= allied and Hero.visible and pos:DistanceTo(Hero.pos) < range then
			local enemy = GetTarget(range)
			if not allied or allied and (enemy and enemy.pos:DistanceTo(Hero.pos) < enemy.pos:DistanceTo(myHero.pos)+100 or not enemy) and Hero ~= myHero then
				near = near + 1
			end
		end
	end
	return near
end

function GetHeros(pos,range,allied)
	local near = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.dead ~= true and Hero.isEnemy ~= allied and Hero.visible and pos:DistanceTo(Hero.pos) < range then
			local enemy = GetTarget(range)
			if not allied or allied and (enemy and enemy.pos:DistanceTo(Hero.pos) < enemy.pos:DistanceTo(myHero.pos)+200 or not enemy) and Hero ~= myHero then
				table.insert(near, Hero)

			end
		end
	end
	return near
end


function GetNearestEnemyTower(pos,range)
	for i = 1, Game.TurretCount() do
		local Tower = Game.Turret(i)
		if Tower.isEnemy and pos:DistanceTo(Tower.pos) < range then
			return Tower
		end
	end
	return nil
end

function WaypointToVector(myWaypoint)
	if myWaypoint then 
		return TowerToVector(WaypointToTower(myWaypoint))
	end
	return nil
end

function TowerToVector(Tower)
		return Vector(Tower[1],0,Tower[2]) 
end

function WaypointToTower(Waypoint)
	return Towers[Waypoint[1]][Waypoint[2]][Waypoint[3]]
end

function IsActiveWaypoint(WayPoint)
	return WaypointToTower(WayPoint)[3] ~= nil
end


--- Helper Functions ---

function CheckGameStart()
	local items = 0
	local Itemslots = { myHero:GetItemData(ITEM_1), myHero:GetItemData(ITEM_2), myHero:GetItemData(ITEM_3), myHero:GetItemData(ITEM_4), myHero:GetItemData(ITEM_5), myHero:GetItemData(ITEM_6) }
	for i = 1, #Itemslots do
		if Itemslots[i].itemID ~= 0 then
			items = items+1
		end
	end
	if items == 0 then -- Start of Game
		buystance = true
		return true
	end
	return false
end

function CheckScriptEnable()
	if not Tweetiebot.Enable:Value() then
	
		if enabled == true then
			enabled = false
			ResetModes(nil)
		end
		
		ClearDraw()
		return false
	else
		if enabled == false then
			enabled = true
			CheckItems()
		end
		return true
	end
end


function ChangeMode(mode,value)

	if mode==Mode_Combo and BotOrb:HasMode(Mode_Combo) ~= value then
		BotOrb.Menu.Keys.Combo:Value(value) --BotOrb.Modes[Mode_Combo] = value
	end
	
	if mode==Mode_Clear and BotOrb:HasMode(Mode_Clear) ~= value then
		BotOrb.Menu.Keys.LaneClear:Value(value)
	end
	
	if mode==Mode_Flee and BotOrb:HasMode(Mode_Flee) ~= value then
		BotOrb.Menu.Keys.Flee:Value(value)
	end
	
	if mode==Mode_Harass and BotOrb:HasMode(Mode_Harass) ~= value then
		BotOrb.Menu.Keys.Harass:Value(value)
	end
	
	if mode==Mode_Lasthit and BotOrb:HasMode(Mode_Lasthit) ~= value then
		BotOrb.Menu.Keys.LastHit:Value(value)
	end
end

function ActiveMode()

	if BotOrb:HasMode(Mode_Combo) then
		return Mode_Combo
	end
	
	if BotOrb:HasMode(Mode_Clear) then
		return Mode_Clear
	end
	
	if BotOrb:HasMode(Mode_Flee) then
		return Mode_Flee
	end
	
	if BotOrb:HasMode(Mode_Harass) then
		return Mode_Harass
	end
	
	if BotOrb:HasMode(Mode_Lasthit) then
		return Mode_Lasthit
	end
	
	return -1
end

function ResetModes(Exception)
	ChangeMode(Mode_Combo,t(Exception==Mode_Combo, true, false))
	ChangeMode(Mode_Clear,t(Exception==Mode_Clear, true, false))
	ChangeMode(Mode_Flee,t(Exception==Mode_Flee, true, false))
	ChangeMode(Mode_Harass,t(Exception==Mode_Harass, true, false))
	ChangeMode(Mode_Lasthit,t(Exception==Mode_Lasthit, true, false))
end

function GDraw()
	if not Tweetiebot.Enable:Value() then
		ClearDraw()
		return
	end
	
	
	for k=1, #drawables do
		local v = drawables[k]
		if v then
			if type(v[1]) == "string" and type(v[2]) == "number" then
				Draw.Text(v[1],v[2],v[3],v[4],v[5])
			end
			
			if type(v[1]) == "userdata" and type(v[2]) == "number" then
				if v[3] then
					Draw.Circle(v[1],v[2],v[3],v[4])
				else
					Draw.Circle(v[1],v[2],v[4])
				end
			end
			
			if type(v[1]) == "userdata" and type(v[2]) == "userdata" then
					Draw.Line(v[1],v[2],v[3])
			end
		end
		-- userdata
	end
		
end

function ClearDraw()
	for k=1, #drawables do
		drawables[k] = nil
	end
end

function Chat(value)
	Enter()
	Write(value)
	Enter()
	Enter()
end



function GetEnemyAARangeTo(target)
	if target == nil then
		return nil
	end
	return target.range + target.boundingRadius * 0.5 + (myHero.boundingRadius ~= nil and (myHero.boundingRadius - 30) or 35)
end

function GetAARangeTo(target)
	return myHero.range + myHero.boundingRadius * 0.5 + (target ~=nil and target.boundingRadius ~= nil and (target.boundingRadius - 30) or 35)
end

function IsUnderTower(object,allied)
	for i = 1, Game.TurretCount() do
		local Tower = Game.Turret(i)
		if (allied and Tower.team == object.team or not allied and Tower.team ~= object.team) and object.pos:DistanceTo(Tower.pos) < TowerDangerZone then
			return true
		end
	end
	return false
end

function GetPrediction(target,Spelldata)
	local spell = Prediction:SetSpell(Spelldata, TYPE_LINEAR, true)
	return spell:GetPrediction(target,myHero.pos) 
end

function DoesSpellHit(pred)
	return pred and pred.hitChance >= HitChanceModifier and pred:mCollision() == 0 and pred:hCollision() == 0
end


function IsInBuyDistance()
	return StartPoint:DistanceTo(myHero.pos) < BuyDistanceToStart or myHero.dead
end

function SetBuyStance()
	local textPos = myHero.pos:To2D()
	if not buystance and IsInBuyDistance() and CanAffordNextItem() then
		--p-rint("Start Buy items")
		buystance = true
		CheckItems()
	elseif buystance and (not IsInBuyDistance() or not CanAffordNextItem()) and (buystate == 0 or buystate == 6) then
		--p-rint("End Buy items")
		buystance = false
		buystate = 0
	end
end

function CheckBuy(send)
	Orb(false)
	--p-rint("buystate " .. tostring(send) .. " " ..  tostring(buystate))
	if send and buystate ~= 6 then	
		ClearDraw()
		drawables[2] = {"Buying " ,20, myHero.pos:To2D().x - 33, myHero.pos:To2D().y + 40, Draw.Color(255, 0, 255, 0)}
		if IsInBuyDistance() and myHero.isChanneling then
			BreakChannel()
		else
			Buy()
		end
	end
end

function GetTarget(range)
	local target = _G.SDK.TargetSelector:GetTarget(range)
	if target and target.visible and not target.dead then
		return target
	end
	return nil
end

function IsAARangeMultEnemy(target, mult)
	if not target or target and myHero.pos:DistanceTo(target.pos) > GetEnemyAARangeTo(target) * mult then
		return false
	end
	return true
end

function IsAARangeMult(target, mult)
	if not target or target and target.pos:DistanceTo(myHero.pos) > GetAARangeTo(target) * mult then
		return false
	end
	return true
end

function IsAARange(target)
	return IsAARangeMult(target, 1)
end


function CanLvl(Spell)
	return math.floor((myHero.levelData.lvl+1)/2) > myHero:GetSpellData(Spell).level and myHero:GetSpellData(Spell).level < 5
end

function CanLvlR(Spell)
	return math.floor((myHero.levelData.lvl-1)/5) > myHero:GetSpellData(Spell).level and myHero:GetSpellData(Spell).level < 3
end

function LevelSpell(Spell)
	local mylevelpts = myHero.levelData.lvl - (myHero:GetSpellData(_Q).level + myHero:GetSpellData(_W).level + myHero:GetSpellData(_E).level + myHero:GetSpellData(_R).level)
	if mylevelpts > 0 then
		KeyCombo(HK_LUS,Tweetiebot.Keys[Spell]:Key())
	end
end

function CanAffordNextItem()

	for k=1, #Items do
		if k > currenthave then
			if myHero.gold >= Items[k][3] then
				return true
			else
				return false
			end
			break
		end
	end

end

function CanAffordNextMajorItem()
	local goldsum = 0
	
	for k=1, #Items do
		if k > currenthave then
			if Items[k][4] ~= nil then
				goldsum = goldsum + Items[k][3]
			else
				goldsum = goldsum + Items[k][3]
				if myHero.gold >= goldsum then
					return true
				else
					return false
				end
				break
			end
		end
	end
		
end

function CheckItems()
	local Itemslots = { myHero:GetItemData(ITEM_1), myHero:GetItemData(ITEM_2), myHero:GetItemData(ITEM_3), myHero:GetItemData(ITEM_4), myHero:GetItemData(ITEM_5), myHero:GetItemData(ITEM_6), myHero:GetItemData(ITEM_7) }
	local End = false
	
	for k=1, #Items do
		if HasItem(Items[k],Itemslots) then
			currenthave = k
			--p-rint(Items[k][1])
		elseif not End then
			if Items[k][4] and not HasItem(Items[Items[k][4]],Itemslots) then
				--p-rint("does not have " .. Items[k][1] .. " " .. Items[k][4])
				End = true
			end
		elseif End then
			return
		end
	end
	
end

function HasItem(item, Items)
	for k=1, #Items do
		if Items[k] and Items[k].itemID == item[2] then
			return true
		end
	end
	 
	return false
end

function SelectSearchFieldBuy()
	KeyCombo(17,"L")
end



Callback.Add("Load", function()
	if not _G.Prediction_Loaded then return end
	__init()
	print("Tweetieshy Bot "..ScriptVersion.." Loaded")
end)