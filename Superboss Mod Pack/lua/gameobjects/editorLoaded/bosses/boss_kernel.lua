-- KERNEL, THE POMPOUS BOT UNDER COMMANDER'S INFLUENCE!
local _KERNEL    = BaseObject:subclass ( "KERNEL_BOSS" ):INCLUDE_COMMONS ( )
FSM:addState  ( _KERNEL, "CUTSCENE"             )
Mixins:attach ( _KERNEL, "gravityFreeze"        )
Mixins:attach ( _KERNEL, "spawnFallingBlocks"   )
Mixins:attach ( _KERNEL, "bossTimer"            )

_KERNEL.static.IS_PERSISTENT     = true
_KERNEL.static.SCRIPT            = "dialogue/boss/cutscene_final_3_boss" 
_KERNEL.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-kernel"

_KERNEL.static.EDITOR_DATA = {
  width   = 2,
  height  = 2,
  ox      = -19,
  oy      = -16,
  mx      = 26,
  order   = 9985,
  category = "bosses",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isUnique      = true,
    isTargetable  = true,
  }
}

_KERNEL.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "kernel_boss"   )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.obstacles,   "obstacles"     )
  CutsceneManager.preload   ( _KERNEL.SCRIPT                              )
end

_KERNEL.static.PALETTE             = Colors.Sprites.kernel
_KERNEL.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue, 
  Colors.green_blue, 
  Colors.green_blue, 
  Colors.green_4, 
  Colors.green_4, 
  Colors.green_4
)

_KERNEL.static.DEFEATED_AFTER_IMAGE_PAL = createColorVector (
    Colors.darkest_red_than_kai,
    Colors.hacker_purple_2,
    Colors.hacker_purple_2,
    Colors.hacker_purple_1,
    Colors.hacker_purple_1,
    Colors.hacker_purple_1
)
--[[
Colors.Sprites.commander =
  createColorVector (
    Colors.black,
    Colors.hacker_purple_2,
    Colors.hacker_purple_1,
    Colors.virus_purple_1,
    Colors.kai_yellow,
    Colors.white 
  )
]]

_KERNEL.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_KERNEL.static.DIMENSIONS = {
  x            =   7,
  y            =   6,
  w            =  20,
  h            =  26,
  -- these basically oughto match or be smaller than player
  grabX        =  10,
  grabY        =   6,
  grabW        =  14,
  grabH        =  26,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_KERNEL.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_KERNEL.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
}

_KERNEL.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
}

_KERNEL.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_KERNEL.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_KERNEL.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_KERNEL.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:finalize ( parameters )
  RegisterActor ( ACTOR.KERNEL, self )

  self:translate ( -12, 0 )
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "kernel_boss", 1 )
  self.sprite:addInstance  ( 2 )
  self.sprite:addInstance  ( "shield" )

  self.isFlinchable = false
  self.sprite:change ( 1, "prefight-idle", 1, true )

  self.actionsWithoutRest   = 0
  self.nextActionTime       = 10
  self.desperationActivated = false

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.sensors = {
    PILEDRIVE_CATCH = 
      Sensor
        :new ( self, self.filters.player, -19, -20, 45, 21 )
        :expectOnlyOneItem  ( true ),
        --:disableDraw        ( true ),
    SERIAL_PUNCH = 
      Sensor
        :new ( self, self.filters.player, -19, -25, 43, 26 )
        :expectOnlyOneItem  ( true ),
        --:disableDraw        ( true ),
    SPINNAROO =
      Sensor
        :new ( self, self.filters.player, -31, -26, 41, 35 )
        :expectOnlyOneItem  ( true ),
  }

  self.dunkLayer = Layers:get ( "STATIC-OBJECTS-FRONT" )

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self.slamsInRow = 0

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -1,  0, 36,  36, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil

  if parameters and parameters.bossRush then
    self.sprite:flip ( -1, 1 )
    if parameters.kernelOnly then
      self.state.isBossRushSpawn       = true
      self.state.isBoss                = true
      self.listener                    = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    else
      self.state.isBossRushSpawn       = true
      self.state.isMultiPhaseBossFight = 1
      self.state.isBoss                = true
      self.listener                    = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    end
  elseif parameters and parameters.isTarget then
    self.state.isMultiPhaseBossFight = true
    self.state.isBoss                = true
    self.listener                    = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    --self:gotoState ( "BOSS_CIRCUIT_PICKUP" )

    --[[
    -- do flag stuff at spawn
    local flag = GetFlag ( "cable-boss-prefight-dialogue" ) 
    if not flag then
      self.sprite:change ( 1, nil )
    end
    ]]
    --if not flag  then
    --  self:gotoState      ( "PREFIGHT_INTRO" )
    --end
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end

  --SetStageFlag ( "original-kernel-boss-defeated", 1 )
  if GetStageFlag ( "original-kernel-boss-defeated" ) then
    self.sprite:change ( 1, nil )

    self.IS_PURPLE        = true
    self.burstBossIdToUse = 12

    self.alwaysUsePaletteShader      = true
    self.BASE_PALETTE                = self.class.PALETTE
    self.ACTIVE_PALETTE              = Colors.Sprites.commander
  
    self:setAfterImagesPalette ( self.class.PALETTE, self.class.DEFEATED_AFTER_IMAGE_PAL )
  else
    self.burstBossIdToUse = 11
  end

  -- not hittable until activated
  self.state.isHittable = false


  self.hitParticleLayer = Layer:get ( "PARTICLES" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Misc                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

-- §activate
function _KERNEL:activate ( )
  if self.state.isBossRushSpawn  then
    MapData.BossRush.continueTimer ( )
  end
  SetTempFlag ( "kernel-boss-challenge-hits", 0 )
  GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )

  self.state.isHittable = true
  self.health           = GAMEDATA.boss.getMaxHealth()  
  self.regenTimer       = 60
  self.activated        = true
  self.nextActionTime   = 5
  self.timer            = 0
  self.commanderObj     = GetActor ( ACTOR.COM )
end

function _KERNEL:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end
  if self._emittingSmoke then
    Environment.smokeEmitter ( self, true )
  end
  UnregisterActor ( ACTOR.KERNEL, self )
end

function _KERNEL:isDrawingWithPalette ( )
  return true
end

function _KERNEL:specialEndOfBossBehavior ( )
  GlobalObserver:none      ( "FORCE_UNDIM_BACKGROUNDS" )
  CutsceneManager.CONTINUE ( )
  self:delete              ( )
end

function _KERNEL:cutscene_changeAnimation ( ... )
  self.sprite:change ( ... )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Barrier §shield ----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:activateBarrier ( )
  self.actionsSinceBarrier = 0
  self.commanderObj:giveKernelBarrier ( )
  self:initShield                     ( )
end

