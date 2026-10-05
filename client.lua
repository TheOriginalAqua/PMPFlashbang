local effectsRunning = false
local audioSceneOn   = false

local stun = {
    level = 0.0, deaf = 0.0,
    blindUntil = 0, deafUntil = 0, disUntil = 0, moveLockUntil = 0,
}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function norm(v)
    local l = #v
    if l < 0.0001 then return vector3(0.0, 0.0, 0.0) end
    return v / l
end

local function camForward()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

local function loadPtfx(a)
    RequestNamedPtfxAsset(a)
    local t = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(a) and GetGameTimer() < t do Wait(0) end
    return HasNamedPtfxAssetLoaded(a)
end

local function notify(text)
    text = tostring(text):gsub('~%a~', '')
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end

CreateThread(function()
    RequestAnimDict(Config.QuickThrowAnim.dict)
    RequestModel(Config.Model)
    while not HasModelLoaded(Config.Model) do
        Wait(100)
        RequestModel(Config.Model)
    end
end)

local handProp  = 0
local hideUntil = 0

local function removeHandProp()
    if handProp ~= 0 and DoesEntityExist(handProp) then DeleteEntity(handProp) end
    handProp = 0
end

local function hideHandProp(ms)
    hideUntil = GetGameTimer() + ms
    removeHandProp()
end

CreateThread(function()
    while true do
        local sleep = 300
        local ped = PlayerPedId()

        if Config.HandProp then
            local _, current = GetCurrentPedWeapon(ped, true)
            local holding = current == Config.Weapon
                and GetAmmoInPedWeapon(ped, Config.Weapon) > 0
                and not IsEntityDead(ped)
                and not IsPedInAnyVehicle(ped, false)
                and GetGameTimer() >= hideUntil

            if holding then
                sleep = 100
                local wep = GetCurrentPedWeaponEntityIndex(ped)
                if wep ~= 0 then SetEntityVisible(wep, false, false) end

                if (handProp == 0 or not DoesEntityExist(handProp)) and HasModelLoaded(Config.Model) then
                    local c = GetEntityCoords(ped)
                    handProp = CreateObject(Config.Model, c.x, c.y, c.z, true, true, false)
                    SetEntityCollision(handProp, false, false)
                    local o, r = Config.HandPropOffset, Config.HandPropRot
                    AttachEntityToEntity(handProp, ped, GetPedBoneIndex(ped, Config.HandBone),
                        o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true)
                end
            else
                removeHandProp()
            end
        end

        Wait(sleep)
    end
end)

local quickThrow = false
local scrubUntil = 0

local function launch()
    local ped = PlayerPedId()
    local model = Config.Model
    if not HasModelLoaded(model) then RequestModel(model) return end

    local off  = Config.HandOffset
    local hand = GetPedBoneCoords(ped, 57005, off.x, off.y, off.z)
    local fwd  = camForward()

    local obj = CreateObject(model, hand.x, hand.y, hand.z, true, true, false)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityNoCollisionEntity(obj, ped, false)
    ActivatePhysics(obj)

    local vel = fwd * Config.ThrowSpeed + vector3(0.0, 0.0, Config.ThrowSpeed * Config.ThrowArc)
    SetEntityVelocity(obj, vel.x, vel.y, vel.z)
    ApplyForceToEntity(obj, 1, 0.0, 0.0, Config.SpinForce, 0.0, 0.08, 0.0, 0, true, true, true, false, true)

    local netId = ObjToNet(obj)
    SetNetworkIdCanMigrate(netId, false)

    CreateThread(function()
        Wait(Config.FuseTime)
        if DoesEntityExist(obj) then
            TriggerServerEvent('flashbang:detonate', netId, GetEntityCoords(obj))
        end
    end)
end

CreateThread(function()
    local lastAmmo   = -1

    while true do
        local sleep = 300
        local ped   = PlayerPedId()

        if HasPedGotWeapon(ped, Config.Weapon, false) then
            sleep = 0
            local ammo = GetAmmoInPedWeapon(ped, Config.Weapon)

            if lastAmmo >= 0 and ammo < lastAmmo and not quickThrow then
                RemoveAllProjectilesOfType(Config.Weapon, false)
                scrubUntil = GetGameTimer() + 2000
                hideHandProp(900)
                TriggerServerEvent('flashbang:thrown')
                launch()
            end
            lastAmmo = ammo
        else
            lastAmmo = -1
        end

        if GetGameTimer() < scrubUntil then
            sleep = 0
            RemoveAllProjectilesOfType(Config.Weapon, false)
        end

        Wait(sleep)
    end
end)

