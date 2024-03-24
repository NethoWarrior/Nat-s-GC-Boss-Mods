-- MEDLEY, THE WAVE CIRCUIT, CITY BOSS
local _MEDLEY    = BaseObject:subclass ( "MEDLEY_WAVE_CIRCUIT" ):INCLUDE_COMMONS ( )
FSM:addState  ( _MEDLEY, "CUTSCENE"             )
FSM:addState  ( _MEDLEY, "BOSS_CIRCUIT_PICKUP"  )
Mixins:attach ( _MEDLEY, "gravityFreeze"        )
Mixins:attach ( _MEDLEY, "bossTimer"            )

_MEDLEY.static.IS_PERSISTENT      = true
_MEDLEY.static.SCRIPT             = "dialogue/boss/cutscene_medleyConfrontation"
_MEDLEY.static.BOSS_CLEAR_FLAG    = "boss-defeated-flag-medley"

_MEDLEY.static.EDITOR_DATA = {
  width   = 2,
  height  = 2,
  ox      = -16,
  oy      = -22,
  mx      = 31,
  order   = 9975,
  category = "bosses",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isUnique      = true,
    isTargetable  = true,
  }
}

_MEDLEY.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc, "medley"  )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "commander"     )
  CutsceneManager.preload   ( _MEDLEY.SCRIPT                )
end

_MEDLEY.static.PALETTE              = Colors.Sprites.medley
_MEDLEY.static.AFTER_IMAGE_PALETTE  = createColorVector ( 
  Colors.darkest_blue, 
  Colors.medley_dark_blue, 
  Colors.medley_dark_blue, 
  Colors.medley_middle_blue, 
  Colors.medley_middle_blue, 
  Colors.medley_middle_blue
)

_MEDLEY.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_MEDLEY.static.DIMENSIONS = {
  x            =   4,
  y            =   6,
  w            =  20,
  h            =  26,
  -- these basically oughto match or be smaller than player
  grabX        =   7,
  grabY        =   4,
  grabW        =  14,
  grabH        =  28,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_MEDLEY.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_MEDLEY.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
  warningTile       = Filters:get ( "queryWarningTile"            ),
  enemy             = Filters:get ( "queryEnemyObjectsFilter"     ),
}

_MEDLEY.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  behind    = Layer:get ( "BEHIND-TILES", "SPRITES"   ),
}

_MEDLEY.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_MEDLEY.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_MEDLEY.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_MEDLEY.static.BOSS_CIRCUIT_SPAWN_OFFSET = {
  x = 0,
  y = -16,
}

_MEDLEY.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:finalize ( parameters )
  RegisterActor ( ACTOR.MEDLEY, self )
  self:translate ( 0, 16 )
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "medley", 1 )
  self.sprite:change ( 1, "walk" )
  self.sprite:addInstance ( 2 )
  self.sprite:addInstance ( 3 )

  self.isFlinchable           = false
  self.isImmuneToLethalTiles  = true

  self.actionsWithoutRest   = 0
  self.nextActionTime       = 1
  self.desperationActivated = false
  self.spinAttacking = false

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.overlays = {
    2,
    draw = true,
  }

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -4, -2, 36, 36, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil

  -- §bossrush §boss rush
  if parameters and parameters.bossRush then
    self.state.isBossRushSpawn  = true
    self.state.isBoss           = true
    self.sprite:change          ( 1, "preboss-battle-intro-1", 1, false )
    self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
      self.sprite:change ( 1, "idle" )
    end
  elseif parameters and parameters.isTarget then
    self.state.isBoss   = true
    self.listener       = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    self.sprite:change   ( 1, "preboss-battle-intro-1", 1, false )
    local flag  = GetFlag ( "medley-boss-prefight-dialogue" )
    local flag2 = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" ) 
    
    if GAMESTATE.speedrun then
      flag  = true
      flag2 = 0
    end

    if (not flag) or (flag2 and flag2 > 0) then
      self:gotoState      ( "PREFIGHT_INTRO" )
    end
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end
end

function _MEDLEY:activate ( )  
  if not self.state.isSpawnBoss then
    GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  end
  
  self.health      = 64  
  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "medley", self.health )
  self.activated   = true
end

function _MEDLEY:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end

  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end

  UnregisterActor ( ACTOR.MEDLEY, self )
end

function _MEDLEY:isDrawingWithPalette ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _MEDLEY:prenotifyBossBattleOver ( )
  local items, len = Physics:queryRect ( Camera:getX()+2, Camera:getY()+2, GAME_WIDTH-4, GAME_HEIGHT-4, self.filters.enemy )
  for i = 1, len do
    if items[i] and items[i].parent ~= self then
      if items[i].parent.stateVars then
        items[i].parent.stateVars.exitedProperly = true
      end
      if items[i].parent:hasState ( "DESTRUCT" ) then
        items[i].parent:gotoState("DESTRUCT")
      elseif items[i].parent.despawn then
        items[i].parent:despawn()
      end
    end
  end

  self:booCrowd ( true )
end

function _MEDLEY:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _MEDLEY:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:isFacingRight() then
    mx = mx - 2
  else
    mx = mx + 2
  end
  my = my - 1
  return mx, my
end

function _MEDLEY:handleDeathKneeling ( )
  self.sprite:change ( 1, "death-kneel" )
end

function _MEDLEY:manageStunEnter ( )
  if self.state.isSpawnBoss then
    GAMESTATE.disableBouncePads = true
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Crowd   ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:activateCrowd ( )
  if not self.crowd then
    self.crowd = GameObject:spawn ( "medley_crowd_bot", 0, 0 )
  end
end

function _MEDLEY:booCrowd ( defeated )
  if self.crowd then
    Audio:playSound ( SFX.gameplay_medley_crowd_boo  )
    self.crowd:booBounce ( )
    if defeated then
      self.crowd:setToDisappear ( )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _MEDLEY:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end
  if self.spinAttacking == true then
    self.plasmaBallTimer = self.plasmaBallTimer - 1
    if self.plasmaBallTimer == 0 then
      local mx, my = self:getMiddlePoint()
      GameObject:spawn ( 
        "plasma_ball", 
        mx, 
        my, 
        0, 
        1
      )
      self.plasmaBallTimer = 20
    end
  end
  self:updateBossInvulnerability ( )
  self:updateLocations ( )

  if self.activated and self:isInState ( nil ) then
    if self:updateBossTimer ( ) then
      self:pickAction()
    end
  end

  if not (self.isChainedByHookshot) then
    self:tick ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:drawSensors()

  self:updateContactDamageStatus ()
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )
end