function _KERNEL:initShield ( )
  if not self._SHIELD then self._SHIELD = {} end
  local s      = self._SHIELD

  -- init
  s.offset     = {[-1]={x=0,y=0},[1]={x=0,y=0}}
  s.broken     = false
  s.positions  = {}
  s.len        = 0
  s.health     = 5
  s.maxHealth  = 5
  s.x          = 0
  s.y          = 0
  s.timer      = 1

  self.state.useHitDirForShield   = true
  self.state.isShielded           = true
  self.isLaunchedAfterGuardBreak  = true

  self.fakeOverkilledTimer        = nil
  self.state.isHittable           = true
  self.state.isBossInvulnerable   = false
end


function _KERNEL:shieldDamage ( damage, direction, knockbackX, knockbackY, launchingAttack, bouncingFromEnemy )
  if not self._SHIELD then return false end

  self:applyShake ( 2, 0.25, direction )

  self.hitFlash.current = self.hitFlash.max
  self._SHIELD.health   = self._SHIELD.health - damage

  if launchingAttack or bouncingFromEnemy or self._SHIELD.health <= 0  then
    self.actionsSinceBarrier = 0
    self.state.isShielded    = false

    self.sprite:change ( "shield", "barrier-break", 1, true )

    self:spawnBossMidpointRewards ( true )

    local mx, my = self:getMiddlePoint  ( )
    local l      = self.layers.sprite   ( ) + 30

    if self.IS_PURPLE then
      Particles:addSpecial ( "pink_big_punch_sparks", mx, my, l, false )
    else
      Particles:addSpecial ( "big_punch_sparks", mx, my, l, false )
    end

    for i = 1, 8 do
      Particles:addSpecial ( "emit_green_beam", mx, my, l+1, false, true )
    end

    GlobalObserver:say  ( "GUARD_BREAK" )
    Audio:playSound     ( SFX.gameplay_guard_break )

    return true, nil, true--, launchingAttack--true
  else
    return true
  end
end

function _KERNEL:getShieldHealthPercentage ( )
  return self._SHIELD and (self._SHIELD.health/self._SHIELD.maxHealth) or 1
end

function _KERNEL:getShieldOffsets ( scaleX )
  if self.state.isBossInvulnerable then
    return ((scaleX > 0) and -10 or -25), -31
  else
    if scaleX < 0 then
      return 32, -34
    else
      return -7, -34
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §emit smoke          ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:env_emitSmoke ( )
  if GetTime() % 12 > 0 then return end
  local mx,my = self:getMiddlePoint     ( )
  local sx    = self.sprite:getScaleX   ( )

  local anim = self.sprite:getAnimation ( )

  if anim == "death-kneel" then
    local f = self.sprite:getFrame()
    if f == 3 then
      mx = mx + (sx > 0 and 3 or -3)
    elseif f >= 4 then
      mx = mx + (sx > 0 and 8 or -8)
    end
  end

  if sx < 0 then
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx-11, 
      my-26, 
      math.rsign(), 
      1, 
      RNG:n()*0.25, 
      -1.25,
      self.layers.bottom()-2,
      false,
      nil,
      true
    )
  else
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx-14, 
      my-26, 
      math.rsign(), 
      1, 
      RNG:n()*0.25, 
      -1.25,
      self.layers.bottom()-2,
      false,
      nil,
      true
    )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Animation handling -------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:manageChainAnimation ( )
  if self.state.isLaunched then
    self.sprite:change ( 1, "spin", 1 )
    self.sprite:stop   ( 1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _KERNEL:notifyBossBattleOver ( )
  SetStageFlag        ( "original-kernel-boss-defeated", 1 )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _KERNEL:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:getScaleX() > 0 then
    mx = mx + 6
  else
    mx = mx - 8
  end
  return mx, my
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _KERNEL:update (dt)
  if self.ignoredClearEventually then
    self:tryClearingIgnored ()
  end

  if self.state.isShielded then
    self.regenTimer = self.regenTimer - 1
    if self.regenTimer <= 0 then
      self.health = self.health + 1
      GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", -1, 1, self.health  )
      GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
      self.regenTimer = 80
    end
  end

  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self:updateBossInvulnerability ( )
  self:updateLocations           ( )

  if self.activated and self:isInState ( nil ) then
    --self.timer = self.timer + 1
    --self:updateBossTimer ( )
    --if self.nextActionTime < self.timer then
    if self:updateBossTimer ( ) then
      self:pickAction()
    end
  end

  if not (self.isChainedByHookshot) then
    self:tick    ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  if self.smoking then 
    if self.smoking % 6 == 0 then
      local l      = self.layers.sprite() - 1
      local mx, my = self:getMiddlePoint ()
      my = my - 32
      mx = mx - 16
      Particles:addFromCategory ( 
        "directionless_dust", 
        mx, 
        my, 
        math.rsign(), 
        1, 
        RNG:n()*0.4, 
        -1.5,
        l,
        false,
        nil,
        true
      )
    end
    self.smoking = self.smoking - 1
    if self.smoking <= 0 then
      self.smoking = nil
    end
  end

  self:updateContactDamageStatus ()
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )
end

function _KERNEL:tick ()
  self:applyPhysics()
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_KERNEL.static.ACTIONS = {
  "DESPERATION_ACTIVATION",        -- 1
  "GEYSER_SLAM",                   -- 2, working            
  "DUNK_DASH",                     -- 3, working, animation could use changes
  "SERIAL_PUNCH",                  -- 4, working
  "WAIT_FOR_BARRIER",              -- 5, working
  "SPINNAROO",                     -- 6, implementing
  "DESTROY"                        -- 7,
  -- ???
}

