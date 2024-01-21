-- Nega, that final stage 1 boss
local _NEGA    = BaseObject:subclass ( "NEGA_UNCAPED" ):INCLUDE_COMMONS ( )
FSM:addState  ( _NEGA, "CUTSCENE"             )
Mixins:attach ( _NEGA, "gravityFreeze"        )
Mixins:attach ( _NEGA, "spawnShards"          )
Mixins:attach ( _NEGA, "bossTimer"            )

_NEGA.static.IS_PERSISTENT     = true
_NEGA.static.SCRIPT            = "dialogue/boss/cutscene_negaConfrontation" 
_NEGA.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-nega"

_NEGA.static.EDITOR_DATA = {
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

_NEGA.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "nega-boss"     )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.obstacles,   "obstacles"     )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "commander"     )
  CutsceneManager.preload   ( _NEGA.SCRIPT                                )

  SetFlag ( "kernel-disappeared" )
end

_NEGA.static.PALETTE             = Colors.Sprites.nega
_NEGA.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_red_than_kai, 
  Colors.hacker_purple_2, 
  Colors.hacker_purple_2, 
  Colors.hacker_purple_1, 
  Colors.hacker_purple_1, 
  Colors.hacker_purple_1
)

_NEGA.static.DIALOGUE_BUBBLE_PALETTE = Colors.Sprites.nega_pink

_NEGA.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_NEGA.static.DIMENSIONS = {
  x            =   9,
  y            =   8,
  w            =  16,
  h            =  24,
  -- these basically oughto match or be smaller than player
  grabX        =  10,
  grabY        =   6,
  grabW        =  14,
  grabH        =  26,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_NEGA.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
  isTile     = false,
}

_NEGA.static.SLIDE_PROPERTIES = {
  isDamaging = false,
  isTile     = false,
}

_NEGA.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
}

_NEGA.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
}

_NEGA.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_NEGA.static.DAMAGE = {
  CONTACT        = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE,
  CONTACT_NORMAL = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE,
  CONTACT_ATTACK = GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE,
}

_NEGA.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_NEGA.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true

