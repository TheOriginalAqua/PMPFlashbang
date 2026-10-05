Config = {}

Config.Model = `w_ex_grenadefrag`

Config.HandProp       = true
Config.HandBone       = 57005
Config.HandPropOffset = vector3(0.11, 0.01, -0.03)
Config.HandPropRot    = vector3(-90.0, 0.0, 0.0)

Config.Weapon      = `WEAPON_GRENADE`
Config.GiveCommand = 'flashbang'
Config.DefaultAmmo = 5
Config.MaxAmmo     = 25

Config.ServerAmmoCheck  = true
Config.MaxThrowDistance = 40.0

Config.QuickThrowKey      = 'X'
Config.QuickThrowCooldown = 1200
Config.MaxCookTime        = 2500
Config.QuickThrowAnim     = { dict = 'weapons@projectile@aim_throw_rifle', clip = 'aim_throw_m', release = 400, total = 700 }

Config.ThrowSpeed = 18.0
Config.ThrowArc   = 0.24
Config.SpinForce  = 0.06
Config.HandOffset = vector3(0.05, 0.0, 0.0)

Config.FuseTime       = 1800
Config.Bangs          = 9
Config.BangInterval   = { min = 120, max = 380 }
Config.CasingLifetime = 30 * 60 * 1000
Config.MaxCasings     = 30
Config.HopForce       = 1.1

Config.SmokeEffect   = 'exp_grd_bzgas_smoke'
Config.SmokeTime     = 1000
Config.SmokeInterval = 500
Config.SmokeScale    = 0.1
Config.SmokeAlpha    = 0.3

Config.FullEffectRadius = 4.0
Config.FlashRadius      = 18.0
Config.AudioRadius      = 55.0
Config.RagdollRadius    = 7.0
Config.RagdollAlways    = 2.5
Config.RagdollChanceFar = 0.12
Config.RagdollCurve     = 1.6
Config.FlashFalloff     = 2.2
Config.AudioFalloff     = 2.0
Config.BackTurnedFlash  = 0.25
Config.IndoorAudioBoost = 1.35

Config.OcclusionFlash = 0.0
Config.OcclusionAudio = 0.18
Config.PartialCover   = 0.45
Config.MinExposure    = 0.18

Config.BlindHold        = 1800
Config.BlindFade        = 5000
Config.DeafTime         = 8000
Config.DisorientTime    = 16000
Config.StumbleChance    = 0.004
Config.MasterVolume     = 0.55
Config.TinnitusLevel    = 0.35
Config.ShakeScale       = 0.72
Config.DisorientClipset = 'move_m@drunk@verydrunk'

Config.AffectNPCs = true

Config.OnDeafen = function(isDeaf)
end