function _KERNEL:pickAction (recursion, px, py, mx, my)
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 1
      return
    end
  end
  local cx                = Camera:getX()
  local action, extra     = 0, nil

  if (self.forceDesperation) then
    -- Desperation phase
    self.hadForcedLaunch          = false
    self.forceDesperation         = false
    self.actionsSinceDesperation  = 0
    action                        = 1
  end

  if not self.actionList then
    self.actionList          = { 2, 3, 4, 6, 7, 7 }
    self.actionsSinceBarrier = 0
    --action                   = 5
  end

  if action <= 0 then
    if self.forcedNextAction then
      action                = self.forcedNextAction
      self.forcedNextAction = nil
    else
      action = table.remove ( self.actionList, RNG:range ( 1, #self.actionList ) )
      if #self.actionList <= 0 then
        self.actionList  = { 2, 3, 4, 6, 7, 7 }
      end
      if (action == 6 and math.abs(px-mx) > 80) or (action == 6 and self.lastAction == 6 and RNG:n() < 0.4) then
        action = table.remove ( self.actionList, RNG:range ( 1, #self.actionList ) )
        if #self.actionList <= 0 then
          self.actionList  = { 2, 3, 4, 6, 7, 7 }
        end
      end
    end
  end

  if py < my - 64 and action ~= 1 then
    if self.lastAction ~= 2 or self.slamsInRow < 2 then --RNG:n() < 0.7 then
      action = 2
    end
  end

  -- §§dpick
  --[[
  if action ~= 1 then
    --if not self.desperationActivated then
     --action                    = 6
    --end
    --self.desperationActivated = true
  end--]]

  if not self.state.isShielded and action ~= 1 and self.desperationActivated then
    self.actionsSinceBarrier = self.actionsSinceBarrier + 1
    -- original values were: self.desperationActivated and 1 or 3
    -- but then it became impossible for Kernel to get shield out of desperation phase
    if GAMEDATA.isHardMode() then
      if self.actionsSinceBarrier > 2 then
        action = 5
      end
    else
      -- history: 1 -> 3 -> 2
      if self.actionsSinceBarrier > 2 then
        action = 5
      end
    end
  end

  if action <= 0 then
    return 
  end

  if action == 2 then
    self.slamsInRow = self.slamsInRow + 1
  else
    self.slamsInRow = 0
  end
  self.lastAction = action

  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end

  self.wentAbove = false
end

-- §endaction
function _KERNEL:endAction ( finishedNormally, forceWait, clearActions )
  if clearActions then
    self.actionsWithoutRest = 0
  end
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest < 3 and not forceWait then
      self.nextActionTime     = self.desperationActivated and 1 or 1
    else
      self.nextActionTime     = self.desperationActivated and 1 or 1
      self.actionsWithoutRest = 0
    end

    if GAMEDATA.isHardMode() then
      if not self.state.isShielded and self.desperationActivated then
        self.nextActionTime = self.nextActionTime + 4
      end
    else
      if not self.state.isShielded and self.desperationActivated then
        self.nextActionTime = self.nextActionTime + 10
      end
    end
  end
end

function _KERNEL:getLocations ()
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _KERNEL:updateLocations()
  local x, y = GlobalObserver:single ("GET_PLAYER_MIDDLE_POINT" )
  if x then
    self.lastPlayerX, self.lastPlayerY = x, y
  end
  self.playerIsKnownToBeAlive                  = GlobalObserver:single ("IS_PLAYER_ALIVE")
  self.lastKnownPlayerX, self.lastKnownPlayerY = self.lastPlayerX, self.lastPlayerY
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Landing dust -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local LAYER      = Layer:get ( "LANDING-PARTICLES" )
function _KERNEL:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 then
    return
  end

  local cx,cy   = self:getPos()
  local x,y,w,h = cx+self.dimensions.x,
                  cy+self.dimensions.y,
                  self.dimensions.w,
                  self.dimensions.h


  local itemsL, lenL = Physics:queryRect ( x,   y+1, 1, h+1, self.filters.landablePlatform )
  local itemsR, lenR = Physics:queryRect ( x+w, y+1, 1, h+1, self.filters.landablePlatform )

  if lenR > 0 then
    Particles:addFromCategory ( "landing_dust", cx + 24, cy + 21, -1, 1,  0.25, -0.1, LAYER() )
  end

  if lenL > 0 then
    Particles:addFromCategory ( "landing_dust", cx - 4, cy + 21,  1, 1, -0.25, -0.1, LAYER() )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _KERNEL:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _KERNEL:addState ( "DESPERATION_ACTIVATION" )

function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )
  self.timer = -20
  if self.sprite:getAnimation() ~= "take-damage-1" then
    self.sprite:change ( 1, "take-damage-1", 1, true )
  end
  if not self._emittingSmoke then
    self.fakeOverkilledTimer      = 10000
    self.state.isBossInvulnerable = true
  end
end

function _DESPERATION_ACTIVATION:exitedState ( )
  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false
  self.desperationActivated     = true

  self:endAction                       ( false )
  self:permanentlyDisableContactDamage ( false )

  self.forcedNextAction = 2
end

function _DESPERATION_ACTIVATION:tick ( )
  self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )

  self.timer = self.timer + 1
  if self.timer == -5 then
    if self.IS_PURPLE then
      self.sprite:change ( 1, "desperation-kneel" )
    else
      self.sprite:change ( 1, "death-kneel" )
    end
  end

  if self.timer == 45 then
    self.commanderObj:cutscene_quickFlashEyeDarkver ( )
  end

  if self.timer == 65 then
    if not self.raisedFloorAgain then
      self.raisedFloorAgain = true
      self.commanderObj:giveKernelDesperationAlt      ( )
    end
    if self.IS_PURPLE then
      self.sprite:change ( 1, "desperation-activation-purple", 2, true )
    else
      self.sprite:change ( 1, "desperation-activation", 2, true )
    end
    Audio:playSound ( SFX.gameplay_stun )
    self:applyShake ( 2, 0.25, RNG:rsign() )
    self.hitFlash.current = self.hitFlash.max + 16

    Environment.smokeEmitter    ( self )
    self._emittingSmoke           = true
  end

  --if not self.IS_PURPLE and self.sprite:getAnimation(1) == "desperation-activation" and self.sprite:getFrame() == 3 and self.sprite:getFrameTime() == 0 then
  --  Audio:playSound ( SFX.gameplay_kernel_scream, 0.5 )
  --end 

  local extraTime = 25
  if self.timer == 150+extraTime then
    self:activateBarrier ( )
  end

  if self.timer == 174+extraTime then
    self.sprite:change ( "shield", "barrier-start", 1, true )
  end

  if self.timer == 190+extraTime then
    self:endAction ( true )
  end

  self:applyPhysics ( )
end

function _DESPERATION_ACTIVATION:env_emitSmoke ( )
  if GetTime() % 12 > 0 then return end
  local mx,my = self:getMiddlePoint   ( )
  local sx    = self.sprite:getScaleX ( )

  local anim = self.sprite:getAnimation()

  if anim == "death-kneel" or anim == "desperation-activation" then
    local f = self.sprite:getFrame()
    if f == 3 then
      mx = mx + (sx > 0 and 3 or -3)
    elseif f >= 4 then
      mx = mx + (sx > 0 and 8 or -8)
    end
  end

  if sx < 0 then
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx-11, 
      my-26, 
      math.rsign(), 
      1, 
      RNG:n()*0.25, 
      -1.25,
      self.layers.bottom()-2,
      false,
      nil,
      true
    )
  else
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx-14, 
      my-26, 
      math.rsign(), 
      1, 
      RNG:n()*0.25, 
      -1.25,
      self.layers.bottom()-2,
      false,
      nil,
      true
    )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §geyser slam --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SLAM = _KERNEL:addState ( "GEYSER_SLAM" )

function _SLAM:enteredState ( px, py, mx, my, skipPreframes )

  if py < my - 64 then
    self.stateVars.extraHeight = true
  end 

  self.sprite:change ( 1, "geyser-hop", 2, true )
  self.timer = skipPreframes and 2 or 8
end

function _SLAM:exitedState ( )
  self:endAction ( false )
  self:setAfterImagesEnabled(false)
end