function _MEDLEY:tick ()
  if math.abs(self.velocity.vertical.current) > 0 then
    self.velocity.vertical.current = self.velocity.vertical.current - 0.25 * math.sign(self.velocity.vertical.current)
  end
  self:applyPhysics()
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_MEDLEY.static.ACTIONS = {
  "DESPERATION_ACTIVATION", -- 1
  "WALK",                   -- 2
  "LAUNCH_HOP",             -- 3 -- originally 'dodge'
  "BOUNCE_PROJECTILE",      -- 4
  "BOOM_BOX_ATTACK",        -- 5 -- unused? it sure is
  "SPIN_ATTACK",            -- 6
  "WAVE_PROJECTILE",        -- 7 -- the boombox
}

function _MEDLEY:pickAction ( recursion, px, py, mx, my )
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 10
      return
    end
  end

  local action = 0
  local extra  = 0
  if (self.forceDesperation) then
    -- Desperation phase
    self.forceDesperation         = false
    self.actionsSinceDesperation  = 0
    action                        = 1
  end


  local chance = RNG:n()
  if action ~= 1 then
    -- ...
    if self.hitWhileWalking then
      self.hitWhileWalking = false
      if chance > 0.65 then
        action = 6
      elseif chance > 0.2 then
        action = 7
      else
        action = 4
      end
    elseif self.lastAction == 2 then
      if chance > 0.7 then
        action = 6
      elseif chance > 0.4 then
        action = 4
      else
        action = 7
      end
    else
      if chance > 0.75 then
        action = 6
      elseif chance > 0.5 + (self.lastAction == 4 and 0.1 or 0) then
        action = 4
      elseif chance > 0.3 then
        action = 7
      else
        action = 2
      end
    end

    if (action ~= 2 and action ~= 6) and not recursion then
      if not self.actionsWithoutMovement then
        self.actionsWithoutMovement = 0
      end
      self.actionsWithoutMovement = self.actionsWithoutMovement + 1
    else
      self.actionsWithoutMovement = 0
    end

    if self.actionsWithoutMovement >= 2 then
      action = RNG:n() > 0.55 and 6 or 2
    end

    if self.lastAction == action and not recursion then
      self:pickAction ( true, px, py, mx, my )
      return
    end
  end

  if action > 1 and action ~= 4 and action ~= 7 then
    if not self.actionsWithoutProjectiles then
      self.actionsWithoutProjectiles = 0
    end
    self.actionsWithoutProjectiles = self.actionsWithoutProjectiles + 1
    if self.actionsWithoutProjectiles > 2 then
      action = RNG:flip() and 4 or 7
      self.actionsWithoutProjectiles = 0
    end
  end

  if BUILD_FLAGS.DEBUG_BUILD then
    if UI.kb.isDown ( "1") then
      action = 1
    end
  end

  if action <= 0 then return end
  if self.desperationActivated then
    if not self.actionsSinceDesperation then
      self.actionsSinceDesperation = 0
    end
    self.actionsSinceDesperation = self.actionsSinceDesperation + 1
    if self.actionsSinceDesperation > 4 then
      self.forceDesperation = RNG:n() < (0.15 + (self.actionsSinceDesperation-4)*0.165)
    end
  end

  if action <= 0 then return end
  self.lastAction = action

  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §end action ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:endAction ( finishedNormally )
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.nextActionTime = self.desperationActivated and 35 or 45
  
    if GAMEDATA.isHardMode() then
      self.nextActionTime = self.nextActionTime - 16
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §locations ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:getLocations ( )
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

-- §updatelocations
function _MEDLEY:updateLocations()
  local x, y = GlobalObserver:single ("GET_PLAYER_MIDDLE_POINT" )
  if x then
    self.lastPlayerX, self.lastPlayerY = x, y
  end
  self.playerIsKnownToBeAlive                  = GlobalObserver:single ("IS_PLAYER_ALIVE")
  self.lastKnownPlayerX, self.lastKnownPlayerY = self.lastPlayerX, self.lastPlayerY
end

function _MEDLEY:checkIsPlayerFrozen ( )
  return GlobalObserver:single ( "IS_PLAYER_FROZEN" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Landing dust -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 then
    return
  end

  local x,y   = self:getPos()
  Environment.landingParticle ( x, y, self.dimensions, -7, 20, 17 )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _MEDLEY:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _MEDLEY:addState ( "DESPERATION_ACTIVATION" )
function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )
  self.sprite:change ( 1, "angry" )

  self.timer           = 17
  self.foolProofTimer  = 60
  if self.desperationActivated then
    self.stateVars.angry = false
  else
    self.stateVars.angry = true
    self.sprite:change ( 1, "angry", 1, true )
  end
end

function _DESPERATION_ACTIVATION:exitedState ()
  if self.stateVars.startedSuperFlash then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end
  self.fakeOverkilledTimer = nil
  self.state.isHittable    = true
  self:endAction(false, true)

  self:setAfterImagesEnabled( false )
  self:permanentlyDisableContactDamage ( false )

  self.state.isBossInvulnerable = false
end

