-- BIT, THE SHIFT CIRCUIT, HIGHWAY AREA BOSS
local _BIT    = BaseObject:subclass ( "BIT_SHIFT_CIRCUIT" ):INCLUDE_COMMONS ( )
FSM:addState  ( _BIT, "CUTSCENE"             )
FSM:addState  ( _BIT, "BOSS_CIRCUIT_PICKUP"  )
Mixins:attach ( _BIT, "gravityFreeze"        )
Mixins:attach ( _BIT, "bossTimer"            )

_BIT.static.IS_PERSISTENT     = true
_BIT.static.SCRIPT            = "dialogue/boss/cutscene_bitConfrontation"
_BIT.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-bit"

_BIT.static.EDITOR_DATA = {
  width   = 2,
  height  = 2,
  ox      = -47,
  oy      = -27,
  mx      = 88,
  order   = 9980,
  category = "bosses",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isUnique      = true,
    isTargetable  = true,
  }
}

_BIT.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc, "bit" )
  CutsceneManager.preload   ( _BIT.SCRIPT               )
end

_BIT.static.PALETTE             = Colors.Sprites.bit
_BIT.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue, 
  Colors.bit_color_4,
  Colors.bit_color_4,
  Colors.bit_color_3,
  Colors.bit_color_3,
  Colors.bit_color_3
)

_BIT.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_BIT.static.DIMENSIONS = {
  x            =   2,
  y            =   6,
  w            =  24,
  h            =  26,
  -- these basically oughto match or be smaller than player
  grabX        =   7,
  grabY        =   4,
  grabW        =  14,
  grabH        =  28,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_BIT.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_BIT.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
  warningTile       = Filters:get ( "queryWarningTile"            ),
  enemy             = Filters:get ( "queryEnemyObjectsFilter"     ),
}

_BIT.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  behind    = Layer:get ( "BEHIND-TILES", "SPRITES"   ),
}

_BIT.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_BIT.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_BIT.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_BIT.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true
_BIT.static.BOSS_CIRCUIT_SPAWN_OFFSET          = {
  x = 0,
  y = -16,
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:finalize ( parameters )
  RegisterActor ( ACTOR.BIT, self )
  self:translate ( 0, 16 )
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )
  self.velocity.vertical.gravity.maximum = 6.5

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "bit", 1 )
  self.sprite:change ( 1, "idle" )
  self.sprite:addInstance ( 2 )
  self.sprite:addInstance ( 3 )

  self.isFlinchable           = false
  self.isImmuneToLethalTiles  = true
  self.ignoresDamagingTiles   = true

  self.summonTime   = 0
  self.summonX      = 0
  self.summonY      = 0
  self.pillarTime   = 0
  self.pillarWidth  = 0

  self.actionsWithoutRest   = 0
  self.nextActionTime       = 10
  self.desperationActivated = false

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.actions = {
    "DESPERATION_ACTIVATION",
  }

  self.sensors = {
    VERTICAL_SLASH_SENSOR = 
      Sensor
        :new                ( 
          self, 
          self.filters.player, 
          -self.dimensions.x-self.dimensions.w-10, 
          -10,
          self.dimensions.w+(10+self.dimensions.x)*2,
          10 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),
    DASH_IN_SENSOR = 
      Sensor
        :new                ( 
          self, 
          self.filters.player, 
          -self.dimensions.x-self.dimensions.w-40, 
          -self.dimensions.y-self.dimensions.h-20,
          self.dimensions.w+(40+self.dimensions.x)*2,
          self.dimensions.h+(20+self.dimensions.y)*2-4)
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),
    WARNING_SENSOR = 
      Sensor
        :new                ( 
          self, 
          self.filters.warningTile, 
          -self.dimensions.x-self.dimensions.w-5, 
          -self.dimensions.y-self.dimensions.h-5,
          self.dimensions.w+(5+self.dimensions.x)*2,
          self.dimensions.h+(5+self.dimensions.y)*2-4)
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        --:disableDraw        ( true )
        --:activate           ( true )
  }

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -4, -2, 36, 36, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.state.isHittable = false

  self.defaultStateFromFlinch = nil
  if parameters and parameters.bossRush then
    self.state.isBossRushSpawn  = true
    self.state.isBoss           = true
    self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
      self.sprite:change ( 1, "battle-idle" )
    end
  elseif parameters and parameters.isTarget then
    self.state.isBoss   = true
    self.listener       = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)

    local flag  = GetFlag ( "bit-boss-prefight-dialogue" ) 
    local flag2 = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" ) 

    if GAMESTATE.speedrun then
      flag  = true
      flag2 = 0
    end
    
    if (not flag) or (flag2 and flag2 > 0)  then
      self:gotoState      ( "PREFIGHT_INTRO" )
    end
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end
end

function _BIT:activate ( )    
  if not self.state.isSpawnBoss then
    GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  end
  
  self:createBlockades ( )
  self.health           = GAMEDATA.boss.getMaxHealth ( )  
  self.activated        = true
  self.state.isHittable = true
end

function _BIT:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end

  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end

  UnregisterActor ( ACTOR.BIT, self )
end

function _BIT:isDrawingWithPalette ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §lethal tiles -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:handleLethalTiles ( sensor )
  if sensor then
    if self.isStunned and not self.state.isRecovering then
      if self.sensors.WARNING_SENSOR:check() then
        self.stateVars.exitedProperly = true
        self:gotoState ( "PIT_RECOVER" )
      end
    end
    return
  end

  if self.isStunned then
    self.stateVars.exitedProperly = true
  end
  self:gotoState ( "PIT_RECOVER" )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §blockades ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:createBlockades ( )
  local isOfficial, map = MapTracker:isOfficialMap ( )
  if not isOfficial --[[or map ~= "SHIFT"]] then return end

  local cx, cy = Camera:getPos()
  local h      = 96*6+GAME_HEIGHT*6
  -- left side of the screen
  local items, len = Physics:queryRect ( cx - 160, cy-96, 160, h )
  for i = 1, len do
    if not items[i].isDamaging and items[i].isSolid then
      Physics:removeObject ( items[i] )
    end
  end

  -- right side of the screen
  items, len = Physics:queryRect ( cx + GAME_WIDTH, cy-96, 160, h )
  for i = 1, len do
    if not items[i].isDamaging and items[i].isSolid then
      Physics:removeObject ( items[i] )
    end
  end

  local prop = { isTile = true, isWallJumpPreventing = true, isSolid = true, noCollisionWithHookshot = true }
  local leftw, rightw = Physics:newObject ( "left_bit_wall",  0, 0, 16, h, prop ),
                        Physics:newObject ( "right_bit_wall", 0, 0, 16, h, prop )

  Physics:insertObject ( leftw,  cx - 16,          cy - 96 * 4 - 1200 )
  Physics:insertObject ( rightw, cx + GAME_WIDTH,  cy - 96 * 4 - 1200 )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _BIT:prenotifyBossBattleOver ( )
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
end

