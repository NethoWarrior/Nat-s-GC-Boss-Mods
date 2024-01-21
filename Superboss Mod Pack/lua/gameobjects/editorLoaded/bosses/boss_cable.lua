-- CABLE, THE POWER CIRCUIT, THE POWER PLANT BOSS
local _CABLE    = BaseObject:subclass ( "CABLE_POWER_CIRCUIT" ):INCLUDE_COMMONS ( )
FSM:addState  ( _CABLE, "CUTSCENE"             )
FSM:addState  ( _CABLE, "BOSS_CIRCUIT_PICKUP"  )
Mixins:attach ( _CABLE, "gravityFreeze"        )
Mixins:attach ( _CABLE, "bossTimer"            )


_CABLE.static.IS_PERSISTENT     = true
_CABLE.static.SCRIPT            = "dialogue/boss/cutscene_cableConfrontation" 
_CABLE.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-cable"

_CABLE.static.EDITOR_DATA = {
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

_CABLE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "cable"         )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.obstacles,   "obstacles"     )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "hash"        )
  CutsceneManager.preload   ( _CABLE.SCRIPT                               )
end

_CABLE.static.PALETTE             = Colors.Sprites.cable
_CABLE.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue, 
  Colors.green_blue, 
  Colors.green_blue, 
  Colors.green_4, 
  Colors.green_4, 
  Colors.green_4
)

_CABLE.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_CABLE.static.DIMENSIONS = {
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

_CABLE.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_CABLE.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
}

_CABLE.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
}