function _DESPERATION_ACTIVATION:tick ()
  self:applyPhysics()

  if self.stateVars.angry then
    local f = self.sprite:getFrame()
    if (f == 8 or f == 14 or f == 20) and f ~= self.stateVars.angry then
      self.stateVars.angry = f
      local mx, my = self:getMiddlePoint()
      local sx     = self.sprite:getScaleX()

      Audio:playSound ( SFX.gameplay_boss_cable_landing, 1.2 )
      Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and -16 or 10),  my+2,  -sx, 1, -0.25*sx, -0.1 )
    end
    if not self.sprite:isPlaying() then
      self.stateVars.angry = false
    end
  elseif not self.stateVars.hopped  then

    if not self.stateVars.hopStarted then

      self:setAfterImagesEnabled( true )
      self.stateVars.hopStarted = true
      local mx, my, px, py
      mx, my = self:getPos()
      px, py = Camera:getPos()
      px     = px + GAME_WIDTH/2
      local dif    = math.abs(mx - px)
      local dir    = mx > px and -1 or 1
      self.velocity.horizontal.direction  = dir
      dif = dif / 52
      dif = dif - (dif%0.125)

      local finalPosition = mx
      for i = 1, 52 do
        local adjust  = dif * dir 
        finalPosition = mx + adjust
        finalPosition = finalPosition - (finalPosition % 0.25)
      end
      if finalPosition < px-10 or finalPosition > px+10 then
        dif = dif + 0.25
      end

      self.velocity.horizontal.direction = dir
      self.velocity.horizontal.current   = dif
      self.velocity.vertical.current     = -6.5
      self.state.isGrounded              = false

      self.sprite:flip ( dir )
      self.sprite:change ( 1, "hop-forward", 1, true )
    elseif self.state.isGrounded then

      self:setAfterImagesEnabled( false )
      self.sprite:change ( 1, "land" )
      self.stateVars.hopped = true

    else
      local cx, cy = Camera:getPos()
      cx           = cx + GAME_WIDTH/2
      local mx, my = self:getMiddlePoint()
      if (mx < (cx + 8)) and (mx > (cx - 8)) then 
        self.velocity.horizontal.current = math.max(self.velocity.horizontal.current - 0.325, 0)
      end
    end
  elseif not self.stateVars.launched then
    self.foolProofTimer = self.foolProofTimer - 1
    if self.foolProofTimer <= 0 then
      self.stateVars.launched = true
      self.sprite:change ( 1, "hop-neutral" )

      self.velocity.horizontal.current    = 0
      self.velocity.horizontal.direction  = 1
      self.velocity.vertical.current      = -6.0
    end
  elseif not self.stateVars.finishedFlash then
    self.timer = self.timer + 1
    if not self.stateVars.activated and self.velocity.vertical.current >= 0 then
      self.velocity.vertical.update      = false
      self.velocity.vertical.current     = 0
      self.velocity.horizontal.current   = 0
      self.velocity.horizontal.direction = 0
      self.stateVars.activated           = true
      self.timer                         = 0
      local dir                          = self.sprite:getScaleX()
      local mx, my                       = self:getMiddlePoint()
      Particles:addSpecial ( "super_flash", mx + (dir > 0 and 0 or 2), my-15, self.layers.sprite()-2, self.layers.sprite()-1, false, mx, my )
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_START", self ) 
        self:permanentlyDisableContactDamage ( false ) 
        self.stateVars.startedSuperFlash = true
        self.state.isBossInvulnerable    = true
      end
      self.sprite:change ( 1, "desperation-activation" )
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_medley", 6 )
      self.fakeOverkilledTimer = 1000
    end

    if self.stateVars.activated and self.timer == 20 then
      self:spawnAttack()
    end

    if not self.stateVars.finishedFlash and self.stateVars.activated and self.timer >= 20 then
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_END" )
        self.stateVars.startedSuperFlash = false
      end
      --self.velocity.vertical.update     = true
      self.stateVars.finishedFlash      = true
      self.desperationActivated         = true
      self.stateVars.finishedAttacking  = false
      self.timer                        = 40
    end
  elseif not self.stateVars.finishedAttacking then
    if not self.velocity.vertical.update then
      self.timer = self.timer - 1
      if self.timer <= 0 then
        self.velocity.vertical.update = true
      end
    end

    if self.state.isGrounded then
      if not self.stateVars.landed then
        self.stateVars.landed = true
        self:setAfterImagesEnabled  ( false )
        self.sprite:change          ( 1, "land-slam" )

        Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
        Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )

        if self.stateVars.secondHop then
          self:spawnWaveProjectile(1)
          self:spawnWaveProjectile(-1)
        end
      end

      self.timer = self.timer - 1
      if self.timer <= 0 then
        self.timer = 1
        self.stateVars.finishedAttacking = true
      end
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction(true)
    end
  end
end

function _DESPERATION_ACTIVATION:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 then
    return
  end

  self.velocity.horizontal.current = 0

  local x,y   = self:getPos()
  Environment.landingParticle ( x, y, self.dimensions, -3, 16, 17 )
end

function _DESPERATION_ACTIVATION:applyInstantLaunch ( )
  if self.stateVars.angry then
    return false
  end
  if self.stateVars.finishedFlash and self.stateVars.secondHop then
    return false
  end

  self.stateVars.hopStarted = true
  self.stateVars.launched   = true
  self.stateVars.hopped     = true

  self.sprite:change ( 1, "hop-neutral" )

  self:setAfterImagesEnabled( true )

  self.velocity.horizontal.current    = 0
  self.velocity.horizontal.direction  = 1
  self.velocity.vertical.current      = -6.5

  if self.stateVars.finishedFlash then
    Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
    Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )

    local px, py, mx, my = self:getLocations()

    self.velocity.horizontal.direction = px < mx and 1 or -1
    self.velocity.horizontal.current   = 1.5

    self:spawnWaveProjectile(1,nil,2)
    self:spawnWaveProjectile(-1,nil,2)
    self.stateVars.secondHop = true
    self.sprite:change ( 1, "ground-slam" )
  end

  return true
end

function _DESPERATION_ACTIVATION:applyLaunch ( )
  if not self.stateVars.angry then
    self.stateVars.hopStarted = true
    self.stateVars.launched   = true
    self.stateVars.hopped     = true
  end

  self.sprite:change ( 1, "hop-neutral" )
  self:setAfterImagesEnabled ( true )

  self.velocity.horizontal.current    = 0
  self.velocity.horizontal.direction  = 1
  self.velocity.vertical.current      = -6.5
end

_MEDLEY.static.DESPERATION_POSITIONS = 
{
  left = {
    [1] = { 32+0,  68+10  },
    [2] = { 32+48, 68+10  },
    [3] = { 32+96, 68+10  },
    [4] = { 32+0,  68+50  },
    [5] = { 32+48, 68+50  },
    [6] = { 32+96, 68+50  },
    [7] = { 32+0,  68+90  },
    [8] = { 32+48, 68+90  },
    [9] = { 32+96, 68+90  },
  },
  right = {
    [1] = { 240+0,  68+10  },
    [2] = { 240+48, 68+10  },
    [3] = { 240+96, 68+10  },
    [4] = { 240+0,  68+50  },
    [5] = { 240+48, 68+50  },
    [6] = { 240+96, 68+50  },
    [7] = { 240+0,  68+90  },
    [8] = { 240+48, 68+90  },
    [9] = { 240+96, 68+90  },
  },
}