function _BIT:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _BIT:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:isFacingRight() then
    mx = mx + 6
  else
    mx = mx - 4
  end
  my = my + 1
  return mx, my
end

function _BIT:handleDeathKneeling ( )
  self.sprite:change ( 1, "death-kneel" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _BIT:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self:updateBossInvulnerability ( )
  self:updateLocations           ( )

  if self.activated and self:isInState ( nil ) then
    if self:updateBossTimer ( ) then
      self:pickAction ( )
    end
  end

  if not (self.isChainedByHookshot) then
    self:tick    ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:handleLethalTiles ( true )

  --self:drawSensors(true)

  self:updateContactDamageStatus  ( )
  self:updateShake                ( )
  self:handleAfterImages          ( )
  self.sprite:update              ( dt )
end

function _BIT:tick ()
  if math.abs(self.velocity.vertical.current) > 0 then
    self.velocity.vertical.current = self.velocity.vertical.current - 0.25 * math.sign(self.velocity.vertical.current)
  end
  self:applyPhysics()
end

function _BIT:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_BIT.static.ACTIONS = {
  "DESPERATION_ACTIVATION", -- 1
  "HORIZONTAL_SLASH",       -- 2
  "VERTICAL_SLASH",         -- 3
  "UPPERCUT_PROJECTILE",    -- 4
  "DASH",                   -- 5, 
  "SNEAK_JAB",              -- 6, -- unused
  "DASH_OUT",               -- 7
  "DOWNWARD_PROJECTILE",    -- 8
}

function _BIT:pickAction ( recursion, px, py, mx, my  )
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 1
      return
    end
  end

  if not self.actionList then
    self.actionList  = { 2, 2, 3, 3, 4, 4, 7, 7, 7, 8, 8 }
    self.loopActions = {}
    for i = 1, #self.actionList do
      self.loopActions[i] = self.actionList[i]
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
  if action <= 0 then
    chance = RNG:range ( 1, #self.loopActions )
    action = table.remove ( self.loopActions, chance )
    if #self.loopActions <= 0 then
      for i = 1, #self.actionList do
        self.loopActions[i] = self.actionList[i]
      end
    end
  end

  if action <= 0 then return end
  if self.lastAction == action and action > 1 and not recursion then
    self:pickAction ( true, px, py, mx, my )
    return
  end
  if self.desperationActivated then
    if action ~= 1 and action ~= 7 then
      if not self.actionsSinceDesperation then
        self.actionsSinceDesperation = 0
      end
      self.actionsSinceDesperation = self.actionsSinceDesperation + 1
      if self.actionsSinceDesperation > 6 then
        self.forceDesperation = RNG:n() < (0.175 + (self.actionsSinceDesperation-6)*0.15)
      end
    end
  end

  if action <= 0 then return end

  self.lastAction = action
  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §end action ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:endAction ( finishedNormally )
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.nextActionTime = self.desperationActivated and 18 or 25
    if self.forceDesperation then
      self.nextActionTime = self.nextActionTime + 10
    end
    -- hard mode boss timers tick faster, so this is some sort of soft-padding
    if GAMEDATA.isHardMode() then
      self.nextActionTime = self.nextActionTime + 3
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §locations ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

-- §getLocations
function _BIT:getLocations ( )
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _BIT:updateLocations()
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

function _BIT:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 or not self.activated then
    return
  end

  local x,y   = self:getPos()
  Environment.landingParticle ( x, y, self.dimensions, -7, 20, 17 )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _BIT:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §horizontal slash ---------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HORI = _BIT:addState ( "HORIZONTAL_SLASH" )

function _HORI:enteredState ( px, py, mx, my )

  if (mx > Camera:getX() + GAME_WIDTH - 112) then
    if px > mx then
      self.stateVars.abortThis = true
    else
      self.sprite:flip ( -1 )
    end
  elseif (mx < Camera:getX() + 112) then
    --self.sprite:flip ( 1 )
    if px < mx then
      self.stateVars.abortThis = true
    else
      self.sprite:flip ( 1 )
    end
  else
    self.sprite:flip ( px >= mx and 1 or -1 )
  end

  if self.stateVars.abortThis then return end

  self.stateVars.initialPlayerSide    = px < mx and -1 or 1

  self.velocity.horizontal.direction  = 0
  self.velocity.horizontal.current    = 0
  self.velocity.vertical.update       = true

  self.sprite:change ( 1, "horizontal-slash",          2, true )
  self.sprite:change ( 2, "horizontal-slash-boosters", 2, true )

  self.timer              = 0
  self.stateVars.inc      = 0
  self.stateVars.finishT  = 0
  self.stateVars.precaution = 3
end

function _HORI:exitedState ( )
  if self.stateVars.abortThis then return end
  self:endAction ( false )
  self.sprite:change ( 2, nil )
  GameObject:spawn ( 
    "shift_screen_slash",
    16, 
    16,
    hori,
    true
  )
  :setOffset ( 32, -32 )
  :addTime   ( 32 )
  :noSfx     (  )
  :setSprite ( self.sprite )

  self.velocity.horizontal.direction  = 0
  self.velocity.horizontal.current    = 0
  self.velocity.vertical.update       = true
  self:setAfterImagesEnabled           ( false )

  if GAMEDATA.isHardMode() then
    self.nextActionTime = 1
  else
    self.nextActionTime = 1
  end
end

function _HORI:disableFollowup ()
  self.stateVars.noFollowup = true
end

function _HORI:tick ( )
  if self.stateVars.abortThis then
    self:gotoState ( "DASH_OUT" )
    return
  end

  self.timer = self.timer + 1

  if self.stateVars.startInc then
    self.stateVars.inc = self.stateVars.inc + 1
    if self.stateVars.inc == 4 then
      self.stateVars.startInc = false
    end
  end

  if not self.stateVars.slashStarted then
    local tTime = (self.desperationActivated and 26 or 35)
    if GAMEDATA.isHardMode() then
      if self._HORI_SLASH_REPEAT_COUNT and self._HORI_SLASH_REPEAT_COUNT >= 1 then
        tTime = tTime - 6
      else
        tTime = tTime - 3
      end
    end
    if self.timer == tTime then
      if self.desperationActivated then
        self.sprite:setFrame ( 1, 8, true )
        self.sprite:setFrame ( 2, 8, true )
      end
      self.stateVars.startInc             = true
      self.stateVars.inc                  = 1
      self.velocity.horizontal.current    = 1
      self.velocity.horizontal.direction  = self.sprite:getScaleX()
      self:setAfterImagesEnabled( true )
    end
  elseif not self.stateVars.slashed then
    if self.timer == 7 then
      self.stateVars.slashed = true
      self.timer             = 0
    end
  end

  if not self.stateVars.ding and self.sprite:getFrame() == 3 then
    self.stateVars.ding = true
    Audio:playSound ( SFX.gameplay_bit_blade_ready )
  end

  if not self.stateVars.ding2 and self.sprite:getFrame() == 8 then
    self.stateVars.ding2 = true
    Audio:playSound ( SFX.gameplay_bit_dash_3 )
  end

  if self.velocity.horizontal.current > 3 then
      
    for i = 1, 3 do
      local mx, my = self:getMiddlePoint()
      my           = my - 6
      mx           = mx + (self.sprite:getScaleX() > 0 and -8 or 8)
      Particles:add ( "shift-circuit-uppercut-trail-particle", mx+(i-1)*3*-self.velocity.horizontal.direction, my+(math.random(2,10)*math.rsign()), -self.velocity.horizontal.direction, 1, 0.5*-self.velocity.horizontal.direction, 0, self.layers.sprite()-1, false, nil, true )
    end
  end

  if self.velocity.horizontal.current > 4 and self.stateVars.inc > 0 then
    local x, y = self:getMiddlePoint    ( )
    local sx   = self.sprite:getScaleX  ( )
    y = y - 12

    for i = -3, self.velocity.horizontal.current-1 do
      Particles:add ( "shift-circuit-slash-particle-bottom", x + sx * i + sx * 5, y, 1, 1, 0, 0, self.layers.sprite()-2, false, nil, true )
      Particles:add ( "shift-circuit-slash-particle-top",    x + sx * i + sx * 5, y, 1, 1, 0, 0, self.layers.sprite()+2, false, nil, true )
    end
  end

  self.velocity.horizontal.current = math.max ( math.min ( self.velocity.horizontal.current + self.stateVars.inc, 20 ), 0 )

  if not Camera:isObjectInView ( self, 0 ) then
    self.stateVars.inc = -5
  end

  if not self.stateVars.slashStarted and self.stateVars.inc < 0 and self.velocity.horizontal.current <= 0 then
    self.stateVars.slashStarted = true
    self.timer                  = 0
  end

  local px, _, mx = self:getLocations()
  local finished  = false
  if self.velocity.horizontal.direction > 0 then
    if (mx >= Camera:getX() + GAME_WIDTH - 110) or (mx >= px+32) then
      self.stateVars.finishT    = self.stateVars.finishT + 1
      self.stateVars.finishing  = true
      self.stateVars.inPlace    = true
      self.velocity.horizontal.current = math.floor(self.velocity.horizontal.current / 2)
    end
  elseif self.velocity.horizontal.direction < 0 then
    if (mx <= Camera:getX() + 118) or (mx <= px-32) then
      self.stateVars.finishT    = self.stateVars.finishT + 1
      self.stateVars.finishing  = true
      self.stateVars.inPlace    = true
      self.velocity.horizontal.current = math.floor(self.velocity.horizontal.current / 2)
    end
  end

  if self.stateVars.finishT > 1 then
    self.sprite:change ( 1, nil )
    self.sprite:change ( 2, nil )
    finished = true
  elseif self.stateVars.finishing then
    self.stateVars.precaution = self.stateVars.precaution - 1
    if self.stateVars.precaution <= 0 then
      self.sprite:change ( 1, nil )
      self.sprite:change ( 2, nil )
      finished = true
    end
  end

  if finished then
    local x, y = self:getMiddlePoint    ( )
    local sx   = self.sprite:getScaleX  ( )
    y = y - 12

    local max = 55
    if sx < 0 then
      max = 70
    end
    for i = -5, max do
      local px = x + sx * i + sx * 5
      if px >= Camera:getX()+GAME_WIDTH-50 then
        break
      elseif px <= Camera:getX()+36 then
        break
      end
      Particles:add ( "shift-circuit-slash-particle-bottom", px, y, 1, 1, 0, 0, self.layers.sprite()-2, false, nil, true )
      Particles:add ( "shift-circuit-slash-particle-top",    px, y, 1, 1, 0, 0, self.layers.sprite()+2, false, nil, true )
    end

    self:setAfterImagesEnabled            ( false )
    --self:removeCollidersFromPhysicalWorld ( )
    local followup = false
    if self.stateVars.initialPlayerSide and (self.desperationActivated or GAMEDATA.isHardMode()) and not self.stateVars.noFollowup then
      local px, _, mx = self:getLocations()
      local side      = px < mx and -1 or 1
      if side ~= self.stateVars.initialPlayerSide then
        followup = true
      end
    end

    self:gotoState    ( "DASH", true, true, self.stateVars.inPlace )
    if followup then
      self:quickSlash ( )
    end
  else
    if not self.stateVars.finishing then
      self:applyPhysics()
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §vertical slash -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _VERT = _BIT:addState ( "VERTICAL_SLASH" )

function _VERT:enteredState ( px, py, mx, my, extra, followup, followupCount )

  Audio:playSound ( SFX.gameplay_player_hazard_hit, 0.8 )
  --self.sprite:flip ( px >= mx and 1 or -1 )
  self.timer              = 0
  self.stateVars.inc      = 0
  self.stateVars.second   = followup

  self.stateVars.useCount = followupCount or 1

  self.stateVars.prepTime = 12

  self:disableContactDamage ( 37 )

  self.sprite:change ( 1, "vertical-slash-start", 7, true )
end

function _VERT:exitedState ( )
  self:endAction ( false )
  self.sprite:change ( 2, nil )
  self.sprite:change ( 3, nil )
  local mx, my = self:getMiddlePoint ( )
  GameObject:spawn ( 
    "shift_downcut_projectile", 
    mx-132,
    my-140, 
    1 
  )
  GameObject:spawn ( 
    "shift_downcut_projectile", 
    mx+72,
    my-140, 
    1 
  )

  self.velocity.horizontal.current  = 0
  self.state.isHittable             = true
  self.isIgnoringTiles              = false
  self.velocity.vertical.update     = true
  self:permanentlyDisableContactDamage ( nil )
  if not GAMEDATA.isHardMode() then
    self.nextActionTime = 1
  else
    self.nextActionTime = 1
  end
end

function _VERT:tick ( )
  self.timer = self.timer + 1

  if self.sprite:getFrame() == 8 and not self.stateVars.disabled then
    self:permanentlyDisableContactDamage ( true )
    self.stateVars.disabled = true
    self.state.isGrounded   = false
  end

  if not self.sprite:getAnimation() and not self.stateVars.jumped then

    if not self.stateVars.second then
      if self.stateVars.prepTime > 0 then
        self.state.isHittable   = false
        self.stateVars.prepTime = self.stateVars.prepTime - 1
        self.timer              = self.timer - 1
        return
      end
    end

    if not self.state.isHittable then
      self.state.isHittable = true
    end

    self.stateVars.readyDign  = true
    local px, py, mx, my      = self:getLocations()
    local cx                  = Camera:getX()

    local x = 0
    if px < cx + 44 then
      x = cx + 44
    elseif px > cx + GAME_WIDTH - 72 then
      x = cx + GAME_WIDTH - 72
    else
      x = px - 15
    end

    local ty = my - 96
    if ty > (py-48) then
      ty = py - 55
    end

    self.sprite:flip ( x >= mx and 1 or -1 )

    self:setActualPos ( x, ty )
    self.velocity.vertical.update = false
    self.stateVars.jumped         = true
    self.state.isGrounded         = false

    self.sprite:change ( 1, "vertical-slash" )
    self.geyserPositionX = self:getX()
    self.geyserPositionY = self:getY()
    self:permanentlyDisableContactDamage ( nil )
  end

  if self.stateVars.readyDign and not self.stateVars.ding and self.sprite:getFrame() == 3 then
    self.stateVars.ding = true
    Audio:playSound ( SFX.gameplay_bit_blade_ready )
  end

  if self.stateVars.readyDign and not self.stateVars.ding2 and self.sprite:getFrame() == 9 then
    self.stateVars.ding2 = true
    Audio:playSound ( SFX.gameplay_bit_dash_2 )
  end

  if self.velocity.vertical.current > 0 then
    local x, y = self:getMiddlePoint    ( )
    local sx   = self.sprite:getScaleX  ( )
    y = y - 12

    if sx > 0 then
      x = x - 5
    else
      x = x - 8
    end

    sx = 1
    y  = y - 4
    for i = -5, self.velocity.vertical.current do
      Particles:add ( "shift-circuit-slash-particle-bottom", x, y+ sx * i + sx * 5, 1, 1, 0, 0, self.layers.sprite()-2, false, nil, true )
      Particles:add ( "shift-circuit-slash-particle-top",    x, y+ sx * i + sx * 5, 1, 1, 0, 0, self.layers.sprite()-1, false, nil, true )
    end
  end

  local t_time = 30
  if GAMEDATA.isHardMode() and self.stateVars.useCount > 1 then
    t_time = 26
  end
  if self.timer == t_time then
    self.stateVars.updateVert = true
    if GAMEDATA.isHardMode() then
      self.sprite:change ( 1, "vertical-slash", 8, true )
    end
  end

  if self.stateVars.updateVert then
    self.velocity.vertical.current = self.velocity.vertical.current + 1
  end

  self:applyPhysics()
  if _VERT.hasQuitState(self) then return end

  if self.stateVars.jumped and self.state.isGrounded and not self.stateVars.attacked then
    self.sprite:change ( 1, "vertical-slash-land" )
    self.sprite:change ( 3, "vertical-slash-land-geyser" )
    Audio:playSound ( SFX.gameplay_enemy_bounces_on_enemy_2 )
    self.stateVars.attacked = true
    if self.sensors.VERTICAL_SLASH_SENSOR:check() then
      local px, py, mx, my = self:getLocations()
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", px > mx and 1 or -1 )
    end
  end

  if GAMEDATA.isHardMode() then
    if self.stateVars.updateVert  then
      local uses = self.desperationActivated and 3 or 2
      if self.stateVars.useCount < uses then
        if self.stateVars.jumped and self.state.isGrounded then
          if self.sprite:getFrame() == 5 then
            self:gotoState ( "VERTICAL_SLASH", nil, nil, nil, nil, nil, true, self.stateVars.useCount + RNG:range ( 1, 2 ) )
          end
        end
        return
      end
    end
  else
    if self.desperationActivated and not self.stateVars.second then
      if self.stateVars.jumped and self.state.isGrounded then
        if self.sprite:getFrame() == 5 then
          self:gotoState ( "VERTICAL_SLASH", nil, nil, nil, nil, nil, true )
        end
      end
      return
    end
  end

  if self.stateVars.jumped and self.state.isGrounded then
    --self.sprite:change ( 1, "battle-idle" )
    self:endAction(true)
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §uppercut projectile ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _UPPERCUT = _BIT:addState ( "UPPERCUT_PROJECTILE" )

function _UPPERCUT:enteredState ( px, py, mx, my )
  self.sprite:flip    ( px >= mx and 1 or -1 )
  self.sprite:change  ( 1, "vertical-slash-start", 1, true )

  self.stateVars.finished = false
  self.timer              = 1
  self.stateVars.spawns   = 0

  self.stateVars.baseX,
  self.stateVars.baseY          = self:getMiddlePoint() 
  self.velocity.vertical.update = true

  if self.sprite:getScaleX() > 0 then
    self.stateVars.baseX = mx+2--Camera:getX() + 32
  else
    self.stateVars.baseX = mx-14--Camera:getX() + GAME_WIDTH - 32
  end

  self.stateVars.removed = false
  self.initialTimer      = GAMEDATA.isHardMode() and 15 or 20
end

function _UPPERCUT:exitedState ( )
  self:endAction ( false )
  self.nextActionTime = self.desperationActivated and 18 or 23
  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime + 6
  end
end

function _UPPERCUT:tick ( )

  if self.initialTimer > 0 then
    self.initialTimer = self.initialTimer - 1
  else
    self.timer = self.timer + 1
  end

  if not self.stateVars.pointSfx and self.sprite:getAnimation() == "vertical-slash-start" and self.sprite:getFrame() == 3 then
    self.stateVars.pointSfx = true
    Audio:playSound ( SFX.gameplay_boss_cable_pointing, 1.3 )
  end

  local spawn       = false
  local targetCount = (self.desperationActivated and 3 or 2)

  if GAMEDATA.isHardMode() then
    targetCount = 3--targetCount + 1
  end
  if self.stateVars.spawns < targetCount then
    if self.timer % 28 == 0 then
      local tSpawns = 3
      --if GAMEDATA.isHardMode() then
      --  tSpawns = 4
      --end
      if self.stateVars.spawns < tSpawns then
        self.stateVars.spawns = self.stateVars.spawns + 1
        spawn                 = true
      end

      if self.stateVars.spawns == 1 then
        self.velocity.vertical.current = -5.5
      elseif self.stateVars.spawns == 2 then
        self.velocity.vertical.current = -1.75
      else
        self.velocity.vertical.current = -3.5
      end
    end
  else
    if self.state.isGrounded and not self.stateVars.landed then
      Audio:playSound ( SFX.gameplay_boss_cable_landing, 1.9 )
      self.stateVars.landed = true
      self.sprite:change ( 1, "land" )
    end
  end

  if spawn then
    Audio:playSound ( SFX.gameplay_bit_uppercut )
    self.sprite:change  ( 1, "uppercut-slash", 6, true )
    local mx, my = self.stateVars.baseX, self.stateVars.baseY
    if self.stateVars.spawns % 2 == 0 then
      my = my - 48
    end

    local obj = GameObject:spawn ( "shift_uppercut_projectile", mx,my-43, self.sprite:getScaleX() )
    GameObject:spawn ( 
      "shift_screen_slash",
      76, 
      16,
      hori,
      true
    )
    :setOffset ( -16, -32 )
    :addTime   ( 8 )
    :noSfx     (  )
    :setSprite ( self.sprite )
    GameObject:spawn ( 
      "shift_screen_slash",
      -56, 
      16,
      hori,
      true
    )
    :setOffset ( -16, -32 )
    :addTime   ( 8 )
    :noSfx     (  )
    :setSprite ( self.sprite )
    if GAMEDATA.isHardMode() then
      obj:addSpeed ( 1.0 )
    end

    if self.sprite:getScaleX() > 0 then mx = mx + 18 end
    Particles:add    ( "circuit_pickup_flash_large", mx-24, my-32, 1, 1, 0, 0, Layer:get ( "PARTICLES" )() )
  end

  self:applyPhysics ( )

  if self.stateVars.landed and self.timer >= 90 then
    self:endAction ( true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §sneak jab ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SNEAK_JAB = _BIT:addState ( "SNEAK_JAB" )

function _SNEAK_JAB:enteredState ( px, py, mx, my )

end

function _SNEAK_JAB:exitedState ( )
  self:endAction ( false )
end

function _SNEAK_JAB:tick ( )
  self:endAction ( true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _BIT:addState ( "DESPERATION_ACTIVATION" )

function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )
  self.sprite:change ( 1, "angry" )

  self._HORI_SLASH_REPEAT_COUNT = 0

  self.timer = 0
  if self.desperationActivated then
    self.stateVars.angerTime = 0
    self.stateVars.angry = false
    self.sprite:change ( 1, "desperation-activation", 1, true )
  else
    self.stateVars.angerTime  = 50
    self.stateVars.angry      = true
    self.sprite:change ( 1, "angry", 1, true )
  end

  self.stateVars.firstIsVert = false--RNG:rsign() > 0

  self.desperationTable = GAMEDATA.isHardMode() and self.class.DESPERATION_ATTACK_TIMES_HARD or self.class.DESPERATION_ATTACK_TIMES 
end

function _DESPERATION_ACTIVATION:exitedState ()
  if self.stateVars.startedSuperFlash then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end
  self.velocity.vertical.update = true
  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true
  self:endAction(false, true)

  self:setAfterImagesEnabled           ( false )
  self:permanentlyDisableContactDamage ( false )


  self.state.isBossInvulnerable = false
end

_BIT.static.DESPERATION_ATTACK_TIMES = {
  45,
  55,
  50,
  45,
  40,
  35,
  33,
  31,
  29,
}

_BIT.static.DESPERATION_ATTACK_TIMES_HARD = {
  45,
  45,
  40,
  35,
  30,
  29,
  28,
  27,
  26,
}

function _DESPERATION_ACTIVATION:tick ()
  if not self.stateVars.removed then
    self:applyPhysics()
  end

  if self.stateVars.angerTime > 0 then
    self.stateVars.angerTime = self.stateVars.angerTime - 1
    return
  end

  self.stateVars.angerTime = self.stateVars.angerTime - 1
  if (self.stateVars.angry and self.stateVars.angerTime == -17) 
    or (not self.stateVars.angry and self.stateVars.angerTime == -28)  then
    Audio:playSound ( SFX.gameplay_player_hazard_hit, 1.0 )
  end

  if not self.stateVars.finishedFlash then
    self.timer = self.timer + 1
    if self.timer == 1 and not self.stateVars.activated then
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
      --self.sprite:change ( 1, "desperation-activation" )
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_bit", 5 )
      self.fakeOverkilledTimer = 1000
    end

    if not self.stateVars.finishedFlash and self.stateVars.activated and self.timer >= 20 then
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_END" )
        self.stateVars.startedSuperFlash = false
        self.state.isBossInvulnerable    = true
      end
      self.stateVars.finishedFlash      = true
      self.desperationActivated         = true
      self.stateVars.finishedAttacking  = false
      self.timer                        = 25
      self.stateVars.desperationPoint   = 1
      self.stateVars.last               = 0
    end
  elseif not self.stateVars.finishedAttacking then
    self.timer = self.timer + 1

    if not self.stateVars.spawnedThings and self.timer >= (self.stateVars.last + self.desperationTable [ self.stateVars.desperationPoint ]) then
      self.stateVars.last             = self.stateVars.last + self.desperationTable [ self.stateVars.desperationPoint ]
      self.stateVars.desperationPoint = self.stateVars.desperationPoint + 1
      local hori = false
      if self.stateVars.firstIsVert then
        hori = self.stateVars.desperationPoint % 2 == 0
      else
        hori = self.stateVars.desperationPoint % 2 ~= 0
      end

      if self.stateVars.desperationPoint > #self.desperationTable then
        GameObject:spawn ( 
          "shift_screen_slash",
          16, 
          16,
          hori,
          true
        )
        :setOffset ( -16, -32 )
        :addTime   ( 8 )
        :noSfx     (  )
        :setSprite ( self.sprite )
        GameObject:spawn ( 
          "shift_screen_slash",
          16, 
          16,
          hori,
          true
        )
        :setOffset ( 16, -32 )
        :addTime   ( 16 )
        :noSfx     (  )
        :setSprite ( self.sprite )
        GameObject:spawn ( 
          "shift_screen_slash",
          16, 
          16,
          hori,
          true
        )
        :setOffset ( -32, -32 )
        :addTime   ( 24 )
        :noSfx     (  )
        :setSprite ( self.sprite )
        GameObject:spawn ( 
          "shift_screen_slash",
          16, 
          16,
          hori,
          true
        )
        :setOffset ( 32, -32 )
        :addTime   ( 32 )
        :noSfx     (  )
        :setSprite ( self.sprite )
      end
      GameObject:spawn ( 
        "shift_screen_slash",
        16, 
        16,
        hori,
        true
      )
      :addTime ( -2 )
      :setSprite ( self.sprite )

      if self.stateVars.desperationPoint > #self.desperationTable then
        self.stateVars.spawnedThings = true
        self.timer = 0
      end
    end

    if not self.stateVars.removed then
      self.stateVars.removed = true
      self:removeCollidersFromPhysicalWorld ( )
    end

    if self.stateVars.spawnedThings and self.timer >= 80 then
      self.stateVars.finishedAttacking = true
      self.timer                       = 21
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:gotoState      ( "DASH", true )
      self:setQuickAction ( )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pit recover --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _RECOVER = _BIT:addState ( "PIT_RECOVER" )

function _RECOVER:enteredState ( )

  Audio:playSound ( SFX.gameplay_player_hazard_hit, 0.8 )

  self.state.isRecovering            = true
  self.velocity.vertical.update      = false
  self.velocity.vertical.current     = 0
  self.velocity.horizontal.current   = 0
  self.velocity.horizontal.direction = 0
  self:removeCollidersFromPhysicalWorld ( )
  self.sprite:change ( 1, "warp-damaged", 2 )
  self.timer = 0
  self:setAfterImagesEnabled( false )
end

function _RECOVER:exitedState ( )
  self.velocity.vertical.update = true
end

function _RECOVER:tick ( )
  self.timer = self.timer + 1
  if self.timer >= 30 then
    self:gotoState ( "DASH", true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §dash out §dout -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DOUT = _BIT:addState ( "DASH_OUT" )

function _DOUT:enteredState ( )
  Audio:playSound                       ( SFX.gameplay_player_hazard_hit, 0.8 )
  self.sprite:change                    ( 1, "dash-out" )
  self:removeCollidersFromPhysicalWorld ( )
  self.timer = 0
end

function _DOUT:exitedState ( )

end

function _DOUT:tick ( )
  self.timer = self.timer + 1
  if self.timer >= 30 then
    self:gotoState ( "DASH", true )
    self:setQuickAction ( )
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Dash appear §dappear -----------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DAPPEAR = _BIT:addState ( "DASH" )

_BIT.static.DASH_LOCATIONS = {
  [1] = {
    x = 56 + 8,
    y = 160,
    dir = 1,
  },
  [2] = {
    x = 56 + 52,
    y = 160,
    dir = 0,
  },
  [3] = {
    x = 56 + 52 * 2,
    y = 160,
    dir = 0,
  },
  [4] = {
    x = 56 + 52 * 3,
    y = 160,
    dir = 0,
  },
  [5] = {
    x = 56 + 52 * 4,
    y = 160,
    dir = 0,
  },
  --272  160 <- spawn
  [6] = {
    x = 316 - 8,
    y = 160,
    dir = -1,
  },
}

function _DAPPEAR:enteredState ( appear, forceOppositeEnd, inPlace )
  local location = 0
  if self.health <= 0 or forceOppositeEnd then
    self.stateVars.kneelAfterwards = self.health <= 0
    local cx = Camera:getX() + GAME_WIDTH/2
    location = (cx < self:getX()) and 4 or 1
  else
    location = nil
  end

  self.stateVars.inPlace        = inPlace
  self.stateVars.appearLocation = location
  self.stateVars.disappeared    = appear
  self.stateVars.finished       = false
  self.stateVars.inserted       = false
  self.stateVars.appearCount    = 0
  self.timer                    = 0
end

function _DAPPEAR:exitedState ( )
  self.velocity.vertical.update = true
  self.state.isRecovering       = false
end

function _DAPPEAR:setQuickAction ( )
  self.stateVars.quickAction = true
end

function _DAPPEAR:quickSlash ( )
  if GAMEDATA.isHardMode() then
    if not self._HORI_SLASH_REPEAT_COUNT then
      self._HORI_SLASH_REPEAT_COUNT = 0
    end
    if self.desperationActivated then
      self._HORI_SLASH_REPEAT_COUNT = self._HORI_SLASH_REPEAT_COUNT + (RNG:range ( 1, 2 ) - 1)
    else
      self._HORI_SLASH_REPEAT_COUNT = 2
    end
  end
  self.stateVars.quickSlash = true
end

function _DAPPEAR:tick ( )
  self.timer = self.timer + 1

  if not self.stateVars.disappeared then

  elseif not self.stateVars.appeared then
    if not self.stateVars.appearLocation then
      self:verifySafety()
    end
    if self.stateVars.inPlace then
      -- ...
      local x,y     = self:getPos()
      local tx, ty  = x + 32 * self.sprite:getScaleX(), y

      if self:getX() > Camera:getX()+GAME_WIDTH-95 then
        tx, ty = Camera:getX()+GAME_WIDTH-95, y 
      elseif self:getX() < Camera:getX()+64 then
        tx, ty = Camera:getX()+65, y 
      end
      self:applyPhysics ( true, tx, ty )
    else
      local cx, cy = Camera:getPos()
      cx,cy        = cx + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].x,
                     cy + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].y
      local dir = self.class.DASH_LOCATIONS[self.stateVars.appearLocation].dir 
      if dir  == 0 then
        local px, _, mx = self:getLocations()
        if px < mx then
          dir = -1
        else
          dir = 1
        end
      end

      self:setActualPos ( cx + dir * (self.stateVars.quickAction and 1 or 23), cy )
    end
    self.stateVars.appeared = true
    if self.stateVars.kneelAfterwards then
      self.stunTimer = nil
      self.sprite:change ( 1, "death-kneel-from-dash", 1, true )
      self.knelt = true
    else
      self.sprite:change ( 1, "dash-in", 1, true )
    end
    if self.stateVars.inPlace then
      -- ...
      self.stateVars.appearDir = self.sprite:getScaleX()
      self.sprite:mirrorX()
    else
      self.stateVars.appearDir = self.class.DASH_LOCATIONS[self.stateVars.appearLocation].dir 
      if self.stateVars.appearDir == 0 then
        local px, _, mx = self:getLocations()
        if px < mx then
          self.stateVars.appearDir = -1
        else
          self.stateVars.appearDir = 1
        end
      end
      self.sprite:flip ( self.stateVars.appearDir )
    end
    self:setAfterImagesEnabled( true )
    self.timer = 0
  elseif not self.stateVars.appearing then
    if not self.stateVars.sfxPlayed then
      self.stateVars.sfxPlayed = true
      Audio:playSound ( SFX.gameplay_player_hazard_hit, 0.8 )
    end
    if self.timer < (self.stateVars.quickAction and 1 or 9) then
      self:translate ( self.stateVars.appearDir*2, 0 )
    elseif self.timer < (self.stateVars.quickAction and 4 or 12) then
      self:translate ( self.stateVars.appearDir, 0 )
    elseif self.timer >= (self.stateVars.quickAction and 4 or 12) then
      if not self.stateVars.inserted  then
        self.stateVars.inserted = true
        if not self.stateVars.inPlace then
          self:insertCollider ( "collision" )
          self:insertCollider ( "grabbox"   )
          self:insertCollider ( "grabbed"   )
        end
      end
      self.stateVars.appearing = true
      self.stateVars.finished  = true
      self:setAfterImagesEnabled( false )
    end
    if self.stateVars.inPlace  then
      self:applyPhysics()
    end
  elseif self.stateVars.finished then
    if self.timer >= (self.stateVars.quickAction and 2 or 20) then
      if self.stateVars.kneelAfterwards then
        if self.state.isBossRushSpawn then
            if not self._notifiedBossRushHandler then
              self._notifiedBossRushHandler   = true
              GAMESTATE.bossRushMode.defeated = true
              GlobalObserver:none ( "CUTSCENE_START", "special/cutscene_bossRushHandler" )
            end
        elseif not self.state.isSpawnBoss then
          self:notifyBossBattleOver ( )
        end
      else
        if self.stateVars.quickSlash then
          local px, py, mx, my = self:getLocations ( )
          self:gotoState       ( "HORIZONTAL_SLASH", px, py, mx, my )
          if not GAMEDATA.isHardMode() or (self._HORI_SLASH_REPEAT_COUNT and self._HORI_SLASH_REPEAT_COUNT >= 2) then
            self:disableFollowup ( )
          end
        else
          self._HORI_SLASH_REPEAT_COUNT = 0
          self:endAction(true)
        end
      end
    end
  end
end

-- §verify
function _DAPPEAR:verifySafety ()
  local len = #self.class.DASH_LOCATIONS
  self.stateVars.appearLocation = RNG:range(1,len)
  local px     = self:getLocations()
  local mx, my = self:getMiddlePoint()
  local cx, cy = Camera:getPos()
  cx,cy        = cx + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].x,
                 cy + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].y

  if math.abs(mx-cx) > 48 then
    self:setActualPos ( cx, cy )

    if not self.sensors.DASH_IN_SENSOR:check() then
      return
    end
  end

  self.stateVars.appearLocation = self.stateVars.appearLocation + RNG:range(1, 2)
  if self.stateVars.appearLocation > len then
    self.stateVars.appearLocation = self.stateVars.appearLocation - len
  end

  cx, cy = Camera:getPos()
  cx,cy        = cx + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].x,
                 cy + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].y
  
  if math.abs(mx-cx) > 48 then
    self:setActualPos ( cx, cy )

    if not self.sensors.DASH_IN_SENSOR:check() then
      return
    end
  end

  self.stateVars.appearLocation = self.stateVars.appearLocation + RNG:range(1, 2)
  if self.stateVars.appearLocation > len then
    self.stateVars.appearLocation = self.stateVars.appearLocation - len
  end

  cx, cy = Camera:getPos()
  cx,cy        = cx + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].x,
                 cy + self.class.DASH_LOCATIONS[self.stateVars.appearLocation].y

  self:setActualPos ( cx, cy )

  if self.sensors.DASH_IN_SENSOR:check() then
    if px < (Camera:getX() + GAME_WIDTH/2) then
      self.stateVars.appearLocation = 6
    else
      self.stateVars.appearLocation = 1
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DOWNWARD PROJECTILE ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DOWNP = _BIT:addState ( "DOWNWARD_PROJECTILE" )