_CABLE.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_CABLE.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_CABLE.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_CABLE.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:finalize ( parameters )
  RegisterActor ( ACTOR.CABLE, self )
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )
  self.velocity.vertical.gravity.maximum = 6.5

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "cable", 1 )

  self.isFlinchable = false
  self.sprite:change ( 1, "battle-intro-pose", 1, false )

  self.beams                = {}
  self.beamsToCallDown      = 0
  self.beamsToCallDownTimer = 0
  self.actionsWithoutRest   = 0
  self.nextActionTime       = 1
  self.desperationActivated = false

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.sensors = {
    ARCH_JUMP = 
      Sensor
        :new                ( self, self.filters.player,   22,  -10, -64, GAME_HEIGHT )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    GROUND_SLAM = 
      Sensor
        :new                ( self, self.filters.player,   24,  -10, -68, GAME_HEIGHT )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    CEILING_CHECK =
      Sensor
        :new                ( self, self.filters.player, -80,  -200, 140, 150 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( false ),
    CEILING_CHECK_WALLS =
      Sensor
        :new                ( self, self.filters.tile,  -32,  -10,  44, 2 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    CEILING_CHECK_2 =
      Sensor
        :new                ( self, self.filters.player, -400, -200, 820, 55 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    HOP_SENSOR =
      Sensor
        :new                ( self, self.filters.tile,  -10,   -20,  32,  16 ),
    MELEE_SENSOR =
      Sensor
        :new                ( self, self.filters.player,-10,   -27,  44,  30 )
        :disableDraw        ( true ),
    ELECTRIFIABLE_SURFACE_SENSOR =
      Sensor
        :new                ( self, self.filters.tile,  -22, 3, 24, 4 )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    FLOOR_SENSOR_FOR_WALL_JUMPING =
      Sensor
        :new                ( self, self.filters.tile,  -19, 3, 18, 35 )
        :isScaleAgnostic    ( true )
        :expectOnlyOneItem  ( true )
        :disableDraw        ( true ),
  }

  self.sensors.ARCH_JUMP:activate(false)
  self.sensors.GROUND_SLAM:activate(false)

  self.HAS_IGNORED_TILES = {}

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -1,  0, 36,  36, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil
  if parameters and parameters.bossRush then
    self.state.isBossRushSpawn  = true
    self.state.isBoss           = true
    self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
      self.sprite:change ( 1, "idle" )
    end
  elseif parameters and parameters.isTarget then
    self.state.isBoss   = true
    self.listener       = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    --self:gotoState ( "BOSS_CIRCUIT_PICKUP" )

    local flag  = GetFlag ( "cable-boss-prefight-dialogue" ) 
    local flag2 = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" ) 

    if GAMESTATE.speedrun then
      flag  = true
      flag2 = 0
    end
    
    if (not flag) or (flag2 and flag2 > 0) then
      self.sprite:change ( 1, nil )
    end
    --if not flag  then
    --  self:gotoState      ( "PREFIGHT_INTRO" )
    --end
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end
end

function _CABLE:activate ( )  
  if not self.state.isSpawnBoss then
    GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  end
  
  self.health      = 48
  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "cable", self.health )
  self.activated   = true
  self:grabBeams()
end

function _CABLE:grabBeams ( )
  if self.beamsInit then return end
  self.beamsInit = true
  local x, y       = Camera:getPos()
  local items, len = Physics:queryRect ( x+1, y+1, GAME_WIDTH-2, 128, self.filters.elecBeam )
  for i = 1, len do
    self.beams[i] = items[i].parent
  end
  local sort_func = function ( a,b ) return a:getX() < b:getX() end
  table.sort(self.beams, sort_func)
end 

function _CABLE:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end

  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end

  UnregisterActor ( ACTOR.CABLE, self )
end

function _CABLE:isDrawingWithPalette ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Animation handling -------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:manageChainAnimation ( )
  if self.state.isLaunched then
    self.sprite:change ( 1, "spin", 1 )
    self.sprite:stop   ( 1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _CABLE:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _CABLE:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:getScaleX() > 0 then
    mx = mx - 3
  else
    mx = mx + 1
  end
  return mx, my
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _CABLE:update (dt)
  if self.ignoredClearEventually then
    self:tryClearingIgnored ()
  end

  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self:updateBossInvulnerability ( )
  self:updateLocations           ( )
  self:updateBeams               ( )

  if self.activated and self:isInState ( nil ) then
    --self.timer = self.timer + 1
    --if self.nextActionTime < self.timer then
    if self:updateBossTimer ( ) then
      self:pickAction()
    else
      if not self.wentAbove and self.sensors.CEILING_CHECK:check() then
        self.wentAbove = true
      end
    end
  end

  if not (self.isChainedByHookshot) then
    self:tick    ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:updateContactDamageStatus ()
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )
end

function _CABLE:tick ()
  self:applyPhysics()
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_CABLE.static.ACTIONS = {
  "DESPERATION_ACTIVATION",        -- 1
  "CEILING_COUNTER_ELEC_BEAM_VER", -- this one is unused
  "CEILING_COUNTER",               -- 3
  "HOP",                           -- 4
  "ARCH_JUMP",                     -- 5
  "LUNGE_ATTACK",                  -- 6
  "HOP",                           -- 7
  "CALL_BEAM",                     -- 8
}

function _CABLE:pickAction (recursion, px, py, mx, my)
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
  local chance            = RNG:getPercent ()
  if (self.forceDesperation) and (self.lastAction ~= 8 or self.hadForcedLaunch) then
    -- Desperation phase
    self.hadForcedLaunch          = false
    self.forceDesperation         = false
    self.actionsSinceDesperation  = 0
    action                        = 1
  elseif self.sensors.CEILING_CHECK_2:check() and self.beamsToCallDown <= 0 and self.beamsToCallDownTimer <= 0 then
    -- Ceiling counter, ceiling beams ver
    action = 8
    extra  = true
  elseif not self.sensors.CEILING_CHECK_WALLS:check() and self.wentAbove and chance < 0.40 then
    -- Ceiling counter
    action = 3
  elseif self.beamsToCallDown <= 0 and chance < 0.2 and (px > cx+32 and px < cx+GAME_WIDTH-32) then
    action = 8
    extra  = false
  elseif chance < 0.275 or (py+50) < my then
    local dir = mx > px and -1 or 1
    if self:checkBumpOnTheFloor ( dir ) then
      -- Hop that leads to arch jump
      action = 4
      extra  = true
    else
      -- Arch jump
      action = 5
    end
  else
    if math.abs(px-mx) < 50 and RNG:n() < 0.45 then
      -- Melee attack
      action = 6
    else
      -- Hop
      action = 7
    end
  end

  if not recursion and self.lastAction and action == self.lastAction then
    if RNG:flip() then
      self:pickAction(true, px, py, mx, my) 
      if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
        print("[BOSS] Rerolling action:", action)
      end
    end
    return
  end

  if self.desperationActivated then
    if not self.actionsSinceDesperation then
      self.actionsSinceDesperation = 0
    end
    self.actionsSinceDesperation = self.actionsSinceDesperation + 1
    if self.actionsSinceDesperation > 7 and self.lastAction ~= 8 then
      self.forceDesperation = RNG:n() < (0.15 + (self.actionsSinceDesperation-7)*0.15)
    end
  end

  self.lastAction = action

  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end

  self.wentAbove = false
end

function _CABLE:endAction ( finishedNormally, forceWait, clearActions )
  if clearActions then
    self.actionsWithoutRest = 0
  end
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest < 3 and not forceWait then
      self.nextActionTime     = self.desperationActivated and 3 or 3
    else
      self.nextActionTime     = self.desperationActivated and 3 or 3
      self.actionsWithoutRest = 0
    end
    --if GAMEDATA.isHardMode() then
    --  self.nextActionTime = self.nextActionTime - 2
    --end
  end
end

function _CABLE:getLocations ()
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _CABLE:updateLocations()
  local x, y = GlobalObserver:single ("GET_PLAYER_MIDDLE_POINT" )
  if x then
    self.lastPlayerX, self.lastPlayerY = x, y
  end
  self.playerIsKnownToBeAlive                  = GlobalObserver:single ("IS_PLAYER_ALIVE")
  self.lastKnownPlayerX, self.lastKnownPlayerY = self.lastPlayerX, self.lastPlayerY
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Randomly ignore ground ---------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:checkBumpOnTheFloor ( dir, force )
  local hit, cols, len = self.sensors.HOP_SENSOR:check(dir,1)
  if force then

  end
  if not hit then
    return false
  end

  if not force then
    if RNG:n() < 0.4 then
      return true
    end
  end

  for i = 1, len do
    if not cols[i].isElectrifiable then
      return true
    end
  end

  for i = 1, len do
    self.ignoredClearEventually     = 20
    self.HAS_IGNORED_TILES[cols[i]] = true 
  end
  return false
end

function _CABLE:tryClearingIgnored ( )
  if self.ignoredClearEventually > 0 then
    self.ignoredClearEventually = self.ignoredClearEventually - 1
    return
  end
  local x,y = self:getPos()
  x = x + self.class.DIMENSIONS.x
  y = y + self.class.DIMENSIONS.y

  local _, len = Physics:queryRect ( x, y, self.class.DIMENSIONS.w, self.class.DIMENSIONS.h, self.filters.tile )
  if len <= 0 then
    self.ignoredClearEventually = false
    cleanTable ( self.HAS_IGNORED_TILES )
  end 
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Landing dust -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:handleYBlock(_,__,currentYSpeed)
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
--[[------------------------------ §Beams   ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _CABLE:updateBeams ()
  if not self.state.isBoss or self.isUsingDesperation then return end
  if self.beamsToCallDown > 0 then
    if self.beamsToCallDownTimer > 0 then
      self.beamsToCallDownTimer = self.beamsToCallDownTimer - 1
      return
    end
  else
    if self.beamsToCallDownTimer > 0 then
      self.beamsToCallDownTimer = self.beamsToCallDownTimer - 1
    end
    return
  end
  self.beamsToCallDownTimer = 8
  self.beamsToCallDown      = self.beamsToCallDown - 1
  local cx = Camera:getX()
  local x = math.floor(self.lastKnownPlayerX - cx) 
  x = math.round(x / 16)
  if self.lastKnownPlayerX < cx + 16 + (x-1) * 16 then
    x = x - 1
  end
  if x <= 0 then
    x = 1
  elseif x >= #self.beams then
    x = #self.beams
  end
  if self.beams[x] then
    if self.beams[x]:isActivated() then
      self:checkNonActiveBeams(RNG:rsign(), x)
    else
      self.beams[x]:activate(true, 80 )
    end
  end
end

function _CABLE:checkNonActiveBeams(dir, x, recursive)
  for i = x, (dir > 0 and #self.beams or 1), dir do
    if not self.beams[i] then
      if not recursive then
        self:checkNonActiveBeams(-dir, x, true)
      end
      return
    end
    if not self.beams[i]:isActivated() then
      self.beams[i]:activate(true, 80 )
      return
    end
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _CABLE:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Hop ----------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HOP = _CABLE:addState ( "HOP" )
function _HOP:enteredState ( px, py, mx, my, fromShortHopToArchJump )
  local dir    = mx > px and -1 or 1
  self.sprite:flip ( dir )
  self.stateVars.fromShortHopToArchJump = fromShortHopToArchJump
  self.stateVars.continuousHop = 0
  if fromShortHopToArchJump or self:checkBumpOnTheFloor ( dir ) then
    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    self.velocity.horizontal.direction  = -dir
    self.velocity.horizontal.current    = 1
    self.velocity.vertical.current      = -4
    self.stateVars.backHop              = true
    self.sprite:change ( 1, "hop-backwards-2" )
  else
    self:longHop ( dir )
  end
  self.sensors.GROUND_SLAM:activate(true)
  self.timer = 0
end

function _HOP:exitedState ( )
  self.sensors.GROUND_SLAM:activate(false)
  self:endAction(false)
  self.velocity.horizontal.current = 0
end

function _HOP:longHop ( dir )
  local chance = RNG:n()
  if self.stateVars.lastWasShortHop then
    chance = chance - 0.15
  end
  if chance < (0.4+self.stateVars.continuousHop) then
    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    self.stateVars.bigHop               = true
    self.velocity.vertical.current      = -6
    self.velocity.horizontal.direction  = dir
    self.velocity.horizontal.current    = 2.25
    self.stateVars.backHop              = false
    self.stateVars.performSlam          = true
  elseif chance < 0.75 or self.stateVars.fake then
    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    self.velocity.vertical.current      = -4
    self.velocity.horizontal.direction  = dir
    self.velocity.horizontal.current    = 1.25
    self.stateVars.backHop              = false
    self.stateVars.performSlam          = true
    self.stateVars.continuousHop        = self.stateVars.fake and (self.stateVars.continuousHop + 0.15) or (self.stateVars.continuousHop + 0.075)
  else
    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    self.velocity.vertical.current      = -3
    self.velocity.horizontal.direction  = dir
    self.velocity.horizontal.current    = 0.5
    self.stateVars.backHop              = false
    self.stateVars.fake                 = true
    self.stateVars.continuousHop        = self.stateVars.continuousHop + 0.05
  end
  --if self.velocity.horizontal.current > 1.5 then
    self.sprite:change ( 1, "jump" )
  --end
end

function _HOP:tick ( )
  self.timer = self.timer + 1
  self:applyPhysics()

  if self.velocity.vertical.current >= 0 then
    self.sprite:change ( 1, "fall" )
  end

  if self.state.isGrounded then
    Audio:playSound ( SFX.gameplay_boss_cable_landing )
    local px, py, mx, my = self:getLocations()
    self.sprite:flip   ( px > mx and 1 or -1 )
    self.sprite:change ( 1, "hop-land" )
    if self.stateVars.backHop or self.stateVars.fake then
      local dir = self.sprite:getScaleX()
      if self:checkBumpOnTheFloor ( dir ) then
        Audio:playSound ( SFX.gameplay_boss_cable_jump )
        self.velocity.horizontal.direction  = -dir
        self.velocity.horizontal.current    = 0.5
        self.velocity.vertical.current      = -4
        self.stateVars.backHop              = true
        self.sprite:change ( 1, "hop-backwards-2" )
        return
      end
      px, py, mx, my = self:getLocations()
      if (RNG:n() < 0.25 and px) or self.stateVars.fromShortHopToArchJump then
        self:gotoState ( "ARCH_JUMP", px, py, mx, my )
        return
      else
        px, py, mx, my = self:getLocations()
        dir = px > mx and 1 or -1
        self.sprite:flip(dir)
        self.stateVars.lastWasShortHop = true
        self:longHop(dir)
      end
    else
      self:endAction(true)
    end
  end

  if self.stateVars.bigHop and self.stateVars.performSlam then
    --self.sprite:change ( 1, "idle" )
    if math.abs(self.velocity.vertical.current)   < 3 and self.sensors.GROUND_SLAM:check() then
      self:gotoState ( "GROUND_SLAM", false )
    end
    --elseif math.abs(self.velocity.vertical.current) < 1 then
    --  self:gotoState ( "GROUND_SLAM", true  )
    --end
    return
  end
end

function _HOP:handleXBlock ()
  if self.timer < 10 then return end
  if self.sensors.FLOOR_SENSOR_FOR_WALL_JUMPING:check() then
    return
  end
  local px, py, mx, my = self:getLocations()
  if px then
    self:gotoState ( "ARCH_JUMP", px, py, mx, my, true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Ground slam --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _GROUND_SLAM = _CABLE:addState ( "GROUND_SLAM" )
function _GROUND_SLAM:enteredState ( diagonal )
  if diagonal then
    local speed                       = self.velocity.horizontal.current / 2
    speed                             = speed - (speed%0.25) +.25
    self.velocity.horizontal.current  = self.velocity.horizontal.current / 2
    self.stateVars.diagonalSlam       = true
  else
    self.velocity.horizontal.current  = 1
  end
  self.velocity.vertical.current      = -1
  self.velocity.vertical.gravity.acceleration = 0.35
  self.timer                          = 0
  self.stateVars.goingDown            = false
  self.stateVars.landedFromSlam       = false
  self:setAfterImagesEnabled(true)
  self.sprite:change ( 1, "grand-slam-down" )
  local px, py, mx, my = self:getLocations()
  Particles:addFromCategory ( "warp_particle_hash", mx, my,   1,  1, 0, -0.5, l, false, 1, true )
  local px, py = self.lastPlayerX, self.lastPlayerY
  self:setActualPos ( px, py-90)
  local px, py, mx, my = self:getLocations()
  Particles:addFromCategory ( "warp_particle_hash", mx, my,   1,  1, 0, -0.5, l, false, 1, true )
  Audio:playSound ( SFX.gameplay_hash_warp_out )

  Audio:playSound ( SFX.gameplay_boss_cable_pointing )
end

function _GROUND_SLAM:exitedState (  )
  self.velocity.horizontal.current            = 0
  self.velocity.vertical.gravity.acceleration = 0.50
  self.velocity.vertical.gravity.maximum      = 8
  self:endAction                  ( false )
  self:setAfterImagesEnabled      ( false )
  self.velocity.horizontal.current = 0
end

function _GROUND_SLAM:tick ( )
  self.timer = self.timer + 1
  self:applyPhysics()
  if not self.stateVars.goingDown and self.timer == 20 then
    if self.stateVars.diagonalSlam then
      self.velocity.horizontal.current = 1.5
    end
    self.velocity.vertical.current              = 2.5
    self.velocity.vertical.gravity.acceleration = 1
    self.velocity.vertical.gravity.maximum      = self.desperationActivated and  10 or 7
    self.stateVars.goingDown                    = true
    self:setAfterImagesEnabled(true)
  end

  if self.state.isGrounded then
    if self.stateVars.diagonalSlam then
      self.sprite:change ( 1, "ground-slam-land-forward" )
    else
      self.sprite:change ( 1, "ground-slam-land-down" )
    end
    if not self.stateVars.landedFromSlam then
      Audio:playSound ( SFX.gameplay_punch_hit )
      self.velocity.horizontal.current = 0
      self.stateVars.landedFromSlam    = true
      local x,y = self:getMiddlePoint()
      GameObject:spawn     ( "shift_uppercut_projectile", x,   y-26, -1 )
      GameObject:spawn     ( "shift_uppercut_projectile", x,   y-26,  1 )
      self.timer                       = 0 
      self.velocity.vertical.gravity.acceleration = 0.25
      self.velocity.vertical.gravity.maximum      = 5.75
      self.velocity.vertical.current = 0

      local hit, items, len = self.sensors.ELECTRIFIABLE_SURFACE_SENSOR:check ()
      if hit then
        for i = 1, len do
          if items[i].isElectrifiable then
            Environment.electrifiedSurface ( items[i] )
          end
        end
      end
    elseif self.timer >= 20 then
      self:endAction ( true )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Arch jump ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _ARCH_JUMP = _CABLE:addState ( "ARCH_JUMP" )
function _ARCH_JUMP:enteredState ( px, py, mx, my, straightToWallJump )
  self.velocity.vertical.current = -7.0
  --self.velocity.vertical.current = -11
  --self.velocity.vertical.gravity.acceleration = 0.5
  --self.velocity.vertical.gravity.maximum      = 11

  if straightToWallJump then
    self:wallJump()
  else
    Audio:playSound ( SFX.gameplay_boss_cable_jump )
    local dif    = math.abs(mx - px)
    local dir    = mx > px and -1 or 1
    self.sprite:flip ( dir )
    self.velocity.horizontal.direction  = dir
    dif = dif / 41
    dif = dif - (dif % 0.25) +.5
    self.velocity.horizontal.current    = dif

    self.stateVars.jumped = false

    self.sensors.ARCH_JUMP:activate(true)
    self:setAfterImagesEnabled(true)
  end

  self.sprite:change ( 1, "jump" )
  self.timer = 0

  self.stateVars.targetCount = (self.desperationActivated and 3 or 1)
  if GAMEDATA.isHardMode() then
    self.stateVars.targetCount = self.stateVars.targetCount + 2
  end
end

function _ARCH_JUMP:exitedState ()
  self:endAction(false)
  self.velocity.vertical.gravity.maximum      = 5.75
  self.velocity.horizontal.direction          = 0
  self.velocity.horizontal.current            = 0
  self.velocity.vertical.gravity.acceleration = 0.25
  self.sensors.ARCH_JUMP:activate(false)
  self:setAfterImagesEnabled(false)
end

function _ARCH_JUMP:tick ()
  self.timer = self.timer + 1
  self:applyPhysics()
  if self.stateVars.wallJumped and self.stateVars.wallJumped > 0 then
    if self.stateVars.wallJumped == 16 then
      self.sprite:change ( 1, "wall-jump" )
    end
    self.stateVars.wallJumped = self.stateVars.wallJumped - 1
    if self.stateVars.wallJumped <= 0 then
      Audio:playSound ( SFX.gameplay_boss_cable_jump )
      self.velocity.horizontal.direction          = self.velocity.horizontal.direction * -1
      self.velocity.horizontal.current            = 2.25
      self.velocity.vertical.gravity.acceleration = 0.25
      self.velocity.vertical.current              = -3
      self.stateVars.detected                     = false
      self.stateVars.jumped                       = false
      local px, py, mx, my = self:getLocations()
      Particles:addFromCategory ( "warp_particle_hash", mx, my,   1,  1, 0, -0.5, l, false, 1, true )
      local px, py = self.lastPlayerX, self.lastPlayerY
      self:setActualPos ( px, py-70)
      local px, py, mx, my = self:getLocations()
      Particles:addFromCategory ( "warp_particle_hash", mx, my,   1,  1, 0, -0.5, l, false, 1, true )
      Audio:playSound ( SFX.gameplay_hash_warp_out )
      return
    end
  elseif not self.stateVars.jumped then
    if not self.stateVars.detected and self.sensors.ARCH_JUMP:check() then
      if self.velocity.vertical.current > -5 and self.velocity.vertical.current < 4.75 then
        self.sprite:change ( 1, "shoot-down-start" )
        self.stateVars.detected           = 10
        self.velocity.vertical.current    = -2
        local speed = self.velocity.horizontal.current / 2
        speed = speed - (speed%0.25) +.25
        self.velocity.horizontal.current  = speed
      end
    elseif self.stateVars.detected then
      self.stateVars.detected = self.stateVars.detected - 1
      if self.stateVars.detected <= 0 then
        self.velocity.horizontal.current            = 1.5
        self.velocity.vertical.current              = -3.75
        self.stateVars.jumped                       = true
        self.stateVars.counter                      = -1
        self.state.isGrounded                       = false
        self.timer                                  = 0
      end
    end
  end

  if self.stateVars.jumped and self.timer % 6 == 0 then
    if self.stateVars.counter > -1 and self.stateVars.counter < self.stateVars.targetCount then
      self.sprite:change ( 1, "shoot-down-release", 1 )
      local dir = self.sprite:getScaleX()
      local x,y = self:getPos()
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 10 or 7), 
        y+27, 
        0, 
        1
      )
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 10 or 7)+30, 
        y+27, 
        0, 
        1
      )
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 10 or 7)-30, 
        y+27, 
        0, 
        1
      )
    end
    self.stateVars.counter = self.stateVars.counter + 1
  end

  if self.state.isGrounded then
    Audio:playSound ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 1, "hop-land" )
    self.stateVars.finished = true
    self:endAction(true)
  end