function _DESPERATION_ACTIVATION:spawnAttack ()
  local cx, cy = Camera:getPos()
  local pos    = self.class.DESPERATION_POSITIONS

  local r = RNG:range ( 1,3 )
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.left[r][1], 
    cy + pos.left[r][2]-48,
    0
  )

  --local r = RNG:range ( 4,6 )
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.left[r][1], 
    cy + pos.left[r][2]-8,
    1
  )

  --local r = RNG:range ( 7,9 )
  r = r + 3
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.left[r][1], 
    cy + pos.left[r][2]-8,
    2
  )

  r = r + 3
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.left[r][1], 
    cy + pos.left[r][2]-8,
    3
  )

  local r = RNG:range ( 1,3 )
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.right[r][1], 
    cy + pos.right[r][2]-48,
    0
  )

  --local r = RNG:range ( 4,6 )
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.right[r][1], 
    cy + pos.right[r][2]-8,
    1
  )

  --local r = RNG:range ( 7,9 )
  r = r + 3
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.right[r][1], 
    cy + pos.right[r][2]-8,
    2
  )

  r = r + 3
  GameObject:spawn ( 
    "wave_speaker_projectile",
    cx + pos.right[r][1], 
    cy + pos.right[r][2]-8,
    3
  )

  
  if GAMEDATA.isHardMode() then
    for i = 0, 1 do
      local px, py = self:getLocations()
      px, py       = px - 16, py - 25
      px, py       = px - (px%16), py - (py%16)

      GameObject:spawn ( 
        "wave_speaker_projectile",
        px, 
        py,
        6 + i * 5
      ):setDelayedAim ( )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §walk    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _WALK = _MEDLEY:addState ( "WALK" )

function _WALK:enteredState ( px, py, mx, my, _, forceSpin )
  self.sprite:flip ( px < mx and -1 or 1 )

  self.sprite:change ( 1, "walk-start" )
  self.timer = 1
  if forceSpin then
    self.timer               = 1
    self.stateVars.forceSpin = true
    self.hitWhileWalking     = true
  end

  self.stateVars.spun = false
end

function _WALK:exitedState ( )
  self:endAction              ( false  )
  self.sprite:change          ( 2, nil )
  self:setAfterImagesEnabled  ( false  )

  self.nextActionTime = 2
  if GAMEDATA.isHardMode() then
    self.nextActionTime = 1
  end
end

function _WALK:tick ( )
  self.timer = self.timer - 1
  if self.timer == 0 then
    self.velocity.horizontal.current   = 1.00
    self.velocity.horizontal.direction = self.sprite:getScaleX()
  elseif self.timer <= 0 then
    if (self.hitFlash.current > 0 or self.stateVars.forceSpin) and not self.stateVars.spun then

      --[[
      local px, py, mx, my = self:getLocations ( )
      self:gotoState ( "LAUNCH_HOP", true )
      local dir = px >= mx and -1 or 1
      self.velocity.horizontal.direction = dir
      self.velocity.horizontal.current   = 3.5
      self.velocity.vertical.current     = -5.5
      self.sprite:flip ( -dir )]]
      self.stateVars.spun = true
      local dir = -self.sprite:getScaleX()
      if self.playerIsKnownToBeAlive then
        local px, py, mx = self:getLocations()
        dir = (px > mx) and -1 or 1
      end

      self.sprite:flip( -dir )

      self.velocity.horizontal.current    = 5.5
      self.velocity.horizontal.direction  = dir
      self.hitWhileWalking = true
      self.sprite:change ( 1, "dash-dodge",           1, true )
      self.sprite:change ( 2, "spin-attack-overlay",  2, true )
    end

    if self.stateVars.spun then
      self.velocity.horizontal.current = math.max(self.velocity.horizontal.current - 0.125,0)
      if self.velocity.horizontal.current > 0 then
        self:setAfterImagesEnabled( true )

        if not self.sprite:getAnimation(2) and self.velocity.horizontal.current > 1 then
          self.sprite:change ( 2, "spin-attack-overlay",  2, true )
        end

        if GetLevelTime() % 4 == 0 then
          local mx, my = self:getMiddlePoint()
          local sx     = self.velocity.horizontal.direction
          Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and 3 or -9),  my+3, -sx, 1, 0.25*-sx, -0.1 )
        end
      else
        self:setAfterImagesEnabled( false )
        if self.sprite:getAnimation() == "idle" then
          self:endAction(true)
        end
      end
    end
  end

  self:applyPhysics()
end

function _WALK:handleXBlock ( )
  if not self.stateVars.spun then
    self:applyLaunch ( 0, -1 )
  end
end

--[[
function _WALK:applyInstantLaunch ( ... )
  if not GAMEDATA.isHardMode() then return end
  if self.stateVars.spun then return end
  self:applyLaunch ( ... )
end]]

function _WALK:applyLaunch ( speedX, speedY, fromSelf )
  if self.velocity.horizontal.current > 4.0 then return end 

  if speedY >= 0 then
    return
  end

  if not self.hitWhileWalking then
    local px, py, mx, my = self:getLocations ( )
    if px > mx then
      speedX = 1
      self.sprite:flip ( speedX, 1 )
    elseif px < mx then
      speedX = -1
      self.sprite:flip ( speedX, 1 )
    else
      speedX = RNG:n() < 0.375 and -self.velocity.horizontal.direction or self.velocity.horizontal.direction
      self.sprite:flip ( speedX, 1 )
    end
  else
    local cx, cy = Camera:getX()
    cx           = cx + GAME_WIDTH/2
    local mx, my = self:getMiddlePoint()

    if cx - 96 > mx then
      speedX = 1
      self.sprite:flip ( speedX, 1 )
    elseif cx + 96 < mx then
      speedX = -1
      self.sprite:flip ( speedX, 1 )
    else
      speedX = RNG:n() < 0.375 and -self.velocity.horizontal.direction or self.velocity.horizontal.direction
    end
  end

  self:gotoState ( "LAUNCH_HOP", true )

  self.velocity.horizontal.current    = 1.5
  self.velocity.horizontal.direction  = speedX
  self.velocity.vertical.current      = -6.5
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §dodge    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DODGE = _MEDLEY:addState ( "DODGE" )

function _DODGE:enteredState ( px, py, mx, my )

end

function _DODGE:exitedState ( )

end

function _DODGE:tick ( )

end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §SPIN ATTACK --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SPIN_ATTACK = _MEDLEY:addState ( "SPIN_ATTACK" )

function _SPIN_ATTACK:enteredState ( px, py, mx, my )

  self.sprite:flip ( px >= mx and 1 or -1 )

  self.sprite:change ( 1, "spin-attack-start" )
  self.stateVars.spinning = false
  self.stateVars.ended    = false
  self.stateVars.bonks    = 0
  self.stateVars.spinTime = 0
  self.stateVars.slowing  = false
  self.timer              = 25
  self.plasmaBallTimer    = 20
  self.spinAttacking      = true
  self.sfxTimer           = -1
end

