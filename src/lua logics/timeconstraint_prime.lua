-- powered by schizophrenia

local TIMECONSTRAINT_WAVE = 6

local classIndices_Internal = {
	[1] = "Scout",
	[3] = "Soldier",
	[7] = "Pyro",
	[4] = "Demoman",
	[6] = "Heavyweapons",
	[9] = "Engineer",
	[5] = "Medic",
	[2] = "Sniper",
	[8] = "Spy",
}

local DEATH_INSULTS = {
	Scout = {
		"Jumping won't save you, %s",
		"Unequip the Fan-o-War, %s",
		"Try upgrading your primary weapon, %s",
	},
	Soldier = {
		"Unbind your attack key, %s",
		"Don't buy rocket specialist next time, %s",
	},
	Pyro = {
		"Hey %s! Did you know that the airblast force upgrade makes you take 50%% more damage?",
		"Hey %s! Did you know that equipping the scorch shot makes you take 150%% more damage?",
		"Hey %s! Unbind your airblast key",
	},
	Demoman = {
		"Try using your movement keys next time, %s",
		"Are you actually drunk, %s? You're playing like you are",
		"Your incompetency is truly explosive, %s",
	},
	Heavyweapons = {
		"Consider playing a more interesting class, %s",
		"I hope that got you to leave a negative review on the end-of-operation survey, %s",
		"Keep standing directly infront of me, %s, see how well that goes next time",
	},
	Engineer = {
		"Build yourself better gamesense, %s",
		"Sentry blocking going well, aye %s?",
		"Unequip the wrangler, %s",
	},
	Medic = {
		"How's that canteen spam going for you, %s?",
		"Try idling more %s, maybe that will work",
		"Too bad you can't reanimate yourself, %s",
	},
	Sniper = {
		"Stop aiming for my head and start aiming to be better at the game, %s",
		"Thanks for standing still, %s!",
	},
	Spy = {
		"I hate the french",
		"Try running in circle harder, %s",
		"Couldn't dead ring that one, %s? Unfortunate",
	},
}

local WAVE_ICONS = {
    [1] = {
        [1] = {
            name = "timer_lite",
            flag = 8,
            count = 1,
        },
    },
    [2] = {
        [1] = {
            name = "timer_lite",
            flag = 8,
            count = 1,
        },
        [2] = {
            name = "heavy_chief",
            flag = 8,
            count = 1,
        },
        [3] = {
            name = "soldier_sergeant_crits",
            flag = 8,
            count = 1,
        },
    },
}

local wavebarLogic

local randomIcons = {
	"scout",
	"soldier",
	"heavy",
	"demo",
	"pyro",
	"soldier_spammer",
	"spy",
	"soldier_blackbox",
	"medic_giant",
	"timer_lite",
	"helicopter_blue_nys",
	"soldier_barrage",
	"heavy_chief",
	"demoknight_giant",
	"soldier_sergeant_crits",
	"demo_bomber",
	"heavy_shotgun",
}

local inWave = false
local curWave = nil

local timeconstraint_alive = false
local cur_constraint = false -- current time constraint bot

local pvpActive = false
local gamestateEnded = false
local specialLinePlaying = false

local function chatMessage(message)
	local outputMessage = "{blue}" .. "Time-Constraint Prime:" .. "{reset}: " .. message

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		player:AcceptInput("$DisplayTextChat", outputMessage)
	end
end

local function hasTag(tags, tagToFind)
	for _, tag in pairs(tags) do
		if tag == tagToFind then
			return true
		end
	end
end

local function removeCallbacks(bot, callbacks)
	if not IsValid(bot) then
		return
	end

	for _, callbackId in pairs(callbacks) do
		bot:RemoveCallback(callbackId)
	end
end
local function removeTimers(timers)
	for _, timerId in pairs(timers) do
		print(timerId)
		timer.Stop(timerId)
	end
end

local function resetWavebar()
	if wavebarLogic then
		timer.Stop(wavebarLogic)
		wavebarLogic = nil
	end

	-- local objResource = ents.FindByClass("tf_objective_resource")

	-- objResource.m_nMannVsMachineWaveEnemyCount = 1

	-- objResource.m_nMannVsMachineWaveClassFlags[1] = 9
	-- objResource.m_iszMannVsMachineWaveClassNames[1] = "timer_lite"

	-- for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
	--     if i > 1 then
	--         objResource.m_nMannVsMachineWaveClassCounts[i] = 0
	--     end
	-- end