end

function _ARCH_JUMP:handleXBlock ()
  if self.timer < 10 then return end
  if not self.stateVars.wallJumped and self.velocity.vertical.current < 5.0 then
    if not self.sensors.FLOOR_SENSOR_FOR_WALL_JUMPING:check() then
      self:wallJump()
    end
  end
end

function _ARCH_JUMP:wallJump ()
  self.sprite:change ( 1, "wall-jump", 1 )
  self.stateVars.wallJumped = 16
  self.velocity.vertical.gravity.acceleration = 0
  self.velocity.vertical.current              = 0
  self.velocity.horizontal.current            = 0
  self.stateVars.jumped                       = false
  self.sprite:mirrorX()
  self:setAfterImagesEnabled(false)
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Lunge attack §Melee ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _LUNGE_ATTACK = _CABLE:addState ( "LUNGE_ATTACK" )
function _LUNGE_ATTACK:enteredState ( px, py, mx, my )
  local dir    = mx > px and -1 or 1
  self.sprite:flip ( dir )
  self.velocity.horizontal.direction  = dir

  self.timer = 0

  self.stateVars.lunged   = false
  self.stateVars.deaccel  = 0.25
  self.sprite:change ( 1, "melee-attack", 1, true )
  self.stateVars.shot     = false
end