function _SLAM:tick ( )

  self.timer = self.timer - 1
  if self.timer == 0 and not self.stateVars.jumped then
    self:setAfterImagesEnabled(true)
    self.sprite:change ( 1, "geyser-hop", 6, true )
    self.state.isGrounded         = false
    self.velocity.vertical.update = true

    Audio:playSound ( SFX.gameplay_boss_cable_jump )

    self.stateVars.landed = false
    local px, py, mx, my  = self:getLocations ( )

    local dif    = math.abs(mx - px)
    local dir    = mx > px and -1 or 1
    self.velocity.horizontal.direction  = dir
    dif = dif / (self.stateVars.extraHeight and 42 or 74) --52
    dif = dif - (dif%0.125)

    local finalPosition = mx
    for i = 1, 52 do -- ?????? what is this
      local adjust  = dif * dir 
      finalPosition = mx + adjust
      finalPosition = finalPosition - (finalPosition % 0.25)
    end
    if finalPosition < px-10 or finalPosition > px+10 then
      dif = dif + 0.25
    end

    if self.velocity.horizontal.current < 1 then
      self.velocity.horizontal.current = 1
    end

    self.velocity.horizontal.direction = dir
    self.velocity.horizontal.current   = dif
    self.velocity.vertical.current     = -6.0 + (self.stateVars.extraHeight and (self.desperationActivated and -0.25 or -2.0) or 0)
    self.state.isGrounded              = false
    self.stateVars.jumped              = true


    if self.stateVars.double then
      self.velocity.horizontal.current = 1.5
      self.velocity.vertical.current   = -4.0
    end

    self.sprite:flip ( self.velocity.horizontal.direction, 1 )
  end

  self:applyPhysics ( )

  if _SLAM.hasQuitState ( self ) then return end

  if self.stateVars.jumped and self.state.isGrounded and not self.stateVars.landed then

    self:setAfterImagesEnabled(false)
    self.sprite:change ( 1, "geyser-land", 1, true )

    self.floatY                      = 0
    self.velocity.horizontal.current = 0
    self.stateVars.landed            = true

    self:applyVerticalShake ( 3, 0.25, 1 )
    Camera:startShake       ( 0, 3, 20, 0.25 )
    Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
    Audio:playSound         ( SFX.gameplay_crash_impact )
    Audio:playSound         ( SFX.gameplay_boss_cable_landing )

    Audio:playSound         ( SFX.gameplay_geyser_2 )

    --self:spawnFallingBlocks ( nil, nil )

    local x, y = self:getPos()
    local sx   = self.sprite:getScaleX()
    if sx > 0 then
      x = x + 4
    else
      x = x - 17
    end
    GameObject:spawn (
      "lava_geyser",
      x+16,
      y+32,
      sx,
      nil,
      nil,
      true
    )
    :setGeneration (0)

    self.timer = 17

    if self.desperationActivated and not self.stateVars.double then
      self.stateVars.jumped = false
      self.stateVars.landed = false
      self.timer            = 22
      self.stateVars.double = true
    end
  end

  if self.timer <= 0 and self.stateVars.landed then
    self:endAction ( true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DUNK ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DUNK = _KERNEL:addState ( "DUNK_DASH" )

function _DUNK:enteredState ( px, py, mx, my )
  self.timer                       = 0
  self.velocity.horizontal.current = 0

  self.sprite:flip ( px < mx and -1 or 1, 1 ) 

  self.sprite:change ( 1, "dunk-start", self.desperationActivated and 3 or 2, true )
end

function _DUNK:exitedState ( )
  self:setAfterImagesEnabled           ( false )
  self:permanentlyDisableContactDamage ( false )
  self:endAction                       ( false )

  self.velocity.horizontal.current = 0
end

function _DUNK:tick ( )
  self.timer = self.timer + 1

  if self.sprite:getFrame(1) == 7 and self.sprite:getFrameTime(1) == 0 and not self.stateVars.started then
    self.stateVars.started             = true
    self.velocity.horizontal.direction = self.sprite:getScaleX ( )
    self:permanentlyDisableContactDamage ( true )
    self:setAfterImagesEnabled           ( true )

    Audio:playSound ( SFX.gameplay_powered_walker_dash )
    self.sprite:change ( 1, "dunk-start", 7, true )
  end

  if self.sprite:getAnimation(1) == "dunk-run" then
    local f = self.sprite:getCurrentFrame()
    if f == 9 or f == 5 then
        if not self.stateVars.sfxPlayed then
        self.stateVars.sfxPlayed = true
        Audio:playSound ( SFX.gameplay_footstep )
      end
    else
      self.stateVars.sfxPlayed = false
    end
  end

  if self.stateVars.started and not self.stateVars.bonked then
    self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.75, self.desperationActivated and 8 or 6 )
  end

  self:applyPhysics ( )

  if _DUNK.hasQuitState ( self ) then return end

  if not self.stateVars.bonked and not self.stateVars.noMoreChecks and self.velocity.horizontal.current > 1 then
    local hit, obj = self.sensors.PILEDRIVE_CATCH:check ( )
    if hit and obj then
      obj.parent._disableSuperArmor = true
      local able, counter = GlobalObserver:single ( "PLAYER_CAN_BE_GRABBED_BY_ENEMY" )
      obj.parent._disableSuperArmor = false
      if able then
        obj.parent:gotoState  ( "GRABBED_BY_ENEMY" )
        self:gotoState        ( "DUNK_FOLLOWUP", obj.parent ) 
        return
      elseif counter then
        self.stateVars.noMoreChecks = true
      end
    end
  end

  if self.stateVars.bonked and not self.stateVars.bonkHopped then
    self:permanentlyDisableContactDamage ( false )
    self:setAfterImagesEnabled           ( false )

    self.stateVars.bonkHopped          = true
    self.velocity.vertical.current     = -3.5
    self.velocity.horizontal.current   = 1.5
    self.velocity.horizontal.direction = -self.velocity.horizontal.direction
    self.state.isGrounded              = false

    self.sprite:change ( 1, "hop-neutral", 1, true )
  elseif self.stateVars.started and GetTime() % 3 == 0 and not self.stateVars.bonkHopped then
    local cx,cy   = self:getPos()
    local x,y,w,h = cx+self.dimensions.x,
                    cy+self.dimensions.y,
                    self.dimensions.w,
                    self.dimensions.h

    if self.velocity.horizontal.direction > 0 then
      Particles:addFromCategory ( "landing_dust", cx + 8, cy + 21, -1, 1,  0.25, -0.1, LAYER() )
    else
      Particles:addFromCategory ( "landing_dust", cx + 13, cy + 21,  1, 1, -0.25, -0.1, LAYER() )
    end
  end

  if self.stateVars.bonkHopped and self.state.isGrounded then
    if not self.stateVars.landed then
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.stateVars.landed             = true
      self.velocity.horizontal.current  = 0
      self.timer                        = 0
      self.sprite:change ( 1, "land", 1, true )
    elseif self.timer == 2 and self.desperationActivated then
      local px, py, mx, my = self:getLocations ( )
      if RNG:n() < 0.5 then
        self:gotoState ( "GEYSER_SLAM", px, py, mx, my, true )
      else
        self:gotoState ( "SERIAL_PUNCH", px, py, mx, my, true )
      end
      return
    elseif self.timer == 10 then
      self:endAction ( true )
    end
  end