function _SPIN_ATTACK:exitedState ( )
  self:setAfterImagesEnabled( false )
  self:endAction ( false )
  self.nextActionTime = 1
  self.sprite:change ( 2, nil )
  self.spinAttacking = false

  if GAMEDATA.isHardMode() then
    self.nextActionTime = 1
  end
end

function _SPIN_ATTACK:tick ( )
  if not self.stateVars.spinning then
    if self.sprite:getFrame() == 3 then
      self.stateVars.spinning = true
      self.velocity.horizontal.current   = 0
      self.velocity.horizontal.direction = self.sprite:getScaleX()
    end
  else
    if self.timer <= 0 then
      local maxBonks = self.desperationActivated and 2 or 1
      local hard     = GAMEDATA.isHardMode()
      if hard then
        maxBonks = maxBonks + 1
      end
      if self.stateVars.bonks >= maxBonks then
        self.stateVars.spinTime = self.stateVars.spinTime + 1
      end

      if self.stateVars.spinTime > 20 then
        local x,y,w,h = self:getX()+self.dimensions.x, self:getY()+self.dimensions.y, self.dimensions.w, self.dimensions.h
        if Physics:queryRectSingleItem ( x,y,w,h, self.filters.warningTile ) then
          self.stateVars.slowing = true
        end
      end

      if not self.stateVars.slowing then
        if self.state.isGrounded and self.stateVars.bonked then
          self.stateVars.bonked = false
        end
        if not self.stateVars.bonked then
          if self.velocity.horizontal.current < 1 then
            self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25
          elseif self.velocity.horizontal.current < 3 then
            self.velocity.horizontal.current = self.velocity.horizontal.current + 0.5
          else
            self.velocity.horizontal.current = self.velocity.horizontal.current + 1
          end
          self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current, hard and 12.0 or 8.0 )
        else
          self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current, 4.5 )
        end
      else
        if self.velocity.horizontal.current > 10 then
          self.velocity.horizontal.current = self.velocity.horizontal.current - 1
        elseif self.velocity.horizontal.current > 4 then
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.5
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.25
        end
        self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current, 0 )
        self.stateVars.ending      = true
        if self.velocity.horizontal.current <= 0.25 and not self.stateVars.ended and self.state.isGrounded then
          self.sprite:change ( 1, "spin-attack-end" )
          self.stateVars.ended = true
          self.spinAttacking = false

          if self.stateVars.previousFrameYVel > 0.5 then
            Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
            Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )

            self:spawnWaveProjectile(1)
            self:spawnWaveProjectile(-1)

            if GAMEDATA.isHardMode() then
              local px, py = self:getLocations()
              px, py       = px - 16, py - 25
              px, py       = px - (px%16), py - (py%16)

              GameObject:spawn ( 
                "boss_commander_oval_bomb",
                px, 
                py,
                1
              )
            end
          end
        end
      end
    else
      self.timer = self.timer - 1
    end
  end

  self:setAfterImagesEnabled(self.velocity.horizontal.current>0.25)

  if self.sprite:getAnimation () == "spin-attack-start" then
    if self.sprite:getFrame() > 4 then
      self.sfxTimer = self.sfxTimer + 1
      if self.sfxTimer % 8 == 0 then
        Audio:playSound ( SFX.gameplay_medley_spin_loop )
      end
    end
  end

  if self.velocity.horizontal.current > 0.5 then
    if not self.sprite:getAnimation(2) then
      self.sprite:change ( 2, "spin-attack-overlay", 2, true )
    end
    if GetLevelTime() % 4 == 0 and (not self.stateVars.bonked or self.stateVars.ending) and self.state.isGrounded then
      local mx, my = self:getMiddlePoint()
      local sx     = self.velocity.horizontal.direction
      Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and 3 or -9),  my+3,  sx, 1, 0.25*sx, -0.1 )
    end
  elseif self.timer <= 10 and self.timer > 0 then
    if not self.sprite:getAnimation(2) then
      self.sprite:change ( 2, "spin-attack-overlay", 2, true )
    end
  end 
  if not self.state.isGrounded then
    if not self.sprite:getAnimation(2) then
      self.sprite:change ( 2, "spin-attack-overlay", 2, true )
    end
  end

  if self.stateVars.ended and not self.stateVars.endedFlip and self.sprite:getFrame() == 8 and self.sprite:getFrameTime() == 0 then
    self.stateVars.endedFlip = true
    local px, py, mx, my = self:getLocations ( )
    self.sprite:flip( px >= mx and 1 or -1 )
  end

  if self.stateVars.ended and not self.stateVars.taunted and self.sprite:getFrame() == 5 then
    self.stateVars.taunted = true
    Audio:playSound ( SFX.gameplay_medley_wink )

    local mx, my = self:getMiddlePoint()
    local sx     = self.sprite:getScaleX()
    Particles:add ( "wave-note-taunt-particle", mx + (sx < 0 and -23 or 7), my-30, 1, 1, 0, 0, self.layers.sprite()+1 )
  end

  local before                     = self.velocity.horizontal.current
  self.stateVars.previousFrameYVel = self.velocity.vertical.current
  self:applyPhysics()

  if not _SPIN_ATTACK.hasQuitState(self) then
    if not self.stateVars.ended then
      --if before ~= self.velocity.horizontal.current then
      --  if self.stateVars.launched then
        --  self.velocity.horizontal.current = before
      --  end
      --end
    else
      if self.sprite:getAnimation() == "idle" then
        self:endAction ( true )
      end
    end
  end
end

function _SPIN_ATTACK:handleXBlock ( )
  if not self.stateVars.ended then
    self.velocity.horizontal.direction = -self.velocity.horizontal.direction
    self.stateVars.bonks               = self.stateVars.bonks + 1
    --if not self.stateVars.bonked then
      self.stateVars.launched            = false
      self.velocity.horizontal.current   = 0.5
      self.stateVars.bonked              = true
      self.state.isGrounded              = false
      self.velocity.vertical.current     = -3.0
    --end

    Audio:playSound ( SFX.gameplay_medley_wave_impact )
  end
end

function _SPIN_ATTACK:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 then
    return
  end

  if self.stateVars.launched then
    local maxBonks = self.desperationActivated and 3 or 2
    if GAMEDATA.isHardMode() then
      maxBonks = maxBonks + 1
    end
    if self.stateVars.bonked and not self.stateVars.ending and self.stateVars.bonks < maxBonks then
      self.stateVars.bounce = self.stateVars.bounce + 1
      if self.stateVars.bounce == 1 then
        self.velocity.vertical.current = -3.5
      elseif self.stateVars.bounce == 2 then
        self.velocity.vertical.current = -1.5
      end
    end
  end

  if not self.stateVars.slowing then
    Audio:playSound ( SFX.gameplay_medley_wave_impact )
  end

  local x,y   = self:getPos()
  Environment.landingParticle ( x, y, self.dimensions, -3, 16, 17 )
