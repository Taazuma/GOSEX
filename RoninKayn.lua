require "DamageLib"
require 'Eternal Prediction'
class "RoninKayn"

Callback.Add("Load", function() RoninKayn:OnLoad() end)

function RoninKayn:OnLoad()
  self:myMenu()
  self:mySpells()
  
  Callback.Add("Tick", function() self:OnTick() end)
	--Callback.Add("Draw", function() self:OnDraw() end)
end

function RoninKayn:mySpells()

	self.Q = { range = 350, width = myHero:GetSpellData(_Q).width, delay = 0.15, speed = myHero:GetSpellData(_Q).speed }
  self.W = { range = 700, width = myHero:GetSpellData(_W).width, delay = 0.15, speed = myHero:GetSpellData(_W).speed }
  self.E = { range = myHero:GetSpellData(_E).range, width = myHero:GetSpellData(_E).width, delay = 0.15, speed = myHero:GetSpellData(_E).speed }
  self.R = { range = 500, width = myHero:GetSpellData(_R).width, delay = 0.15, speed = math.huge }
end
  
function RoninKayn:myMenu()
  
  self.Ronin = MenuElement({id = "Ronin", name = "Ronin Kayn", type = MENU, leftIcon = "https://ddragon.leagueoflegends.com/cdn/7.23.1/img/passive/Diana_Passive_LunarBlade.png"})
  
	self.Ronin:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Ronin:MenuElement({id = "Clears", name = "Clear", type = MENU})
	self.Ronin:MenuElement({id = "Key", name = "Key Settings", type = MENU})
  
  -- Keys
	self.Ronin.Key:MenuElement({id = "Combo", name = "Combo", key = string.byte(" ")})
	self.Ronin.Key:MenuElement({id = "Clear", name = "Lane/JungleClear", key = string.byte("V")})

	-- Combo
	self.Ronin.Combo:MenuElement({id = "quse", name = "Use [Q}", value = true, leftIcon = "http://i.epvpimg.com/jp5Ecab.png"})
	self.Ronin.Combo:MenuElement({id = "wuse", name = "Use [W}", value = true, leftIcon = "http://i.epvpimg.com/uF5Pbab.png"})
	self.Ronin.Combo:MenuElement({id = "euse", name = "Use [E]", value = true})
	self.Ronin.Combo:MenuElement({id = "ruse", name = "Use [R]", value = false, leftIcon = "http://i.epvpimg.com/iADGfab.png"})
  self.Ronin.Combo:MenuElement({id = "rsmart", name = "Use Smart [R]", value = true, leftIcon = "http://i.epvpimg.com/iADGfab.png"})

	-- Clear
	self.Ronin.Clears:MenuElement({id = "quse", name = "Use [Q]", value = true, leftIcon = "http://i.epvpimg.com/jp5Ecab.png"})
  self.Ronin.Clears:MenuElement({id = "wuse", name = "Use [W]", value = true, leftIcon = "http://i.epvpimg.com/uF5Pbab.png"})
	self.Ronin.Clears:MenuElement({id = "usemana", name = "Mana Usage", value = 25, min = 0, max =      100, step = 1})
  self.Ronin.Clears:MenuElement({id = "sliderminion", name = "Minions", value = 2, min = 0, max =      10, step = 1})
end

function RoninKayn:GetTarget(range)

	if _G.EOWLoaded then
		return EOW:GetTarget(range, EOW.ap_dec, myHero.pos)
	elseif _G.SDK and _G.SDK.TargetSelector then
		return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
	elseif _G.GOS then
		return GOS:GetTarget(range, "AP")
	end
end

function RoninKayn:IsReadyToCast(slot)
	return Game.CanUseSpell(slot) == 0
end

function RoninKayn:IsValid(range, unit)
	return unit:IsValidTarget(range, nil, myHero) and not unit.isImmortal and unit.health > 0 and not unit.dead and self:GetDistance(myHero.pos, unit.pos) <= range
end

function RoninKayn:GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return (dx * dx + dz * dz)
end

function RoninKayn:GetDistance(p1, p2)
    return math.sqrt(self:GetDistanceSqr(p1, p2))
end

function RoninKayn:GetDistance2D(p1,p2)
    return math.sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

function RoninKayn:GetHpPercent(unit)
    return unit.health / unit.maxHealth * 100
end

function RoninKayn:GetManaPercent(unit)
	return unit.mana / unit.maxMana * 100
end

function RoninKayn:OnTick()

	if myHero.dead then return end

	Orb:GetMode()

	self.target = self:GetTarget(800)

	if Orb.combo and self.target ~= nil then
		self:Combo(self.target)
	elseif Orb.harass and target ~= nil then
		self:Harass(target)
	elseif Orb.lastHit then
		--self:LastHit()
	elseif Orb.laneClear or Orb.jungleClear then
		self:Clear()
	end
end



function RoninKayn:Combo(target)

	if self.target == nil then return end

  -- Q --
  if self:IsReadyToCast(_Q) and self:IsValid(self.Q.range, self.target) and self.Ronin.Combo.quse:Value() then
    Control.CastSpell(HK_Q, self.target)
  end
  -- R Smart -- only when Buff Q
  local AA = CalcPhysicalDamage(myHero, self.target, myHero.totalDamage)
  if self:IsReadyToCast(_R) and self:IsValid(self.R.range, self.target) and self.Ronin.Combo.rsmart:Value() then
    Control.CastSpell(HK_R, self.target)
  end
    -- R --
  if self:IsReadyToCast(_R) and self:IsValid(self.R.range, self.target) and self.Ronin.Combo.ruse:Value() then
    Control.CastSpell(HK_R, self.target)
  end
	-- W --
	if self:IsReadyToCast(_W) and self:IsValid(self.W.range, self.target) and self.Ronin.Combo.wuse:Value() then
		Control.CastSpell(HK_W, self.target)
	end
  -- E --
	if self:IsReadyToCast(_E) and self:IsValid(self.E.range, self.target) and self.Ronin.Combo.euse:Value() then
      Control.CastSpell(HK_E)
    end
	end

function RoninKayn:Clear()

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

	if qMinion ~= nil and self:IsReadyToCast(_Q) and self.Ronin.Clears.quse:Value() and
			self:GetManaPercent(myHero) > self.Ronin.Clears.usemana:Value() then
			Control.CastSpell(HK_Q, qMinion.pos)
  end
  if qMinion ~= nil and self:IsReadyToCast(_W) and self.Ronin.Clears.wuse:Value() and
    self:GetManaPercent(myHero) > self.Ronin.Clears.usemana:Value() then
    Control.CastSpell(HK_W, qMinion.pos)
  end
end

--

--------------------------------------------------------------------------------------------------------------------------------------------------
--credits to D.noob-senpai

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