local function quickThrowFlashbang()
    local ped = PlayerPedId()
    if quickThrow then return end
    if IsEntityDead(ped) or IsPedRagdoll(ped) then return end
    if not HasPedGotWeapon(ped, Config.Weapon, false) then return end

    local _, current = GetCurrentPedWeapon(ped, true)
    if current == Config.Weapon or not IsPedArmed(ped, 4) then return end

    local ammo = GetAmmoInPedWeapon(ped, Config.Weapon)
    if ammo < 1 then
        notify('No flashbangs left')
        return
    end

    quickThrow = true
    local a = Config.QuickThrowAnim
    scrubUntil = GetGameTimer() + a.total + 2500
    SetPedAmmo(ped, Config.Weapon, ammo - 1)
    TriggerServerEvent('flashbang:thrown')

    CreateThread(function()
        RequestAnimDict(a.dict)
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(0) end

        if HasAnimDictLoaded(a.dict) then
            TaskPlayAnim(ped, a.dict, a.clip, 1000.0, -8.0, a.total, 51, 0.0, false, false, false)
        end

        Wait(a.release)
        hideHandProp(900)
        launch()

        Wait(Config.QuickThrowCooldown)
        SetPedAmmo(ped, Config.Weapon, ammo - 1)
        quickThrow = false
    end)
end

CreateThread(function()
    local holdStart, forcing = 0, false

    while true do
        local sleep = 300
        local ped = PlayerPedId()
        local _, current = GetCurrentPedWeapon(ped, true)

        if current == Config.Weapon then
            sleep = 0
            local now = GetGameTimer()

            if forcing then
                DisableControlAction(0, 24, true)
                if not IsDisabledControlPressed(0, 24) then
                    forcing, holdStart = false, 0
                end
            elseif IsControlPressed(0, 24) then
                if holdStart == 0 then holdStart = now end
                if now - holdStart >= Config.MaxCookTime then
                    forcing = true
                    DisableControlAction(0, 24, true)
                end
            else
                holdStart = 0
            end
        else
            holdStart, forcing = 0, false
        end

        Wait(sleep)
    end
end)

RegisterCommand('+flashbang_quick', quickThrowFlashbang, false)
RegisterCommand('-flashbang_quick', function() end, false)
RegisterKeyMapping('+flashbang_quick', 'Quick throw flashbang', 'keyboard', Config.QuickThrowKey)

RegisterNetEvent('flashbang:give', function(amount, total)
    local ped = PlayerPedId()
    if HasPedGotWeapon(ped, Config.Weapon, false) then
        AddAmmoToPed(ped, Config.Weapon, amount)
    else
        GiveWeaponToPed(ped, Config.Weapon, amount, false, false)
    end
    SetPedAmmo(ped, Config.Weapon, math.min(total or amount, Config.MaxAmmo))
end)

RegisterNetEvent('flashbang:notify', notify)

local DISABLED = { 21, 22, 23, 24, 25, 37, 44, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264, 69, 70, 92, 114 }

local function setDeaf(on)
    if on and not audioSceneOn then
        StartAudioScene('CHARACTER_CHANGE_IN_SKY_SCENE')
        audioSceneOn = true
        Config.OnDeafen(true)
    elseif not on and audioSceneOn then
        StopAudioScene('CHARACTER_CHANGE_IN_SKY_SCENE')
        audioSceneOn = false
        Config.OnDeafen(false)
    end
end

local function cleanup()
    local ped = PlayerPedId()
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    ResetPedMovementClipset(ped, 1.0)
    setDeaf(false)
    stun.level, stun.deaf = 0.0, 0.0
    SendNUIMessage({ type = 'reset' })
end

local function startEffects()
    if effectsRunning then return end
    effectsRunning = true

    CreateThread(function()
        RequestAnimSet(Config.DisorientClipset)
        local clipsetApplied, disActive = false, false

        while true do
            local now = GetGameTimer()
            if now > stun.disUntil and now > stun.deafUntil and now > stun.blindUntil then break end
            local ped = PlayerPedId()

            local dis = clamp((stun.disUntil - now) / 6000, 0.0, 1.0) * stun.level
            if dis > 0.0 then
                if not disActive then
                    SetTimecycleModifier('hud_def_blur')
                    disActive = true
                end
                for i = 1, #DISABLED do DisableControlAction(0, DISABLED[i], true) end
                DisablePlayerFiring(PlayerId(), true)

                SetTimecycleModifierStrength(clamp(dis * 1.2, 0.0, 1.0))
                if not IsGameplayCamShaking() then ShakeGameplayCam('DRUNK_SHAKE', 1.0) end
                SetGameplayCamShakeAmplitude((0.32 + dis * 1.55) * Config.ShakeScale)

                if not clipsetApplied and HasAnimSetLoaded(Config.DisorientClipset) then
                    SetPedMovementClipset(ped, Config.DisorientClipset, 1.0)
                    clipsetApplied = true
                end

                if not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped) then
                    if math.random() < Config.StumbleChance * dis then
                        SetPedToRagdoll(ped, 900, 1400, 3, false, false, false)
                    elseif dis > 0.5 and math.random() < 0.01 then
                        stun.moveLockUntil = now + math.random(250, 700)
                    end
                end
                if now < stun.moveLockUntil then
                    DisableControlAction(0, 30, true)
                    DisableControlAction(0, 31, true)
                end

                if IsPedInAnyVehicle(ped, false) and math.random() < 0.3 * dis then
                    DisableControlAction(0, 71, true)
                    DisableControlAction(0, 59, true)
                end
            elseif disActive then
                ResetPedMovementClipset(ped, 1.0)
                ClearTimecycleModifier()
                StopGameplayCamShaking(true)
                clipsetApplied, disActive = false, false
            end

            if now >= stun.deafUntil then setDeaf(false) end
            Wait(0)
        end

        cleanup()
        effectsRunning = false
    end)