function _LUNGE_ATTACK:exitedState ()
  self:endAction (false)
  self:setAfterImagesEnabled(false)
  self.velocity.horizontal.current = 0
end

function _LUNGE_ATTACK:tick ()
  self.timer = self.timer + 1
  self:applyPhysics()

  if self.stateVars.finished and self.timer == 28 then
    self:endAction(true)
    return
  end

  if not self.stateVars.finished then
    if self.stateVars.lunged and self.velocity.horizontal.current > 0 then
      self.velocity.horizontal.current = self.velocity.horizontal.current - self.stateVars.deaccel
      if self.velocity.horizontal.current <= 0 then
        self:setAfterImagesEnabled(false)
        --self.sensors.HOP_SENSOR:check(self.sprite:getScaleX())
        self.velocity.horizontal.current = 0
        self.timer                       = 0
        self.stateVars.finished          = true
      end
    elseif self.stateVars.lunged and self.velocity.horizontal.current <= 0 then
      self:setAfterImagesEnabled(false)
      self.velocity.horizontal.current = 0
      self.timer                       = 0
      self.stateVars.finished          = true
    end
  end

  if self.stateVars.lunged and self.timer < 9 then
    local dir = self.sprite:getScaleX()
    if not self.stateVars.shot then
      local x,y = self:getPos()
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 20 or -4), 
        y+7, 
        dir, 
        0,
        3,
        true
      )
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 20 or -4), 
        y-7, 
        dir, 
        0,
        3,
        true
      )
      GameObject:spawn ( 
        "elec_ball", 
        x+(dir > 0 and 20 or -4), 
        y-17, 
        dir, 
        0,
        3,
        true
      )
      local count = 0
      if self.desperationActivated then
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y+7, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 8 )
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y-7, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 8 )
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y-17, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 8 )
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y+7, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 16 )
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y-7, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 16 )
        GameObject:spawn ( 
          "elec_ball", 
          x+(dir > 0 and 20 or -4), 
          y-17, 
          dir, 
          0,
          3,
          true
        ):setDelay ( 16 )
        count = 2
      end
      self.stateVars.shot = true
    end

    --if self.sensors.MELEE_SENSOR:check(dir) then
    --  GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_MEDIUM, "weak", dir )
    --end
  end

  if self.timer == 24 and not self.stateVars.lunged then
    self.velocity.horizontal.current  = 0.0
    self.stateVars.lunged             = true
    Audio:playSound ( SFX.gameplay_punch )
  end