end

function _DUNK:handleXBlock ( )
  Audio:playSound     ( SFX.gameplay_crash_impact, 0.9 )
  Camera:startShake   ( 0, 3, 20, 0.25 )

  self.stateVars.bonked = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DUNK FOLLOWUP §dfollowup -------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DUNK_FOLLOWUP = _KERNEL:addState ( "DUNK_FOLLOWUP" )

function _DUNK_FOLLOWUP:enteredState ( obj )
  local mx, my = self:getMiddlePoint ( )
  local l      = Layer:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )()

  SetTempFlag ( "kernel-boss-challenge-hits", 1 )

  self.isDunking = true

  if self.IS_PURPLE then
    Particles:addSpecial ( "pink_hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false )
    Particles:addSpecial ( "pink_hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false )
  else
    Particles:addSpecial ( "hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false )
    Particles:addSpecial ( "hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false ) 
  end

  self:permanentlyDisableContactDamage ( true )

  local x,y = self:getPos()
  if self.sprite:getScaleX() < 0 then
    obj:setPos ( x-20, y )
  else
    obj:setPos ( x+20, y )
  end

  self.stateVars.grabbedObject = obj
  Audio:playSound    ( SFX.gameplay_hookshot_latch_object  )
  self.sprite:change ( 2, "dunk-grab-hop-overlay", 2, true )
  self.sprite:change ( 1, "dunk-grab-hop", 2, true )
  self.timer = 0

  --self.activeLayer = Layers:get ( "STATIC-OBJECTS-FRONT" )

  self.velocity.horizontal.current = 0
  self.velocity.vertical.current   = 0
  self.velocity.vertical.update    = false
  self.stateVars.positiveStep      = 0.75


  self.isBursting = true
end

function _DUNK_FOLLOWUP:exitedState ( )
  self.isDunking                = false
  self.velocity.vertical.update = true

  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false

  self:endAction                        ( false )
  self:setAfterImagesEnabled            ( false )
  self:permanentlyDisableContactDamage  ( false )

  self.sprite:change ( 2, nil )

  self.isBursting = false
end

function _DUNK_FOLLOWUP:tick ( )
  self.timer = self.timer + 1
  if not self.stateVars.flying then
    if self.timer == 15 and not self.stateVars.firstAnim then
      self.stateVars.firstAnim = true
      self.timer               = 0
    elseif self.timer == 2 and not self.stateVars.flying and self.stateVars.firstAnim  then

      self.sprite:change ( 2, "dunk-grab-hop-overlay", 6, true )
      self.sprite:change ( 1, "dunk-grab-hop", 6, true )

      self.stateVars.izunaDropAnimation = true
      self.velocity.vertical.current    = self.desperationActivated and -6.75 or -8.5
      self.stateVars.flying             = true
      self.velocity.vertical.update     = false
      self.stateVars.notFlipped         = true
      self.velocity.horizontal.current  = 2.0

      Audio:playSound ( SFX.gameplay_boss_cable_jump )

      local cx = Camera:getX()
      cx       = cx + GAME_WIDTH / 2
      local mx = self:getMiddlePoint ( )
      if self.velocity.horizontal.direction < 0 and mx < (cx - 100) then
        self.velocity.horizontal.direction = 1
      elseif self.velocity.horizontal.direction > 0 and mx > (cx + 100) then
        self.velocity.horizontal.direction = -1
      end

      self.sprite:flip ( self.velocity.horizontal.direction, 1 )
      self:setAfterImagesEnabled ( true )
    end
  elseif not self.stateVars.suplexed then
    if self.velocity.vertical.current > -3 and not self.stateVars.spinAnimationStarted then
      self.stateVars.spinAnimationStarted = true
    end
    if self.stateVars.notFlipped and self.velocity.vertical.current >= -9 then
      self.stateVars.notFlipped = false
      self.stateVars.grabbedObject.sprite:flip  ( nil, -1 )

      self.stateVars.positiveStep = 1.0
      self.stateVars.hangTime     = 4
      self.stateVars.flippy       = true
    end

    if not self.stateVars.hangTime and self.velocity.vertical.current < 17 then
      local vel = self.velocity.vertical.current
      self.stateVars.positiveStep     = math.min(self.stateVars.positiveStep + 0.15, 0.75)
      vel                             = math.min ( vel + (vel > 0 and self.stateVars.positiveStep or 0.625), 25 )
      self.velocity.vertical.current  = vel
    end
    if self.stateVars.hangTime then
      self.stateVars.hangTime = self.stateVars.hangTime - 1
      if self.stateVars.hangTime <= 0 then
        self.stateVars.hangTime = nil
      end
    end
  end

  self:applyPhysics ()

  if self.stateVars.izunaDropAnimation and not self.stateVars.suplexed then
    local obj             = self.stateVars.grabbedObject
    local f,scale         = self.sprite:getCurrentFrame(1), self.sprite:getScaleX()
    local ox,oy,ox2,oy2   = 0,0
    local x, y            = self:getPos()
    local yOff            = 0
    if self.stateVars.notFlipped then
      yOff = 0
    else
      yOff = 2
    end
    local sx = 1
    if self.sprite:getScaleX() < 0 then
      obj:setPos ( x-20, y-2+yOff )
      sx = -1
    else
      obj:setPos ( x+20, y-2+yOff )
    end

    if f == 7 then
      obj:translate ( 0, -2 )
    elseif f == 8 then
      obj:translate ( -1*sx, -6 )
    elseif f == 9 then
      obj:translate ( -2*sx, -7 )
    elseif f == 10 then
      obj:translate ( -3*sx, -8 )
    elseif f == 11 then
      obj:translate ( -4*sx, -9 )
    end
  end

  if self.stateVars.exitNextTick then
    self.stateVars.exitNextTick = false
    self.sprite:flip   ( nil, 1 )
    self.sprite:change ( 1, "hop-neutral", 1, true )
    self.sprite:change ( 2, nil )

    local obj                    = self.stateVars.grabbedObject 
    self.stateVars.grabbedObject = nil
    obj.sprite:flip ( nil, 1 )
    obj._disableSuperArmor = true
    GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_MEDIUM, self.sprite:getScaleX(), true, -3, 1.5 ) 
    if not obj.dead and obj.health > 0 then
      if obj.setSpinAnimation then
        obj:makeBounceOnWallImpact ( true )
        obj:setSpinAnimation       ( )
      end
    end
    obj._disableSuperArmor = false
  end

  if self.stateVars.flying and self.state.isGrounded and not self.stateVars.suplexed then
    self:finishSuplex ()
  elseif self.stateVars.suplexed and self.state.isGrounded then
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.velocity.horizontal.current = 0
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )
  end
end

function _DUNK_FOLLOWUP:finishSuplex ( fromHit )
  local mx, my = self:getMiddlePoint("collision")
  mx, my = mx+1, my+1
  local l = Layer:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )()
  Particles:add       ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, l )
  Particles:addSpecial( "small_explosions_in_a_circle", mx, my, l, false, 0.75 )

  Audio:playSound ( SFX.gameplay_enemy_punch_heavy )

  Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
  Audio:playSound         ( SFX.gameplay_crash_impact )

  self.stateVars.exitNextTick = true
  GAMESTATE.addFreezeFrames ( 6 )
  Camera:startShake         ( 0, 3, 20, 0.25 )

  --self.sprite:stop   ( 1 )
  --self.sprite:stop   ( 2 )
  --self.sprite:stop   ( 3 )

  self.sprite:change ( 2, "dunk-grab-hop-overlay", 4, true )
  self.sprite:change ( 1, "dunk-grab-hop", 4, true )

  local obj             = self.stateVars.grabbedObject
  local f,scale         = self.sprite:getCurrentFrame(1), self.sprite:getScaleX()
  local ox,oy,ox2,oy2   = 0,0
  local x, y            = self:getPos()
  local yOff            = 0

  if self.sprite:getScaleX() < 0 then
    obj:setPos ( x-20, y-2+yOff )
  else
    obj:setPos ( x+20, y-2+yOff )
  end

  self.stateVars.suplexed = true

  self.velocity.vertical.update       = true
  self.velocity.vertical.current      = -3.5
  self.velocity.horizontal.current    = 2.5
  self.velocity.horizontal.direction  = -self.sprite:getScaleX()
