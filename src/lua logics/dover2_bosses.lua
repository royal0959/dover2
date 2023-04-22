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
                if player:IsAlive() and player.m_iTeamNum ~= activator.m_iTeamNum then
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
-- scaled down to small size when near deathr
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

	local logic
	logic = timer.Create(0.1, function()
		if not activator:IsAlive() then
			timer.Stop(logic)
			return
		end

		-- if growing then
		-- 	return
		-- end

		local health = activator.m_iHealth

		if health == lastHealth then
			return
		end

		local height = BASE_HEIGHT * (activator.m_flModelScale)

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

		lastHealth = health
		-- grow(PHASES[goalPhase].Scale)
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