end

function _LUNGE_ATTACK:handleXBlock () 
  self.stateVars.deaccel              = 0.25
  self.velocity.horizontal.current    = 0.25
  self.velocity.horizontal.direction  = self.velocity.horizontal.direction * -1
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Ceiling counter ----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _CEILING_COUNTER = _CABLE:addState ( "CEILING_COUNTER" )
function _CEILING_COUNTER:enteredState ( px, py, mx, my )
  local dir    = mx > px and -1 or 1
  self.sprite:flip ( dir )

  self.stateVars.dir      = dir
  self.stateVars.counter  = 0
  self.sprite:change(1, "shoot-arc", 2 )
  self.timer               = 0
  self.stateVars.initWait  = true
  self.stateVars.shotFrame = -1
end

function _CEILING_COUNTER:exitedState ()
  self:endAction(false)
end

function _CEILING_COUNTER:tick ()
  self.timer = self.timer + 1
  self:applyPhysics()

  local x,y = self:getPos()
  local f   = self.sprite:getFrame()
  if f == 8 and self.stateVars.shotFrame ~= 8 then
    x = x + (self.stateVars.dir > 0 and 15 or 1)
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y+4, 
      self.stateVars.dir, 
      0,
      3,
      true
    )
    self.stateVars.shotFrame = f

    local delay = 10
    if self.desperationActivated then
      GameObject:spawn ( 
        "elec_ball", 
        x, 
        y+4, 
        self.stateVars.dir, 
        0,
        3,
        true
      ):setDelay ( 10 )
      delay = 20
    end
    if GAMEDATA.isHardMode() then
      GameObject:spawn ( 
        "elec_ball", 
        x, 
        y+4, 
        self.stateVars.dir, 
        0,
        3,
        true
      ):setDelay ( delay )
    end  

  elseif f == 9 and self.stateVars.shotFrame ~= 9 then
    x = x + (self.stateVars.dir > 0 and 15 or 1)
    local dirX, dirY = math.nineWayShotAngles ( self.stateVars.dir > 0 and 9 or 7)
    GameObject:spawn ( 
      "elec_ball", 
      x, 
      y-6, 
      dirX, 
      dirY,
      3,
      true
    )
    self.stateVars.shotFrame = f

    local delay = 10
    if self.desperationActivated then
      GameObject:spawn ( 
        "elec_ball", 
        x, 
        y-6, 
        dirX, 
        dirY,
        3,
        true
      ):setDelay ( 10 )
      delay = 20
    end
    if GAMEDATA.isHardMode() then
      GameObject:spawn ( 
        "elec_ball", 
        x, 
        y-6, 
        dirX, 
        dirY,
        3,
        true
      ):setDelay ( delay )
    end  

  elseif f == 10 and self.stateVars.shotFrame ~= 10 then
    local x,y = self:getPos()
    x = x + (self.stateVars.dir > 0 and -14 or 12)
    GameObject:spawn ( 
      "elec_ball", 
      x+10, 
      y-16, 
      0, 
      -1,
      3,
      true
    )
    self.stateVars.shotFrame = 10

    local delay = 10
    if self.desperationActivated then
      GameObject:spawn ( 
        "elec_ball", 
        x+10, 
        y-16, 
        0, 
        -1,
        3,
        true
      ):setDelay ( 10 )
      delay = 20
    end
    if GAMEDATA.isHardMode() then
      GameObject:spawn ( 
        "elec_ball", 
        x+10, 
        y-16, 
        0, 
        -1,
        3,
        true
      ):setDelay ( delay )
    end  

  end
  if self.sprite:getAnimation() == "idle" then self:endAction(true) end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Call beam ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _CALL_DOWN = _CABLE:addState ( "CALL_BEAM" )