end

local function setWaveBar(subwave)
	if wavebarLogic then
		timer.Stop(wavebarLogic)
		wavebarLogic = nil
	end

	local objResource = ents.FindByClass("tf_objective_resource")

	local subwaveIcons = WAVE_ICONS[subwave]

	local totalCount = 0
	for _, iconData in pairs(subwaveIcons) do
		totalCount = totalCount + iconData.count
	end

	objResource.m_nMannVsMachineWaveEnemyCount = totalCount

	objResource.m_nMannVsMachineWaveClassFlags[1] = 9
	objResource.m_iszMannVsMachineWaveClassNames[1] = "timer_lite"

	for i = 1, #objResource.m_iszMannVsMachineWaveClassNames do
	    if subwaveIcons[i] then
	        objResource.m_iszMannVsMachineWaveClassNames[i] = subwaveIcons[i].name
	    end
	end
	for i = 1, #objResource.m_nMannVsMachineWaveClassFlags do
	    if subwaveIcons[i] then
	        objResource.m_nMannVsMachineWaveClassFlags[i] = subwaveIcons[i].flag
	    end
	end
	for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
	    if subwaveIcons[i] then
	        objResource.m_nMannVsMachineWaveClassCounts[i] = subwaveIcons[i].count
		else
	        objResource.m_nMannVsMachineWaveClassCounts[i] = 0
	    end
	end
end

local playersCallback = {}
local timers = {}