function _NEGA:setBossChallengeFlag ( )
  local fl = GetTempFlag ( "nega-boss-challenge-hits" )
  fl       = fl or 0
  fl       = fl + 1
  SetTempFlag ( "nega-boss-challenge-hits" , fl )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:finalize ( parameters )
  RegisterActor ( ACTOR.NEGA, self )
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "nega-boss", 1 )
  self.sprite:addInstance ( 2 )
  self.sprite:addInstance ( 3 )
  self.sprite:addInstance ( 4 )
  self.sprite:addInstance ( 5 )
  self.sprite:addInstance ( 6 )

  self.sprite:addInstance ( "hs-1" )
  self.sprite:addInstance ( "hs-2" )
  self.sprite:addInstance ( "hs-3" )

  self.isFlinchable = false
  self.sprite:change ( 1, "stand-still", 1, true )

  self.beams                = {} 
  self.beamsToCallDown      = 0
  self.beamsToCallDownTimer = 0
  self.actionsWithoutRest   = 0
  self.nextActionTime       = 10
  self.desperationActivated = false
  self.lastResortActivated  = false
  self.fakeoutTimer         = -1

  self.izunaLayer = Layers:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL"    )
  self.hsLayer    = Layers:get ( "STATIC-OBJECTS-FRONT", "PROJECTILES" )

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.sensors = {
    FLOOR_SENSOR_FOR_WALL_JUMPING =
      Sensor
        :new                ( self, self.filters.tile,  -19, 3, 18, 35 )
        :isScaleAgnostic    ( true )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),

    JAB_SENSOR_NORMAL =
      Sensor
        :new                ( self, self.filters.player, -5, -20, 45, 22 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    JAB_SENSOR_EXTENDED =
      Sensor
        :new                ( self, self.filters.player, -5, -20, 52, 22 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    CATCH_INTERRUPT_SHORT     =
      Sensor
        :new                ( self, self.filters.player, -23, -42, 32, 52 )
        :expectOnlyOneItem  ( true ),
    CATCH_INTERRUPT     =
      Sensor
        :new                ( self, self.filters.player, -25, -42, 42, 52 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    CATCH_INTERRUPT_EXTEND     =
      Sensor
        :new                ( self, self.filters.player, -34, -44, 69, 57 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    FLYING_STRIKE = 
      Sensor
        :new ( self, self.filters.player, -19, -25, 28, 22 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    PILEDRIVE_CATCH = 
      Sensor
        :new ( self, self.filters.player, -19, -15, 40, 16 )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
    HOOKSHOT_DASH =
      Sensor
        :new ( self, self.filters.player, -28, -42, 41, 57 )
        :expectOnlyOneItem  ( true ),
  }

  self.HAS_IGNORED_TILES = {}

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "slide_collision", self.dimensions.x, self.dimensions.y+8, self.dimensions.w, self.dimensions.h-8, self.class.SLIDE_PROPERTIES )
  self:addCollider            ( "grabbox", -1,  0, 36,  36, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )
  self:insertCollider         ( "slide_collision" )

  self.defaultStateFromFlinch = nil
  self.hitsSinceLastDodge     = 0
  
  self.state.isBoss  = true
  self.listener      = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)

  self:setShardData          ( "glasses", 4, "glass-shards" )
  self:setShardFrameData     ( "glasses", 6, true, true )
  self:setShardSpawnOffset   ( "glasses", 2, 0 )
  self:setShardCollision     ( "glasses", true )
  self:setShardDustOffset    ( "glasses", -12, 0 )
  self:setShardLayer         ( self.class.LAYERS.gibs, "glasses" )


  local dialAgain = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" )
  local fl        = GetFlag ( "nega-boss-prefight-dialogue" )
  if GAMESTATE.speedrun then
    dialAgain = nil
    fl        = true
  end
  if parameters and parameters.bossRush then
    dialAgain = nil
    fl        = true
    self.state.isBossRushSpawn = true
  end
  if (dialAgain and dialAgain > 0) or (not fl) then
    self.sprite:change ( 1, "nega-cape", 1, true )
    self.sprite:flip   ( 1, 1 )
  else
    self.sprite:change ( 1, "stand-still", 1, true )
    self.sprite:flip   ( -1, 1 )
  end

  self.hitParticleLayer = Layer:get ( "PARTICLES" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Misc                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

-- §activate
function _NEGA:activate ( )
  GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  
  --self.instantDeath = true
  if self.instantDeath then
    self.health      = 1
  else
    self.health      = 48
    GlobalObserver:none ( "BRING_UP_BOSS_HUD", "nega", self.health )
  end
  self.activated   = true
end

function _NEGA:cleanup ( )
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end
  if self.scarf then
    self.scarf:delete ( )
  end
  if self.hookshot then
    self.hookshot:delete ( )
  end
  if self._emittingSmoke then
    Environment.smokeEmitter ( self, true )
  end
  UnregisterActor ( ACTOR.NEGA, self )
end

function _NEGA:isDrawingWithPalette ( )
  return true
end

function _NEGA:specialEndOfBossBehavior ( )
  GlobalObserver:none      ( "FORCE_UNDIM_BACKGROUNDS" )
  CutsceneManager.CONTINUE ( )
  self:delete              ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Animation handling -------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:manageChainAnimation ( )
  if self.state.isLaunched then
    self.sprite:change ( 1, "spin", 1 )
    self.sprite:stop   ( 1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health, self.health <= 1 and not self.lastResortActivated )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _NEGA:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _NEGA:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:getScaleX() > 0 then
    mx = mx - 3
  else
    mx = mx + 1
  end
  return mx, my
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §scarf offsets ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_NEGA.static.SCARF_OFFSETS = {
  ["nega-rising-upper"] = {
    left = {
      [6]  = { 1, 0, foreground = true },
      [7]  = { 1, 0, foreground = true },
      [8]  = { 1, 0, foreground = true },
      [9]  = { 1, 0, foreground = true },
      [10] = { 1, 0, foreground = true },
      [11] = { 1, 0, foreground = true },
      [12] = { 1, 0, foreground = true },
      [13] = { 1, 0, foreground = true },
      universal = { 1, 0, foreground = false },
    },
    right = {
      [6]  = { 3, 0, foreground = true },
      [7]  = { 3, 0, foreground = true },
      [8]  = { 3, 0, foreground = true },
      [9]  = { 3, 0, foreground = true },
      [10] = { 3, 0, foreground = true },
      [11] = { 3, 0, foreground = true },
      [12] = { 3, 0, foreground = true },
      [13] = { 3, 0, foreground = true },
      universal = { 3, 0, foreground = false },
    },
  },
  ["nega-piledriver-start"] = {
    [1] = {-3, 0, foreground = true },
    [2] = {-1, 0, foreground = true },
    [3] = { 0, 0, foreground = true },
  },
  ["nega-piledriver-body-top"] = {
    [1] = { 3, 3, foreground = true  },
    [2] = { 1, 3, foreground = false },
    [3] = { 0, 3, foreground = false },
    [4] = {-1, 3, foreground = false },
    [5] = {-3, 3, foreground = true  },
    [6] = {-1, 3, foreground = true  },
    [7] = { 0, 3, foreground = true  },
  },
}

_NEGA.static.HOOKSHOT_PALETTE = createColorVector ( 
  Colors.virus_purple_1,
  Colors.pink,
  Colors.white,
  Colors.whitePlus,
  Colors.whitePlus,
  Colors.whitePlus
)

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _NEGA:update (dt)
  if not self.scarf then
    -- §§scarf
    local s,h = GlobalObserver:single ( "CREATE_PLAYER_SCARF", self.ID, self, true )
    if s then
      self.scarf = s
      if not s.class.OFFSETS._negaAdded then
        s.class.OFFSETS._negaAdded = true
        for k,v in pairs ( self.class.SCARF_OFFSETS ) do
          s.class.OFFSETS[k] = v
        end
      end
    end
    if h then
      self.hookshot = h
      self.sprite:releaseScaleLockInstance ( 5 )
      self.sprite:releaseScaleLockInstance ( 6 )
      self.sprite:releaseScaleLockInstance ( 7 )
      self.sprite:releaseScaleLockInstance ( 14 )


      self.sprite:flipInstance ( "hs-1", 1, 1 )
      self.sprite:flipInstance ( "hs-2", 1, 1 )
      self.sprite:flipInstance ( "hs-3", 1, 1 )

      self.sprite:scaleLockInstance ( "hs-1" )
      self.sprite:scaleLockInstance ( "hs-2" )
      self.sprite:scaleLockInstance ( "hs-3" )

      self.hookshot:setSpriteInstances ( "hs-1", "hs-2", "hs-3" )
      self.hookshot:setLayers ( 
        Layers:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL"   ), 
        Layers:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )
      )
      self.hookshot.staticPalette = self.class.HOOKSHOT_PALETTE
      self.hookshot.staticCol     = Colors.hacker_purple_1
      self.hookshot:setAltFilter       ( )
      self.hookshot:setPlayerCollision ( )
    end
  end

  if self.fakeoutTimer > 0 then
    self.fakeoutTimer = self.fakeoutTimer - 1

    if self.fakeoutTimer == 19 then
        local mx, my = self:getMiddlePoint("collision")
        local l      = self.layers.sprite()+14
        mx,my = mx + self.velocity.horizontal.current * self.velocity.horizontal.direction,
                my + self.velocity.vertical.current
        GAMESTATE.addFreezeFrames ( 20, Colors.kai_dark_red, mx, my )
        Particles:add ( "beam_palm_purge_explosion", mx,my, 1, 1, 0, 0, l )
      --elseif self.stateVars.finalKillTimer == 15 then
      --  GameObject:startSlowdown ( 1 )
    end

    if self.fakeoutTimer <= 0 then
      GameObject:stopSlowdown ()
    end
  end

  if BUILD_FLAGS.DEBUG_BUILD and UI.kb.isDown ( "d" ) then
    self.desperationActivated = true
  end

  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self:updateBossInvulnerability ( )
  self:updateLocations           ( )

  if self.activated and self:isInState ( nil ) then
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

  self:updateContactDamageStatus  ( )
  self:updateShake                ( )
  self:handleAfterImages          ( )


  ----------------------
  -- NEGA SPECIALTIES --
  ----------------------
  --[[
  if BUILD_FLAGS.DEBUG_BUILD then
    if UI.kb.isDown ( "1" ) then
      self.sprite:flip ( -1, 1 )
    elseif UI.kb.isDown ( "2" ) then
      self.sprite:flip ( 1, 1 )
    elseif UI.kb.isDown ( "3" ) then
      self.health = 0
      self.sprite:change ( 1, "death-kneel", 1, true )
      self:clearShards  ( "glasses"  )
    end
  end]]

  self:updateShards ( "glasses" )

  if not self.activated and self.sprite:getAnimation() == "battle-intro-pose" then
    self.sprite:flip ( -1, 1 )
    if self.sprite:getFrame() == 7 and self.sprite:getFrameTime() == 0 then
      Audio:playSound ( SFX.hud_mission_start_shine, 0.3 )
    end
    if self.sprite:getFrame() == 18 and self.sprite:getFrameTime() == 0 then
      Audio:playSound ( SFX.gameplay_boss_cable_landing )
      local mx, my = self:getPos()
      Particles:addFromCategory ( "landing_dust", mx - 3, my + 21,  1, 1, -0.25, -0.1 )
    end
  end

  if self.health <= 0 then
    if self.sprite:getAnimation() == "death-kneel" and self.sprite:getFrameTime() == 0 then
      local f = self.sprite:getFrame()
      if f == 22 then
        SetStageFlag ( "nega-is-dying-for-real", 1 )
        Audio:playSound ( SFX.gameplay_ice_clink_echo )
        self:spawnShards ( "glasses" )
      elseif f == 7 then
        Audio:playSound ( SFX.gameplay_elec_pole_timer_beep  )
      end
    end
  end

  if self.limp then
    self.limp.sprite:update()

    if self.limp.circuitSpawned then
      self.limp.sineTimer = self.limp.sineTimer + 0.05
      self.limp.sineY     = -math.floor(math.sin(self.limp.sineTimer) * 3)
    end

    if self.limp.emitSmoke then
      self:cutscene_emit_nega_smoke ( )
    end
  end

  self:flowScarf     ( dt )
  self.sprite:update ( dt )

  if self.hookshot then
    self.hookshot:update ( dt )
  end
end

function _NEGA:tick ()
  self:applyPhysics()
end

function _NEGA:flowScarf ( dt, useForeground, movementToUse )
  if not self.scarf or (self.stateVars and self.stateVars.forceScarfFlow) then return end
  if self.isChainedByHookshot then
    self.scarf:update ( 
      dt, 
      0,
      useForeground, 
      self.stateVars and self.stateVars.hookshotActive--self.abilities.hookshot.active == true --[[or self.state.isDashing == true]] 
    )
    return
  end
  if not self.velocity.horizontal.current or not self.velocity.vertical.current then return end
  self.scarf:update ( 
    dt, 
    movementToUse 
      or (math.abs(self.velocity.horizontal.current) 
      + (math.abs(self.velocity.vertical.current))),
    useForeground, 
    self.stateVars and self.stateVars.hookshotActive--self.abilities.hookshot.active == true --[[or self.state.isDashing == true]] 
  )
end

function _NEGA:getOrigin ()
  if not self.state.isGrounded then
    if self.sprite:getScaleX() < 0 then
      return  self:getX() + self.colliders.collision.rect.x + self.colliders.collision.rect.w / 2 - 1 ,
              self:getY() + self.colliders.collision.rect.y + self.colliders.collision.rect.h / 2 + 1
    end
    return  self:getX() + self.colliders.collision.rect.x + self.colliders.collision.rect.w / 2,
            self:getY() + self.colliders.collision.rect.y + self.colliders.collision.rect.h / 2 - 2
  end
  return self:getX() + self.colliders.collision.rect.x + self.colliders.collision.rect.w / 2,
         self:getY() + self.colliders.collision.rect.y + self.colliders.collision.rect.h / 2 - 3
end

function _NEGA:extraHookshotSpawnHandler (x,y)
  if not self.state.isGrounded then
    if self.sprite:getScaleX() < 0 then
      return x-1,y+1
    end
    return x,y-2
  end
  return x,y-3
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
_NEGA.static.ACTIONS = {
  "DESPERATION_ACTIVATION",        -- 1, implemented
  "LAST_RESORT",                   -- 2, implemented, just missing chained bursts after the fact, or at least piledriver
  "RUN_UP",                        -- 3, implemented, can lead to either JABS or DIVEKICK, depending on situation
  "DIVEKICK",                      -- 4, implemented
  "SLIDE",                         -- 5, implemented
  "HOOKSHOT",                      -- 6, implemented
  "CATCH_INTERRUPT",               -- 7, implemented
  "RISING_UPPER",                  -- 8, implemented
  "FLYING_STRIKE",                 -- 9, implemented
  "HEAVENLY_PILEDRIVER_APPROACH",  -- 10, implemented, essentially checks distance to player, and does either dodge_hop or heavenly_piledriver from the word go
  "GRAB_AND_THROW",                -- 11, implemented
  "DODGE_HOP",                     -- 12, implemented
  --"JABS",                        -- 13, implemented, should not be called directly, instead follows up from RUN_UP
}

_NEGA.static.SPECIALS = {
  [1]  = true,
  [2]  = true,
  [7]  = true,
  [8]  = true,
  [9]  = true,
  [10] = true,
}

function _NEGA:pickAction (recursion, px, py, mx, my)
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 10
      return
    end
  end
  local cx                = Camera:getX()
  local action, extra     = 0, nil
  local chance            = RNG:getPercent ()

  if self.forceDesperation then
    action                = 1
    self.forceDesperation = false
  elseif self.forceLastResort then
    action                = 2
    self.forceLastResort  = false
  end

  if not self.actionList then
    self.actionList  = { 3, 4, 5, 6, 11, 3, 4 }
    self.specialList = { 8, 9, 10 }
  end

  local forcedForced = false
  if self.lastActionWasBurst then
    self.forceBurst         = true
    self.lastActionWasBurst = false
    self.actionsSinceBurst  = 1
    forcedForced            = true
  else
    if self.lastResortActivated then
      if not self.actionsSinceBurst then
        self.actionsSinceBurst = 0
      end
      self.actionsSinceBurst = self.actionsSinceBurst + 1
      if self.actionsSinceBurst > 3 then
        self.forceBurst = RNG:n() < (0.15 + (self.actionsSinceBurst-3)*0.15)
        if self.forceBurst then
          self.actionsSinceBurst = self.actionsSinceBurst - 3
        end
      end
    end
  end

  if self.forceBurst then
    self.forceBurst = false
    if math.abs(px - mx) < 62 and self.hitFlash.current <= 0 and RNG:n() < 0.4 then
      action = 7
    else
      action = table.remove ( self.specialList, RNG:range ( 1, #self.specialList ) )
      if #self.specialList <= 0 then
        self.specialList = { 8, 9, 10 }
      end
    end
    if not forcedForced then
      self.lastActionWasBurst = true
    end
  end

  if not self.class.SPECIALS[action] then
    if not self.firstActionTaken then
      action = RNG:n() < 0.5 and 3 or 4
      self.firstActionTaken = true
    else
      action = table.remove ( self.actionList, RNG:range ( 1, #self.actionList ) )
      --if action == 6 then
      --  action = RNG:n() < 0.5 and 11 or 6
      --end
      if #self.actionList <= 0 then
        self.actionList = { 3, 4, 5, 6, 11, 3, 4 }
      end
    end
  end

  -- force dodge
  if not self.class.SPECIALS[action] and self.lastAction ~= 12 and math.abs(px - mx) < 62 then
    if self.hitsSinceLastDodge > 0.075 and RNG:n() < (0.30 + self.hitsSinceLastDodge) then
      self.hitsSinceLastDodge = 0
      action = 12
    end
  end

  --action = 11
  --if self.lastAction == 11 then
  --  action = 3
  --end

  -- prevent grab&throw and hookshot next to walls
  if action == 11 or action == 6 then
    local cx = Camera:getX()
    if (mx < (cx + 60)) or (mx > (cx + GAME_WIDTH -60)) then
      action = RNG:n() < 0.5 and 3 or 4
    end
  end

  self.hitsSinceLastDodge = self.hitsSinceLastDodge + 0.025
  self.lastAction         = action

  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end

  self.wentAbove = false
end

function _NEGA:endAction ( finishedNormally, forceWait, clearActions )
  if clearActions then
    self.actionsWithoutRest = 0
  end
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest < 3 and not forceWait then
      self.nextActionTime     = self.desperationActivated and 6 or 6
    else
      self.nextActionTime     = self.desperationActivated and 6 or 6
      self.actionsWithoutRest = 0
    end

    if self.lastResortActivated then
      self.nextActiontime = self.nextActionTime - 4
    end

    if GAMEDATA.isHardMode() then
      self.nextActionTime = self.nextActionTime - 1
    end
  end
end

function _NEGA:getLocations ()
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _NEGA:updateLocations()
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

function _NEGA:handleYBlock(_,__,currentYSpeed)
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
    Particles:addFromCategory ( "landing_dust", cx + 24, cy + 21, -1, 1,  0.25, -0.1 )
  end

  if lenL > 0 then
    Particles:addFromCategory ( "landing_dust", cx - 4, cy + 21,  1, 1, -0.25, -0.1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §loop collisions     ------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _NEGA:loopCollisions ( cols, len )
  for i = 1, len do
    if cols[i] and cols[i].other and cols[i].other.isPlayer then
      if cols[i].other.parent and (not cols[i].other.parent.lastTimeTookDamage or (cols[i].other.parent.lastTimeTookDamage + 3 > GetLevelTime())) then
        return true
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §set attack overlay  ------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _NEGA:setAttackOverlay ( instance, regularOverlay, extendedOverlay )
  if self.desperationActivated then
    self.sprite:change ( instance, extendedOverlay or "jab-overlay-extended", 1 )
  else
    self.sprite:change ( instance, regularOverlay or "jab-overlay", 1  )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _NEGA:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _NEGA:addState ( "DESPERATION_ACTIVATION" )

function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )
  self.timer            = 0
  self.stateVars.equips = { 3, --[[12,]] 14, 16 }
  self.stateVars.index  = 0

  self.sprite:change ( 1, "desperation-offer", 2, true )
  self.stateVars.appeared = false
  self.isBursting         = true
end

function _DESPERATION_ACTIVATION:exitedState ()
  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false

  self:permanentlyDisableContactDamage ( false )

  self.desperationActivated     = true
  self.isBursting               = false
end

function _DESPERATION_ACTIVATION:tick ()
  self.timer = self.timer + 1

  if not self.stateVars.appeared and self.sprite:getFrame() == 2 and self.sprite:getFrameTime() == 0 then
    self.sprite:change ( 3, "desperation-chip-appear", 1, true )
    self.stateVars.appeared = true
  end

  if self.timer >= 45 then
    if self.stateVars.index < #self.stateVars.equips then
      if not self.stateVars.disappeard then
        self.stateVars.disappeard = true
        self.sprite:change ( 3, "desperation-chip-disappear", 1, true )
      end
      self.sprite:change ( 1, "equip",       2, true )
      --if self.stateVars.index == 0 then
        self.sprite:change ( 2, "equip-shine", 2, true )
      --end
      self.timer           = 0
      self.stateVars.index = self.stateVars.index + 1
      UI.specialEquippableNotification ( self.stateVars.equips[self.stateVars.index] ) 
      Audio:playSound                  ( SFX.gameplay_repair_done )
    else
      self:endAction ( true )
    end
  end

  self:applyPhysics()
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Last resort        -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _LRESORT = _NEGA:addState ( "LAST_RESORT" )

function _LRESORT:enteredState ( px, py, mx, my )
  self.forceLastResort = false
  self.timer           = 0

  local val = GetStageFlag ("nega-faked-death-in-boss")
  if self.state.isBossRushSpawn then
    val = 1
  end

  if not val or val ~= 1 then
    SetStageFlag ( "nega-faked-death-in-boss", 1 )
    self.stateVars.timeToWait = 150
  else
    self.stateVars.timeToWait = 93
  end

  self:setGrabbableStatus ( false )
  self.isBursting = true
end

function _LRESORT:exitedState ( )
  self:setGrabbableStatus              ( true )
  self:permanentlyDisableContactDamage ( false )

  self.state.isHittable         = true
  self.state.isBossInvulnerable = false
  self.desperationActivated     = true
  self.lastResortActivated      = true
  self.isBursting               = false
end

function _LRESORT:tick ( )
  self.timer = self.timer + 1
  if self.timer == 10 then
    self.sprite:change ( 1, "death-kneeling-fake", 2, true )
  elseif self.timer == self.stateVars.timeToWait then
    self.sprite:change ( 1, "last-resort-end",         2, true )
    self.sprite:change ( 5, "last-resort-end-overlay", 2, true )
    local mx, my = self:getMiddlePoint()
    local omx, omy = mx, my
    mx, my = mx - 2*self.sprite:getScaleX(), my-9
    Particles:addSpecial ( "super_flash", mx, my, self.layers.bottom(), self.layers.bottom()+2, false, omx, omy )

    if not (GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush) then
      Audio:playTrack       ( BGM.boss_final_stage_1_phase_2 )
      Audio:fadeMusicVolume ( 1, 1 )
    end

    self._halfPipHealth = nil
    GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
    local health = GlobalObserver:single ( "FILL_HEALTH_BAR_FOR_BOSS", 1 )
    self.health  = 32

    GlobalObserver:none         ( "SUPER_FLASH_START", self )
    GlobalObserver:none         ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_nega", 9 )
    Environment.smokeEmitter    ( self )
    self._emittingSmoke = true
    GoalTracker:unsetGoalReach  ( )
  elseif self.timer == self.stateVars.timeToWait+10 then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end

  if self.sprite:getAnimation() == "land" and not self.stateVars.landingDust then
    self:handleYBlock(nil,nil,3)
    self.stateVars.landingDust = true
    Audio:playSound ( SFX.gameplay_boss_cable_landing )
  end

  if self.timer >= self.stateVars.timeToWait+25 then
    self:spawnBossMidpointRewards ( )
    --[[
    local n = RNG:n()
    local px, py, mx, my = self:getLocations ( )
    if n < 0.5 then
      self:gotoState ( "RISING_UPPER",  px, py, mx, my )
    else
      self:gotoState ( "FLYING_STRIKE", px, py, mx, my )
    end]]

    local px, py, mx, my = self:getLocations ( )
    self:gotoState ( "FLYING_STRIKE", px, py, mx, my )
    self.risingUpperAfter       = true
    self.burstPiledriverAfter   = true
    return
    --self:endAction ( true )
  end

  if self.sprite:getAnimation() == "death-kneeling-fake" then
    if self.sprite:getFrame() == 13 and self.sprite:getFrameTime() == 0 then
      Audio:playSound ( SFX.hud_mission_start_shine, 0.3 )
      Audio:playSound ( SFX.gameplay_boss_cable_landing )
      local mx, my = self:getPos()
      if self.sprite:getScaleX() < 0 then
        Particles:addFromCategory ( "landing_dust", mx + 29, my + 21,  -1, 1, 0.25, -0.1 )
      else
        Particles:addFromCategory ( "landing_dust", mx - 8, my + 21,   1, 1, -0.25, -0.1 )
      end
    end
  end

  self:applyPhysics ( )
end

function _NEGA:env_emitSmoke ( )
  if GetTime() % 12 > 0 then return end
  local mx,my = self:getMiddlePoint   ( )
  local sx    = self.sprite:getScaleX ( )
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

function _LRESORT:takeDamage ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §run up              ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _RUN_UP = _NEGA:addState ( "RUN_UP" )
function _RUN_UP:enteredState ( px, py, mx, my )
  self.timer = 0

  local dir = px < mx and -1 or 1
  self.sprite:flip                   ( dir )
  self.velocity.horizontal.direction = dir

  self.sprite:change ( 1, "sprint", 2, true )
end

function _RUN_UP:exitedState ( )
  self.class.DAMAGE.CONTACT        = self.class.DAMAGE.CONTACT_NORMAL
  self.velocity.horizontal.current = 0

  self:setAfterImagesEnabled ( false )
  self:endAction             ( false )
end

function _RUN_UP:tick ( )
  self.timer = self.timer + 1

  if not self.stateVars.started then
    local t = (self.desperationActivated and 18 or 28)
    if GAMEDATA.isHardMode() then
      t = t - 3
    end
    if self.lastResortActivated then
      t = t - 6
    end
    if self.timer > (self.desperationActivated and 16 or 30) then
      self.sprite:change ( 1, "sprint", 6, true )
      Audio:playSound ( SFX.gameplay_sprint_start )
      self.stateVars.started           = true
      self.velocity.horizontal.current = 1
      self.timer                       = 0
      self.stateVars.dustTimer         = 0

      self:setAfterImagesEnabled ( true )
      Particles:addFromCategory  ( "slide_start_dust", self:getX()+10*self.sprite:getScaleX()*-1, self:getY()+10, self.sprite:getScaleX(), 1, 0,0, self.layers.particles()  )

      if self.desperationActivated then
        self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_ATTACK
      end
    end
  elseif not self.stateVars.jabsStarted and not self.stateVars.bonk then

    if self.desperationActivated then
      self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_ATTACK
    end

    local f = self.sprite:getCurrentFrame()
    if f == 10 or f == 14 then
        if not self.stateVars.sfxPlayed then
        self.stateVars.sfxPlayed = true
        Audio:playSound ( SFX.gameplay_footstep )
      end
    else
      self.stateVars.sfxPlayed = false
    end

    if self.stateVars.dustTimer <= 0 then
      local sx = self.sprite:getScaleX()
      if sx < 0 then
        Particles:addFromCategory ( 
          "dust_ball", 
          self:getX()+23, 
          self:getY()+15, 
          self.sprite:getScaleX(), 
          1, 
          0.4*self.sprite:getScaleX(), 
          -0.03 - self.velocity.horizontal.current / 20,
          self.layers.particles()
        )
      else
        Particles:addFromCategory ( 
          "dust_ball", 
          self:getX()-15, 
          self:getY()+15, 
          self.sprite:getScaleX(), 
          1, 
          0.4*self.sprite:getScaleX(), 
          -0.03 - self.velocity.horizontal.current / 20,
          self.layers.particles()
        )
      end
      self.stateVars.dustTimer = 6
    else
      self.stateVars.dustTimer = self.stateVars.dustTimer - 1
    end

    local px, py, mx, my = self:getLocations ( )
    local cx             = Camera:getX       ( )
    if math.abs ( px - mx ) < 40 and self.timer > (self.desperationActivated and 16 or 10) then
      self:gotoState ( "JABS" )
    else
      if self.velocity.horizontal.direction < 0 and mx < cx + 84 then
        self:gotoState ( "DIVEKICK", px, py, mx, my, false, self.velocity.horizontal.direction, 3, -5 )
      elseif self.velocity.horizontal.direction > 0 and mx > (cx + GAME_WIDTH - 84) then
        self:gotoState ( "DIVEKICK", px, py, mx, my, false, self.velocity.horizontal.direction, 3, -5 )
      else
        local maxspeed = 6
        if self.lastResortActivated then
          maxspeed = 10
        elseif self.desperationActivated then
          maxspeed = 8
        end
        if GAMEDATA.isHardMode() then
          maxspeed = maxspeed + 0.5
        end
        self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.5, maxspeed )
      end
    end
  end

  self:applyPhysics ( )

  if _RUN_UP.hasQuitState ( self ) then return end

  if self.desperationActivated and self.stateVars.started and not self.stateVars.bonk then
    self.sprite:change ( 2, "sprint-overlay" )
  end

  if self.stateVars.bonk then
    if not self.stateVars.bonkHopped then
      local px, py = self:getLocations ()
      py = py - 8
      Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

      self.sprite:change ( 1, "speedbasher-bonk", 1, true )
      Audio:playSound ( SFX.gameplay_punch_hit )
      self.stateVars.bonkHopped          = true
      self.velocity.horizontal.direction = -self.velocity.horizontal.direction
      self.velocity.horizontal.current   = 1.5
      self.velocity.vertical.current     = -3.5
      self.state.isGrounded              = false
      self:setAfterImagesEnabled ( false )
    elseif self.state.isGrounded then
      self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_NORMAL
      self.velocity.horizontal.current = 0
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.sprite:change ( 1, "land", 1, true )
      self:endAction     ( true )
    elseif self.velocity.vertical.current > 0 then
      self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_NORMAL
    end
  end
end

function _RUN_UP:handleCollisions ( colsX, lenX, colsY, lenY )
  if _RUN_UP.hasQuitState ( self ) or not self.stateVars.started or not self.desperationActivated then return end
  if lenX > 0 and self:loopCollisions ( colsX, lenX ) then
    self.stateVars.bonk = true
    return
  end
  if lenY > 0 and self:loopCollisions ( colsY, lenY ) then
    self.stateVars.bonk = true
    return
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §jabs                ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _JABS = _NEGA:addState ( "JABS" )
function _JABS:enteredState ( )

  self.stateVars.jabsMax = self.desperationActivated and 3 or 3

  Audio:playSound ( SFX.gameplay_punch )
  self.sprite:change ( 1, "jab-1", 2, true )
  self.timer                 = 0
  self.stateVars.jabs        = 1
  self.stateVars.jabsStarted = true
end

function _JABS:exitedState ( )
  self:endAction     ( false )
  self.sprite:change ( 2, nil )
  self.sprite:change ( 3, nil )
end

function _JABS:tick ( )
  self.timer                       = self.timer + 1
  if not self.stateVars.hopkicking then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.5, 0 )
  else
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, 0 )
  end

  if not self.stateVars.stopJabs then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.5, 0 )
    if self.stateVars.jabs % 2 == 1 then
      if self.timer == 2 then
        self:setAttackOverlay ( 2 )
        self.stateVars.jabHit = false
      elseif self.sprite:getFrame() == (6 - (self.desperationActivated and 1 or 0)) and self.sprite:getFrameTime() == 0 then
        self.stateVars.jabs = self.stateVars.jabs + 1
        if self.stateVars.jabs <= (self.stateVars.jabsMax - (self.stateVars.hitConfirm and 1 or 0)) then
          Audio:playSound ( SFX.gameplay_punch )
          self.sprite:change ( 1, "jab-2", 2, true )
          self.timer          = 0
          local sx = self.sprite:getScaleX()
          GameObject:spawn ( 
            "laser_beam", 
            self:getX()+(sx < 0 and 0 or 31), 
            self:getY()+17, 
            sx < 0 and 4 or 6,
            180
          )
          GameObject:spawn ( 
            "laser_beam", 
            self:getX()+(sx < 0 and 7 or 24), 
            self:getY()+27, 
            sx < 0 and 4 or 6,
            180
          )
          GameObject:spawn ( 
            "laser_beam", 
            self:getX()+(sx < 0 and 7 or 24), 
            self:getY()+7, 
            sx < 0 and 4 or 6,
            180
          )
        else
          self.stateVars.stopJabs = true
          self.timer              = 4
        end
      end
    else
      if self.timer == 2 then
        self:setAttackOverlay ( 3 )
        self.stateVars.jabHit = false
      elseif self.sprite:getFrame() == (5 - (self.desperationActivated and 1 or 0)) and self.sprite:getFrameTime() == 0 then
        self.stateVars.jabs = self.stateVars.jabs + 1
        if self.stateVars.jabs <= (self.stateVars.jabsMax - (self.stateVars.hitConfirm and 1 or 0)) then
          Audio:playSound ( SFX.gameplay_punch )
          self.sprite:change ( 1, "jab-1", 2, true )
          self.timer          = 0
        else
          self.stateVars.stopJabs = true
          self.timer              = 6
        end
      end
    end
  elseif self.stateVars.hitConfirm then
    -- hop kick
    local t  = (self.desperationActivated and 6 or 8)
    local th = (self.desperationActivated and 12 or 15)
    local tc = 27
    if self.lastResortActivated then
      t  = 5
      th = 10
      tc = 24
    end
    if self.timer == t then
      self.sprite:change ( 1, "hop-kick", 1, true )
      self:setAttackOverlay ( 3, "hop-kick-overlay", "hop-kick-overlay-extended" )
    elseif self.timer == th then
      Audio:playSound ( SFX.gameplay_punch )
      self.velocity.vertical.current     = -3.75
      self.velocity.horizontal.direction = self.sprite:getScaleX ()
      self.velocity.horizontal.current   = 2.0
      self.stateVars.hopkicking          = true
    elseif self.desperationActivated and self.stateVars.hopkickHit and not self.stateVars.crescent and self.timer >= tc then
      self.stateVars.hopkickHit = false
      self.stateVars.crescent   = true
      self.velocity.horizontal.current   = 2.0
      self.sprite:change    ( 1, "crescent-kick", 1, true )
      self:setAttackOverlay ( 3, "crescent-kick-overlay", "crescent-kick-overlay-extended" )
      self.velocity.vertical.current = -1.5
      GameObject:spawn ( 
        "virus_engineer_grenade",
        self:getX()+20, 
        self:getY()-10,
        1,
        -2,
        -2.0
      )
    end
  else
    if self.sprite:getAnimation() == "idle" then
      self:endAction ( true )
    end
  end

  if self.timer >= 3 and self.timer <= 6 and not self.stateVars.jabHit then
    local s = self.desperationActivated and self.sensors.JAB_SENSOR_EXTENDED or self.sensors.JAB_SENSOR_NORMAL
    local hit, obj = s:check ( )
    if hit and obj then
      if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO, self.sprite:getScaleX(), false, -2.0, nil, self.stateVars.hitConfirm ~= true ) then
        if self.stateVars.hitConfirm then
          Audio:playSound ( SFX.gameplay_punch_hit_stunned )
        end

        if obj.parent.landCausesLandStop then
          obj.parent:landCausesLandStop ( )
        end

        local px, py = obj.parent:getMiddlePoint ()
        py = py - 8
        Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

        Audio:playSound ( SFX.gameplay_punch_hit )
        GAMESTATE.addFreezeFrames ( 2 )
        self.stateVars.jabHit     = true
        self.stateVars.hitConfirm = true

        self:disableContactDamage  ( 16 )
      end
    end
  elseif self.timer > 14 and self.stateVars.hopkicking and not self.stateVars.hopkickHit then
    local s = self.desperationActivated and self.sensors.JAB_SENSOR_EXTENDED or self.sensors.JAB_SENSOR_NORMAL
    local hit, obj = s:check ( )
    if hit and obj then
      self.stateVars.hopkickHit = true
      if not self.desperationActivated or self.stateVars.crescent then
        if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO, self.sprite:getScaleX(), true, -4, 2 ) then
          Audio:playSound ( SFX.gameplay_punch_hit )
          GAMESTATE.addFreezeFrames ( 2 )
          Audio:playSound ( SFX.gameplay_punch_hit_stunned )

          if obj.parent.setSpinAnimation then
            obj.parent:setSpinAnimation ( )
          end
          local px, py = obj.parent:getMiddlePoint ()
          py = py - 8
          Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )
        end
      else
        if self.desperationActivated then
          if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO, self.sprite:getScaleX(), false, -3.5, 1.0 ) then
            Audio:playSound ( SFX.gameplay_punch_hit )
            self:disableContactDamage  ( 16 )
            GAMESTATE.addFreezeFrames ( 2 )
            Audio:playSound ( SFX.gameplay_punch_hit_stunned )

            if obj.parent.setSpinAnimation then
              obj.parent:setSpinAnimation ( )
            end

            local px, py = obj.parent:getMiddlePoint ()
            py = py - 8
            Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )
          end
        else
          if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO, self.sprite:getScaleX(), true, -3.5, 2 ) then
            Audio:playSound ( SFX.gameplay_punch_hit )
            self:disableContactDamage  ( 16 )
            GAMESTATE.addFreezeFrames ( 2 )
            Audio:playSound ( SFX.gameplay_punch_hit_stunned )

            if obj.parent.setSpinAnimation then
              obj.parent:setSpinAnimation ( )
            end

            local px, py = obj.parent:getMiddlePoint ()
            py = py - 8
            Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )
          end
        end
      end
    end
  end

  self:applyPhysics ( )

  if _JABS.hasQuitState ( self ) then return end

  if self.state.isGrounded and not self.stateVars.hitConfirm and not self.stateVars.hopkicking and self.hitFlash.current > 0 then
    if not self.stateVars.pickedDodge then
      self.stateVars.pickedDodge = true
      if RNG:n() < 0.50 then
        local px, py, mx, my = self:getLocations ()
        self:gotoState ( "DODGE_HOP", px, py, mx, my )
        return
      end
    end
  elseif self.hitFlash.current <= 0 then
    self.stateVars.pickedDodge = false
  end

  if self.stateVars.hopkicking and self.state.isGrounded then
    self.velocity.horizontal.current = 0
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )
  end
