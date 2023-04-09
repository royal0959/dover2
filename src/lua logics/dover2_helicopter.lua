local MAX_OFFSET = 200
local MAIN_WEAPON_COOLDOWN = 1
local STICKIES_COOLDOWN = 5

local STICKIES_PER_SHOT = 15
local DETONATE_DELAY = 3

local function lerp(a,b,t)
    return a * (1-t) + b * t
end

local function traceBetween(origin, target)
	local DefaultTraceInfo = {
		start = origin,
		endpos = target,
		mask = MASK_ALL,
		collisiongroup = COLLISION_GROUP_DEBRIS,
	}
	local trace = util.Trace(DefaultTraceInfo)

	return trace.Hit, trace.HitPos
end

function HelicopterBot(_, activator)
    local nextWeaponFire = 0
    local nextStickyFire = 0
    local nextDetonate = 0

    local redFilter = ents.CreateWithKeys("filter_activator_tfteam", {
        Negated = 0,
        TeamNum = 2,
    })

    local helicopterBaseBoss = ents.CreateWithKeys("base_boss", {
        teamnum = activator.m_iTeamNum,
        model = "models/props_frontline/helicopter_windows.mdl",
        skin = 1,
    })

    helicopterBaseBoss:AddCallback(ON_DAMAGE_RECEIVED_POST, function(_, damageInfo)
        activator.m_iHealth = helicopterBaseBoss.m_iHealth
    end)

    helicopterBaseBoss:AddCallback(ON_REMOVE, function()
        activator:Suicide()
    end)

    helicopterBaseBoss:SetCollisionFilter(redFilter)

    helicopterBaseBoss.effects = 32 -- no draw

    local maxHealth = activator.m_iHealth
    helicopterBaseBoss:SetMaxHealth(maxHealth)
    helicopterBaseBoss:SetHealth(maxHealth)
    helicopterBaseBoss:SetSpeed(0)
    helicopterBaseBoss:Disable()

    local collideCallback
    collideCallback = activator:AddCallback(ON_SHOULD_COLLIDE, function (_, other)
        return false
    end)

    local helicopterModel = ents.CreateWithKeys("prop_dynamic", {
        model = "models/props_frontline/helicopter_windows.mdl",
		DefaultAnim = "fly_idle",
        solid = 0,
        skin = 1,

        ["$positiononly"] = 1,
        ["$modules"] = "rotator",
        ["$rotationspeedx"] = 100,
        ["$rotationspeedy"] = 100,
    }, true, true)


    local rocketMimic = ents.CreateWithKeys("tf_point_weapon_mimic", {
        teamnum = activator.m_iTeamNum,
        ["$preventshootparent"] = 1,
        ["SpeedMax"] = 800,
        ["SpeedMin"] = 800,
        ["SplashRadius"] = 144,
        ["SpreadAngle"] = 0,
        ["WeaponType"] = 0,
		["ModelScale"] = 1,
        ["$positiononly"] = 1,

        damage = 125,
    })

    local stickyMimic = ents.CreateWithKeys("tf_point_weapon_mimic", {
        teamnum = activator.m_iTeamNum,
        ["$preventshootparent"] = 1,
        ["SpeedMax"] = 1000,
        ["SpeedMin"] = 100,
        ["SplashRadius"] = 144,
        ["SpreadAngle"] = 30,
        ["WeaponType"] = 3,
		["ModelScale"] = 1,
		["ModelOverride"] = "models/weapons/w_models/w_stickybomb.mdl",
        ["$positiononly"] = 1,

        damage = 100,
    })

    -- rocketMimic["$SetOwner"](rocketMimic, activator)
    -- stickyMimic["$SetOwner"](stickyMimic, activator)

    helicopterBaseBoss:SetFakeParent(helicopterModel)
    helicopterBaseBoss["$fakeparentoffset"] = Vector(0, 0, 50)
    rocketMimic:SetFakeParent(helicopterModel)
    rocketMimic["$fakeparentoffset"] = Vector(0, 0, 50)
    stickyMimic:SetFakeParent(helicopterModel)
    stickyMimic["$fakeparentoffset"] = Vector(0, 0, 50)

    -- helicopterModel["$fakeparentoffset"] = Vector(0, 0, MAX_OFFSET)
    -- helicopterModel:SetFakeParent(activator)

    local offset = MAX_OFFSET
    local offsetGoal = offset
    local offsetLerp = 1

    local playerTarget

    local logic

    local function stop()
        activator:RemoveCallback(collideCallback)

        timer.Stop(logic)
        if IsValid(helicopterBaseBoss) then
            helicopterBaseBoss:Remove()
        end
        helicopterModel:Remove()
        rocketMimic:Remove()
        stickyMimic:Remove()
    end

    logic = timer.Create(0, function()
        if not activator:IsAlive() then
            stop()
            return
        end

        local lastGoal = offsetGoal

        local activatorOrigin = activator:GetAbsOrigin()

        local traceOffsets =
        {
            Vector(0, 0, 0),
            Vector(5, 0, 0),
            Vector(0, 5, 0),
            Vector(-5, 0, 0),
            Vector(0, -5, 0),
        }

        local didHitObstacle
        for _, traceOffset in pairs(traceOffsets) do
            local origin = activatorOrigin + traceOffset
            local obstacle, obstaclePos = traceBetween(origin, origin + (Vector(0, 0, MAX_OFFSET + 50) + traceOffset))

            if obstacle then
                local obstacleDistance = origin.z - obstaclePos.z
                offsetGoal = MAX_OFFSET + obstacleDistance
                didHitObstacle = true

                break
            end
        end

        if not didHitObstacle then
            offsetGoal = MAX_OFFSET
        end

        -- offsetGoal = math.max(offsetGoal, 80)

        if lastGoal ~= offsetGoal then
            offsetLerp = 0
        end

        offset = lerp(offset, offsetGoal, offsetLerp)

        offsetLerp = math.min(offsetLerp + 0.005, 1)

        local newOrigin = activatorOrigin + Vector(0, 0, offset)
        helicopterModel:SetAbsOrigin(newOrigin)
        -- rocketMimic:SetAbsOrigin(newOrigin)
        -- stickyMimic:SetAbsOrigin(newOrigin)

        local closest = { nil, math.huge }
        for _, player in pairs(ents.GetAllPlayers()) do
            if player:IsAlive() and player.m_iTeamNum ~= activator.m_iTeamNum then
                local distance = newOrigin:Distance(player:GetAbsOrigin())
                local hit = traceBetween(helicopterModel:GetAbsOrigin(), player:GetAbsOrigin())

                if not hit and distance < closest[2] then
                    closest = { player, distance }
                end
            end
        end

        local curTime = CurTime()

        if curTime >= nextDetonate then
            stickyMimic["DetonateStickies"](stickyMimic)
        end

        if not closest[1] then
            return
        end

        rocketMimic:FaceEntity(playerTarget)
        stickyMimic:FaceEntity(playerTarget)

        if curTime >= nextWeaponFire then
            nextWeaponFire = curTime + MAIN_WEAPON_COOLDOWN
            rocketMimic["FireOnce"](rocketMimic)
        end

        if curTime >= nextStickyFire then
            nextStickyFire = curTime + STICKIES_COOLDOWN
            nextDetonate = curTime + DETONATE_DELAY
            stickyMimic["FireMultiple"](stickyMimic, STICKIES_PER_SHOT)
        end

        if playerTarget == closest[1] then
            return
        end

        playerTarget = closest[1]

        helicopterModel:RotateTowards(playerTarget)
    end, 0)
end