function _DOWNP:enteredState ( px, py, mx, my )
  self.positionRoundingDisabled = true
  self.stateVars.forceSecondShot = self.desperationActivated or GAMEDATA.isHardMode()

  self:disableContactDamage ( 30 )
end

function _DOWNP:exitedState ( )
  self:endAction ( false )
  self.positionRoundingDisabled = false
end

function _DOWNP:tick ( )
  local px, py, mx, my = self:getLocations()
  if not self.stateVars.jumped then
    self.sprite:change ( 1, "hop-forward" )
    self.stateVars.jumped          = true
    self.velocity.vertical.current = -6

    Audio:playSound ( SFX.gameplay_boss_cable_jump )


    local dif    = math.abs(mx - px)
    local dir = mx > px and -1 or 1
    self.velocity.horizontal.direction  = dir
    dif = dif / 28

    self.velocity.horizontal.direction = dir
    self.velocity.horizontal.current   = dif

    self.sprite:flip ( dir )

  elseif not self.stateVars.shot then
    if self.velocity.vertical.current > 1.25 then
      if self.stateVars.forceSecondShot then
        if self.stateVars.secondShot then
          self.stateVars.shot       = true
          self.stateVars.secondShot = false
        else
          self.stateVars.secondShot = true
        end
      else
        self.stateVars.shot = true
      end
      self.velocity.vertical.current = -3

      local dif    = math.abs(mx - px)
      dif          = dif / 35
      self.velocity.horizontal.current   = self.stateVars.secondShot and dif or 1
      self.velocity.horizontal.direction = self.stateVars.forceSecondShot and (px < mx and -1 or 1) or self.velocity.horizontal.direction
      if GAMEDATA.isHardMode() then
        self.velocity.horizontal.current = self.velocity.horizontal.current + 0.50
      end

      Audio:playSound ( SFX.gameplay_bit_uppercut )
      self.sprite:change  ( 1, "uppercut-slash", 5, true )
      GameObject:spawn ( 
        "shift_downcut_projectile", 
        mx-32,
        my-8, 
        1 
      )
      GameObject:spawn     ( "shift_uppercut_projectile", mx+12,my+5,  1 )
      GameObject:spawn     ( "shift_uppercut_projectile", mx-12,   my+5, -1 )
      Particles:add    ( "circuit_pickup_flash_large", mx-24+(self.sprite:getScaleX() < 0 and 1 or 3), my-24, 1, 1, 0, 0, Layer:get ( "PARTICLES" )() )
    end
  elseif self.state.isGrounded then
    self.velocity.horizontal.current = 0
    Audio:playSound ( SFX.gameplay_boss_cable_landing, 1.9 )
    self.stateVars.landed = true
    self.sprite:change ( 1, "land" )

    self:endAction ( true )
  end

  --[[
  if self.velocity.horizontal.direction > 0 and (Camera:getX() + GAME_WIDTH - 64) < mx then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
  elseif self.velocity.horizontal.direction < 0 and (Camera:getX() + 64) > mx then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
  end

  if self.velocity.horizontal.direction > 0 and (Camera:getX() + GAME_WIDTH - 80) < mx then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
  elseif self.velocity.horizontal.direction < 0 and (Camera:getX() + 80) > mx then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
  end]]

  self:applyPhysics()

  if self.sensors.WARNING_SENSOR:check() then
    self:gotoState ( "PIT_RECOVER" )
    return
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _BIT:addState ( "TECH_RECOVER" )

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

  self._HORI_SLASH_REPEAT_COUNT   = 0