end

local function bangVisuals(pos)
    CreateThread(function()
        local untilT = GetGameTimer() + 70
        while GetGameTimer() < untilT do
            DrawLightWithRange(pos.x, pos.y, pos.z + 0.3, 255, 250, 235, 30.0, 80.0)
            Wait(0)
        end
    end)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.35, false, false, false)
end

local function exposure(pos, ped)
    local head  = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local chest = GetPedBoneCoords(ped, 24818, 0.0, 0.0, 0.0)
    local feet  = GetEntityCoords(ped) - vector3(0.0, 0.0, 0.9)
    local open, n = 0, 0
    local flags = 1 + 2 + 8 + 16
    for _, target in ipairs({ head, chest, feet }) do
        local ray = StartExpensiveSynchronousShapeTestLosProbe(pos.x, pos.y, pos.z + 0.15,
            target.x, target.y, target.z, flags, ped, 4)
        local _, hit = GetShapeTestResult(ray)
        if not (hit == true or hit == 1) then open = open + 1 end
        n = n + 1
    end
    return open / n, head
end

local function applyBangToPlayer(pos)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    local los, head = exposure(pos, ped)
    local dist = #(head - pos)
    if dist > Config.AudioRadius then return end

    local losFlash, losAudio
    if los <= 0.0 then
        losFlash, losAudio = Config.OcclusionFlash, Config.OcclusionAudio
    elseif los >= 0.999 then
        losFlash, losAudio = 1.0, 1.0
    else
        losFlash = Config.OcclusionFlash + (Config.PartialCover - Config.OcclusionFlash) * los
        losAudio = Config.OcclusionAudio + (1.0 - Config.OcclusionAudio) * (Config.PartialCover + los * 0.5)
    end

    local camPos = GetGameplayCamCoord()
    local fwd = camForward()
    local toBang = norm(pos - camPos)
    local dot = fwd.x * toBang.x + fwd.y * toBang.y + fwd.z * toBang.z
    local facing = Config.BackTurnedFlash + (1.0 - Config.BackTurnedFlash) * clamp((dot + 0.2) / 1.2, 0.0, 1.0)

    local distF
    if dist <= Config.FullEffectRadius then
        distF = 1.0
    else
        local t = (dist - Config.FullEffectRadius) / (Config.FlashRadius - Config.FullEffectRadius)
        distF = clamp(1.0 - t, 0.0, 1.0) ^ Config.FlashFalloff
    end
    local flash = distF * facing * losFlash

    local audio = (clamp(1.0 - dist / Config.AudioRadius, 0.0, 1.0) ^ Config.AudioFalloff) * losAudio
    local myInt = GetInteriorFromEntity(ped)
    if myInt ~= 0 and GetInteriorAtCoords(pos.x, pos.y, pos.z) == myInt then audio = audio * Config.IndoorAudioBoost end
    audio = clamp(audio, 0.0, 1.0)

    local right = norm(vector3(fwd.y, -fwd.x, 0.0))
    local flat  = norm(vector3(toBang.x, toBang.y, 0.0))
    local pan = clamp(flat.x * right.x + flat.y * right.y, -1.0, 1.0)

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)

    SendNUIMessage({
        type = 'bang',
        onScreen = onScreen == true or onScreen == 1,
        sx = sx, sy = sy,
        flash = flash, audio = audio, pan = pan,
        deaf = stun.deaf,
        dist = dist / Config.AudioRadius,
        occluded = los <= 0.0,
        hold = Config.BlindHold * flash, fade = Config.BlindFade * flash,
        deafMs = Config.DeafTime * audio,
        volume = Config.MasterVolume,
        tin = Config.TinnitusLevel,
    })

    local exposureLevel = math.max(flash, audio * 0.8)
    if exposureLevel < Config.MinExposure then return end

    local now = GetGameTimer()
    ShakeGameplayCam(dist < 6.0 and 'LARGE_EXPLOSION_SHAKE' or 'SMALL_EXPLOSION_SHAKE', (0.12 + audio * 0.40) * Config.ShakeScale)

    stun.blindUntil = math.max(stun.blindUntil, now + math.floor((Config.BlindHold + Config.BlindFade) * flash))
    if audio > 0.3 then
        stun.deaf = math.max(stun.deaf, audio)
        stun.deafUntil = math.max(stun.deafUntil, now + math.floor(Config.DeafTime * audio))
        setDeaf(true)
    end
    stun.level = clamp(stun.level + exposureLevel * 0.28, 0.0, 1.0)
    stun.disUntil = math.max(stun.disUntil, now + math.floor(Config.DisorientTime * stun.level))

    if dist < Config.RagdollRadius and los > 0.0 and not IsPedInAnyVehicle(ped, false)
       and not IsPedRagdoll(ped) then
        local chance
        if dist <= Config.RagdollAlways then
            chance = 1.0
        else
            local t = (dist - Config.RagdollAlways) / (Config.RagdollRadius - Config.RagdollAlways)
            chance = Config.RagdollChanceFar + (1.0 - Config.RagdollChanceFar) * ((1.0 - t) ^ Config.RagdollCurve)
        end
        chance = chance * clamp(exposureLevel + 0.2, 0.0, 1.0)
        if math.random() < chance then
            local span = math.floor(1200 + 1800 * (1.0 - clamp(dist / Config.RagdollRadius, 0.0, 1.0)))
            SetPedToRagdoll(ped, span, span + 800, 0, false, false, false)
        end
    end

    startEffects()