end

function _DUNK_FOLLOWUP:takeDamage()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §serial punch  ------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SERIAL = _KERNEL:addState ( "SERIAL_PUNCH" )

function _SERIAL:enteredState ( px, py, mx, my )
  self.timer             = 0
  self.stateVars.punches = 0

  self.sprite:flip   ( px < mx and -1 or 1, 1 )

  self.stateVars.approachJump = math.abs ( px - mx ) > 100

  if self.stateVars.approachJump then
    self.sprite:change ( 1, "hop-neutral", 1, true )
  else
    self.sprite:change ( 1, "serial-punch", 2, true )
  end

end

function _SERIAL:exitedState ( )
  self.velocity.horizontal.current = 0
  self:setAfterImagesEnabled  ( false  )
  self.sprite:change          ( 2, nil )
end

function _SERIAL:tick ( )
  self.timer = self.timer + 1

  if self.stateVars.approachJump then
    self:approachJump ()
    return
  end

  if self.stateVars.started and not self.stateVars.bonked and self.timer > (self.desperationActivated and 6 or 10) then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
  end

  if self.velocity.horizontal.current > 0 and not self.stateVars.bonked and GetTime()%3 == 0 then
    local cx,cy   = self:getPos()
    local x,y,w,h = cx+self.dimensions.x,
                    cy+self.dimensions.y,
                    self.dimensions.w,
                    self.dimensions.h

    if self.velocity.horizontal.direction < 0 then
      Particles:addFromCategory ( "landing_dust", cx + 23, cy + 21, -1, 1,  0.25, -0.1, LAYER() )
    else
      Particles:addFromCategory ( "landing_dust", cx - 3, cy + 21,  1, 1, -0.25, -0.1, LAYER() )
    end
  end

  if self.timer == 23 and not self.stateVars.started then
    self.stateVars.first = true
    self.sprite:change ( 1, "serial-punch", 7, true )
    self.sprite:change ( 2, "serial-punch-overlay", 7, true )
    self:setAfterImagesEnabled           ( true )

    Audio:playSound ( SFX.gameplay_punch )

    self.stateVars.started             = true
    self.velocity.horizontal.direction = self.sprite:getScaleX ( )
    self.velocity.horizontal.current   = self.desperationActivated and 6.5 or 5.75
    self.timer                         = 0
  end

  self:applyPhysics ( )

  if _SERIAL.hasQuitState ( self ) then return end

  if not self.stateVars.started then return end

  if self.stateVars.bonked then
    if not self.stateVars.bonkHopped then
      self:setAfterImagesEnabled           ( false )

      self.stateVars.bonkHopped          = true
      self.velocity.vertical.current     = -3.5
      self.velocity.horizontal.current   = 2.5
      self.velocity.horizontal.direction = -self.velocity.horizontal.direction
      self.state.isGrounded              = false

      self.sprite:change ( 1, "hop-neutral", 1, true )
    else
      if self.state.isGrounded and not self.stateVars.landed then
        Audio:playSound    ( SFX.gameplay_boss_cable_landing )
        self.stateVars.landed             = true
        self.velocity.horizontal.current  = 0
        self.timer                        = 0
        self.sprite:change ( 1, "land", 1, true )
      elseif self.stateVars.landed then
        if self.timer >= 2 and self.desperationActivated then
          local px, py, mx, my = self:getLocations ( )
          self:gotoState ( "GEYSER_SLAM", px, py, mx, my, true )
          return
        elseif self.timer >= 5 then
          self:endAction ( true )
        end
      end
    end
  elseif self.velocity.horizontal.current <= 0 then

    self:setAfterImagesEnabled           ( false )
    self.stateVars.punches = self.stateVars.punches + 1
    if self.stateVars.hit then
      self.stateVars.punches = 999
    end
    if self.stateVars.punches >= (self.desperationActivated and 2 or 1) then
      if not self.stateVars.timerReset then
        self.timer                = 0
        self.stateVars.timerReset = true
        --self.sprite:change ( 1, "idle", 1, true )
      elseif self.timer >= 24 then
        self:endAction ( true )
      end
    else
      local px, py, mx, my = self:getLocations ()
      self.sprite:flip ( px < mx and -1 or 1, 1 )

      self.sprite:change ( 1, "serial-punch", 2, true )
      self.stateVars.started = false
      self.timer             = self.desperationActivated and 7 or 5
    end
  elseif self.velocity.horizontal.current > 0 and not self.stateVars.hit then
    local hit, obj = self.sensors.SERIAL_PUNCH:check ( )
    if hit and obj then
      if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE, self.sprite:getScaleX(), true, -3.5, 5.0 ) then
        self.stateVars.hit = true
        GAMESTATE.addFreezeFrames ( 2 )
        Audio:playSound           ( SFX.gameplay_punch_hit )
        Audio:playSound           ( SFX.gameplay_punch_hit_stunned )

        if obj.parentsetSpinAnimation then
          obj.parent:makeBounceOnWallImpact ( true )
          obj.parent:setSpinAnimation       ( )
        end

        local px, py = obj.parent:getMiddlePoint ()
        py = py - 8

        if self.IS_PURPLE then
          Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )
        else
          Particles:addSpecial ( "punch_sparks", px, py, self.hitParticleLayer(), false )
        end
      end
    end
  end