end

function _TECH:exitedState ( )
  self:endAction ( false )
  if self.forceDesperation then
    self.nextActionTime = 5
  end
end

function _TECH:tick ( )
  self:applyPhysics()

  if self.sensors.WARNING_SENSOR:check() then
    self:gotoState ( "PIT_RECOVER" )
    return
  end

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

function _BIT:manageTeching ( timeInFlinch )
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  if not self.sensors.WARNING_SENSOR:check() then
    return false
  end

  self:gotoState ( "PIT_RECOVER" )
  return true
end

function _BIT:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    return
  end
  if self.health - dmg <= (GAMEDATA.boss.getMaxHealth()/2) then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
    self.forceLaunched            = true
    self.forceDesperation         = true
    self.fakeOverkilledTimer      = 10000
    self.state.isBossInvulnerable = true

    self._HORI_SLASH_REPEAT_COUNT = 0

    self:spawnBossMidpointRewards ( )
    local mx, my = self:getMiddlePoint("collision")
    
    mx, my = mx+2, my-2
    Particles:add       ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.particles() )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

    return true, 1.0, -4
  end
end

function _BIT:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and -2 or -26), -31
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _BIT:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self.sprite:change ( 1, nil )
  self.stateVars.forceTimeout = -1
  self.stateVars.started      = false
  self.timer                  = 0

  self._runAnimation          = self._coolAnimation
  self.dashingForIntro        = false
  Audio:loadBgmAsync ( BGM.tension )