function _CALL_DOWN:enteredState ( px, _, mx, my, punishPlayer )
  self.sprite:flip   ( px > mx and 1 or -1 )
  self.timer                  = punishPlayer and 180 or 60

  if not self.disappointmentCounter then
    self.disappointmentCounter = 0
  end
  if punishPlayer then
    self.disappointmentCounter = self.disappointmentCounter + 1
  end
  self.timer = (GAMEDATA.isHardMode()) and 30 or 60
  if self.disappointmentCounter == 5 then
    -- you've disappointed me, player
    self.stateVars.punishPlayer = true
    self.timer                  = 180
    self.disappointmentCounter  = 2
  end

  self.stateVars.initTimer    = self.timer - 10
end

function _CALL_DOWN:exitedState ()
  self:endAction(false)
end

function _CALL_DOWN:tick ()
  self.timer = self.timer - 1
  if self.timer == self.stateVars.initTimer then
    if self.stateVars.punishPlayer then
      self.sprite:change ( 1, "dissappointment-start" )
    else
      Audio:playSound ( SFX.gameplay_boss_cable_pointing )
      self.sprite:change ( 1, "call-down-beam"       )
      self.beamsToCallDown      = self.desperationActivated and 2 or 1
      self.beamsToCallDownTimer = 16
    end
  end
  if self.stateVars.punishPlayer and self.timer == 50 then
    Audio:playSound ( SFX.gameplay_boss_cable_pointing )
    self.sprite:change ( 1, "call-down-beam", 2 )
    self.beamsToCallDown      = 3
    self.beamsToCallDownTimer = 16
  end

  self:applyPhysics()
  if self.timer <= 0 then
    self:endAction(true)
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _CABLE:addState ( "DESPERATION_ACTIVATION" )
function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )

  self.isUsingDesperation = true

  self.sprite:flip ( px < mx and -1 or 1 )
  mx, my = self:getPos()
  px, py = Camera:getPos()
  px     = px + GAME_WIDTH/2 - 19
  local dif    = math.abs(mx - px)
  local dir    = mx > px and -1 or 1
  self.velocity.horizontal.direction  = dir
  dif = dif / 52
  dif = dif - (dif%0.25)

  local finalPosition = mx
  for i = 1, 52 do
    local adjust  = dif * dir 
    finalPosition = mx + adjust
    finalPosition = finalPosition - (finalPosition % 0.25)
  end
  if finalPosition < px-10 or finalPosition > px+10 then
    dif = dif + 0.25
  end

  self.stateVars.speedToTarget  = dif
  self.stateVars.jumped         = false
  self.timer                    = -40

  self.sprite:change ( 1, "angry" )


  if self.desperationActivated then
    --self.stateVars.jumped = true     
    --self.sprite:flip      ( self.velocity.horizontal.direction )
    self.timer = 58
  else
    self.timer = 0
    self.sprite:change ( 1, "angry" )
  end