end

function _SPIN_ATTACK:applyLaunch ( )
  self.state.isGrounded              = false
  self.stateVars.bounce              = 0
  self.stateVars.launched            = true
  self.stateVars.bonked              = true
  self.velocity.vertical.current     = -6.5
  self.velocity.horizontal.current   = 4.5
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §bounce §projectile -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _BOUNCE_PROJECTILE = _MEDLEY:addState ( "BOUNCE_PROJECTILE" )

function _BOUNCE_PROJECTILE:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )

  self.stateVars.started = true
  self.stateVars.spawned = 0
  self.timer = 2
  --self.sprite:change ( 1, "idle" )
  self.sprite:change ( 1, "spawn-projectile", 1, true )
end

function _BOUNCE_PROJECTILE:exitedState ( )
  self:endAction ( false )
  self.nextActionTime = self.nextActionTime + (self.desperationActivated and 2 or 6)

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 3
  end
end

function _BOUNCE_PROJECTILE:tick ( )
  self:applyPhysics()
  if (self.hitFlash.current > 0) then
    local px, py, mx, my = self:getLocations()
    self:gotoState ( "WALK", px, py, mx, my, nil, true )
    return
  end

  if not self.stateVars.started then
    -- ...
    --if self.sprite:getFrame() == 1 then
      self.stateVars.started = true
      self.sprite:change ( 1, "spawn-projectile", 1, true )
    --end
  else
    self.timer = self.timer + 1
    if self.timer == 10 then
      if self.stateVars.spawned <= (self.desperationActivated and 2 or 1) then
        self.stateVars.spawned = self.stateVars.spawned + 1
        --self.sprite:change ( 1, "spawn-projectile", 1, true )

        local mx, my = self:getMiddlePoint()
        local sx     = self.sprite:getScaleX()

        GameObject:spawn ( 
          "spicy_note_projectile",
          mx + (sx < 0 and -41 or 31), 
          my-16,
          -sx
        )
        if self.stateVars.spawned <= (self.desperationActivated and 2 or 1) then
          self.timer = 1
        else
          self.timer = 1
        end
      else
        if GAMEDATA.isHardMode() then
          local px, py, mx, my = self:getLocations()
          self:gotoState ( "WAVE_PROJECTILE", px, py, mx, my )
        else
          self:endAction(true)
        end
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §wave §projectile §boom §speaker ------------]]--
--[[----------------------------------------------------------------------------]]--
local _WAVE_PROJECTILE = _MEDLEY:addState ( "WAVE_PROJECTILE" )

function _WAVE_PROJECTILE:enteredState ( px, py, mx, my )
  -- ...
  self.sprite:flip ( px < mx and -1 or 1 )

  self.stateVars.started = false
  self.stateVars.spawned = 0
  self.timer = 0
  self.sprite:change ( 1, "spawn-boom-box", 2, true )
end

function _WAVE_PROJECTILE:exitedState ( )
  -- ...
  self:endAction ( false )
  self.nextActionTime = self.desperationActivated and 16 or 25
  self.nextActionTime = self.nextActionTime - 7 -- lol

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 4
  end
end

function _WAVE_PROJECTILE:tick ( )
  -- ...
  self.timer = self.timer + 1

  local checkSucceeded = false
  if GAMEDATA.isHardMode () then
    if self.desperationActivated then
      checkSucceeded = self.timer == 10 or self.timer == 20 or self.timer == 30 or self.timer == 40
    else
      checkSucceeded = self.timer == 10 or self.timer == 20 or self.timer == 30
    end
  else
    checkSucceeded = self.timer == 15 or (self.timer == 30 and self.desperationActivated )
  end

  if checkSucceeded then
    local px, py = self:getLocations()
    px, py       = px - 16, py - 25
    px, py       = px - (px%16), py - (py%16)
    local cx = Camera:getX()
    if not self.stateVars.firstX then
      self.stateVars.firstX = px
      self.stateVars.firstY = py
    else
      if GAMEDATA.isHardMode() then
        if not self.stateVars.pickedDir then
          self.stateVars.pickedDir = px < self.stateVars.firstX and -1 or 1
          if self.stateVars.pickedDir > 0 and px > cx + 350 then
            self.stateVars.pickedDir = -1
          elseif self.stateVars.pickedDir < 0 and px < cx + 50 then
            self.stateVars.pickedDir = 1
          end 
          self.stateVars.count     = 0
        end

        self.stateVars.count = self.stateVars.count + 1
        px = self.stateVars.firstX + self.stateVars.pickedDir * self.stateVars.count * 48
        py = py
      else
        if math.rectIntersect2 ( 
            self.stateVars.firstX-4, 
            self.stateVars.firstY-4, 
            40, 
            40, 
            px-4, 
            py-4, 
            40, 
            40 
          ) 
        then
          if px < self.stateVars.firstX then
            px = self.stateVars.firstX - 48
            self.stateVars.firstX = px
          elseif px > self.stateVars.firstX then
            px = self.stateVars.firstX + 48
            self.stateVars.firstX = px
          else
            px = self.stateVars.firstX + 48 * RNG:rsign()
            self.stateVars.firstX = px
          end
        end
      end
    end

    if px > (cx + 16) and px < (cx + 384) then
      GameObject:spawn ( 
        "boss_commander_oval_bomb",
        px, 
        py
      )
    end
  end

  if self.timer == 3 then
    Audio:playSound ( SFX.gameplay_medley_wink )
    local mx, my = self:getMiddlePoint()
    local sx     = self.sprite:getScaleX()
    Particles:add ( "wave-note-taunt-particle", mx + (sx < 0 and -23 or 7), my-30, 1, 1, 0, 0, self.layers.sprite()+1 )
  end

  if GAMEDATA.isHardMode () and self.timer >= 50 then
    self:endAction ( true )
  end

  if self.sprite:getAnimation() == "idle" then
    self:endAction(true)
  end
end