end

function _SERIAL:approachJump ( )
  if self.timer == 8 and not self.stateVars.approachJumped then
      self:setAfterImagesEnabled           ( true )
    self.sprite:change ( 1, "hop-neutral", 6, true )
    self.state.isGrounded         = false
    self.velocity.vertical.update = true

    Audio:playSound ( SFX.gameplay_boss_cable_jump )

    self.stateVars.landed = false
    local px, py, mx, my  = self:getLocations ( )

    local dif    = math.abs(mx - px)
    local dir    = mx > px and -1 or 1
    self.velocity.horizontal.direction  = dir
    dif = dif / 60 --52
    dif = dif - (dif%0.125)

    local finalPosition = mx
    for i = 1, 52 do -- ?????? what is this
      local adjust  = dif * dir 
      finalPosition = mx + adjust
      finalPosition = finalPosition - (finalPosition % 0.25)
    end
    if finalPosition < px-10 or finalPosition > px+10 then
      dif = dif + 0.25
    end

    if self.velocity.horizontal.current < 1 then
      self.velocity.horizontal.current = 1
    end

    self.velocity.horizontal.direction = dir
    self.velocity.horizontal.current   = dif
    self.velocity.vertical.current     = -5.0
    self.state.isGrounded              = false
    self.stateVars.approachJumped      = true
  end

  self:applyPhysics ( )

  if _SERIAL.hasQuitState ( self ) or not self.stateVars.approachJumped then return end

  if self.state.isGrounded then
    self.velocity.horizontal.current = 0
    if not self.stateVars.approachLanded then
      self:setAfterImagesEnabled           ( false )
      self.stateVars.approachLanded = true
      self.sprite:change ( 1, "land", 1, true )
      self.timer                        = 0
      self.sprite:change ( 1, "land", 1, true )
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    elseif self.timer == 4 then
      self.sprite:change ( 1, "serial-punch", 2, true )
      self.stateVars.approachJump = false
      self.timer                  = 0
    end
  end
end

function _SERIAL:handleXBlock ( )
  Audio:playSound     ( SFX.gameplay_crash_impact, 0.9 )
  Camera:startShake   ( 0, 3, 20, 0.25 )

  self.stateVars.bonked = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §WAIT FOR BARRIER ---------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _B_WAIT = _KERNEL:addState ( "WAIT_FOR_BARRIER" )

function _B_WAIT:enteredState ( )
  self:activateBarrier ( )
  self.timer = 45

  self.velocity.horizontal.current = 0
end

function _B_WAIT:exitedState ( )

end

function _B_WAIT:tick ( )
  self:applyPhysics ( )

  self.timer = self.timer - 1

  if self.timer == 24 then
    self.sprite:change ( "shield", "barrier-start", 1, true )
  end

  if self.timer < 0 then
    self:endAction ( true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §spinnaroo           ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SPIN = _KERNEL:addState ( "SPINNAROO" )

function _SPIN:enteredState ( px, py, mx, my )
  self.timer = 0

  self.velocity.horizontal.direction = 1
  self.velocity.horizontal.current   = 0

  self.stateVars.fullSpins = 0

  self.sprite:flip ( px < mx and -1 or 1 )
  self.sprite:change ( 1, "spinnaroo-start", 2, true )
end

function _SPIN:exitedState ( )
  self:setAfterImagesEnabled(false)
  self.sprite:change ( 2, nil )
  self:endAction     ( false )
end

function _SPIN:tick ( )
  self.timer = self.timer + 1

  if not self.stateVars.started and self.timer == (self.desperationActivated and 14 or 20) then
    self.stateVars.started = true
    self.sprite:change ( 1, "spinnaroo",         1, true )
    self.stateVars.sfxTimer = -1
    --self.sprite:change ( 2, "spinnaroo-overlay", 1, true )
  end

  if self.stateVars.started and not self.sprite:getAnimation(2) and self.sprite:getFrame() > 4 and not self.stateVars.ending then
    self.sprite:change ( 2, "spinnaroo-overlay", 1, true )
    self:setAfterImagesEnabled(true)
  end

  if self.stateVars.started and not self.stateVars.ending and self.sprite:getFrame() > 4 then
    local px, py, mx, my               = self:getLocations ( )

    self.stateVars.sfxTimer = self.stateVars.sfxTimer + 1
    if self.stateVars.sfxTimer % 8 == 0 then
      Audio:playSound ( SFX.gameplay_medley_spin_loop )
    end

    if not self.stateVars.initialDir then
      self.stateVars.initialDir = px < mx and -1 or 1
    else
      if self.stateVars.initialDir == -1 and px - 16 > mx then
        self.stateVars.initialDir = 1
      elseif self.stateVars.initialDir == 1 and px + 16 < mx then
        self.stateVars.initialDir = -1
      end
    end

    local hit = self.sensors.SPINNAROO:check()
    if hit then
      GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", math.sign(self.velocity.horizontal.current ) )
    end

    if self.stateVars.initialDir == -1 then
      local accel = self.velocity.horizontal.current > -1 and 0.25 or 0.50
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - accel, self.desperationActivated and -4.0 or -3.0 )
    else
      local accel = self.velocity.horizontal.current < 1 and 0.25 or 0.50
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + accel, self.desperationActivated and 4.0 or 3.0 )
    end

    if GetTime() % 3 == 0 then
      local mx, my = self:getMiddlePoint()
      local sx     = math.sign ( self.velocity.horizontal.current )
      Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and 3 or -9),  my+3,  sx, 1, 0.25*sx, -0.1, LAYER() )
    end

  elseif self.stateVars.ending  then
    if self.velocity.horizontal.current < 0 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 0 )
    elseif self.velocity.horizontal.current > 0 then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    end

    if self.velocity.horizontal.current == 0 then
      if not self.stateVars.endAnimationPlayed then
        self.stateVars.endAnimationPlayed = true
        self.sprite:change ( 1, "spinnaroo-end" )
      end
      self.stateVars.endTime = self.stateVars.endTime + 1
      if self.stateVars.endTime == 6 then
        self:endAction     ( true )
        return
      end
    end
  end

  if self.sprite:getFrame() == 11 and self.sprite:getFrameTime() == 0 then
    self.stateVars.fullSpins = self.stateVars.fullSpins + 1
    if self.stateVars.fullSpins > (self.desperationActivated and 6 or 4) then
      self.stateVars.ending  = true
      self.timer             = 0
      self.stateVars.endTime = 0
      self:setAfterImagesEnabled(false)
    end
  end

  self:applyPhysics ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DESTROY BOMB -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESTROY = _KERNEL:addState ( "DESTROY" )

function _DESTROY:enteredState ( )
  self.timer = 16

  self.velocity.horizontal.current = 0
end

function _DESTROY:exitedState ( )

end

