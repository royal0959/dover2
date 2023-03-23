
-- pair/totem bots
-- tag format: pair_<PAIR GROUP NAME>_[carrier/carried]
local BASE_HEIGHT = 80

local waiting = {
    Carriers = {},
    Carried = {},
}

function OnWaveSpawnBot(bot, wave, tags)
    _OnWaveSpawnBot_CustomWeapon(bot, wave ,tags)
    _OnWaveSpawnBot_BossResistance(bot, wave ,tags)

    for _, tag in pairs(tags) do
        local split = {}

        for k, _ in string.gmatch(tag, '([^_]+)') do
            table.insert(split, k)
        end

        if split[1]:lower() == "pair" then
            local pairName = split[2]
            local pairPlacement = split[3]:lower()

            local waitTable
            local otherWaitTable

            if pairPlacement == "carried" then
                waitTable = waiting.Carried
                otherWaitTable = waiting.Carriers

                bot:SetAttributeValue("no_attack", 1)
                bot:AddCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
            elseif pairPlacement == "carrier" then
                waitTable = waiting.Carriers
                otherWaitTable = waiting.Carried
            else
                print("invalid carrier placement tag")
            end

            if not waitTable[pairName] then
                waitTable[pairName] = {}
            end

            table.insert(waitTable[pairName], bot)
            if otherWaitTable[pairName] and otherWaitTable[pairName][1] then
                PairBots(waiting.Carriers[pairName][1], waiting.Carried[pairName][1])

                waiting.Carriers[pairName] = nil
                waiting.Carried[pairName] = nil
            end
        end
    end
end

function OnWaveInit()
    waiting = {
        Carriers = {},
        Carried = {},
    }
end

function PairBots(carrier, carried)
	local height = BASE_HEIGHT * (carrier.m_flModelScale)

	local carrierCallbacks = {}
	local carrierTimer

	local lastOrigin
	local function teleport()
		if not IsValid(carrier) then
			if not lastOrigin then
				return
			end

			-- prevents carried briefly disappearing after carrier death
			carried:SetAbsOrigin(lastOrigin + Vector(0, 0, height))

			return
		end

		local origin = carrier:GetAbsOrigin()
		carried:SetAbsOrigin(origin + Vector(0, 0, height))

		lastOrigin = origin
	end

	carrierTimer = timer.Create(0, function()
		teleport()
	end, 0)

	teleport()

    local function endPairLogic()
        for _, id in pairs(carrierCallbacks) do
            carrier:RemoveCallback(id)
        end
        timer.Stop(carrierTimer)
    end

	carrierCallbacks.died = carrier:AddCallback(ON_DEATH, function()
		carried:RemoveCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
		timer.Simple(2, function ()
			carried:SetAttributeValue("no_attack", nil)
		end)

		-- carried:ClearFakeParent()
		endPairLogic()

		if not lastOrigin then
			return
		end

		-- suspend in place to prevent source jank from teleporting it back to spawn
		local iterated = 1
		for _ = 0, 1, 0.1 do
			timer.Simple(0.07 * iterated, function()
				carried:SetAbsOrigin(lastOrigin)
			end)

			iterated = iterated + 1
		end
	end)
	carrierCallbacks.spawn = carrier:AddCallback(ON_SPAWN, function()
		endPairLogic()
	end)
end