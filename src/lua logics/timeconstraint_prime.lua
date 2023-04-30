local TIMECONSTRAINT_WAVE = 6

local wavebarLogic

local randomIcons = {
    "scout", "soldier", "heavy", "demo", "pyro", "soldier_spammer", "spy", "soldier_blackbox", "medic_giant", "timer_lite",
    "helicopter_blue_nys", "soldier_barrage", "heavy_chief", "demoknight_giant", "soldier_sergeant_crits", "demo_bomber", "heavy_shotgun"
}

local inWave = false
local curWave = nil

local function chatMessage(message)
    local outputMessage = "{blue}"
	.. "Time-Constraint Prime"
	.. "{reset}: ".. message

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		player:AcceptInput("$DisplayTextChat", outputMessage)
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

function _TimeConstraintOnWaveInit(wave)
    inWave = false
    curWave = wave

    resetWavebar()

    if wave ~= TIMECONSTRAINT_WAVE then
        return
    end

    -- resetWavebar()

    local objResource = ents.FindByClass("tf_objective_resource")

    timer.Simple(1, function ()
        if inWave then
            return
        end

        if curWave ~= TIMECONSTRAINT_WAVE then
            return
        end

        chatMessage("I await")

        wavebarLogic = timer.Create(0.5, function ()
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

    -- resetWavebar()
end