end

function _JABS:env_emitSmoke ( )
  if GetTime() % 12 > 0 then return end
  local mx,my = self:getMiddlePoint   ( )
  local sx    = self.sprite:getScaleX ( )
  if sx < 0 then
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx-19, 
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
      mx-7, 
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

function _JABS:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §divekick            ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DIVEKICK = _NEGA:addState ( "DIVEKICK" )
function _DIVEKICK:enteredState ( px, py, mx, my, toWallJump, dirX, velX, velY )

  if toWallJump then
    self:wallJump()
  elseif velX and velY then

    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    self.sprite:flip ( dirX )
    self.velocity.horizontal.direction  = dirX
    self.velocity.horizontal.current    = velX
    self.velocity.vertical.current      = velY

    self.stateVars.instantWallJump = true

    self:setAfterImagesEnabled ( true )
    self:disableContactDamage  ( 10   )

    self.sprite:change ( 1, "jump", 3, true )
  else

    local high = py < (Camera:getY() + 100)

    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    local dif = math.abs(mx - px)
    local dir = mx > px and -1 or 1
    dif       = dif / 41
    dif       = dif - (dif % 0.25) +.5

    self.sprite:flip ( dir )
    self.velocity.vertical.current      = high and -8.5 or -6
    self.velocity.horizontal.direction  = dir
    self.velocity.horizontal.current    = dif
    self:setAfterImagesEnabled ( true )
    self:disableContactDamage  ( 10   )

    self.sprite:change ( 1, "jump", 3, true )
  end

  self.timer = 0
end

function _DIVEKICK:exitedState ( )

  self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_NORMAL

  self:setAfterImagesEnabled ( false )
  self.velocity.vertical.current              = 0
  self.velocity.horizontal.current            = 0
  self.velocity.vertical.gravity.acceleration = 0.25
  self.velocity.vertical.update               = true

  self.sprite:change ( 2, nil )
  self.sprite:change ( 3, nil )

  self:endAction ( false )
  self.nextActionTime = self.nextActionTime + 2
end

function _DIVEKICK:tick ( )
  self.timer = self.timer + 1

  if self.stateVars.wallJumped then
    if self.stateVars.wallJumped == 16 then
      self.sprite:change ( 1, "wall-jump" )
    end
    self.stateVars.wallJumped = self.stateVars.wallJumped - 1
    if self.stateVars.wallJumped <= 0 then
      if self.desperationActivated then
        self.sprite:change ( 1, "divekick-down", 1, true )
      else
        self.sprite:change ( 1, "divekick-down-long", 1, true )
      end
      Audio:playSound ( SFX.gameplay_boss_cable_jump )
      self.velocity.horizontal.direction          = self.velocity.horizontal.direction * -1
      self.velocity.horizontal.current            = 2.25
      self.velocity.vertical.gravity.acceleration = 0.25
      self.velocity.vertical.current              = -4.5
      self.stateVars.wallJumped                   = false
      self.stateVars.divekicked                   = true
    end
  elseif not self.stateVars.divekicked then
    if self.velocity.vertical.current > 2 then
      local px, py, mx, my = self:getLocations ( )
      if math.abs ( px - mx ) < 48 then
        if self.desperationActivated then
          self.sprite:change ( 1, "divekick-down", 1, true )
        else
          self.sprite:change ( 1, "divekick-down-long", 1, true )
        end
        Audio:playSound ( SFX.gameplay_boss_cable_jump )
        --self.velocity.horizontal.direction          = self.velocity.horizontal.direction * -1
        self.velocity.horizontal.current            = 1.25
        self.velocity.vertical.gravity.acceleration = 0.25
        self.velocity.vertical.current              = -4.5
        self.stateVars.wallJumped                   = false
        self.stateVars.divekicked                   = true
      end
    elseif self.velocity.vertical.current > 0 then
      self.sprite:change ( 1, "fall" )
    end
  elseif not self.stateVars.divekickActivated then
    local f = self.desperationActivated and 11 or 15
    if self.sprite:getFrame() == f and self.sprite:getFrameTime() == 0 then
      self.stateVars.divekickActivated = true
      Audio:playSound ( SFX.gameplay_punch )
      GameObject:spawn (
        "boss_commander_oval_bomb",
        self:getX()+10,
        self:getY()+10,
        3,
        self.projectileLayer
      )

      self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_ATTACK
      local px, py, mx, my = self:getLocations ( )

      if self.lastResortActivated then
        self.velocity.vertical.current = self.velocity.vertical.gravity.maximum + 2.25
      elseif self.desperationActivated then
        self.velocity.vertical.current = self.velocity.vertical.gravity.maximum + 1.75
      else
        self.velocity.vertical.current = self.velocity.vertical.gravity.maximum + 1.25
      end

      self.velocity.vertical.current = self.velocity.vertical.gravity.maximum + 1.25
      self.velocity.vertical.update  = false
      if math.abs ( px - mx ) < 32 then
        self.sprite:change ( 1, "divekick-down", 12, true )
        self.sprite:change ( 2, "divekick-down-overlay-tip" )
        self.sprite:change ( 3, "divekick-down-overlay" )
        self.stateVars.overlay             = 1
        self.velocity.horizontal.current   = 0
        self.velocity.horizontal.direction = 0
      --elseif math.abs ( px - mx ) < 64 then
      else
        self.sprite:change ( 1, "divekick-forward", 12, true    )
        self.sprite:change ( 2, "divekick-forward-overlay-tip"  )
        self.sprite:change ( 3, "divekick-forward-overlay"      )

        self.velocity.horizontal.direction = (px < mx) and -1 or 1
        self.sprite:flip ( self.velocity.horizontal.direction )
        self.stateVars.overlay             = 2

        if self.lastResortActivated then
          self.velocity.horizontal.current   = 5
        elseif self.desperationActivated then
          self.velocity.horizontal.current   = 4.5
        else
          self.velocity.horizontal.current   = 4
        end
      end
      --[[
      else
        self.sprite:change ( 1, "divekick-forward", 12, true    )
        self.sprite:change ( 2, "divekick-forward-overlay-tip"  )
        self.sprite:change ( 3, "divekick-forward-overlay"      )

        self.velocity.horizontal.direction = (px < mx) and -1 or 1
        self.sprite:flip ( self.velocity.horizontal.direction )
        self.stateVars.overlay             = 2
        self.velocity.horizontal.current   = 5.5
      end]]
    end
  elseif not self.stateVars.divekickHit then
    if not self.sprite:getAnimation(3) then
      self.sprite:change ( 3, self.stateVars.overlay == 2 and "divekick-forward-overlay" or "divekick-down-overlay" )
    end
  else
    if self.velocity.vertical.current > 0 then
      self.sprite:change ( 1, "fall" )
    end
  end

  self:applyPhysics ( )

  if _DIVEKICK.hasQuitState ( self ) then return end

  if self.state.isGrounded then
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )
  elseif self.stateVars.divekickHit then
    if not self.stateVars.handledHit then
      local px, py = self:getLocations ()
      py = py - 8
      Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

      self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_NORMAL
      self.stateVars.handledHit = true
      self.sprite:change ( 1, "double-jump" )
      self.sprite:change ( 2, nil )
      self.sprite:change ( 3, nil )
      self.velocity.vertical.current   = -4.5
      self.velocity.horizontal.current = 1.5
      self.velocity.vertical.update    = true
      Audio:playSound ( SFX.gameplay_punch_hit )
      self:setAfterImagesEnabled ( false )
    end
  end
end

function _DIVEKICK:handleXBlock ( )
  if (self.timer < 10 and not self.stateVars.instantWallJump) or self.stateVars.divekicked then return end
  if not self.stateVars.wallJumped and (self.velocity.vertical.current < 5.0 or self.stateVars.instantWallJump) then
    if self.stateVars.instantWallJump or not self.sensors.FLOOR_SENSOR_FOR_WALL_JUMPING:check() then
      self:wallJump()
    end
  end
end

function _DIVEKICK:handleCollisions ( colsX, lenX, colsY, lenY )
  if not self.stateVars.divekickActivated then return end
  if lenX > 0 and self:loopCollisions ( colsX, lenX ) then
    self.stateVars.divekickHit = true
    return
  end
  if lenY > 0 and self:loopCollisions ( colsY, lenY ) then
    self.stateVars.divekickHit = true
    return
  end
end

