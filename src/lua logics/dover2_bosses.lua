-- Colonel Dronemann
-- 2 drones on each side of him that can be destroyed, has the wrangler out
function ColDronemanSpawn(_, activator)
	local bulletWeapons = {
		[1] = "HOMING_ROCKETLAUNCHER_DRONE",
		-- [1] = "MARKER",
		[2] = "ROCKETLAUNCHER_WEAK",
	}
    local fireTime = {
        [1] = 3,
        [2] = 0.8
    }
	for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
		if wearable.m_hOwnerEntity == activator then
			wearable.m_flModelScale = 1.25
		end
	end

	local dronesDeadCount = 0

	local dronePrefix = "drone" .. tostring(activator:GetHandleIndex())
	for i = 1, 2 do
		local sentryModel = ents.CreateWithKeys("prop_dynamic", {
			model = "models/rcat/rcat_level2.mdl",
            ["$positiononly"] = 1,
			skin = 1,
		}, true, true)

		sentryModel:SetName(dronePrefix .. tostring(sentryModel:GetHandleIndex()))

		local weaponMimic = ents.CreateWithKeys("tf_point_weapon_mimic", {
			teamnum = activator.m_iTeamNum,
			["$preventshootparent"] = 1,
			["$weaponname"] = bulletWeapons[i],
			["$firetime"] = fireTime[i],
		})

		weaponMimic:SetName(dronePrefix .. "_weaponmimic_" .. tostring(sentryModel:GetHandleIndex()))

		weaponMimic["$SetOwner"](weaponMimic, activator)
		weaponMimic:SetParent(sentryModel)

		local offsetMult = i == 1 and 1 or -1
		local offset = Vector(0, 75 * offsetMult, 100)

		sentryModel["$fakeparentoffset"] = offset
		sentryModel:SetFakeParent(activator)

        weaponMimic["$StartFiring"](weaponMimic, math.huge)

		local logic
		logic = timer.Create(0.1, function()
			if not IsValid(sentryModel) then
				timer.Stop(logic)
				return
			end

			local curOrigin = sentryModel:GetAbsOrigin()

			local closest = { nil, math.huge }
			for _, player in pairs(ents.GetAllPlayers()) do
				local valid = true

				if not player:IsAlive() then
					valid = false
				elseif player.m_iTeamNum == activator.m_iTeamNum then
					valid = false
				elseif player:InCond(TF_COND_DISGUISED) == 1 then
					valid = false
				elseif player:InCond(TF_COND_STEALTHED) == 1 then
					valid = false
				end

                if valid then
                    local distance = curOrigin:Distance(player:GetAbsOrigin())

                    if distance < closest[2] then
                        closest = { player, distance }
                    end
                end
			end

            if not closest[1] then
                return
            end

            sentryModel:FaceEntity(closest[1])
		end, 0)

		-- go straight to phase 2 if both drones are destroyed prematurely
		-- drone:AddCallback(ON_REMOVE, function ()
		--     dronesDeadCount = dronesDeadCount + 1

		--     if dronesDeadCount >= 2 then
		--         ColDronemanEngaged(_, activator, true)
		--     end
		-- end)
	end
end

local function getDrones(activator)
	local dronePrefix = "drone" .. tostring(activator:GetHandleIndex()) .. "_weaponmimic_"

	return ents.FindAllByName(dronePrefix .. "*")
end

local function removeAllDrones(activator)
	for _, drone in pairs(ents.FindAllByName("drone" .. tostring(activator:GetHandleIndex()) .. "*")) do
		util.ParticleEffect("ExplosionCore_buildings", drone:GetAbsOrigin(), Vector(0, 0, 0))
		drone:Remove()
	end
end

function ColDronemanDeath(_, activator)
	removeAllDrones(activator)
end

function ColDronemanPhase2(_, activator, forced)
	if not forced and #getDrones(activator) == 0 then
		return
	end

	for _, drone in pairs(getDrones(activator)) do
        drone["$weaponname"] = "STICKYBOMB_DRONE"
		drone["$firetime"] = 0.8
	end

	local oneLiner = "{blue}"
	.. "Colonel Dronemann"
	.. "{reset}: These babies are in second gear now. Watch your steps"

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		player:AcceptInput("$DisplayTextChat", oneLiner)
	end
end

function ColDronemanEngaged(_, activator, forced)
	if not forced and #getDrones(activator) == 0 then
		return
	end

	removeAllDrones(activator)

	activator:ChangeAttributes("Engaged")

	-- crit jumpscare prevention
	activator:SetAttributeValue("no_attack", 2)
	timer.Simple(1, function()
		activator:SetAttributeValue("no_attack", nil)
	end)

	for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
		if wearable.m_hOwnerEntity == activator then
			wearable.m_flModelScale = 1.5
		end
	end

	local oneLiner = "{blue}"
	.. "Colonel Dronemann"
	.. "{reset}: Ring-a-Ding-Ding baby!"

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		player:AcceptInput("$DisplayTextChat", oneLiner)
	end