function _TimeConstraintOnWaveInit(wave)
	inWave = false
	curWave = wave

	gamestateEnded = false
	timeconstraint_alive = false
	pvpActive = false
    specialLinePlaying = false

	removeTimers(timers)
	for player, plrCallbacks in pairs(playersCallback) do
		removeCallbacks(player, plrCallbacks)
	end

	resetWavebar()

	if wave ~= TIMECONSTRAINT_WAVE then
		return
	end

	-- resetWavebar()

	local objResource = ents.FindByClass("tf_objective_resource")

	timer.Simple(1, function()
		if inWave then
			return
		end

		if curWave ~= TIMECONSTRAINT_WAVE then
			return
		end

		chatMessage("I await")

		wavebarLogic = timer.Create(0.5, function()
			objResource.m_nMannVsMachineWaveEnemyCount = math.random(1, 100)

			for i = 1, #objResource.m_nMannVsMachineWaveClassFlags do
				local random = math.random(1, 4)

				local flag = 1
				if random == 2 then
					flag = 9
				end

				objResource.m_nMannVsMachineWaveClassFlags[i] = flag
			end
			for i = 1, #objResource.m_iszMannVsMachineWaveClassNames do
				objResource.m_iszMannVsMachineWaveClassNames[i] = randomIcons[math.random(#randomIcons)]
			end
			for i = 1, #objResource.m_nMannVsMachineWaveClassCounts do
				objResource.m_nMannVsMachineWaveClassCounts[i] = math.random(0, 999)
			end
		end, 0)
	end)
end

function OnWaveStart(wave)
	inWave = true
	resetWavebar()

	if wave ~= TIMECONSTRAINT_WAVE then
		return
	end

	setWaveBar(1)

	-- resetWavebar()
end

local rollbacks = {}

local CLASSES = { "player", "obj_*" }

local function addEntToRollback(ent, class)
	if not ent:IsCombatCharacter() then
		return
	end

	if ent.m_iTeamNum ~= 2 then
		return
	end

	rollbacks[ent] = {
		Origin = ent:GetAbsOrigin(), --+ Vector(0, 0, 0),
		Angles = ent:GetAbsAngles(),
		IsPlayer = class == "player" and true,
	}
end

local function storeRollback()
	rollbacks = {}

	for _, class in pairs(CLASSES) do
		for _, ent in pairs(ents.FindAllByClass(class)) do
			addEntToRollback(ent, class)
		end
	end
end

local function fade()
	local fadeEnt = ents.CreateWithKeys("env_fade", {
		holdtime = 1,
		duration = 0.5,
		rendercolor = "255, 255, 255",
		renderamt = 255,
	}, true, true)

	fadeEnt.Fade(fadeEnt)

	timer.Simple(1, function()
		fadeEnt:Remove()
	end)
end

local function revertRollback()
	fade()

	timer.Simple(0.6, function()
		for _, door in pairs(ents.FindAllByClass("func_door")) do
			door:Remove()
		end

		for _, player in pairs(ents.GetAllPlayers()) do
			if player:IsRealPlayer() then
				player:ForceRespawn()
			end
		end

		for ent, data in pairs(rollbacks) do
			if IsValid(ent) and ent:IsAlive() then
				-- ent:SetAbsOrigin(data.Origin)
				-- ent:SetAbsAngles(data.Angles)

				if data.IsPlayer then
					ent:SetAbsOrigin(data.Origin)
					ent:SnapEyeAngles(data.Angles)

					-- local pitch = ent["m_angEyeAngles[0]"]
					-- local yaw = ent["m_angEyeAngles[1]"]
					-- ent:SnapEyeAngles(Vector(-pitch, yaw, 0))
				else
					ent:Teleport(data.Origin, data.Angles)
				end
			end
		end
	end)
end

ents.AddCreateCallback("entity_revive_marker", function(entity)
	if not pvpActive then
		return
	end

	timer.Simple(0, function()
		entity:Remove()
	end)
end)

local function handlePlayerDeath(player)
	playersCallback[player] = {}

	playersCallback[player].died = player:AddCallback(ON_DEATH, function()
		if pvpActive then
			return
		end

		if specialLinePlaying then
			return
		end

		if player.m_iTeamNum ~= 2 then
			return
		end

		local allInsults = DEATH_INSULTS[classIndices_Internal[player.m_iClass]]
		local chosenInsult = allInsults[math.random(#allInsults)]

		local name = player:GetPlayerName()

		chatMessage(string.format(chosenInsult, name))
	end)
end

local function Holder(bot)
	timeconstraint_alive = true

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		if player:IsRealPlayer() then
			handlePlayerDeath(player)
		end
	end

	local callbacks = {}

	storeRollback()

	local milkers = {}

	timers.milkCheck = timer.Create(0.1, function()
		if not timeconstraint_alive then
			removeCallbacks(bot, callbacks)
			removeTimers(timers)
		end

		if not cur_constraint or not cur_constraint:IsAlive() then
			return
		end

		local milker = cur_constraint:GetConditionProvider(TF_COND_MAD_MILK)

		if not milker then
			return
		end

		local secondary = milker:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY)

		-- prevents mistaking mad milk syringes from mad milk
		if secondary.m_iClassname ~= "tf_weapon_jar_milk" then
			return
		end

		local handle = milker:GetHandleIndex()

		if milkers[handle] then
			return
		end

		milkers[handle] = true

		timer.Simple(1.5, function()
			-- chatMessage("Here, have a better weapon. You're welcome")
			milker:GiveItem("The Winger")
			milker:WeaponSwitchSlot(LOADOUT_POSITION_SECONDARY)
		end)
	end, 0)

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		timeconstraint_alive = false

		removeCallbacks(bot, callbacks)
		removeTimers(timers)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
			-- removeTimers(timers)
		end
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
		removeTimers(timers)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
			-- removeTimers(timers)
		end
	end)
end

local function Handle1(bot)
	local callbacks = {}

	storeRollback()

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		specialLinePlaying = true

		timer.Simple(0.5, function()
			chatMessage("This never happened and will not occur again")
		end)

		timer.Simple(1.7, function()
			chatMessage("Let's do that again")
		end)

		timer.Simple(3.5, function()
			setWaveBar(1)
			specialLinePlaying = false
			revertRollback()
		end)

		removeCallbacks(bot, callbacks)
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
	end)
end

local function checkBot(bot, tags)
	if hasTag(tags, "realcontraint") then
		Holder(bot)
		return
	end
	if hasTag(tags, "timeconstraint1") then
		Handle1(bot)
		return true
	end
	-- if hasTag(tags, "timeconstraint2") then
	-- 	Handle2(bot)
	-- 	return true
	-- end
	-- if hasTag(tags, "timeconstraint3") then
	-- 	Handle3(bot)
	-- 	return true
	-- end
	-- if hasTag(tags, "timeconstraintFinal") then
	-- 	HandleFinal(bot)
	-- 	return true
	-- end
end

function _OnWaveSpawnBot_TimeConstraint(bot, _, tags)
	local result = checkBot(bot, tags)

	if result then
		cur_constraint = bot
	end
end