function _DIVEKICK:wallJump ()
  self.sprite:change ( 1, "wall-jump", 1 )
  self.stateVars.instantWallJump = false
  self.stateVars.wallJumped = 16
  self.velocity.vertical.gravity.acceleration = 0
  self.velocity.vertical.current              = 0
  self.velocity.horizontal.current            = 0
  self.sprite:mirrorX()
  self:setAfterImagesEnabled(false)
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §slide               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SLIDE = _NEGA:addState ( "SLIDE" )
function _SLIDE:enteredState ( px, py, mx, my )
  local dir = px < mx and -1 or 1

  self.sprite:flip   ( dir )
  self.sprite:change ( 1, "crouch", 1, true )

  self.velocity.horizontal.direction        = dir

  self.colliders.collision.isDamaging       = false
  self.colliders.slide_collision.isDamaging = true

  self.timer           = 0
end

function _SLIDE:exitedState ( )
  self.class.DAMAGE.CONTACT                 = self.class.DAMAGE.CONTACT_NORMAL
  self.colliders.collision.isDamaging       = true
  self.colliders.slide_collision.isDamaging = false
  self.colliders.current                    = self.colliders.collision

  self:setAfterImagesEnabled  ( false )
  self.scarf:setOriginChange  ( true  )
  self:endAction              ( false )
end

function _SLIDE:tick ( )
  self.timer = self.timer + 1
  if not self.stateVars.started then
    local t = (self.desperationActivated and 24 or 26)
    if GAMEDATA.isHardMode() then
      t = t - 3
    end
    if self.lastResortActivated then
      t = t - 3
    end
    if self.timer > t then
      self.sprite:change ( 1, "slide-start", 4, true )
      self:startSlide    ( )
      self.stateVars.started = true
    end
  else
    self.stateVars.timer = self.stateVars.timer - 1
    if self.stateVars.timer > 5 then
      --...
      local slideVel = self.desperationActivated and 5.0 or 4.75
      if self.lastResortActivated then
        slideVel = 5.5
      end

      if self.stateVars.SlideVelocity < slideVel then
        self.stateVars.SlideVelocity = self.stateVars.SlideVelocity + self.stateVars.SlideDeaccel * 2
      end
    else 
      if self.stateVars.SlideVelocity < 1.5 then
        self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_NORMAL
      end
      if self.stateVars.SlideVelocity > 0 then
        self.stateVars.SlideVelocity = self.stateVars.SlideVelocity - self.stateVars.SlideDeaccel
      else
        if not self.stateVars.FinishedSlide then
          self.sprite:change ( 1, "slide-end" )
          self.stateVars.FinishedSlide = true
          self:setAfterImagesEnabled(false)
          self.colliders.current = self.colliders.collision
        elseif self.stateVars.timer < -3 and self.desperationActivated and not self.stateVars.reslid and not self.stateVars.bonkedThisSlide then
          self.sprite:change ( 1, "slide-start", 3, true )
          self.stateVars.reslid = true
          self:startSlide ( )
        end
      end
    end

    self.velocity.horizontal.current   = self.stateVars.SlideVelocity
    self.velocity.horizontal.direction = self.stateVars.SlideDirection

    if self.stateVars.slideDustTimer > 0 then
      self.stateVars.slideDustTimer = self.stateVars.slideDustTimer - 1
    else
      if self.state.isGrounded then
        if self.velocity.horizontal.current > 0.75 then
          Particles:addFromCategory ( 
            "dust_ball", 
            self:getX()+13*self.sprite:getScaleX()*-1, 
            self:getY()+16, 
            self.sprite:getScaleX(), 
            1, 
            0.4*self.sprite:getScaleX(), 
            -0.03 - self.velocity.horizontal.current / 20,
            self.layers.particles()
          )
          self.stateVars.slideDustTimer = 3
        end
      end
    end

    if self.velocity.horizontal.current < 0 then
      self.stateVars.SlideVelocity = 0
    end
  end

  self:applyPhysics ( )

  if _SLIDE.hasQuitState ( self ) then return end
  
  if self.desperationActivated and self.stateVars.SlideVelocity and self.stateVars.SlideVelocity >= 1 and not self.stateVars.bonkedThisSlide then
    self.sprite:change ( 2, "slide-overlay" )
  end

  if self.stateVars.FinishedSlide then
    if self.sprite:getAnimation() == "idle" then

      self:endAction ( true )
    end
  elseif self.stateVars.bonk then
    self:speedBasherBonk ( )
  end
end

function _SLIDE:handleCollisions ( colsX, lenX, colsY, lenY )
  if not self.desperationActivated or self.stateVars.bonkedThisSlide or not self.stateVars.SlideVelocity then return end
  if lenX > 0 and self:loopCollisions ( colsX, lenX ) then
    self.stateVars.bonk = true
    return
  end
  if lenY > 0 and self:loopCollisions ( colsY, lenY ) then
    self.stateVars.bonk = true
    return
  end
end

function _SLIDE:startSlide ( )
  local px, py, mx, my = self:getLocations()

  local dir = px < mx and -1 or 1

  self.colliders.current                  = self.colliders.slide_collision
  self.stateVars.timer                    = 20
  self.stateVars.SlideVelocity            = 1.0
  self.stateVars.SlideDeaccel             = 0.25
  self.stateVars.SlideDirection           = dir--self.sprite:getScaleX() 
  self.stateVars.FinishedSlide            = false
  self.stateVars.slideDustTimer           = 6
  self.stateVars.wedged                   = false
  self.stateVars.addedAfterImageLastFrame = false
  self.stateVars.bonk                     = false
  self.stateVars.bonkedThisSlide          = false

  self.sprite:flip           ( dir  )
  self.scarf:setOriginChange ( true )
  self:setAfterImagesEnabled ( true )

  Audio:playSound ( SFX.gameplay_slide )
  GameObject:spawn (
    "boss_commander_oval_bomb",
    self:getX()+10,
    self:getY()+10,
    3,
    self.projectileLayer
  )


  if self.desperationActivated then
    self.class.DAMAGE.CONTACT = self.class.DAMAGE.CONTACT_ATTACK
  end
  Particles:addFromCategory ( "slide_start_dust", self:getX()+10*self.sprite:getScaleX()*-1, self:getY()+10, self.sprite:getScaleX(), 1, 0,0, self.layers.particles()  )
end

function _SLIDE:speedBasherBonk ( )
  if not self.stateVars.SlideDirection and self.stateVars.bonkedThisSlide then return end

  local px, py = self:getLocations ()
  py = py - 8
  Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

  Audio:playSound      ( SFX.gameplay_punch_hit )
  self.stateVars.bonkedThisSlide = true
  self.stateVars.bonk           = false
  self.stateVars.timer          = 5
  self.stateVars.SlideDirection = -self.stateVars.SlideDirection
  self.stateVars.SlideVelocity  = 3.75
end

function _SLIDE:getKnockbackDir ( )
  return self.sprite:getScaleX()
end

function _SLIDE:handleXBlock ( )
  if self.stateVars and self.stateVars.SlideVelocity then
    self.stateVars.SlideVelocity = 0
    self.stateVars.timer         = 0
  end
end

function _SLIDE:getMiddlePoint ( )
  local x,y = math.floor( self.transform.x + self.dimensions.x + self.dimensions.w / 2 ),
              math.floor( self.transform.y + self.dimensions.y + self.dimensions.h / 2 )

  if self.stateVars.started and not self.stateVars.FinishedSlide then
    y = y + 8
    return x, y, self.dimensions.w, self.dimensions.h-8
  end
  return x,y,self.dimensions.w,self.dimensions.h
end

function _SLIDE:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §hookshot -----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HOOKSHOT = _NEGA:addState ( "HOOKSHOT" )

function _HOOKSHOT:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )
  self.timer = 0
  self.stateVars.jump = (py < my -16) or RNG:n() < 0.30
  self.velocity.horizontal.current = 0
end

function _HOOKSHOT:exitedState ( )
  if self.stateVars.hookshotLaunched and not self.stateVars.hookshotReturned then
    self.hookshot:deactivate ( "DISSIPATE" )
  end

  -- drop player if we somehow got here without Nega bonking Kai
  if self.stateVars.player and not self.stateVars.actuallyBonked then
    if self.stateVars.player and self.stateVars.player.gotoState then
      self.stateVars.player:gotoState ( nil )
    else
      GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.NULL, "weak", self.sprite:getScaleX() )
    end
  end

  self.velocity.horizontal.current = 0
  self:setAfterImagesEnabled ( false  )
  self:disableContactDamage  ( 1 )
  self:endAction             ( false )
end

function _HOOKSHOT:tick ( )
  if not self.stateVars.shot then
    -- non-jump ver
    if not self.stateVars.jump then
      if not self.stateVars.animStarted then
        self.stateVars.animStarted = true
        self.sprite:change ( 1, "hookshot-launch-nf-grounded", 2, true )
        self.velocity.horizontal.current = 0
      elseif self.sprite:getFrame() == 6 then
        self.timer = self.timer + 1
        local t = self.desperationActivated and 20 or 24
        if GAMEDATA.isHardMode() then
          t = t - 2
        end
        if self.lastResortActivated then
          t = 16
        end
        if self.timer >= t then
          self.sprite:setFrame ( 1, 7, true )
        end
      elseif self.sprite:getFrame() == 7 and self.sprite:getFrameTime() == 0 then
        local dirX = self.sprite:getScaleX()
        local dirY = 0
        local ang  = dirX < 0 and math.pi or 0
        local sx   = dirX
        local dirT = sx < 0 and 4 or 6

        --self.velocity.horizontal.current  = 0.5
        self.stateVars.launchAngle        = dirT
        self.stateVars.hookshotLaunched   = true
        self.stateVars.shot               = true
        self.hookshot:activate ( dirX, dirY, ang, sx, dirT  )
      end
    -- jump ver
    else
      if not self.stateVars.jumped then
        self.sprite:change ( 1, "hookshot-launch-nf-aerial", 2, true )
        self.velocity.vertical.current     = -4.5
        self.stateVars.jumped              = true
        self.velocity.horizontal.direction = -self.sprite:getScaleX()
        self.velocity.horizontal.current   = 1.0
      elseif not self.stateVars.hookshotLaunched and self.velocity.vertical.current > 1.75 then
        self.velocity.vertical.current     = -2.0
        local dirX = self.sprite:getScaleX()
        local dirY = 0
        local ang  = dirX < 0 and math.pi or 0
        local sx   = dirX
        local dirT = sx < 0 and 4 or 6

        self.sprite:setFrame ( 1, 5, true )

        self.velocity.horizontal.current  = 0.5
        self.stateVars.launchAngle        = dirT
        self.stateVars.hookshotLaunched   = true
        self.stateVars.shot               = true
        self.hookshot:activate ( dirX, dirY, ang, sx, dirT  )
      end
    end
  elseif self.stateVars.startDash then
    if not self.stateVars.dashAnim then
      self.stateVars.dashAnim = true
      self.sprite:change ( 1, self.state.isGrounded and "hookshot-dash-nf-grounded" or "hookshot-dash-nf-aerial", 2, true )
    elseif self.sprite:getFrame() == 4 and self.sprite:getFrameTime() == 0 then
      self:setAfterImagesEnabled ( true )
      self:disableContactDamage  ( 999 )
      if self.stateVars.launchAngle == 4 or self.stateVars.launchAngle == 6 then
        self.stateVars.startDash           = false
        self.stateVars.dashing             = true
        self.velocity.horizontal.current   = 10
        self.velocity.horizontal.direction = self.stateVars.launchAngle == 4 and -1 or 1
        self.velocity.vertical.update      = false
        self.velocity.vertical.current     = 0
        self.stateVars.flyTime             = 30
      end
    end
  end

  self:applyPhysics ()

  if _HOOKSHOT.hasQuitState ( self ) then return end


  if self.stateVars.dashing then
    self.stateVars.flyTime = self.stateVars.flyTime - 1
    if BUILD_FLAGS.DEBUG_BUILD and UI.kb.isPress ( "s" ) then
      self:takeDamage ( 999 )
      return
    end

    if self.sensors.HOOKSHOT_DASH:check() or self.stateVars.flyTime <= 0 then

      GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", self.sprite:getScaleX() )
      self.hookshot:deactivate ( "DISSIPATE" )

      self.sprite:change ( 1, "speedbasher-bonk", 1, true )

      local px, py = self:getLocations ()
      py = py - 8
      Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

      Audio:playSound      ( SFX.gameplay_punch_hit )

      self.velocity.horizontal.direction = -self.sprite:getScaleX()
      self.velocity.horizontal.current   = 2
      self.velocity.vertical.current     = -3
      self.velocity.vertical.direction   = 1
      self.velocity.vertical.update      = true
      self.stateVars.dashing             = false
      self.stateVars.hookshotReturned    = true
      self.stateVars.bonk                = true

      self.stateVars.player              = nil
      self.stateVars.actuallyBonked      = true
    end
  end

  if self.state.isGrounded and self.hitFlash.current > 0 then
    if not self.stateVars.pickedDodge then
      self.stateVars.pickedDodge = true
      if RNG:n() < 0.50 then
        local px, py, mx, my = self:getLocations ()
        self:gotoState ( "DODGE_HOP", px, py, mx, my )
        return
      end
    end
  elseif self.hitFlash.current <= 0 then
    self.stateVars.pickedDodge = false
  end

  if self.stateVars.jumped and self.state.isGrounded then
    self.velocity.horizontal.current = 0
    if not self.stateVars.landed then
      self.sprite:change ( 1, "land", 1, true )
    end
  end

  if self.stateVars.hookshotReturned and self.state.isGrounded then
    self.velocity.horizontal.current = 0
    if self.stateVars.bonk then
      self.sprite:change ( 1, "land", 1, true )
    elseif not self.stateVars.landed then
      self.sprite:change ( 1, "hookshot-launch-nf-grounded-end", 2, true )
    end
    self:endAction ( true )
  end
end

function _NEGA:hookshotEnd ( )
  if self.stateVars and self.stateVars.hookshotLaunched then
    self.stateVars.hookshotReturned = true
  end
end

function _NEGA:hookshotPlayer ( obj )
  if self.desperationActivated then
  --if true then
    if GlobalObserver:single    ( "PLAYER_CAN_BE_GRABBED_BY_ENEMY" ) then
      obj.parent:gotoState      ( "GRABBED_BY_ENEMY" )
      self.hookshot:deactivate  ( "ATTACHED", true, nil, true)

      self.stateVars.player    = obj
      self.stateVars.startDash = true

      self.velocity.vertical.update    = false
      self.velocity.vertical.current   = 0
      self.velocity.horizontal.current = 0
      return true
    end
  end

  local ret = GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_WEAK, "weak", self.sprite:getScaleX() )
  return ret
end

function _NEGA:hookshotTile ( )
  self.hookshot:deactivate ( "DISSIPATE" )
  self.stateVars.hookshotReturned = true
end

function _NEGA:drawSpecialCollisions ()
  if not self.hookshot then return end
  self.hookshot:drawCollisionBox()
end

function _HOOKSHOT:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §grab §throw §floor -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _THROW = _NEGA:addState ( "GRAB_AND_THROW" )

function _THROW:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )
  self.timer = 0
  self.sprite:change ( 1, "grab-off-floor", 2, true )
end

function _THROW:exitedState ( )
  if self.stateVars.block then
    self.stateVars.block.isBeingHeldByObject = false
    self.stateVars.block:takeDamage()
  end

  self:endAction ( false )
end

