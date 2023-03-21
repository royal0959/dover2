-- Colonel Droneman
-- 2 drones on each side of him that can be destroyed, has the wrangler out
function ColDronemanSpawn(_, activator)
    local bulletWeapons = {
        [1] = "Upgradeable TF_WEAPON_ROCKETLAUNCHER",
        [2] = "Upgradeable TF_WEAPON_GRENADELAUNCHER"
    }
    local firerateMult = {
        [1] = 4,
        [2] = 3.5
    }
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
            ["$bulletweapon"] = bulletWeapons[i]
        })

        -- timer.Simple(0.1, function ()
        --     drone:SetModelOverride("models/rcat/rcat_level2.mdl")
        -- end)
        drone:SetOwner(activator)
        drone:SetHealth(2500)

        local offsetMult = i == 1 and 1 or -1
        local offset = Vector(0, 50 * offsetMult, 100)

		drone["$fakeparentoffset"] = offset
        drone:SetFakeParent(activator)

        drone:AddCallback(ON_SHOULD_COLLIDE, function(_, other)
            if other.m_iTeamNum == activator.m_iTeamNum then
                return false
            end
        end)
    end
end