end

local SCALE_MAX = 2
local SCALE_HEALTH = 10000
local BASE_HEIGHT = 80

local MINI_THRESHOLD = 1000

local PHASES = {
	[0] = {
		Name = "Default",
	},
	[1] = {
		Name = "Shotgun",
	},
	[2] = {
		Name = "Tomislav",
	},
	[3] = {
		Name = "Minigun",
	},
	[4] = {
		Name = "BrassBeast",
	},
}

-- base health is 25000
local THRESHOLD = {
	[1] = 21000,
	[2] = 18000,
	[3] = 14000,
	[4] = 10000,
}

local function lerp(a,b,t)
    return a * (1-t) + b * t
end

-- Sergeant Sizer
-- gets bigger and moe powerful the more damage taken (eventually becoming a near-titan)
-- scaled down to small size when near death
function SergeantSizer(_, activator)
	local maxHealth = activator.m_iHealth
	local lastHealth = activator.m_iHealth

	local currentPhase = 0

	-- local growing = false

	-- local iterateCount = 10
	-- local function grow(goalSize)
	-- 	growing = true

	-- 	local vscriptBase = "activator.SetScaleOverride(%s)"

	-- 	local startSize = activator.m_flModelScale
	-- 	local curLerp = 0

	-- 	for i = 1, iterateCount do
	-- 		curLerp = curLerp + 1 / iterateCount
	-- 		timer.Simple(0.05 * i, function ()
	-- 			local vscript = vscriptBase:format(tostring(lerp(startSize, goalSize, curLerp)))

	-- 			activator:RunScriptCode(vscript, activator)

	-- 			if i == iterateCount then
	-- 				growing = false
	-- 			end
	-- 		end)
	-- 	end
	-- end

	local smol = false

	local logic
	logic = timer.Create(0.1, function()
		if not activator:IsAlive() then
			timer.Stop(logic)
			return
		end

		if smol then
			return
		end

		local health = activator.m_iHealth

		if health == lastHealth then
			return
		end

		-- if health <= MINI_THRESHOLD then
		-- 	smol = true
		-- 	activator:ChangeAttributes("Default")

		-- 	local iterate = 0
		-- 	for i = SCALE_MAX, 0.7, -0.1 do
		-- 		iterate = iterate + 1
		-- 		timer.Simple(0.1 * iterate, function ()
		-- 			local vscript = ("activator.SetScaleOverride(%s)"):format(tostring(i))
		-- 			activator:RunScriptCode(vscript, activator)

		-- 			for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
		-- 				if wearable.m_hOwnerEntity == activator then
		-- 					wearable.m_flModelScale = i
		-- 				end
		-- 			end
		-- 		end)
		-- 	end

		-- 	timer.Stop(logic)
		-- 	return
		-- end



		-- local height = BASE_HEIGHT * (activator.m_flModelScale)

		-- local DefaultTraceInfo = {
		-- 	start = activator:GetAbsOrigin(),
		-- 	endpos = activator:GetAbsOrigin() + height * 1.2,
		-- 	mask = MASK_SOLID,
		-- 	collisiongroup = COLLISION_GROUP_DEBRIS,
		-- }

		-- local trace = util.Trace(DefaultTraceInfo)

		-- -- don't grow if it'd end up stuck
		-- if trace.Hit then
		-- 	return
		-- end

		local nextThreshol = THRESHOLD[currentPhase + 1]

		if nextThreshol then
			if health <= nextThreshol then
				currentPhase = currentPhase + 1
				activator:ChangeAttributes(PHASES[currentPhase].Name)
			end
		end

		local ratio = math.min((maxHealth - health) / SCALE_HEALTH, 1)

		local size = lerp(1, SCALE_MAX, ratio)

		local vscript = ("activator.SetScaleOverride(%s)"):format(tostring(size))
		activator:RunScriptCode(vscript, activator)

		for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
			if wearable.m_hOwnerEntity == activator then
				wearable.m_flModelScale = size
			end
		end

		lastHealth = health
		-- grow(PHASES[goalPhase].Scale)
	end, 0)
end

-- major mannpower
-- switches between multiple mannpower powerups
-- fires projectiles with mannpower conds attached

local PARTICLE_PREFIX = "powerup_icon_"
-- local MANNPOWERS = {
-- 	"agility", "haste", "king", "plague", "regen", "resistance", "precision", "knockout"
-- }
local MANNPOWERS = {
	"agility", "haste", "crit", "regen", "king"
}