function _THROW:tick ( )
  if not self.stateVars.grabbed and self.sprite:getFrame() == 4 and self.sprite:getFrameTime() == 0 then
    self.stateVars.grabbed = true

      local mx, my = self:getMiddlePoint()
      local l      = Layer:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )()
      if self.sprite:getScaleX() < 0 then
        Particles:addSpecial ( "pink_hookshot_sparks", mx - 20, my+10, l, false )
      else
        Particles:addSpecial ( "pink_hookshot_sparks", mx + 20, my+10, l, false )
      end
      Audio:playSound    ( SFX.gameplay_hookshot_latch_object  )
  elseif self.stateVars.grabbed and not self.stateVars.thrown and not self.stateVars.jumped then
    local f       = self.sprite:getFrame      ( )
    local t       = self.sprite:getFrameTime  ( )
    local mx, my  = self:getMiddlePoint       ( )

    if f == 7 and t == 0 then
      mx = mx - 8
      local b = GameObject:spawn ( 
        "falling_block", 
        mx,
        my-10,
        "metal",
        self,
        true,
        false,
        self
      )

      b.velocity.vertical.update    = false
      b.velocity.vertical.current   = 0
      b.velocity.vertical.direction = 0
      b.isBeingHeldByObject         = true
      self.stateVars.block          = b
    end

    if f == 7 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx - 20, my - 8 )
      else
        self.stateVars.block:setPos ( mx + 20, my - 8 )
      end
    elseif f == 8 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx - 1, my - 16 )
      else
        self.stateVars.block:setPos ( mx - 13, my - 16  )
      end
    elseif f == 9 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx + 1, my - 17 )
      else
        self.stateVars.block:setPos ( mx - 15, my - 17 )
      end
    elseif f == 10 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx + 4, my - 17 )
      else
        self.stateVars.block:setPos ( mx - 18, my - 17 )
      end
    end

    if f == 11 and not self.stateVars.startTicking then
      local px, py, mx, my = self:getLocations()
      if (py < (my -24)) or (RNG:n() < 0.475) then
        self.stateVars.jumped = true
        Audio:playSound ( SFX.gameplay_boss_cable_jump )
        self.velocity.vertical.current = -5.5
        self.sprite:change ( 1, "carry-jump", 2, true )
      else
        self.stateVars.startTicking = true
      end
    end

    if self.stateVars.startTicking then
      self.timer = self.timer + 1
      local t    = self.desperationActivated and 8 or 12

      if GAMEDATA.isHardMode() then
        t = t - 2
      end
      if self.lastResortActivated then
        t = 3
      end
      if self.timer == t then
        self.stateVars.timeToThrow = true
      end
    end
  elseif self.stateVars.jumped and not self.stateVars.thrown then
    if self.velocity.vertical.current > 0.5 then
      self.stateVars.timeToThrow = true
    end
  end

  if self.stateVars.timeToThrow then
    self:throwTheHeldBlock ()
  end

  self:applyPhysics ( )

  if _THROW.hasQuitState ( self ) then return end

  if self.stateVars.jumped and not self.stateVars.thrown and self.stateVars.block then
    local mx, my = self:getMiddlePoint()
    if self.sprite:getScaleX() < 0 then
      self.stateVars.block:setPos ( mx + 4, my - 17 )
    else
      self.stateVars.block:setPos ( mx - 18, my - 17 )
    end
  end

  if self.state.isGrounded and self.stateVars.thrown  then
    self.velocity.horizontal.current = 0
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )
  end
end

function _NEGA:throwTheHeldBlock ( )
  local px, py, mx, my = self:getLocations()
  local omx = mx
  my = my - 17
  mx = mx + (px < mx and -30 or 17)
  self.sprite:flip ( px < mx and -1 or 1 )

  mx = omx + ((self.sprite:getScaleX() < 0) and -14 or 4)


  local dif = math.ceil ( math.abs ( px - mx ) / (self.stateVars.jumped and 49 or 36) )
  if dif < 2 then
    dif = 2
  end
  local difY = math.ceil ( math.abs ( py - my ) / 18 + 0.25)
  if difY < 3.5 then
    difY = 3.5
  end
  if py < my then
    difY = difY + 1.5
  end

  local cx = Camera:getX()
  if mx < cx + 48 and self.sprite:getScaleX() < 0 then
    self.sprite:flip ( 1 )
    dif  = 4
    difY = 3
  elseif mx > cx + GAME_WIDTH - 48 and self.sprite:getScaleX() > 0 then
    self.sprite:flip ( -1 )
    dif  = 4
    difY = 3
  end

  if self.stateVars.jumped and py > my and math.abs(px-mx) < 80 then
    self.sprite:change ( 1, "throw-down-forward", 1, true )
  else
    self.sprite:change ( 1, "throw-forward", 1, true )
  end

  self.stateVars.timeToThrow = false
  self.stateVars.thrown      = true
  Audio:playSound ( SFX.gameplay_throw )

  local sx             = self.sprite:getScaleX ( )
  local b              = self.stateVars.block

  self.stateVars.block               = nil
  self.velocity.vertical.current     = -3.0
  self.velocity.horizontal.current   = 0.5
  self.velocity.horizontal.direction = -sx

  if not b then return end

  b:setThrownLayer()
  b.velocity.vertical.update      = true
  b.velocity.vertical.current     = -difY
  b.velocity.vertical.direction   = 1
  b.velocity.horizontal.current   = dif
  b.velocity.horizontal.direction = sx
  b:setPos       ( mx, my )
  b.isReflected         = false
  b.isBeingHeldByObject = false

  cleanTable ( b.IGNORED_TILES_FOR_COLLISION )
end

function _THROW:bonkCatch ()
  if self.stateVars.thrown and not self.stateVars.block and self.state.isGrounded then
    return true
  end
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §bonk catch ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:bonkCatch ( obj )
  if self.forceDesperation or self.forceLastResort or not self.state.isGrounded or self.isBursting or (self.hookshot and self.hookshot.isActive) or self.state.isLaunched or self.state.isStunned then
    return false
  end

  local cx = Camera:getX          ( )
  local mx = self:getMiddlePoint  ( )
  if (mx < (cx + 60)) or (mx > (cx + GAME_WIDTH -60)) then
    return false
  end

  self:gotoState ( "RETURN_THROW", obj )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §return throw--------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _RETURN = _NEGA:addState ( "RETURN_THROW" )

function _RETURN:enteredState ( obj )
  self.timer = 0

  obj:applyShake ( 2 )

  obj.IGNORED_TILES_FOR_COLLISION[self.colliders.collision]        = true
  obj.IGNORED_TILES_FOR_COLLISION[self.colliders.grabbox]          = true
  obj.IGNORED_TILES_FOR_COLLISION[self.colliders.slide_collision]  = true
  obj.IGNORED_TILES_FOR_COLLISION[self.colliders.grabbed]          = true
  obj.velocity.vertical.update    = false
  obj.velocity.vertical.current   = 0
  obj.velocity.vertical.direction = 0
  obj.velocity.horizontal.current = 0

  self.sprite:flip ( -math.sign(obj.velocity.horizontal.direction))
  obj.isBeingHeldByObject         = true
  obj.isReflected                 = true
  obj.activeLayer                 = obj.layers.sprite
  self.stateVars.block            = obj

  Audio:playSound    ( SFX.gameplay_hookshot_latch_object  )
  self.sprite:change ( 1, "nega-catch-grab", 3, true )


  local mx, my = self:getMiddlePoint      ( )
  if self.sprite:getScaleX() < 0 then
    self.stateVars.block:setPos ( mx - 22, my - 10 )
  else
    self.stateVars.block:setPos ( mx + 22, my - 10 )
  end
end

function _RETURN:exitedState ( )
  if self.stateVars.block then
    self.stateVars.block.isBeingHeldByObject = false
    self.stateVars.block:takeDamage()
  end

  self:endAction ( false )
  self.nextActionTime = self.nextActionTime + 2
end

function _RETURN:tick ( )
  self.timer = self.timer + 1
  if self.timer <= 1 then
    local mx, my = self:getMiddlePoint      ( )
    if self.sprite:getScaleX() < 0 then
      self.stateVars.block:setPos ( mx - 22, my - 10 )
    else
      self.stateVars.block:setPos ( mx + 14, my - 10 )
    end

    local mx, my = self.stateVars.block:getMiddlePoint()
    local l      = Layer:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )()
    Particles:addSpecial ( "pink_hookshot_sparks", mx - 20, my+10, l, false )
  end

  if self.sprite:getAnimation ( ) == "nega-catch-grab" then
    local f      = self.sprite:getFrame     ( )
    local t      = self.sprite:getFrameTime ( )
    local mx, my = self:getMiddlePoint      ( )
    if f == 3 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx - 23, my - 10 )
      else
        self.stateVars.block:setPos ( mx + 15, my - 10 )
      end
    elseif f == 4 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx - 22, my - 10 )
      else
        self.stateVars.block:setPos ( mx + 14, my - 10 )
      end
    elseif f == 5 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx - 1, my - 16 )
      else
        self.stateVars.block:setPos ( mx - 13, my - 16  )
      end
    elseif f == 6 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx + 1, my - 17 )
      else
        self.stateVars.block:setPos ( mx - 15, my - 17 )
      end
    elseif f == 7 and t == 0 then
      if self.sprite:getScaleX() < 0 then
        self.stateVars.block:setPos ( mx + 4, my - 17 )
      else
        self.stateVars.block:setPos ( mx - 18, my - 17 )
      end
    end
  end

  if self.timer >= 20 and self.stateVars.block then
    self:throwTheHeldBlock ( )
  end

  self:applyPhysics ()

  if _RETURN.hasQuitState ( self ) then return end

  if self.state.isGrounded and self.stateVars.thrown  then
    self.velocity.horizontal.current = 0
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §catch interrupt §parry    ------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PARRY = _NEGA:addState ( "CATCH_INTERRUPT" )

function _PARRY:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )
  self.timer      = 0
  self.whiffTimer = 0
  self.isBursting = true
end

function _PARRY:exitedState ( )
  self.sprite:change         ( 3, nil )
  self:endAction             ( false  )
  self:setAfterImagesEnabled ( false  )

  self.nextActionTime = self.nextActionTime + 6

  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false

  self.isBursting = false
end

function _PARRY:tick ( )
  self.timer = self.timer + 1
  if not self.stateVars.started then
    if self.timer > 18 then
      local px, py, mx, my = self:getLocations()
      if math.abs(px-mx) < 64 or self.timer > 16 then
        self.sprite:flip ( px < mx and -1 or 1 )
        self.stateVars.started = true
        --Audio:playSound ( SFX.gameplay_player_death_wireframe_flash )
        Audio:playSound ( SFX.gameplay_bit_blade_ready  )
        self.sprite:change ( 1, "catch-interrupt-start" )
      end
    end
  elseif self.stateVars.countered then
    if not self.stateVars.superFlashed then
      self.stateVars.superFlashed = true
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "burst_attack_title_palm_catch", 9 )
      GlobalObserver:none ( "SUPER_FLASH_START", self ) 
      Audio:playSound     ( SFX.gameplay_super_flash )
      self.sprite:change  ( 1, "catch-interrupt-followup" )

      self.fakeOverkilledTimer      = 1000
      self.state.isBossInvulnerable = true

      local mx, my    = self:getMiddlePoint()
      local omx, omy  = mx, my
      mx, my          = mx + 1, my -3
      if self.sprite:getScaleX() < 0 then
        mx = omx - 1
      end

      local mx, my   = self:getMiddlePoint()
      local omx, omy = mx, my
      mx, my = mx - 21*self.sprite:getScaleX(), my-1
      Particles:addSpecial ( "super_flash", mx, my, self.layers.bottom(), self.layers.bottom()+2, false, omx, omy )

      --Particles:addSpecial ( "pink_big_punch_sparks",  mx, my, self.layers.particles(), false )
      --Particles:addSpecial ( "pink_punch_sparks",      mx, my, self.layers.particles(), false )
    end

    if self.stateVars.followedUp then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, 0 )
    end
    if self.timer == 22 then
      GlobalObserver:none        ( "SUPER_FLASH_END" )
    end
    if self.timer >= 24 and not self.stateVars.followedUp then
      self:disableContactDamage  ( 16 )
      Audio:playSound            ( SFX.gameplay_punch_alt )
      GlobalObserver:none        ( "SUPER_FLASH_END" )
      self:setAfterImagesEnabled ( true )
      self.sprite:change         ( 1, "catch-interrupt-followup-punch", 1, true )
      self.sprite:change         ( 2, "catch-interrupt-followup-punch-overlay", 1, true )
      self.stateVars.followedUp           = true
      self.velocity.horizontal.direction  = self.sprite:getScaleX()
      self.velocity.horizontal.current    = 3.25
      self.velocity.vertical.current      = -4.5
      self.velocity.vertical.update       = true
      self.state.isGrounded               = false
    end
  else
    if self.sprite:getFrame() > 6 then
      self.stateVars.windingDown = true
    end
    if self.sprite:getAnimation() == "idle" then
      if self.stateVars.countered or self.whiffTimer > 10 then
        self:endAction ( true )
      else
        self.whiffTimer = self.whiffTimer + 1
      end
    end
  end

  self:applyPhysics ( )

  if _PARRY.hasQuitState ( self ) then return end
  if self.stateVars.followedUp and not self.stateVars.hit and self.velocity.vertical.current <= -1 then
    local hit, obj = self.sensors.CATCH_INTERRUPT:check()
    if hit then
      --if GlobalObserver:single    ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", self.sprite:getScaleX() ) then
      if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, self.sprite:getScaleX(), true, -4, 2, true ) then
        self:setBossChallengeFlag ( )
        local px, py = obj.parent:getMiddlePoint ()
        Particles:addSpecial ( "pink_big_punch_sparks", px, py, self.hitParticleLayer(), false )
        Audio:playSound           ( SFX.gameplay_punch_hard_hit )
        Camera:startShake         ( 0, 3, 20, 0.25 )
        GAMESTATE.addFreezeFrames ( 4 )
        self.stateVars.hit = true

        if obj.parent.setSpinAnimation then
          obj.parent:makeBounceOnWallImpact ( true )
          obj.parent:setSpinAnimation       ( )
        end
      end
    end
  end

  if self.stateVars.followedUp and self.state.isGrounded then
    self.velocity.horizontal.current = 0
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "land" )
    self:endAction     ( true      )
  end
end

local _ogTakeDamage = _NEGA.takeDamage
function _PARRY:takeDamage ( dmg, dir, ... )
  if _PARRY.hasQuitState ( self ) then return end
  if self.stateVars.countered then return _ogTakeDamage ( self, dmg, dir, ... ) end
  if self.stateVars.started and not self.stateVars.windingDown then
    self.stateVars.countered = true
    self.timer               = 0
    Audio:playSound  ( SFX.gameplay_grab )
    self.sprite:flip ( (dir and math.abs(dir) > 0) and -dir or self.sprite:getScaleX() ) 
    return true
  else
    return _ogTakeDamage ( self, dmg, dir, ... )
  end
end

local _ogGravityFreeze = _NEGA.gravityFreeze
function _PARRY:gravityFreeze ( ... )  
  if _PARRY.hasQuitState ( self ) then return end
  if self.stateVars.countered then return _ogGravityFreeze ( self, ... ) end
  if self.stateVars.started and not self.stateVars.windingDown then
    self:takeDamage ( GAMEDATA.damageTypes.GRAVITY_FREEZE(), -self.sprite:getScaleX() )
  else
    return _ogGravityFreeze ( self, ... )
  end
end

function _PARRY:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §rising upper §upper §reppa -----------------]]--
--[[----------------------------------------------------------------------------]]--
local _UPPER = _NEGA:addState ( "RISING_UPPER" )

function _UPPER:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )
  self.stateVars.deaccel  = 0.125
  self.stateVars.count    = 0
  self.stateVars.hits     = 0
  self.timer              = -5
  self.isBursting = true
end

function _UPPER:exitedState ( )
  self.velocity.horizontal.current = 0
  self.velocity.vertical.update    = true
  self:endAction             ( false )
  self:setAfterImagesEnabled ( false )

  if not self.burstPiledriverAfter then
    self.fakeOverkilledTimer      = nil
    self.state.isHittable         = true
    self.state.isBossInvulnerable = false
  end

  self:disableContactDamage  ( 1 )
  self.isBursting = false
end