end

function _PREFIGHT:exitedState ( )
  self.dashingForIntro = false
end

function _PREFIGHT:tick ( )
  
end

function _PREFIGHT:_coolAnimation ()
  if not self.isInState ( self, "PREFIGHT_INTRO" ) then
    self:gotoState ( "PREFIGHT_INTRO" )
    return false
  end

  self.timer = self.timer + 1
  local hori = false

  if self.timer == 120 then
    local x,y = 292, -5
    GameObject:spawn ( 
      "shift_screen_slash",
      16, 
      16,
      hori,
      true,
      false,
      x+30,
      y,
      1,
      -1
    )
    :setOffset ( -16, -32 )
    :addTime   ( 12 )
    :setSprite ( self.sprite )
    GameObject:spawn ( 
      "shift_screen_slash",
      16, 
      16,
      hori,
      true,
      false,
      x,
      y-20,
      2,
      -1
    )
    :setOffset ( 16, -32 )
    :addTime   ( 20 )
    :noSfx     (  )
    :setSprite ( self.sprite )
    GameObject:spawn ( 
      "shift_screen_slash",
      16, 
      16,
      hori,
      true,
      false,
      x+20,
      y-30,
      3,
      -1
    )
    :setOffset ( -32, -32 )
    :addTime   ( 28 )
    :noSfx     (  )
    :setSprite ( self.sprite )
    GameObject:spawn ( 
      "shift_screen_slash",
      16, 
      16,
      hori,
      true,
      false,
      x-54,
      y,
      1,
      1
    )
    :setOffset ( 32, -32 )
    :addTime   ( 36 )
    :noSfx     (  )
    :setSprite ( self.sprite )
  end

  if self.timer == 430 then
    Audio:playSound       ( SFX.gameplay_highway_bit_intro, 0.275 )
    Audio:playTrack       ( BGM.tension )
    Audio:setMusicVolume  ( 1.0 )
    self._runAnimation = self.__runAnimation
    self.timer = 0

    Tileset:normalizeColors ( 30 )
  end

  return false