end

function _DESPERATION_ACTIVATION:exitedState ()
  if self.stateVars.startedSuperFlash then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end

  self.isUsingDesperation       = false
  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self.state.isBossInvulnerable = false
  self:endAction(false, true)
end

_CABLE.static.DESPERATION_AREAS = {
  [1] = {
    1,
    2,
    3,
    4,
    5,
  },
  [2] = {
    6,
    7,
    8,
    9,
  },
  [3] = {
    10,
    11,
    12,
    13,
    14,
  },
  [4] = {
    15,
    16,
    17,
    18,
  },
  [5] = {
    19,
    20,
    21,
    22,
    23,
  },
}

_CABLE.static.DESPERATION_PATTERNS = {
  [1] = {
    {
      1,
      3,
      5,
    },
    {
      2,
      4,
    },
    {
      1,
      3,
      5,
    },
    waitTime = 21,
  },
  [2] = {
    {
      2,
      4,
    },
    { 
      1,
      3,
      5,
    },
    {
      2,
      4,
    },
    waitTime = 21,
  },
  [3] = {
    {
      1,
      5,
    },
    {
      2,
      4,
    },
    {
      3,
    },
    {
      2,
      4,
    },
    {
      1,
      5,
    },
    waitTime = 21,
  },
  [4] = {
    {
      3,
    },
    {
      2,
      4,
    },
    {
      1,
      5,
    },
    {
      2,
      4,
    },
    {
      3,
    },
    waitTime = 21,
  },
  --[[
  [3] = {
    {
      1,
    },
    {
      2,
    },
    { 
      3,
    },
    { 
      4,
    },
    {
      5,
    },
    waitTime = 21,
  },
  [4] = {
    {
      5,
    },
    {
      4,
    },
    { 
      3,
    },
    { 
      2,
    },
    {
      1,
    },
    waitTime = 21,
  },]]
}