function _UPPER:tick ( )
  self.timer = self.timer + 1
  if not self.stateVars.finishedFlash then
    if self.timer == -3  then
      local mx, my = self:getMiddlePoint()
      local omx, omy = mx, my
      mx, my = mx - 21*self.sprite:getScaleX(), my-1
      Particles:addSpecial ( "super_flash", mx, my, self.layers.bottom(), self.layers.bottom()+2, false, omx, omy )

      GlobalObserver:none ( "SUPER_FLASH_START", self )
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "burst_attack_title_burst_punch_grounded_up", 9 )
      self.sprite:change  ( 1, "nega-rising-upper", 2, true ) 

      self.fakeOverkilledTimer      = 1000
      self.state.isBossInvulnerable = true
    end
    if self.timer == 20 then
      GlobalObserver:none ( "SUPER_FLASH_END" )
    end
    if self.timer >= 45 then
      if self.stateVars.restart then
        self.sprite:change  ( 1, "nega-rising-upper", 8, true ) 
      end

      Audio:playSound     ( SFX.gameplay_punch )
      self.sprite:change  ( 3, "nega-rising-upper-overlay", self.sprite:getFrame(1), true )
      GameObject:spawn     ( "shift_uppercut_projectile", self:getX(),   self:getY()-40, -1 )
      GameObject:spawn     ( "shift_uppercut_projectile", self:getX()+32,self:getY()-40,  1 )
      GlobalObserver:none ( "SUPER_FLASH_END" )


      self:setAfterImagesEnabled ( true )

      self.velocity.horizontal.current    = 4.5 - self.stateVars.count*0.25
      self.velocity.horizontal.direction  = self.sprite:getScaleX()
      self.state.isJumping                = false
      self.velocity.vertical.update       = true
      self.velocity.vertical.current      = -0.5
      self.stateVars.targetVertical       = -2.75 - self.stateVars.count*1.5
      self.state.isGrounded               = false
      self.stateVars.finishedFlash        = true
      self.stateVars.activated            = true
      self.stateVars.deaccelDelay         = 4
      self.stateVars.delayVert            = 2
      self.stateVars.hits                 = 0

      self:disableContactDamage  ( 16 )
    end
  else
    if self.velocity.horizontal.current > 0 then
      --[[
      if self.stateVars.activated then
        self.velocity.horizontal.current = self.velocity.horizontal.current + self.stateVars.deaccel * 2

        if self.velocity.horizontal.current > 2.5 then
          self.stateVars.activated = false
        end
      else]]
        if self.stateVars.deaccelDelay > 0 then
          self.stateVars.deaccelDelay = self.stateVars.deaccelDelay - 1
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current - self.stateVars.deaccel
          if self.velocity.horizontal.current  <= 0 then
            self.velocity.horizontal.current = 0
          end
        end
      --end
    else
      self.velocity.horizontal.current = 0
    end
    if self.stateVars.delayVert > 0 then
      self.stateVars.delayVert = self.stateVars.delayVert - 1
    else
      if self.stateVars.targetVertical and self.velocity.vertical.current > self.stateVars.targetVertical then
        self.velocity.vertical.current = self.velocity.vertical.current - 1.25
        if self.velocity.vertical.current < self.stateVars.targetVertical then
          self.velocity.vertical.current = self.stateVars.targetVertical
          self.stateVars.targetVertical = nil
        end
      end
    end
  end

  self:applyPhysics ( )
  
  if _UPPER.hasQuitState ( self ) then return end

  local f = self.sprite:getFrame(1)
  if self.stateVars.finishedFlash and self.velocity.vertical.current < 1 and f >= 9 and f <= 12 and self.stateVars.hits < 3 then
    if not self.stateVars.lastHit or self.stateVars.lastHit + 6 < GetLevelTime() then
      local sensor = self.stateVars.firstHit and self.sensors.CATCH_INTERRUPT_EXTEND or self.sensors.CATCH_INTERRUPT_SHORT
      local hit, obj = sensor:check()
      if hit then
        self:disableContactDamage  ( 999 )
        if self.stateVars.hits >= 2 and self.stateVars.count >= 2 then
          if GlobalObserver:single     ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.EMPTY, self.sprite:getScaleX(), true, -5.25, 2 ) then
            self:setBossChallengeFlag ( )
          --if obj.parent:takeMinistunDamage ( true, -5.25, 2, false, GAMEDATA.damageTypes.EMPTY(), "weak", self.sprite:getScaleX() ) then
            local px, py = obj.parent:getMiddlePoint ()
            Particles:addSpecial ( "pink_big_punch_sparks", px, py, self.hitParticleLayer(), false )
            --GAMESTATE.addFreezeFrames  ( 4 )
            Audio:playSound            ( SFX.gameplay_punch_hit )
            Audio:playSound            ( SFX.gameplay_punch_hit_stunned )
            self:disableContactDamage  ( 32 )
            self.burstPiledriverAfter = false
          end
        else 
          local allowInvul = false
          if self.stateVars.count >= 2 and f > 10 and self.stateVars.hits <= 1 then
            allowInvul = true
          end
          if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", self.stateVars.hits == 0 and GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO or GAMEDATA.damageTypes.EMPTY, self.sprite:getScaleX(), allowInvul, -4, 2.125, self.stateVars.hits == 0 and not self.stateVars.firstHit ) then
            
            self:setBossChallengeFlag ( )
          --[[if 
            obj.parent:takeMinistunDamage ( 
              false, 
              -4, 
              2.25, 
              self.stateVars.hits == 0 and not self.stateVars.firstHit, 
              self.stateVars.hits == 0 and GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_COMBO() or GAMEDATA.damageTypes.EMPTY(),
              "weak",
              self.sprite:getScaleX() 
            )
            then]]

            self.burstPiledriverAfter = false
            if not allowInvul then
              if obj.parent.setSpinAnimation then
                obj.parent:setSpinAnimation ( )
              end
            end

            if obj.parent.setExtraTimeOnRecover then
              obj.parent:setExtraTimeOnRecover ( 30 )
            end

            local px, py = obj.parent:getMiddlePoint ()
            Particles:addSpecial ( "pink_big_punch_sparks", px, py, self.hitParticleLayer(), false )
            Audio:playSound ( SFX.gameplay_punch_hit )
            self.stateVars.lastHit = GetLevelTime()
            GAMESTATE.addFreezeFrames  ( 4 )
            --self:disableContactDamage  ( 999 )
            self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
            Audio:playSound ( SFX.gameplay_punch_hit_stunned )
            self.stateVars.hits  = self.stateVars.hits + 1
            self.stateVars.firstHit = true
            --self.stateVars.count = 3
          end
        end
      end
    end
  end 

  if self.stateVars.finishedFlash and self.state.isGrounded then
    self.velocity.horizontal.current = 0
    self.sprite:change         ( 1, "land", 1, true )
    self:setAfterImagesEnabled ( false )
    Audio:playSound            ( SFX.gameplay_boss_cable_landing )

    if self.stateVars.count < 2 then
      self.stateVars.hit           = false
      self.stateVars.count         = self.stateVars.count + 1
      self.stateVars.finishedFlash = false
      self.timer                   = 42
      self.stateVars.restart       = true
      self.stateVars.hits          = 0
    else
      if self.burstPiledriverAfter then
        local px, py, mx, my = self:getLocations ()
        self.burstPiledriverAfter = false
        self:gotoState ( "HEAVENLY_PILEDRIVER_APPROACH", px, py, mx, my )
      else
        self:endAction ( true )
      end
    end
  end
end

function _UPPER:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §flying strike       ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _FLYING = _NEGA:addState ( "FLYING_STRIKE" )

function _FLYING:enteredState ( px, py, mx, my, again )
  self.timer = 0

  local cx   = Camera:getX() 
  local left = mx < (cx + (GAME_WIDTH/2))
  px         = cx + (left and 60 or (GAME_WIDTH-60))  

  local high = py < (Camera:getY() + 100)

  self.stateVars.didThisThingSecondTime = again

  Audio:playSound ( SFX.gameplay_boss_cable_jump )
  local dif = math.abs(mx - px)
  local dir = mx > px and -1 or 1
  dif       = dif / 30
  dif       = dif - (dif % 0.25) +.5

  self.sprite:flip ( left and 1 or -1 )
  self.velocity.vertical.current      = high and -8 or -5.0
  self.velocity.horizontal.direction  = dir
  self.velocity.horizontal.current    = dif
  self.state.isGrounded               = false
  self:setAfterImagesEnabled ( true )
  self:disableContactDamage  ( 999  )

  self.stateVars.flashStarted = false

  self.sprite:change ( 1, "jump", 3, true )
  self.isBursting = true
end

function _FLYING:exitedState ( )
  self.velocity.horizontal.current = 0
  self.velocity.vertical.update    = true
  self:endAction             ( false )
  self:setAfterImagesEnabled ( false )
  self:disableContactDamage  ( 1 )
  self.sprite:change         ( 2, nil )
  self.isBursting = false

  if self.risingUpperAfter then
    return
  end

  if not self.stateVars.goingAgain then
    self.fakeOverkilledTimer      = nil
    self.state.isHittable         = true
    self.state.isBossInvulnerable = false
  end
end

function _FLYING:tick ( )
  if self.stateVars.jumped then
    self.timer = self.timer + 1
  end

  if not self.stateVars.jumped then
    if self.velocity.vertical.current > 1 then
      local px, py, mx, my = self:getLocations ( )

      if py < my or math.abs(py-my) < 12 then
        self.stateVars.jumped   = true
        self.stateVars.start    = true
      end
    end
  end

  if self.stateVars.start then
    self:setAfterImagesEnabled ( false )
    self.stateVars.flashStarted = true
    self.stateVars.start = false
    local mx, my = self:getMiddlePoint()
    local omx, omy = mx, my
    mx, my = mx - 14*self.sprite:getScaleX(), my-9
    Particles:addSpecial ( "super_flash", mx, my, self.layers.bottom(), self.layers.bottom()+2, false, omx, omy )

    GlobalObserver:none ( "SUPER_FLASH_START", self )
    GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "burst_attack_title_burst_punch_neutral", 9 )
    self.sprite:change  ( 1, "flying-strike",         1, true ) 
    self.sprite:change  ( 2, "flying-strike-overlay", 1, true ) 

    self.fakeOverkilledTimer      = 1000
    self.state.isBossInvulnerable = true

    self.velocity.horizontal.current = 0
    self.velocity.vertical.current   = 0
    self.velocity.vertical.update    = false
  elseif self.timer == 20 then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  elseif self.timer >= 40 then
    if not self.stateVars.flying then
      self:setAfterImagesEnabled ( true )
      self.stateVars.flying = true
      self:setAfterImagesEnabled ( true )
      self.velocity.horizontal.current   = 14
      self.velocity.horizontal.direction = self.sprite:getScaleX ( )
    end
  end

  self:applyPhysics ( )

  if _FLYING.hasQuitState ( self ) then return end

  if self.stateVars.flying and not self.stateVars.impacted then

    local hit, obj = self.sensors.FLYING_STRIKE:check ( )
    if hit and obj then
      if GlobalObserver:single ( "PLAYER_TAKES_MINISTUN_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, self.sprite:getScaleX(), true, -4, 6 ) then
        self:setBossChallengeFlag ( )
        GAMESTATE.addFreezeFrames ( 4 )
        Audio:playSound           ( SFX.gameplay_punch_hard_hit )
        Audio:playSound           ( SFX.gameplay_crash_impact, 0.9 )
        Camera:startShake         ( 0, 3, 20, 0.25 )

        local px, py = obj.parent:getMiddlePoint ()
        py = py - 8
        Particles:addSpecial ( "pink_punch_sparks", px, py, self.hitParticleLayer(), false )

        self.risingUpperAfter              = false
        self.burstPiledriverAfter          = false

        self.velocity.vertical.update      = true
        self.velocity.vertical.current     = -3
        self.velocity.horizontal.direction = -self.velocity.horizontal.direction
        self.velocity.horizontal.current   = 2
        self.stateVars.impacted            = true
        self.stateVars.actualHit           = true

        if obj.parent.setSpinAnimation then
          obj.parent:makeBounceOnWallImpact ( true )
          obj.parent:setSpinAnimation       ( )
        end

        self.sprite:change ( 1, "speedbasher-bonk-dodge", 1, true )
      end
    end
  end

  if self.stateVars.impacted and self.state.isGrounded then
    if self.stateVars.actualHit or self.stateVars.didThisThingSecondTime then
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.velocity.horizontal.current = 0
      self.sprite:change ( 1, "land", 1, true )

      if self.risingUpperAfter then
        self.risingUpperAfter = nil
        local px, py, mx, my = self:getLocations ()
        self:gotoState ( "RISING_UPPER", px, py, mx, my )
      else
        self:endAction     ( true )
      end
    else
      local px, py, mx, my = self:getLocations ()
      self.stateVars.goingAgain = true
      self:gotoState ( "FLYING_STRIKE", px, py, mx, my, true )
    end
  end
end

function _FLYING:handleXBlock ( )
  if _FLYING.hasQuitState ( self ) then return end

  if not self.stateVars.jumped and not self.stateVars.flashStarted then
    self.stateVars.start  = true
    self.stateVars.jumped = true
    return
  end

  if not self.stateVars.flying or self.stateVars.impacted then 
    return 
  end
  Audio:playSound     ( SFX.gameplay_crash_impact, 0.9 )
  Camera:startShake   ( 0, 3, 20, 0.25 )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+7, 
    self:getY()+47, 
    1,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+24, 
    self:getY()+53, 
    2,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+41, 
    self:getY()+47, 
    3,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX(), 
    self:getY()+30, 
    4,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+48, 
    self:getY()+30, 
    6,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+7, 
    self:getY()+13, 
    7,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+24, 
    self:getY()+7, 
    8,
    70
  )
  GameObject:spawn ( 
    "laser_beam", 
    self:getX()+41, 
    self:getY()+13, 
    9,
    70
  )

  self.velocity.vertical.update      = true
  self.velocity.vertical.current     = -3
  self.velocity.horizontal.direction = -self.velocity.horizontal.direction
  self.velocity.horizontal.current   = 2
  self.stateVars.impacted            = true

  self.sprite:change ( 1, "speedbasher-bonk-dodge", 1, true )
  self.sprite:change ( 2, nil )
end

function _FLYING:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §heavenly §approach -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _APPROACH = _NEGA:addState ( "HEAVENLY_PILEDRIVER_APPROACH" )

function _APPROACH:enteredState ( )
  self.isBursting = true

end

function _APPROACH:exitedState ( )
  self.isBursting = false

end

function _APPROACH:tick ( )
  local px, py, mx, my = self:getLocations()
  if math.abs ( px - mx ) < 62 then
    self:gotoState ( "HEAVENLY_PILEDRIVER", px, py, mx, my )
  else
    self:gotoState ( "DODGE_HOP", px, py, mx, my, nil, true )
  end
end

function _APPROACH:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §heavenly §piledriver §izuna ----------------]]--
--[[----------------------------------------------------------------------------]]--
local _PILEDRIVE = _NEGA:addState ( "HEAVENLY_PILEDRIVER" )

function _PILEDRIVE:enteredState ( px, py, mx, my )
  self.timer                       = 0
  self.velocity.horizontal.current = 0
  self.isBursting                  = true
end

function _PILEDRIVE:exitedState ( )
  self:setAfterImagesEnabled           ( false )
  self:permanentlyDisableContactDamage ( false )
  self:endAction ( false )
  self.isBursting = false
end

function _PILEDRIVE:tick ( )
  self.timer = self.timer + 1

  if self.timer == 5 then
    local px, py, mx = self:getLocations()
    self.sprite:flip ( px < mx and -1 or 1 )

    local mx, my = self:getMiddlePoint()
    local omx, omy = mx, my
    mx, my = mx - 14*self.sprite:getScaleX(), my-9
    Particles:addSpecial ( "super_flash", mx, my, self.layers.bottom(), self.layers.bottom()+2, false, omx, omy )

    GlobalObserver:none ( "SUPER_FLASH_START", self )
    GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "burst_attack_title_piledriver", 9 )

    self.sprite:change ( 1, "nega-piledriver-start", 1, true )
    self:permanentlyDisableContactDamage ( true )

    self.burstPiledriverAfter     = false
    self.fakeOverkilledTimer      = 1000
    self.state.isBossInvulnerable = true
  elseif self.timer == 25 then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  elseif self.timer == 42 then
    if not self.stateVars.flying then
      self:setAfterImagesEnabled ( true )
      self.stateVars.flying = true


      self.velocity.horizontal.current   = 6.5
      self.velocity.horizontal.direction = self.sprite:getScaleX ( )
      self.velocity.vertical.current     = -2.0
      self.stateVars.deaccel             = 0.25
    end
  end

  if self.velocity.horizontal.current > 0 then
    self.velocity.horizontal.current = self.velocity.horizontal.current - self.stateVars.deaccel
    if self.velocity.horizontal.current  <= 0 then
      self.velocity.horizontal.current = 0
    end
  end

  self:applyPhysics ( )

  if _PILEDRIVE.hasQuitState ( self ) then return end
  if self.stateVars.flying and self.velocity.horizontal.current > 1 and not self.stateVars.noMoreChecks then
    local hit, obj = self.sensors.PILEDRIVE_CATCH:check ( )
    if hit and obj then
      obj.parent._disableSuperArmor = true
      local able, counter = GlobalObserver:single ( "PLAYER_CAN_BE_GRABBED_BY_ENEMY" )
      obj.parent._disableSuperArmor = false
      if able then
        obj.parent:gotoState  ( "GRABBED_BY_ENEMY" )
        self:gotoState        ( "HEAVENLY_PILEDRIVER_FOLLOWUP", obj.parent ) 
      elseif counter then
        self.stateVars.noMoreChecks = true


        self.fakeOverkilledTimer      = nil
        self.state.isHittable         = true
        self.state.isBossInvulnerable = false
      end
    end
  end

  if self.stateVars.flying and self.state.isGrounded then
    Audio:playSound    ( SFX.gameplay_boss_cable_landing )
    self.velocity.horizontal.current = 0
    self.sprite:change ( 1, "land", 1, true )
    self:endAction     ( true )

    if self.fakeOverkilledTimer then
      self.fakeOverkilledTimer      = nil
      self.state.isHittable         = true
      self.state.isBossInvulnerable = false
    end
  end