function _MEDLEY:spawnWaveProjectile ( dir, amount, yOffset )
  yOffset              = yOffset or 0
  local i              = 1
  local spawnX, spawnY = self:getPos()
  local inc            = dir or self.sprite:getScaleX()
  local cx             = Camera:getPos()
  spawnY               = spawnY + 32
  if not self.lastSpawnY or spawnY > self.lastSpawnY then
    self.lastSpawnY = spawnY
  else
    spawnY = self.lastSpawnY
  end
  local layer          = Layers:get ( "TILES-MOVING-PLATFORMS-1" )

  if inc > 0 then
    spawnX = spawnX + self.dimensions.x + self.dimensions.w + 4
  else
    spawnX = spawnX + self.dimensions.x - 20
  end

  if dir and self.sprite:getScaleX() == dir then
    spawnX = spawnX + (dir > 0 and -4 or 4)
  end

  if dir and self.sprite:getScaleX() == 1 then
    spawnX = spawnX + 4
  end

  local target = amount or 30
  while i < target do
    GameObject:spawn ( 
      "wave_ground_projectile",
      spawnX, 
      self.lastSpawnY+yOffset,
      (i-1),
      layer
    )
    i      = i + 1
    spawnX = spawnX + 15 * inc
    local x,y = self:getMiddlePoint()
    GameObject:spawn ( 
      "elec_ball", 
      x+20, 
      y-197, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x+16, 
      y-177, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x+12, 
      y-157, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x+8, 
      y-137, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x+4, 
      y-117, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y-97, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y-77, 
      1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x-20, 
      y-197, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x-16, 
      y-177, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x-12, 
      y-157, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x-8, 
      y-137, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x-4, 
      y-117, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y-97, 
      -1, 
      0,
      3,
      true
    )
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y-77, 
      -1, 
      0,
      3,
      true
    )


    if spawnX <= cx or spawnX >= cx + GAME_WIDTH then
      break
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Apply launch §HLOP §launch_hop -------------]]--
--[[----------------------------------------------------------------------------]]--
local _LHOP = _MEDLEY:addState ( "LAUNCH_HOP" )

function _LHOP:enteredState ( doAnAttack )
  self.timer = 20
  if doAnAttack then
    self.sprite:change              ( 1, "ground-slam" )
    self:setAfterImagesEnabled( true )
  else
    self.sprite:change ( 1, "hop-neutral-v2" )
  end

  self.state.isGrounded           = false
  self.velocity.vertical.current  = -2
  self.velocity.vertical.update   = true
  self.stateVars.decrement        = false
  self.stateVars.landed           = false
  self.stateVars.doAnAttack       = doAnAttack
  self.stateVars.landAttack       = doAnAttack

  self:setAfterImagesEnabled( true )
end

function _LHOP:exitedState ( )
  self:endAction ( false )

  self:setAfterImagesEnabled( false )
  if self.forceDesperation then
    self.nextActionTime = self.stateVars.spawned and 5 or 5
  else
    self.nextActionTime = self.stateVars.spawned and 8 or 10
  end

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 6
  end
end

function _LHOP:tick ( )

  --[[
  if self.stateVars.doAnAttack and self.velocity.vertical.current > 3 then
    self.stateVars.doAnAttack         = false
    self.velocity.vertical.current    = -4.5
    self.velocity.horizontal.current  = math.max ( self.velocity.horizontal.current - 1, 0.5 )
    self.sprite:change ( 1, "ground-slam" )
    self:setAfterImagesEnabled( true )
  end]]

  self:applyPhysics()

  if self.state.isGrounded then
    self:setAfterImagesEnabled( false )
    if not self.stateVars.landed then
      if self.stateVars.landAttack then
        self.stateVars.landAttack = false
        self:spawnWaveProjectile(1)
        self:spawnWaveProjectile(-1)
        self.stateVars.spawned = true
      end

      if self.stateVars.spawned then
        Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
        Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )
        self.sprite:change ( 1, "land-slam-smile" )
        self.timer = self.timer + 65
      else
        self.sprite:change ( 1, "land" )
      end
      self.velocity.horizontal.current = 0
      self.stateVars.landed = true
    end

    if self.stateVars.spawned and self.stateVars.landed and self.sprite:getFrame() == 6 and not self.stateVars.smiled then
      Audio:playSound ( SFX.gameplay_medley_wink )
      self.stateVars.smiled = true
      local mx, my = self:getMiddlePoint()
      local sx     = self.sprite:getScaleX()
      Particles:add ( "wave-note-taunt-particle", mx + (sx < 0 and -23 or 7), my-30, 1, 1, 0, 0, self.layers.sprite()+1 )
    end

    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction ( true )
    end
  end
end

function _MEDLEY:applyLaunch ( speedX, speedY )
  if self.health <= 0 then
    return
  end

  speedX = 0
  if speedY >= 0 then
    return
  end

  local cx, cy = Camera:getX()
  cx           = cx + GAME_WIDTH/2

  speedX       = (cx < self:getX()) and -1 or 1

  if self.state.isLaunched then
    self:gotoState ( "TECH_RECOVER" )
    return
  elseif self.forceDesperation and self.fakeOverkilledTimer and self.fakeOverkilledTimer > 0 then
    self:gotoState ( "LAUNCH_HOP" )
    self.velocity.horizontal.current    = 2
    self.velocity.horizontal.direction  = speedX
    self.velocity.vertical.current      = speedY
  else
    self:gotoState ( "LAUNCH_HOP", true )
    self.velocity.horizontal.current    = 2
    self.velocity.horizontal.direction  = speedX
    self.velocity.vertical.current      = -6.5
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _MEDLEY:addState ( "TECH_RECOVER" )

function _TECH:enteredState (  )
  self.fakeOverkilledTimer      = GAMEDATA.boss.getTechRecoverFrames ( self )
  self.state.isBossInvulnerable = true
  
  self._lastBurstAttackId  = nil
  self:disableContactDamage ( 30 )
  self.timer               = 1
  local mx, my = self:getMiddlePoint()
  mx = mx - 8
  my = my - 24
  Particles:add ( "circuit_pickup_flash_large", mx, my, 1, 1, 0, 0, self.layers.sprite()+1 )

  Audio:playSound ( SFX.hud_mission_start_shine )

  self.sprite:flip   ( nil, 1 )
  self.sprite:change ( 1, "hop-neutral-v2" )

  self.state.isGrounded           = false
  self.velocity.vertical.current  = -2
  self.velocity.vertical.update   = true
  self.stateVars.decrement        = false
  self.stateVars.landed           = false
end

function _TECH:exitedState ( )
  self:endAction ( false )
  if self.forceDesperation then
    self.nextActionTime = 1
  end
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

function _MEDLEY:manageTeching ( timeInFlinch )
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  return false
end