end

local function affectNPCs(pos)
    if not Config.AffectNPCs then return end
    for _, npc in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(npc) and NetworkHasControlOfEntity(npc) and not IsEntityDead(npc) then
            local d = #(GetEntityCoords(npc) - pos)
            if d < Config.RagdollRadius * 1.5 then
                SetPedToRagdoll(npc, 3000, 5000, 0, false, false, false)
            elseif d < Config.FlashRadius * 0.6 then
                ClearPedTasks(npc)
                TaskCower(npc, 8000)
            end
        end
    end
end

RegisterNetEvent('flashbang:sequence', function(owner, netId, origin, pattern)
    if #(GetEntityCoords(PlayerPedId()) - origin) > Config.AudioRadius + 40.0 then return end

    local isOwner = GetPlayerServerId(PlayerId()) == owner
    loadPtfx('core')
    local start = GetGameTimer()

    for i, offset in ipairs(pattern) do
        while GetGameTimer() - start < offset do Wait(0) end

        local pos = origin
        local obj = NetworkDoesNetworkIdExist(netId) and NetToObj(netId) or 0
        if obj ~= 0 and DoesEntityExist(obj) then pos = GetEntityCoords(obj) end

        bangVisuals(pos)
        applyBangToPlayer(pos)
        if i == 1 or i == 5 then affectNPCs(pos) end

        if isOwner and obj ~= 0 and DoesEntityExist(obj) then
            local h = Config.HopForce
            ApplyForceToEntity(obj, 1, (math.random() - 0.5) * h, (math.random() - 0.5) * h, h * (0.6 + math.random() * 0.6),
                (math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1, 0.0, 0, false, true, true, false, true)
        end
    end

    local obj = NetworkDoesNetworkIdExist(netId) and NetToObj(netId) or 0
    local pos = (obj ~= 0 and DoesEntityExist(obj)) and GetEntityCoords(obj) or origin

    UseParticleFxAssetNextCall('core')
    local smoke
    if obj ~= 0 and DoesEntityExist(obj) then
        smoke = StartParticleFxLoopedOnEntity(Config.SmokeEffect, obj, 0.0, 0.0, 0.05,
            0.0, 0.0, 0.0, Config.SmokeScale, false, false, false)
    else
        smoke = StartParticleFxLoopedAtCoord(Config.SmokeEffect, pos.x, pos.y, pos.z + 0.05,
            0.0, 0.0, 0.0, Config.SmokeScale, false, false, false, false)
    end

    if smoke and smoke ~= 0 then
        SetParticleFxLoopedAlpha(smoke, Config.SmokeAlpha)
        Wait(Config.SmokeTime)
        StopParticleFxLooped(smoke, false)
        return
    end

    local smokeUntil = GetGameTimer() + Config.SmokeTime
    while GetGameTimer() < smokeUntil do
        obj = NetworkDoesNetworkIdExist(netId) and NetToObj(netId) or 0
        if obj ~= 0 and DoesEntityExist(obj) then pos = GetEntityCoords(obj) end
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', pos.x, pos.y, pos.z + 0.05,
            0.0, 0.0, 0.0, 0.3, false, false, false)
        Wait(Config.SmokeInterval)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        removeHandProp()
        cleanup()
    end
end)