-- Colonel Dronemann
-- 2 drones on each side of him that can be destroyed, has the wrangler out
function ColDronemanSpawn(_, activator)
    local bulletWeapons = {
        -- [1] = "Upgradeable TF_WEAPON_ROCKETLAUNCHER",
        [1] = "MARKER",
        [2] = "Upgradeable TF_WEAPON_GRENADELAUNCHER"
    }
    local firerateMult = {
        [1] = 3,
        [2] = 2.5
    }

    for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
        if wearable.m_hOwnerEntity == activator then
            wearable.m_flModelScale = 1.25
        end
    end

    local dronesDeadCount = 0

    local dronePrefix = "drone"..tostring(activator:GetHandleIndex())
    for i = 1, 2 do
        local drone = ents.CreateWithKeys("obj_sentrygun", {
            teamnum = activator.m_iTeamNum,
            defaultupgrade = 0,
			SolidToPlayer = 0,
			spawnflags = 8, -- inf ammo
            skin = 3,

            ["$sentrymodelprefix"] = "models/rcat/rcat_level2.mdl",
            ["$attributeoverride"] = 1,
            ["$fireratemult"] = firerateMult[i],
            ["$damagemult"] = 0.5,
            ["$rangemult"] = 3,
            ["$bulletweapon"] = bulletWeapons[i]
        })

        -- timer.Simple(0.1, function ()
        --     drone:SetModelOverride("models/rcat/rcat_level2.mdl")
        -- end)
        drone:SetName(dronePrefix..tostring(drone:GetHandleIndex()))
        -- drone:SetOwner(activator)
        drone:SetHealth(2500)

        local offsetMult = i == 1 and 1 or -1
        local offset = Vector(0, 75 * offsetMult, 100)

		drone["$fakeparentoffset"] = offset
        drone:SetFakeParent(activator)

        -- drone:AddCallback(ON_SHOULD_COLLIDE, function(_, other)
        --     if other.m_iTeamNum == activator.m_iTeamNum then
        --         return false
        --     end
        -- end)

        -- go straight to phase 2 if both drones are destroyed prematurely
        drone:AddCallback(ON_REMOVE, function ()
            dronesDeadCount = dronesDeadCount + 1

            if dronesDeadCount >= 2 then
                ColDronemanEngaged(_, activator, true)
            end
        end)
    end
end

local function getDrones(activator)
    local dronePrefix = "drone"..tostring(activator:GetHandleIndex())

    return ents.FindAllByName(dronePrefix.."*")
end

local function removeAllDrones(activator)
    for _, drone in pairs(getDrones(activator)) do
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
        drone["$fireratemult"] = 4
        drone["$bulletweapon"] = "STICKYBOMB_DRONE"
        -- drone["$fireratemult"] = 5
        -- drone["$bulletweapon"] = "HOMING_ROCKETLAUNCHER_DRONE"
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
end

-- Sergeant Rocketmann
function RocketmanSpawn(_, activator)
    for _, wearable in pairs(ents.FindAllByClass("tf_wearable")) do
        if wearable.m_hOwnerEntity == activator then
            wearable.m_flModelScale = 1.5
        end
    end
end

function RocketmanDeath()
    
end