end

function _BIT:__runAnimation ( )
  if not self.isInState ( self, "PREFIGHT_INTRO" ) then
    self:gotoState ( "PREFIGHT_INTRO" )
    return false
  end

  self.timer = self.timer + 1

  if self.stateVars.forceTimeout > self.timer then
    return false
  end

  self:applyPhysics()

  if not self.stateVars.jumped and self.stateVars.started then
    local mx, my = self:getMiddlePoint()  
    local l = self.layers.sprite()
    my      = my - 12
    Particles:add ( "shift-circuit-slash-particle-bottom", mx, my+(math.random(1,4)*math.rsign()), 1, 1, self.velocity.horizontal.direction*0.5, 0, l-2, false, nil, true )
    Particles:add ( "shift-circuit-slash-particle-top",    mx, my+(math.random(1,4)*math.rsign()), 1, 1, self.velocity.horizontal.direction*0.5, 0, l-1, false, nil, true )
  end

  if not self.stateVars.mirrored and self.stateVars.jumped and self.sprite:getFrame(1) == 6 and self.sprite:getFrameTime(1) == 0 then
    self.stateVars.mirrored = true
    self.sprite:mirrorX()
  end

  if not self.stateVars.started then
    self.dashingForIntro = true 
    self.stateVars.started              = true
    self.isIgnoringTiles                = true
    self.velocity.vertical.update       = false
    self.velocity.horizontal.current    = 10
    self.velocity.horizontal.direction  = -1

    local x,y = self:getPos()
    self.stateVars.ogPosX = x
    self.stateVars.ogPosY = y

    self:setAfterImagesEnabled ( true )
    self.sprite:change ( 1, "prebattle-intro-1" )
    self.sprite:change ( 2, "prebattle-intro-1-booster" )

    self:setActualPos ( x + 128, y + 36 )
  elseif not self.stateVars.reversed then
    local cx = Camera:getX()
    if cx > self:getX() + 64 then
      self.sprite:mirrorX()
      self.stateVars.reversed             = true
      self.velocity.horizontal.current    = 5
      self.velocity.horizontal.direction  = 1
      self.stateVars.forceTimeout         = 30
      self.timer                          = 0
    end
  elseif not self.stateVars.jumped then
    local cx = Camera:getX() + GAME_WIDTH/2 -36
    if self:getX() > cx then
      self.dashingForIntro = false
      self.velocity.horizontal.current  = 2.5
      self.velocity.vertical.current    = -6.0
      self.velocity.vertical.update     = true
      self.stateVars.jumped             = true
      Audio:playSound ( SFX.gameplay_boss_cable_jump )
      self.sprite:change ( 1, "prefight-jump-to-platform", 1, true   )
      self.sprite:change ( 2, "prebattle-intro-2-booster" )
    end
  elseif not self.stateVars.collidable then
    if self.velocity.vertical.current >= 0 then
      self.stateVars.collidable = true
      self.isIgnoringTiles      = false
    end
  elseif self.state.isGrounded then
    if not self.stateVars.landAnim then
      Audio:playSound ( SFX.gameplay_boss_cable_landing, 1.9 )
      self.stateVars.landAnim = true
      --self.sprite:mirrorX()
      self.sprite:change ( 1, "land-intro" )
      local x,y   = self:getPos()
      x = x + 4
      y = y - 1
      Environment.landingParticle ( x, y, self.dimensions, -7, 20, 17 )
    end
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    if self.velocity.horizontal.current <= 0 then
      --self.stateVars.finished = true
      self:setAfterImagesEnabled ( false )
      self.timer                  = 0
      self.stateVars.forceTimeout = 15
    end
  end

  if self.stateVars.landAnim then
    if self.sprite:getFrame() == 5 then
      self.sprite:setFrame ( 1, 6, true )
      self.stateVars.finished = true
    end
  end

  if not self.stateVars.finished then return false end

  self:gotoState ( "CUTSCENE" )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §§S HOP -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _S_HOP = _BIT:addState ( "S_HOP" )

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

  self.stateVars.angryDelay       = 45
  self.timer                      = 55
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

  if self.sprite:getAnimation() == "angry" and self.sprite:getFrame() == 14 and self.sprite:getFrameTime() == 0 then
    self.sprite:setFrame ( 1, 9, true )
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

function _BIT:env_emitSmoke ( )
  if not self.sprite:getAnimation() then return end
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

  Particles:addFromCategory ( "warp_particle_bit", x, y,   1,  1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §data chip           ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:adjustDataChipSpawn ( mx, my )
  local cx = Camera:getX()

  if mx < cx + 64 then
    DataChip.adjustSpawnHorizontalVelocity ( 1.50,  1 )
  elseif mx > cx + 336 then
    DataChip.adjustSpawnHorizontalVelocity ( 1.50, -1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §stun                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:manageStunEnter ()
  self.sprite:change(2,nil)
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BIT:customEarlyEnemyDraw ( x, y )
  if self.health <= 0 or self.isDestructed then return end
  self.sprite:drawInstant ( 2, x, y )
end

function _BIT:customEnemyDraw ( x, y, scaleX )
  if self.dashingForIntro then
    y = y - math.round(MapData:getShenaniganOffsets ()) + 1
  end
  self.sprite:drawInstant ( 1, x, y )

  if self.gibs or self.isDestructed then return end
  if self.sprite:getAnimation(3) then
    self.sprite:drawInstant ( 3, x, y )
  end
end

return _BIT