function _DESTROY:tick ( )
  self:applyPhysics ( )

  self.timer = self.timer - 1

  if self.timer == 15 then
    self.sprite:change ( 1, "serial-punch", 7, true )
    local x, y = GlobalObserver:single ("GET_PLAYER_RAW_POSITION" )
    GameObject:spawn (
      "kernel_bomb",
      x,
      y,
      3,
      self.projectileLayer
    )
  end

  if self.timer < 0 then
    self:endAction ( true )
  end
end
  

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _KERNEL:addState ( "TECH_RECOVER" )

function _TECH:enteredState (  )
  self.fakeOverkilledTimer      = GAMEDATA.boss.getTechRecoverFrames ( self )
  self.state.isBossInvulnerable = true
  
  self._lastBurstAttackId  = nil
  self:disableContactDamage ( 30 )
  self.timer               = 20
  local mx, my = self:getMiddlePoint()
  mx = mx - 8
  my = my - 24
  Particles:add ( "circuit_pickup_flash_large", mx, my, 1, 1, 0, 0, self.layers.sprite()+1 )

  Audio:playSound ( SFX.hud_mission_start_shine )

  self.sprite:flip   ( nil, 1 )
  self.sprite:change ( 1, "hop-neutral" )

  self.state.isGrounded           = false
  self.velocity.vertical.current  = -2
  self.velocity.vertical.update   = true
  self.stateVars.decrement        = false
  self.stateVars.landed           = false
end

function _TECH:exitedState ( )
  self:endAction ( false )
end

function _TECH:tick ( )
  self:applyPhysics()

  if self.state.isGrounded then
    if not self.stateVars.landed then
      self.sprite:change ( 1, "land" )
      self.velocity.horizontal.current = 0
      self.stateVars.landed = true
    end
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction ( true )
    end
  end
end

function _KERNEL:manageTeching ( timeInFlinch )
  if self.hadForcedLaunch and self.forceDesperation then  
    if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
      self.hadForcedLaunch             = false
      self:gotoState      ( nil )
      self.nextActionTime = -5
      self.timer          = 0
      self.sprite:change  ( 1, "take-damage-1" )
      return true
    end
    return false
  end
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  return false
end

function _KERNEL:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

function _KERNEL:manageStunEnter ( )
  GAMESTATE.subbossDefeated = true
end

function _KERNEL:manageEnteringStunState ( ... )
  self:spawnBossMidpointRewards ( )
  self:gotoState ( "STUN", ... )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    return
  end
  if self.health - dmg <= (GAMEDATA.boss.getMaxHealth()/2) then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
    self.hadForcedLaunch          = true
    self.forceLaunched            = true
    self.forceDesperation         = true
    self.fakeOverkilledTimer      = 10000
    self.state.isBossInvulnerable = true

    self:spawnBossMidpointRewards ( )
    local mx, my = self:getMiddlePoint("collision")

    Environment.smokeEmitter    ( self )
    self._emittingSmoke = true

    mx, my = mx+2, my-2
    Particles:add ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.particles() )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

    return true, 1.0, -4
  end
end

function _KERNEL:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _KERNEL:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self:setActualPos ( self:getX()-2, self:getY())
  self.sprite:change ( 1, nil )
  self.timer = 20
  self.stateVars.beams = 0
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )

  self:applyPhysics()
end

function _KERNEL:_runAnimation ( )
  

  self:gotoState ( "CUTSCENE" )

  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §cutscene            ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:cutscene_addSmoking ( )
  self.smoking          = 90
  self.hitFlash.current = self.hitFlash.max + 16
  return true, true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §zombe spawn --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:cutscene_purpleZombieSpawn ( )
  if not self._cutscene then
    self._cutscene = 60
    self.sprite:change ( 1, "zombie-spawn", 1, true )
    Audio:playSound ( SFX.gameplay_zombie_spawn )
  end

  if self._cutscene % 6 == 0 then
    local x,y   = self:getPos()
    Environment.landingParticle ( x, y, self.dimensions, -2, 15, 17, nil, nil, "garbage" )
  end

  self._cutscene = self._cutscene - 1

  if self._cutscene <= 0 then
    self._cutscene = nil
    return true
  end

  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §destruct            ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _KERNEL:manageDestructEnter ( )
  if self._emittingSmoke then
    Environment.smokeEmitter ( self, true )
    self._emittingSmoke = nil
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

_KERNEL.static.SHIELD_PALETTE_0 = createColorVector (
  Colors.black,
  Colors.green_blue,
  Colors.kernel_dark_green,
  Colors.grayish_light_blue,
  Colors.white,
  Colors.whitePlus
)
_KERNEL.static.SHIELD_PALETTE_1 = createColorVector (
  Colors.black,
  Colors.green_blue,
  Colors.kernel_dark_green,
  Colors.frozen_blue_1,
  Colors.white,
  Colors.whitePlus
)
_KERNEL.static.SHIELD_PALETTE_2 = createColorVector (
  Colors.black,
  Colors.green_blue,
  Colors.kernel_dark_green,
  Colors.kernel_light_green,
  Colors.white,
  Colors.whitePlus
)
_KERNEL.static.SHIELD_PALETTE_3 = createColorVector (
  Colors.black,
  Colors.green_blue,
  Colors.kernel_dark_green,
  Colors.weird_yellow,
  Colors.kai_yellow,
  Colors.whitePlus
)
_KERNEL.static.SHIELD_PALETTE_4 = createColorVector (
  Colors.black,
  Colors.green_blue,
  Colors.kernel_dark_green,
  Colors.kai_red,
  Colors.kai_orange,
  Colors.whitePlus
)

_KERNEL.static.SHIELD_PALETTES = {
  _KERNEL.SHIELD_PALETTE_4,
  _KERNEL.SHIELD_PALETTE_3,
  _KERNEL.SHIELD_PALETTE_2,
  _KERNEL.SHIELD_PALETTE_1,
  _KERNEL.SHIELD_PALETTE_0,
}

function _KERNEL:drawSpecial ( baseL )
  local x,y = self:getPos           ( )
  if self.isDunking then
    local l   = self.dunkLayer        ( )

    if self.IS_PURPLE then
      Shader:pushColorSwapper ( l, false, self.class.PALETTE, Colors.Sprites.commander )
      self.sprite:draw        ( 2, x, y, l, false )
      Shader:set              ( l, false )
    else
      self.sprite:draw ( 2, x, y, l, false )
    end
  end

  if not self.sprite:getAnimation ( "shield" ) then return end
  local l     = self.layers.bottom() - 5
  local index = self._SHIELD.health > 0 and self._SHIELD.health or 1

  Shader:pushColorSwapper ( l, false, self.class.PALETTE, self.class.SHIELD_PALETTES[index] )
  self.sprite:draw        ( "shield", x, y, l, false )
  Shader:set              ( l, false )
end

function _KERNEL:customEnemyDraw ( x, y, scaleX )
  self.sprite:drawInstant ( 1, x, y )
  self.sprite:drawInstant ( 2, x, y )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Return -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

return _KERNEL