end

function _PILEDRIVE:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §SUPLEX              ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SUPLEX = _NEGA:addState ( "HEAVENLY_PILEDRIVER_FOLLOWUP" )

function _SUPLEX:enteredState ( obj )
  self:setBossChallengeFlag ( )

  local mx, my = self:getMiddlePoint()
  local l      = Layer:get ( "STATIC-OBJECTS-FRONT", "PHYSICAL-2" )()
  Particles:addSpecial ( "pink_hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false )
  Particles:addSpecial ( "pink_hookshot_sparks", mx + self.sprite:getScaleX() * 16, my-1, l, false )

  self:permanentlyDisableContactDamage ( true )

  local x,y = self:getPos()
  if self.sprite:getScaleX() < 0 then
    obj:setPos ( x-20, y )
  else
    obj:setPos ( x+20, y )
  end

  self.stateVars.grabbedObject = obj
  Audio:playSound    ( SFX.gameplay_hookshot_latch_object  )
  self.sprite:change ( 2, nil )
  self.sprite:change ( 1, "nega-piledriver-catch", 3, true )
  self.timer = 0

  self.activeLayer = Layers:get ( "STATIC-OBJECTS-FRONT" )

  self.velocity.horizontal.current = 0
  self.velocity.vertical.current   = 0
  self.velocity.vertical.update    = false
  self.stateVars.positiveStep      = 0.75


  self.isBursting = true
end

function _SUPLEX:exitedState ( )
  self.velocity.vertical.update = true

  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false

  self:endAction                        ( false )
  self:setAfterImagesEnabled            ( false )
  self:permanentlyDisableContactDamage  ( false )


  self.isBursting = false
end

function _SUPLEX:tick ( )
  self.timer = self.timer + 1
  if not self.stateVars.flying then
    if self.timer == 15 and not self.stateVars.firstAnim then
      self.stateVars.firstAnim = true
      self.timer               = 0
      self.sprite:change ( 1, "nega-piledriver-followup-start", 2, true )
    elseif self.timer == 2 and not self.stateVars.flying and self.stateVars.firstAnim  then
      self.sprite:change ( 1, "nega-piledriver-body-top"    , 2 )
      self.sprite:change ( 2, "nega-piledriver-body-bottom" , 2 )
      self.stateVars.izunaDropAnimation = true
      self.velocity.vertical.current = -11
      self.stateVars.flying          = true
      self.velocity.vertical.update  = false
      self.stateVars.notFlipped      = true
      self.velocity.horizontal.current   = 1.0
      self.velocity.horizontal.direction = RNG:rsign ( )
      self:setAfterImagesEnabled ( true )
    end
  elseif not self.stateVars.suplexed then
    if self.velocity.vertical.current > -3 and not self.stateVars.spinAnimationStarted then
      self.stateVars.spinAnimationStarted = true
      self.sprite:change ( 2, nil )
      self.sprite:change ( 1, "nega-piledriver-spin-smear" )
    end
    if self.stateVars.notFlipped and self.velocity.vertical.current >= 0 then
      self.stateVars.notFlipped = false
      self.sprite:scaleLockInstance             ( 3 )
      self.sprite:flip                          ( nil, -1 )
      self.stateVars.grabbedObject.sprite:flip  ( nil, -1 )
      self.sprite:releaseScaleLockInstance      ( 3 )

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
    obj:setPos ( x, y )
    scale = scale * 10
    if f == 1 then
      obj:translate ( -0.6 * scale, oy )
    elseif f == 2 then
      obj:translate ( -1 * scale, oy )
    elseif f == 3 then
      obj:translate ( 0 * scale, oy )
    elseif f == 4 then
      obj:translate ( 1.0 * scale, oy )
    elseif f == 5 then
      obj:translate ( 0.6 * scale, oy )
    elseif f == 6 then
      obj:translate ( 0.25 * scale, oy )
    else
      obj:translate ( -0.25 * scale, oy )
    end
  end

  if self.stateVars.exitNextTick then
    self.activeLayer            = nil
    self.stateVars.exitNextTick = false
    self.sprite:flip   ( nil, 1 )
    self.sprite:change ( 1, "speedbasher-bonk", 1, true )
    self.sprite:change ( 2 )
    self.sprite:change ( 6 )

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

function _SUPLEX:finishSuplex ( fromHit )
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

  self.sprite:stop   ( 1 )
  self.sprite:stop   ( 2 )
  self.sprite:stop   ( 3 )

  self.stateVars.suplexed = true

  self.velocity.vertical.update       = true
  self.velocity.vertical.current      = -3.5
  self.velocity.horizontal.current    = 2.5
  self.velocity.horizontal.direction  = -self.sprite:getScaleX()
end

function _SUPLEX:bonkCatch ()
  return false
end

function _SUPLEX:takeDamage()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Dodge hop ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DODGE = _NEGA:addState ( "DODGE_HOP" )

function _DODGE:enteredState ( px, py, mx, my, again, intoHeavenly )

  Audio:playSound ( SFX.gameplay_slide )
  GameObject:spawn ( 
    "plasma_ball", 
    self:getX()+1, 
    self:getY()+1, 
    1
  )
  local flip = false
  local anim = nil
  if not again then
    local dir = self.sprite:getScaleX() 
    if intoHeavenly then
      self.stateVars.intoHeavenly = true
      dir = px < mx and 1 or -1
      self.sprite:flip ( -dir )
      flip = true

      self.initialPlayerSide = px < mx and -1 or 1
    else
      if px then
        dir = px < mx and -1 or 1
        self.sprite:flip ( dir )

        if RNG:n() > 0.55 then
          dir  = -dir
          flip = true
        end
      end
    end

    self.velocity.horizontal.direction = -dir
    anim               = flip and "double-jump-dodge" or "speedbasher-bonk-dodge"
    self.lastDodgeAnim = anim
  else
    self.stateVars.intoHeavenly = intoHeavenly
    anim                        = self.lastDodgeAnim
  end

  self.hitFlash.current              = 0
  self.stateVars.repeats             = again or 0
  self.velocity.horizontal.current   = 3.0
  self.velocity.vertical.current     = -2.5
  self.hitsSinceLastDodge            = 0

  self.state.isHittable         = false
  self.state.isBossInvulnerable = true

  self.state.isGrounded = false
  self.sprite:change ( 1, anim, 1, true ) 

  self:permanentlyDisableContactDamage ( true )
  self:setAfterImagesEnabled           ( true )

  self:setGrabbableStatus ( false )
end

function _DODGE:exitedState ( )
  self.state.isHittable              = true
  self.state.isBossInvulnerable      = false

  self:endAction                       ( false )
  self.nextActionTime = self.nextActionTime + 2

  self:setGrabbableStatus              ( true  )
  self:setAfterImagesEnabled           ( false )
  self:permanentlyDisableContactDamage ( false )
  self:disableContactDamage            ( 16 )
end

function _DODGE:tick ( )
  self:applyPhysics ( )

  if self.state.isGrounded then
    local px, py, mx, my = self:getLocations ()
    local playerSide     = px < mx and -1 or 1
    if self.stateVars.intoHeavenly and ((math.abs(px-mx) < 70) or self.initialPlayerSide ~= playerSide) then
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.velocity.horizontal.current = 0
      self.sprite:change ( 1, "land", 1, true )
      self:gotoState ( "HEAVENLY_PILEDRIVER", px, py, mx, my ) 
    elseif self.stateVars.intoHeavenly or (self.stateVars.repeats < 1 or RNG:n() < 0.25 and self.stateVars.repeats < 2) then
      self:gotoState ( "DODGE_HOP", nil, nil, nil, nil, self.stateVars.repeats + 1, self.stateVars.intoHeavenly )
    else
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.velocity.horizontal.current = 0
      self.sprite:change ( 1, "land", 1, true )
      self:endAction     ( true )
    end
  end
end

function _DODGE:handleXBlock ( )
  self.stateVars.repeats = 999
end

function _DODGE:takeDamage ()
  return false
end

function _DODGE:bonkCatch ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _NEGA:addState ( "TECH_RECOVER" )

function _TECH:enteredState (  )
  self.fakeOverkilledTimer = GAMEDATA.boss.getTechRecoverFrames ( self )
  
  self._lastBurstAttackId  = nil
  self:disableContactDamage ( 30 )
  self.timer               = 20
  local mx, my = self:getMiddlePoint()
  mx = mx - 8
  my = my - 24
  Particles:add ( "circuit_pickup_flash_large", mx, my, 1, 1, 0, 0, self.layers.sprite()+1 )

  Audio:playSound ( SFX.hud_mission_start_shine )

  self.sprite:flip   ( nil, 1 )
  self.sprite:change ( 1, "jump", 3, true )

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

  if self.velocity.vertical.current > 0 then
    self.sprite:change ( 1, "fall" )
  end

  if self.state.isGrounded then
    if not self.stateVars.landed then
      Audio:playSound    ( SFX.gameplay_boss_cable_landing )
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

function _NEGA:manageTeching ( timeInFlinch )
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    if self.forceLastResort then
      self:gotoState ( "FAKE_IT" )
    else
      self:gotoState ( "TECH_RECOVER" )
    end
    return true
  end

  return false
end

function _NEGA:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

function _NEGA:bonkReduction ( isSelfDamage )
  if not isSelfDamage then
    Challenges.unlock ( Achievements.RETURN_TO_BOSS )
  end
  return GAMEDATA.damageTypes.COLLISION_REDUCED
end

function _TECH:bonkCatch ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §fake                ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _FAKE = _NEGA:addState ( "FAKE_IT" )

function _FAKE:enteredState ( )
  self:setGrabbableStatus ( false )
end

function _FAKE:exitedState ( )
  self:setGrabbableStatus ( true )
end

function _FAKE:tick ( )
  self:applyPhysics()

  if self.state.isGrounded then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current-0.25, 0 )

    if self.velocity.horizontal.current <= 0 then
      self:gotoState ( "LAST_RESORT" )
    end
  end
end

function _FAKE:takeDamage ( )
  return false
end

function _NEGA:setGrabbableStatus ( bool )
  self.colliders.grabbox.isGrabbable  = bool
  self.colliders.grabbox.isGrabbox    = bool
  self.colliders.grabbox.isLaunchable = bool
  self.isDodging                      = not bool
end

function _FAKE:bonkCatch ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:manageForcedLaunch ( dmg )
  local launch = false
  if not self.instantDeath then
    if self.health - dmg <= 0 then
      if not self.lastResortActivated then
        self:setGrabbableStatus ( false )
        self.state.isHittable = false
        self.forceLastResort  = true
        dmg                   = self.health - 1
        launch                = true
      else
        return
      end
    end
  end

  if self.forceLaunched and not launch then return end
  self.hitsSinceLastDodge = self.hitsSinceLastDodge + 0.075
  if (self.health - dmg <= (GAMEDATA.boss.getMaxHealth()/2)) or self.forceLastResort then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
    self.hadForcedLaunch          = true
    self.forceLaunched            = true
    if not self.forceLastResort then
      self.forceDesperation = true
    end
    self.fakeOverkilledTimer      = 10000
    if not self.forceLastResort then
      self.state.isBossInvulnerable = true
    end

    local mx, my = self:getMiddlePoint("collision")

    mx, my = mx+2, my-2
    Particles:add ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.particles() )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

    if self.forceLastResort then
      self.fakeoutTimer = 20
      if self.state.isBossRushSpawn then
        if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
          GameObject:startFinalKillSlowdown ( nil, nil, true )
        else
          GameObject:startFinalKillSlowdown ( true )
        end
      else
        GlobalObserver:single ( "DESTROYED_TARGET_OBJECT", self, true )
      end
      return true, 1.0, -4, dmg, true
    else
      self:spawnBossMidpointRewards ( )
      return true, 1.0, -4
    end
  end
end

function _NEGA:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and -10 or -25), -31
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _NEGA:addState ( "PREFIGHT_INTRO" )

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

function _NEGA:_runAnimation ( )
  self:gotoState ( "CUTSCENE" )

  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Limping scene ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

----------------
-- part 1     --
----------------

function _NEGA:cutscene_limping_nega ( )
  if not self.limp then
    self.limp = { }

    self.limp.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "nega-boss", 1 )
    self.limp.timer  = -10

    self.limp.sprite:addInstance ( "ground",  "cutscene-platform"             )
    self.limp.sprite:addInstance ( "nega",    "cutscene-limp",    1, true     )
    self.limp.sprite:addInstance ( "circuit"        )

    Audio:playTrack       ( BGM.tension_2 )
    Audio:fadeMusicVolume ( 1, 1 )

    self.limp.groundPalette = 0
    self.limp.negaPalette   = 0
    self.limp.negaPaletteF  = 6
    self.limp.negaSteps     = 0
    self.limp.negaVelX      = 0

    self.limp.negaShakeX    = 0
    self.limp.negaShakeXDir = 1

    self.limp.negaTimer     = 0

    self.limp.negaX = 230
    self.limp.negaY = 80

    self.limp.smokeX = 0
    self.limp.smokeY = 0

    self.limp.tween1 = Tween.new ( 30, self.limp, { groundPalette   = 6       }, "linear" )
    self.limp.tween2 = Tween.new ( 30, self.limp, { negaPalette     = 6       }, "linear" )
    self.limp.tween3 = Tween.new ( 16, self.limp, { negaPaletteF    = 0       }, "linear" )

    self.limp.tween3:finish()
  end
  self.limp.timer = self.limp.timer + 1
  local timer     = self.limp.timer

  if timer < 0 then
    return false
  end
  if timer < 90 then
    self.limp.tween1:update(1)
  end

  if timer > 90 then
    self.limp.tween2:update(1)
    if self.limp.negaSteps < 4 and self.limp.negaPalette > 3 then
      self:cutscene_negaStep ( )
    elseif self.limp.negaSteps >= 4 then
      if self.limp.negaTimer < 80 then
        if self.limp.tween3:update(1) then
          self.limp.tween3:setTime ( 0.5 )
        end
        self.limp.negaTimer = self.limp.negaTimer + 1
        self.limp.emitSmoke = true
      else
        self.limp.negaTimer = self.limp.negaTimer + 1
        self.limp.tween3:update(1)
        self.limp.sprite:change ( "nega", "cutscene-fall-over" )
        local f = self.limp.sprite:getFrame("nega")
        if f == 5 then
          self.limp.smokeX = 4
          self.limp.smokeY = -2
        elseif f == 6 then
          self.limp.smokeX = 7
          self.limp.smokeY = -2
        elseif f == 7 then
          self.limp.smokeX = 10
          self.limp.smokeY = 0
        elseif f == 8 then
          self.limp.smokeX = 18
          self.limp.smokeY = 12
        elseif f == 9 then
          self.limp.smokeX = 22
          self.limp.smokeY = 17
        end
        if f == 10 and self.limp.sprite:getFrameTime("nega") == 0 then
          Audio:playSound ( SFX.gameplay_bouncing_enemy_land, 1.5 )
        end

        if self.limp.negaTimer > 200 then
          return true
        end
      end
    end
  end

  if self.limp.negaShakeX > 0 then
    self.limp.negaShakeX    = math.max ( self.limp.negaShakeX - 0.1, 0 )
    if GetTime() % 3 == 0 then
      self.limp.negaShakeXDir = -self.limp.negaShakeXDir
    end
  end

  return false
end