local MANNPOWER_CYCLE = {
	"haste", "crit", "regen"
}
local MANNPOWER_EFFECT_BEGIN = {
	agility = function(activator)
		activator:SetAttributeValue("CARD: move speed bonus", 2)
	end,
	haste = function(activator)
		activator:SetAttributeValue("Reload time decreased", 0.4)
		activator:SetAttributeValue("fire rate bonus HIDDEN", 0.1)
	end,
	regen = function(activator)
		activator:SetAttributeValue("Reload time decreased", -0.8)
	end,
	crit = function(activator)
		activator:AddCond(TF_COND_CRITBOOSTED_CTF_CAPTURE)
	end,
	king = function(activator)
		activator:SetAttributeValue("Reload time decreased", 0.6)
		-- activator:SetAttributeValue("fire rate bonus HIDDEN", 0.15)
		activator:AddCond(TF_COND_CRITBOOSTED_CTF_CAPTURE)
	end,
	-- precision = function(activator)
	-- 	activator:SetAttributeValue("projectile spread angle penalty", -100)
	-- 	activator:SetAttributeValue("Projectile speed increased", 1.5)
	-- end,
}
local MANNPOWER_EFFECT_END = {
	agility = function(activator)
		activator:SetAttributeValue("CARD: move speed bonus", nil)
	end,
	haste = function(activator)
		activator:SetAttributeValue("Reload time decreased", nil)
		activator:SetAttributeValue("fire rate bonus HIDDEN", nil)
	end,
	regen = function(activator)
		activator:SetAttributeValue("Reload time decreased", nil)
	end,
	crit = function(activator)
		activator:RemoveCond(TF_COND_CRITBOOSTED_CTF_CAPTURE)
	end,
	king = function(activator)
		activator:SetAttributeValue("Reload time decreased", nil)
		activator:SetAttributeValue("fire rate bonus HIDDEN", nil)
		activator:RemoveCond(TF_COND_CRITBOOSTED_CTF_CAPTURE)
	end,
	-- precision = function(activator)
	-- 	activator:SetAttributeValue("projectile spread angle penalty", nil)
	-- 	activator:SetAttributeValue("Projectile speed increased", nil)
	-- end,
}

local KINGPHASE_THRESHOLD = 20000

function MajorMannpower(_, activator)
	local particles = {}
	for _, name in pairs(MANNPOWERS) do
		-- local particle = ents.CreateWithKeys("info_particle_system", {
		-- 	effect_name = PARTICLE_PREFIX..name.."_blue",
		-- 	start_active = 0,
		-- 	flag_as_weather = 0,
		-- }, true, true)
		local particle = ents.CreateWithKeys("prop_dynamic", {
			model = "models/pickups/pickup_powerup_"..name..".mdl",
			ModelScale = 0.9,
			skin = 2,
			DefaultAnim = "spin",
			rendermode = 1,

			["$positiononly"] = 1,
		}, true, true)

		particle:Alpha(225)
		particle["$attachment"] = "eyes" -- I don't think this works
		particle["$fakeparentoffset"] = Vector(0, 0, 135)
		particle:SetFakeParent(activator)
		particle:Disable()

		particles[name] = particle
	end

	local function setPowerupIcon(name)
		for pName, particle in pairs(particles) do
			particle:Disable()
			if MANNPOWER_EFFECT_END[pName] then
				MANNPOWER_EFFECT_END[pName](activator)
			end
		end

		particles[name]:Enable()
	end

	local function setPowerup(name)
		setPowerupIcon(name)
		MANNPOWER_EFFECT_BEGIN[name](activator)
	end

	setPowerup("agility")

	local nextCycle = CurTime() + 12
	local phase2 = false

	local logic
	logic = timer.Create(0.1, function()
		if not activator:IsAlive() then
			timer.Stop(logic)
			for _, particle in pairs(particles) do
				particle:Remove()
			end
			return
		end

		if phase2 then
			return
		end

		if activator.m_iHealth <= KINGPHASE_THRESHOLD then
			phase2 = true
			setPowerup("king")
			return
		end

		if CurTime() < nextCycle then
			return
		end

		setPowerup(MANNPOWER_CYCLE[math.random(#MANNPOWER_CYCLE)])
		nextCycle = CurTime() + 5
	end, 0)
end

-- class umbras

local function findFirstPlayerOfClass(classIndex)
	for _, player in pairs(ents.GetAllPlayers()) do
		if player.m_iClass == classIndex then
			return player
		end
	end
end

-- soldier umbra - rocket specialist
function SoldierUmbra(_, activator)
	
end