function _MEDLEY:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    return
  end
  if self.health - dmg <= (32) then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
    self:booCrowd   ( )
    self.forceLaunched            = true
    self.forceDesperation         = true
    self.fakeOverkilledTimer      = 10000
    self.state.isBossInvulnerable = true

    self:spawnBossMidpointRewards ( )
    local mx, my = self:getMiddlePoint("collision")
    
    mx, my = mx+2, my-2
    Particles:add       ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.particles() )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

    return true, 1.0, -4
  end
end

function _MEDLEY:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _MEDLEY:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and -8 or -20), -31
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _MEDLEY:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  local x,y = self:getPos()
  self:setActualPos ( x-4, y )
  self.sprite:change ( 1, nil )
  self.timer = 10
  self.stateVars.first      = true
  self.stateVars.width      = 0
  self.stateVars.lightTween = Tween.new ( 25, self.stateVars, { width = 30 }, "outQuad" )
  self.stateVars.l          = Layers:get  ( "TILES-MOVING-PLATFORMS-1" )
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )
  if self.stateVars.jumped then
    self:applyPhysics()

    if self.state.isGrounded and not self.stateVars.landedSfx then
      self.stateVars.landedSfx = true
      Audio:playSound ( SFX.gameplay_boss_cable_landing, 1.2 )
      self.sprite:change ( 1, "land-slam-smile-for-intro" )
      self.timer = 90
      self:spawnWaveProjectile(1,  3)
      self:spawnWaveProjectile(-1, 3)

      Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
      Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )

      self.velocity.horizontal.current = 0
      self.velocity.vertical.current   = 0
    end
  end
end

function _MEDLEY:_runAnimation ( )
  if not self.isInState ( self, "PREFIGHT_INTRO" ) then
    self:gotoState ( "PREFIGHT_INTRO" )
    return false
  end
  self.timer = self.timer - 1
  if self.stateVars.first then

    local cx, cy = Camera:getPos()
    self:setActualPos  ( cx + 185, cy + 127 )
    Audio:playSound    ( SFX.gameplay_medley_lights_up      )
    SetTempFlag        ( "medley-boss-prefight-entrance", 2 )
    SetTempFlag        ( "medley-boss-prefight-lights",   1 )
    self.sprite:change ( 1, "battle-intro-show-off", 2, true )
    self.timer            = 100
    self.stateVars.first  = false
    self.state.isGrounded = false
    return false
  end

  if not self.stateVars.jumped then
    if self.timer == 97 then
      Audio:playSound ( SFX.gameplay_medley_wink )
      local mx, my = self:getMiddlePoint()
      local sx     = self.sprite:getScaleX()
      Particles:add ( "wave-note-taunt-particle", mx + (sx < 0 and -23 or 7), my-30, 1, 1, 0, 0, self.layers.sprite()+1 )
    end

    if self.timer == 99 then
      self:activateCrowd ( )
    end

    if self.timer == 95 then
      Audio:playSound    ( SFX.gameplay_medley_crowd_cheer )
    end

    if self.sprite:isPlaying() then
      return false
    end

    if not self.stateVars.jumped then
      Audio:playSound ( SFX.gameplay_boss_cable_jump )
      self.sprite:change ( 1, "ground-slam" )
      SetTempFlag ( "medley-boss-prefight-lights", 2 )
      self.stateVars.jumped              = true
      self.velocity.vertical.current     = -6
      self.velocity.horizontal.current   = 1.5
      self.velocity.horizontal.direction = 1
      return false
    end
  end

  if not self.state.isGrounded then
    return false
  end

  if self.stateVars.landedSfx and self.sprite:getFrame() == 6 and not self.stateVars.smiled then
    Audio:playSound ( SFX.gameplay_medley_wink )
    self.stateVars.smiled = true
    local mx, my = self:getMiddlePoint()
    local sx     = self.sprite:getScaleX()
    Particles:add ( "wave-note-taunt-particle", mx + (sx < 0 and -23 or 7), my-30, 1, 1, 0, 0, self.layers.sprite()+1 )
  end

  if self.timer > 0 or self.sprite:isPlaying() then
    return false
  end

  self:gotoState ( "CUTSCENE" )

  return true
end

function _MEDLEY:_activateCrowd ( )
  --Audio:playSound    ( SFX.gameplay_medley_crowd_cheer, 0.5 )
  self:activateCrowd ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §§S HOP -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _S_HOP = _MEDLEY:addState ( "S_HOP" )

function _S_HOP:enteredState ( spawner )
  self.state.isHittable            = false
  self.state.isBossInvulnerable    = true

  self.SPAWNER_OBJ                 = spawner
  self.USES_PALETTIZED_HAZE_SHADER = true
  self.alwaysUsePaletteShader      = true
  self.BASE_PALETTE                = self.class.PALETTE
  self.ACTIVE_PALETTE              = self.class.PALETTE--Colors.Sprites.ghost -- ACTIVE_PALETTE

  --self:setAfterImagesPalette ( self.class.PALETTE, Colors.Sprites.ghost_after_image )

  self._flashingShader            = true
  self.velocity.vertical.current  = 0.0
  self.velocity.vertical.update   = true
  self.state.isGrounded           = false

  self.stateVars.angryDelay       = 20
  self.timer                      = 80
  self.sprite:flip   ( -1, 1 )
  self.sprite:change ( 1, "preboss-battle-intro-1", 1, false )

  self._emitSmoke = true
  Environment.smokeEmitter ( self )
end

function _S_HOP:exitedState ( )
  self:endAction ( false )
end

function _S_HOP:tick ( )
  self:applyPhysics()

  if self.stateVars.angryDelay > 0 then
    self.stateVars.angryDelay = self.stateVars.angryDelay - 1
    if self.stateVars.angryDelay <= 0 then
      self.sprite:change ( 1, "preboss-battle-intro-1", 2, true )
    end
    return
  end

  if self.state.isGrounded then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      --self:endAction ( true )
      if not self.playerIsKnownToBeAlive then return end
      local px, py, mx, my = self:getLocations()
      self:gotoState ( "DESPERATION_ACTIVATION", px, py, mx, my )
      self.actionsSinceDesperation = -1
    end
  end
end

function _MEDLEY:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 then return end
  local x, y = self:getPos            ( )
  local l    = self.layers.bottom     ( )
  local sx   = self.sprite:getScaleX  ( )

  x = x + love.math.random(0,6)*math.rsign()
  y = y + love.math.random(1,2)
  if sx < 0 then
    x = x + 14
    y = y - 20
  else
    x = x + 14
    y = y - 20
  end

  Particles:addFromCategory ( "warp_particle_medley", x, y,   1,  1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §return              ------------------------]]--
--[[----------------------------------------------------------------------------]]--

return _MEDLEY