function _NEGA:cutscene_negaStep ( )
  local f = self.limp.sprite:getFrame ( "nega" )
  if f == 2 then
    self.limp.negaStepStarted = true
  elseif f == 3 then
    self.limp.negaVelX = 0.0
  elseif f == 4 then
    self.limp.negaVelX = 0
  elseif f == 5 then
    self.limp.negaVelX = 0.25
  elseif f == 6 then
    self.limp.negaVelX = 0.75
  elseif f == 7 then
    self.limp.negaVelX = 0.5
  else
    if f==1 and self.limp.negaStepStarted  then
      self.limp.negaStepStarted = false
      self.limp.negaSteps       = self.limp.negaSteps + 1

      if self.limp.negaSteps >= 4 then
        self.limp.sprite:stop  ( "nega" )
        self.limp.tween3:reset ( )
        self.limp.negaShakeX    = 2
        self.limp.negaShakeXDir = -1

        Audio:playSound ( SFX.gameplay_stun )
        local l      = Layers:get ( "LOGO", nil, true )()+5
        local mx, my = self.limp.negaX,self.limp.negaY
        mx = mx + 56
        my = my + 61
        Particles:addSpecial("small_explosions_in_a_circle_gray", mx, my, l, true )
        Particles:add ( "death_trigger_flash_gray",mx,my, math.rsign(), 1, 0, 0, l, true )
      end
    end
    self.limp.negaVelX = 0
  end

  self.limp.negaX = self.limp.negaX - self.limp.negaVelX 
end

function _NEGA:cutscene_emit_nega_smoke ( )
  if GetTime() % 12 == 0 then
    local l      = Layers:get ( "LOGO", nil, true )()-1
    local mx, my = self.limp.negaX,self.limp.negaY
        mx = mx + 44 + self.limp.smokeX
        my = my + 41 + self.limp.smokeY

    Particles:addFromCategory ( 
      "directionless_dust", 
      mx, 
      my, 
      math.rsign(), 
      1, 
      RNG:n()*0.4, 
      -1.5,
      l,
      true,
      nil,
      true
    )
  end
end

----------------
-- part 2     --
----------------

function _NEGA:cutscene_limping_nega_the_circuit_boogaloo ( )
  if not self.limp.part2Started then
    self.limp.part2Started = true
    self.limp.timer        = -10

    self.limp.circuitX = 240
    self.limp.circuitY = 100

    self.limp.circuitSpawnX = 0
    self.limp.circuitSpawnY = 60

    self.limp.sineTimer = 0
    self.limp.sineY     = 0

    self.limp.kaiX         = 75
    self.limp.kaiY         = 96
    self.limp.kaiShakeX    = 0
    self.limp.kaiShakeXDir = 1

    self.limp.kaiMoving  = true

    self.limp.kaiPalette  = 0
    self.limp.kaiPaletteF = 6

    self.limp.kaiVelX     = 0

    self.limp.kaiSteps    = 0

    self.limp.kernelX       = 75
    self.limp.kernelY       = 96
    self.limp.kernelPalette = 0

    self.limp.kernel_timer  = 50

    self.limp.kaiLimpDelay  = 140

    self.limp.sparkleTimer  = 3

    self.limp.sparkW        = 0
    self.limp.sparkA        = 1

    self.limp.tween_kai1 = Tween.new ( 16, self.limp, { kaiPalette     = 2 }, "linear" )
    self.limp.tween_kai2 = Tween.new ( 64, self.limp, { circuitX       = 150, circuitY = 126 }, "inCubic" ) 
    self.limp.tween_kai3 = Tween.new ( 16, self.limp, { kaiPaletteF    = 0 }, "linear" )
    self.limp.tween_kai4 = Tween.new ( 90, self.limp, { circuitSpawnX  = 0, circuitSpawnY  = 0 }, "outBack" )

    self.limp.tween_kai5 = Tween.new ( 60, self.limp, { sparkW         = 300, }, "outQuad" )

    self.limp.tween_kernel = Tween.new ( 16, self.limp, { kernelPalette = 6 }, "linear" )

    self.limp.tween_kai3:finish ()

    self.limp.sprite:addInstance ( "kai" ) -- what, did you expect kai to have non-circuit a name?
    self.limp.sprite:addInstance ( "kernel", "cutscene-kernel-walk", 1, true )
  end

  self.limp.timer = self.limp.timer + 1
  local timer     = self.limp.timer

  if timer < 0 then
    return false
  end

  if timer == 20 then
    self.limp.sprite:change ( "kai", "cutscene-bot-walk-2" )
    self.limp.kai = true
  end

  if self.limp.kai then
    if not self.limp.kai_hash_become_kai then
      self.limp.tween_kai1:update(1)

      if self.limp.kaiMoving then
        self.limp.kaiX = self.limp.kaiX + 0.5
        if timer >= 77 and self.limp.sprite:getFrame( "kai" ) == 5 and self.limp.sprite:getFrameTime( "kai" ) == 0 then
          self.limp.kaiMoving = false

          self.limp.sprite:change ( "kai", "cutscene-shock", 2, true )
          self.limp.kaiShakeX     = 1.6
          self.limp.kaiShakeXDir  = 1

          local x, y = self:getPos()
          GlobalObserver:none (
            "SHOW_EXCLAMATION_ICON_ABOVE_CHARACTER",
            self,
            -x+162,
            -y+104,
            Colors.DialoguePortraits.DarkestDim,
            1,
            nil,
            true,
            Layers:get ( "LOGO", nil, true )() + 10
          )
        end
      end
    else
      if self.limp.tween_kai5:update(1) then
        self.limp.sparkA = self.limp.sparkA - 0.05
      end
      if self.limp.kaiLimpDelay > 0 then
        if self.limp.kaiLimpDelay > 8 then
          if self.limp.sparkleTimer == 0 then
            local mx, my =  self.limp.circuitX + self.limp.circuitSpawnX + 12,
                            self.limp.circuitY + self.limp.sineY + self.limp.circuitSpawnY + 5
            Particles:add ( "circuit_pickup_flash_small_gray", mx-7+(math.random(0,5)*math.rsign()), my-8, 1, 1, 0, -0.5-math.random()*0.75, Layers:get ( "LOGO", nil, true )()-3, true, nil, true )
            self.limp.sparkleTimer = 11
          else
            self.limp.sparkleTimer = self.limp.sparkleTimer - 1
          end
        end

        self.limp.kaiLimpDelay = self.limp.kaiLimpDelay - 1
        if self.limp.kaiLimpDelay == 0 then
          self.limp.sprite:change ( "kai", "cutscene-limp-2" )
        end
      else
        self:cutscene_kaiStep ( )
      end
    end
  end

  if self.limp.kernel then
    self.limp.kernel_timer = self.limp.kernel_timer - 1
    if self.limp.kernel_timer < 0 then
      if self.limp.kernel_timer > -80 then
        self.limp.tween_kernel:update ( 1 )
        self.limp.kernelX = self.limp.kernelX + 0.5
      elseif self.limp.kernel_timer <= -80 then
        self.limp.sprite:change ( "kernel", "cutscene-kernel-walk-end" )

        if not self.limp.kernelExclamation then
          self.limp.kernelExclamation = true
          local x, y = self:getPos()
          GlobalObserver:none (
            "SHOW_EXCLAMATION_ICON_ABOVE_CHARACTER",
            self,
            -x+161,
            -y+100,
            Colors.DialoguePortraits.DarkestDim,
            1,
            nil,
            true,
            Layers:get ( "LOGO", nil, true )() + 10
          )
        end
      end
      if self.limp.kernel_timer <= -180 then
        self.limp.groundPalette = self.limp.groundPalette - 0.25
        self.limp.negaPalette   = self.limp.negaPalette   - 0.25
        self.limp.kernelPalette = self.limp.kernelPalette - 0.25
      end

      if self.limp.groundPalette <= 0 and self.limp.kernel_timer < -220 then
        self.limp = nil
        return true
      end
    end
  end

  if self.limp.kaiShakeX > 0 then
    self.limp.kaiShakeX    = math.max ( self.limp.kaiShakeX - 0.1, 0 )
    if GetTime() % 3 == 0 then
      self.limp.kaiShakeXDir = -self.limp.kaiShakeXDir
    end
  end

  if self.limp.negaShakeX > 0 then
    self.limp.negaShakeX    = math.max ( self.limp.negaShakeX - 0.1, 0 )
    if GetTime() % 3 == 0 then
      self.limp.negaShakeXDir = -self.limp.negaShakeXDir
    end
  end

  if timer == 105 then
    Particles:add           ( "circuit_pickup_flash_large_gray", 228, 130, 1, 1, 0, 0, Layers:get ( "LOGO", nil, true )()-2, true )
    self.limp.tween3:reset  ( )
    self.limp.negaShakeX    = 2
    self.limp.negaShakeXDir = -1
    Audio:playSound ( SFX.gameplay_guard_break, 0.6 )

    self.limp.sprite:change ( "circuit", "cutscene-circuit-spawn", 11, true )
    self.limp.circuitSpawned = true
    self.limp.emitSmoke      = false
  end

  self.limp.tween3:update(1)

  --[[
  if timer == 160 then
    self.limp.sprite:change ( "circuit", "cutscene-circuit-spawn", 2, true )
    Audio:playSound         ( SFX.gameplay_stage_start_1, 0.8 )
    self.limp.circuitSpawned = true
  end
  ]]

  if self.limp.circuitSpawned then
    self.limp.tween_kai4:update(1)
    if timer > 228 then
      if self.limp.tween_kai2:update(1) then
        local f = self.limp.sprite:getFrame ( "circuit" )
        if (f == 11 or f == 18) and self.limp.sprite:getFrameTime ( "circuit" ) then
          self.limp.circuitSpawned = false
          Audio:playSound ( SFX.gameplay_stage_start_2_echo )
          self.limp.tween_kai3:reset()

          self.limp.kai_hash_become_kai = true
          self.limp.sprite:change ( "kai", "cutscene-transformation", 2, true )
          self.limp.kaiPalette = 6
          self.limp.kaiVelX    = 0

          self.limp.tween_kai5:update ( 3 )
        end
      end
      if self.limp.tween_kai2:getTime() > 0.6 and not self.limp.kai_hash_become_kai then
        self.limp.sprite:change ( "kai", "cutscene-look-up" )
      end
    end

    if self.limp.sparkleTimer == 0 then
      local mx, my =  self.limp.circuitX + self.limp.circuitSpawnX + 11,
                      self.limp.circuitY + self.limp.sineY + self.limp.circuitSpawnY + 6
      Particles:add ( "circuit_pickup_flash_small_gray", mx-7+(math.random(0,5)*math.rsign()), my-8, 1, 1, 0, -0.5-math.random()*0.75, Layers:get ( "LOGO", nil, true )()-3, true, nil, true )
      self.limp.sparkleTimer = 14
    else
      self.limp.sparkleTimer = self.limp.sparkleTimer - 1
    end
  end

  self.limp.tween_kai3:update(1)


  if timer > 200 then
    --self.limp = nil
    --return true
  end

  return false
end


function _NEGA:cutscene_kaiStep ( )
  if not self.limp.sprite:getAnimation ( "kai" ) == "cutscene-limp-2" then return end
  local f = self.limp.sprite:getFrame ( "kai" )
  if f == 2 then
    self.limp.kaiStepStarted = true
  elseif f == 3 then
    self.limp.kaiVelX = 0.0
  elseif f == 4 then
    self.limp.kaiVelX = 0
  elseif f == 5 then
    self.limp.kaiVelX = 0.25
  elseif f == 6 then
    self.limp.kaiVelX = 0.75
  elseif f == 7 then
    self.limp.kaiVelX = 0.5
  else
    if f==1 and self.limp.kaiStepStarted  then
      self.limp.kaiStepStarted = false
      self.limp.kaiSteps       = self.limp.kaiSteps + 1
    end
    self.limp.kaiVelX = 0
  end

  if self.limp.kaiSteps >= 3 then
    --self.limp.tween_kai1:update(-1)
    self.limp.kaiPalette = self.limp.kaiPalette - 0.25
    if self.limp.kaiPalette <= 0 then
      self.limp.kernel = true
    end
  end


  self.limp.kaiX = self.limp.kaiX + self.limp.kaiVelX 
end

----------------
-- palettes   --
----------------
_NEGA.static.LIMP_PALETTE_CHARS = createColorVector ( 
  Colors.black, 
  Colors.dark_gray_2,
  Colors.medium_gray_2,
  Colors.light_gray_2,
  Colors.light_gray_1,
  Colors.white
)

_NEGA.static.LIMP_PALETTE_GROUND = createColorVector ( 
  Colors.black, 
  Colors.dark_gray_2, 
  Colors.dark_gray_blue_2, 
  Colors.medium_gray_2, 
  Colors.medium_gray_1, 
  Colors.light_gray_2
)

----------------
-- draw       --
----------------

function _NEGA:cutscene_draw_limp ( )
  local l = Layers:get ( "LOGO", nil, true )()

  if self.limp.groundPalette > 0 then
    Shader:pushColorSwapper   ( l, true, self.class.LIMP_PALETTE_GROUND, self.class.LIMP_PALETTE_GROUND, 0, 6, math.min(math.floor(self.limp.groundPalette),6))
    self.limp.sprite:draw     ( "ground", 0, 0, l, true )
  end

  if self.limp.kai and self.limp.kaiPalette > 0 then
    Shader:pushColorSwapper   ( l, true, self.class.LIMP_PALETTE_CHARS, self.class.LIMP_PALETTE_CHARS, 0, 6, math.min(math.floor(self.limp.kaiPalette),6))
    self.limp.sprite:draw (
      "kai",
      self.limp.kaiX+math.ceil(self.limp.kaiShakeX)*self.limp.kaiShakeXDir,
      self.limp.kaiY,
      l,
      true
    )
  end

  if self.limp.negaPalette > 0 then
    Shader:pushColorSwapper   ( l, true, self.class.LIMP_PALETTE_CHARS, self.class.LIMP_PALETTE_CHARS, math.ceil(self.limp.negaPaletteF), 6, math.min(math.floor(self.limp.negaPalette),6))
    
    if self.limp.circuitSpawned then
      self.limp.sprite:draw ( 
        "circuit",
        self.limp.circuitX + self.limp.circuitSpawnX,
        self.limp.circuitY+self.limp.sineY + self.limp.circuitSpawnY,
        l,
        true
      )
    end

    self.limp.sprite:draw     ( "nega", 
      self.limp.negaX+math.ceil(self.limp.negaShakeX)*self.limp.negaShakeXDir, 
      self.limp.negaY, 
      l, 
      true
    )
  end

  if self.limp.kernelPalette and self.limp.kernelPalette > 0 then
    Shader:pushColorSwapper   ( l, true, self.class.LIMP_PALETTE_CHARS, self.class.LIMP_PALETTE_CHARS, 0, 6, math.min(math.floor(self.limp.kernelPalette),6))
    self.limp.sprite:draw ( 
      "kernel",
      self.limp.kernelX,
      self.limp.kernelY,
      l,
      true
    )
  end

  Shader:set ( l, true )

  if self.limp.sparkA and  self.limp.sparkW > 0 and self.limp.sparkA > 0 then
    local x = self.limp.kaiX
    local y = self.limp.kaiY

    if self.limp.sparkA < 1 then
      GFX:pushUI ( l+20, love.graphics.setColor, 1, 1, 1, self.limp.sparkA )
      GFX:pushUI ( l+20, love.graphics.rectangle, "fill", -10, -10, 440, 300 )
      GFX:pushUI ( l+20, love.graphics.setColor, 1, 1, 1, 1 )
    else
      GFX:pushUI ( l+20, love.graphics.setColor, 1, 1, 1, 1 )
      GFX:pushUI ( l+20, love.graphics.rectangle, "fill", x - self.limp.sparkW + 41, y-200, self.limp.sparkW*2, 400 )
      --GFX:pushUI ( l+20, love.graphics.rectangle, "fill", x - 200, y+35-self.limp.sparkW, 700, self.limp.sparkW*2 )
      GFX:pushUI ( l+20, love.graphics.setColor, 1, 1, 1, 1 )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _NEGA:drawSpecial ( baseL )
  self:drawShards ( "glasses" )
  if self.limp then
    self:cutscene_draw_limp ( )
  end

  if self.activated then
    local x,y = self:getPos           ( )
    local l   = self.layers.particles ( )
    self.sprite:draw ( 2, x, y, l, false )
    self.sprite:draw ( 3, x, y, l, false )
    self.sprite:draw ( 4, x, y, l, false )
    self.sprite:draw ( 5, x, y, self.layers.bottom(), false )
    self.sprite:draw ( 6, x, y, self.izunaLayer(), false )
  end

  if self.scarf then
    self.scarf:draw    ( self.layers.bottom(), self.layers.particles ( ) - 1 )
  end
  if self.hookshot then
    self.hookshot:draw ( )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ § Return ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

return _NEGA