function _DESPERATION_ACTIVATION:tick ()
  self:applyPhysics()
  if not self.stateVars.finishedFlash then
    self.timer = self.timer + 1
    --[[
    if not self.stateVars.jumped and self.timer == 19 then
      self.sprite:flip         ( self.velocity.horizontal.direction )
      self:checkBumpOnTheFloor ( self.sprite:getScaleX(), true )
    end

    if not self.stateVars.jumped and self.timer == 20 then
      self.sprite:change ( 1, "jump" )
      Audio:playSound ( SFX.gameplay_boss_cable_jump )
      self.velocity.horizontal.current  = self.stateVars.speedToTarget
      self.velocity.vertical.current    = -6.5
      self.stateVars.jumped             = true
      self.state.isGrounded             = false
      self.timer                        = 0
    end

    if not self.state.isGrounded and self.velocity.vertical.current >= 0 then
      self.sprite:change ( 1, "fall" )
    end]]

    if --[[self.stateVars.jumped and]] self.state.isGrounded and not self.stateVars.animationStarted and self.timer > 60 then
      --Audio:playSound    ( SFX.gameplay_boss_cable_landing )
      self.sprite:change ( 1, "reach-baton-upwards" )
      self.timer                         = 0
      self.velocity.horizontal.current   = 0
      --self.velocity.horizontal.direction = 0
      self.stateVars.animationStarted    = true
      --self:endAction(true)
    end

    if not self.stateVars.activated and self.stateVars.animationStarted and self.timer > 8 then
      self.velocity.horizontal.current   = 0
      self.velocity.horizontal.direction = 0
      self.stateVars.activated           = true
      self.timer                         = 0
      local dir                          = self.sprite:getScaleX()
      local mx, my                       = self:getMiddlePoint()
      Particles:addSpecial ( "super_flash", mx + (dir > 0 and -13 or 12), my-20, self.layers.sprite()-2, self.layers.sprite()-1, false, mx, my )
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_START", self ) 
        self:permanentlyDisableContactDamage ( false ) 
        self.stateVars.startedSuperFlash = true
        self.state.isBossInvulnerable    = true
      end
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_cable", 4 )
      self.fakeOverkilledTimer = 1000
    end

    if not self.stateVars.finishedFlash and self.stateVars.activated and self.timer >= 20 then
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_END" )
        self.stateVars.startedSuperFlash = false
      end
      self.stateVars.finishedFlash      = true
      self.desperationActivated         = true
      self.stateVars.finishedAttacking  = false
      self.timer                        = 20
      if not self._firstDesperationActivation then
        self._firstDesperationActivation = true
        self.stateVars.pattern           = self.class.DESPERATION_PATTERNS [ 3 ] --RNG:range(3,4) ]
      else
        self.stateVars.pattern           = self.class.DESPERATION_PATTERNS [ RNG:range(1, #self.class.DESPERATION_PATTERNS ) ]
      end
      self.stateVars.patternPhase       = 1
      self.sprite:change ( 1, "reach-baton-upwards-end" )
    end
  elseif not self.stateVars.finishedAttacking then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.sprite:change ( 1, "call-down-beam", 2 )
      local segments = self.stateVars.pattern[self.stateVars.patternPhase]
      for i = 1, #segments do
        local seg = self.class.DESPERATION_AREAS[segments[i]]
        for b = 1, #seg do
          if seg[b] and self.beams[ seg[b] ] then
            self.beams[ seg[b] ]:activate(true,50)
          end
        end
      end
      self.timer                  = self.stateVars.pattern.waitTime
      if GAMEDATA.isHardMode() then
        self.timer = self.timer - 8
      end
      self.stateVars.patternPhase = self.stateVars.patternPhase + 1
      if self.stateVars.patternPhase > #self.stateVars.pattern then
        self.stateVars.finishedAttacking  = true
        self.timer                        = 60
      end
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction(true)
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _CABLE:addState ( "TECH_RECOVER" )

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
  self.sprite:change ( 1, "hop-backwards-2" )

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
      self.sprite:change ( 1, "hop-land" )
      self.velocity.horizontal.current = 0
      self.stateVars.landed = true
    end
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction ( true )
    end
  end
end

function _CABLE:manageTeching ( timeInFlinch )
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  return false
end

function _CABLE:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    return
  end
  if self.health - dmg <= (24) then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
    self.hadForcedLaunch          = true
    self.forceLaunched            = true
    self.forceDesperation         = true
    self.fakeOverkilledTimer      = 10000
    self.state.isBossInvulnerable = true

    self:spawnBossMidpointRewards ( )
    local mx, my = self:getMiddlePoint("collision")

    mx, my = mx+2, my-2
    Particles:add ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.particles() )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

    return true, 1.0, -4
  end
end

function _CABLE:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _CABLE:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and -10 or -25), -31
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _CABLE:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self:setActualPos ( self:getX()-2, self:getY())
  self.sprite:change ( 1, nil )
  self.timer = 20
  self:grabBeams()
  self.stateVars.beams = 0
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )

  self:applyPhysics()
end

function _CABLE:_runAnimation ( )
  if not self.isInState ( self, "PREFIGHT_INTRO" ) then
    self:gotoState ( "PREFIGHT_INTRO" )
    return false
  end

  self.timer = self.timer - 1
  if self.timer > 0 then
    return false
  end

  if self.stateVars.beams < 5 then
    self.stateVars.beams = self.stateVars.beams + 1
    self.timer = 25
    if self.stateVars.beams == 1 then
      self.beams[16]:activate(true, 60 )
    elseif self.stateVars.beams == 2 then
      self.beams[17]:activate(true, 60 )
    elseif self.stateVars.beams == 3 then
      self.beams[18]:activate(true, 60 )
    elseif self.stateVars.beams == 4 then
      self.beams[15]:activate(true, 60 )
      self.timer = 42
    else
      self.sprite:change ( 1, "battle-intro-pose-2", 1, true )
      self.timer = 110
    end
    return false
  end


  self:gotoState ( "CUTSCENE" )

  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §§S HOP -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _S_HOP = _CABLE:addState ( "S_HOP" )

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

  self.stateVars.angryDelay       = 50
  self.timer                      = 50
  self.sprite:flip   ( -1, 1 )
  self.sprite:change ( 1, "idle" )

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
      self.sprite:change ( 1, "angry" )
    end
    return
  end

  if self.state.isGrounded then
    self.timer = self.timer - (self.state.isSpawnBoss and 1.25 or 1)
    if self.timer <= 0 then
      --self:endAction ( true )
      if not self.playerIsKnownToBeAlive then return end
      local px, py, mx, my = self:getLocations()
      self:gotoState ( "DESPERATION_ACTIVATION", px, py, mx, my )
      self.actionsSinceDesperation = -1
    end
  end
end

function _CABLE:env_emitSmoke ( )
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

  Particles:addFromCategory ( "warp_particle_cable", x, y,   1,  1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Return -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

return _CABLE