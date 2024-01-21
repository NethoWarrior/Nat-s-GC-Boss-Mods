-- CRASH, THE BREAK CIRCUIT, QUARRY AREA BOSS
local _CRASH    = BaseObject:subclass ( "CRASH_BREAK_CIRCUIT" ):INCLUDE_COMMONS ( )
FSM:addState  ( _CRASH, "CUTSCENE"             )
FSM:addState  ( _CRASH, "BOSS_CIRCUIT_PICKUP"  )
Mixins:attach ( _CRASH, "spawnFallingBlocks"   )
Mixins:attach ( _CRASH, "gravityFreeze"        )
Mixins:attach ( _CRASH, "bossTimer"            )

-- probably the messiest boss in terms of code. Oh well!

_CRASH.static.IS_PERSISTENT   = true
_CRASH.static.SCRIPT          = "dialogue/boss/cutscene_crashConfrontation"
_CRASH.static.BOSS_CLEAR_FLAG = "boss-defeated-flag-crash"

_CRASH.static.EDITOR_DATA = {
  width   = 2,
  height  = 3,
  ox      = -47,
  oy      = -54,
  mx      = 69,
  order   = 9975,
  category = "bosses",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isUnique      = true,
    isTargetable  = true,
  }
}

_CRASH.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc, "crash" )
  CutsceneManager.preload   ( _CRASH.SCRIPT               )
end

_CRASH.static.PALETTE             = Colors.Sprites.crash
_CRASH.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_red_than_kai,
  Colors.kai_dark_red,
  Colors.kai_dark_red,
  Colors.bruiser_darker_body,
  Colors.bruiser_darker_body,
  Colors.bruiser_darker_body
)

_CRASH.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_CRASH.static.DIMENSIONS = {
  x            =   2,
  y            =   2,
  w            =  24,
  h            =  30,
  -- these basically oughto match or be smaller than player
  grabX        =   7,
  grabY        =   4,
  grabW        =  14,
  grabH        =  28,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_CRASH.static.PROPERTIES = {
  isSolid       = false,
  isEnemy       = true,
  isDamaging    = true,
  isHeavy       = true,
  isNotCrushSpawnBreaking = true,
}

_CRASH.static.DRILL_PROPERTIES = {
  isDamaging    = true,
  isBulletType  = true,
  isNotCrushSpawnBreaking = true,
}

_CRASH.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  tileNonObject     = Filters:get ( "queryNonObjectTile"          ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
  warningTile       = Filters:get ( "queryWarningTile"            ),
  enemy             = Filters:get ( "queryEnemyObjectsFilter"     ),
  enemyOrBreakable  = Filters:get ( "queryEnemyOrBreakableObjectsFilter" ),
  bullet            = Filters:get ( "bulletFilter"                ),

  drillSpawn        = function ( other ) return other.isTile and other.isSolid and not other.isPassable and not other.isDamaging and not other.isBreakable end
}

_CRASH.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  behind    = Layer:get ( "BEHIND-TILES", "SPRITES"   ),
}

_CRASH.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_CRASH.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE
}

_CRASH.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_CRASH.static.BOSS_CIRCUIT_SPAWN_OFFSET = {
  x = 0,
  y = -16,
}

_CRASH.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:finalize ( parameters )
  RegisterActor  ( ACTOR.CRASH, self )
  self:translate ( 0, 16 )

  self.invulBuildup = 0

  self.hazeParticleLayer = Layer:get ( "TILES-RAY-LASERS" )
    
  self.ogSpawnX, self.ogSpawnY = self:getPos()

  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )
  self.velocity.vertical.gravity.maximum = 6.5

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "crash", 1 )
  self.sprite:change ( 1, "idle" )
  self.sprite:addInstance ( 2 )
  self.sprite:addInstance ( 3 )

  self.isFlinchable           = false
  self.isImmuneToLethalTiles  = true

  self.summonTime   = 0
  self.summonX      = 0
  self.summonY      = 0
  self.pillarTime   = 0
  self.pillarWidth  = 0

  self.actionsWithoutRest   = 0
  self.nextActionTime       = 10
  self.desperationActivated = false

  self:setFallingBlockSpawnMaxRange ( 80, 40, 16, 4 )

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.chain   = {
    active    = false,
    x         = 0,
    y         = 0,
    shakeY    = 0,
    shakeYDir = 0,
    drillW    = 25,
    drillH    = 17,
    collider  = Physics:newObject ( "crash_drill_collider_horizontal", 0, 0, 25, 17, self.class.DRILL_PROPERTIES, self, true ),
  }

  self.playerContactType    = "cross" -- this dictates how the drill collider behaves
  self.breakableContactType = "cross"

  self.sensors = {
   WALL_SMASH_SENSOR = 
      Sensor
        :new                ( 
          self, 
          self.filters.player, 
          0, 
          -self.dimensions.h,
          self.dimensions.w+10,
          self.dimensions.h )
        :expectOnlyOneItem  ( true ),
  }

  self.activeAfterImagesLayer = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
  self.actionsSinceStomp      = 0

  self.fallingBlockTimer      = 0
  self.fallingBlockCount      = 0

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -4,  -4, 36, 40, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil

  if parameters and parameters.bossRush then
    self.state.isBossRushSpawn  = true
    self.state.isBoss           = true
    self.sprite:change ( 1, "intro-land", 5, false )
    self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
      self.sprite:change ( 1, "idle" )
    end
  elseif parameters and parameters.isTarget then
    self.state.isBoss   = true
    self.listener       = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
    local flag  = GetFlag ( "crash-boss-prefight-dialogue" ) 
    local flag2 = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" ) 

    if GAMESTATE.speedrun then
      flag  = true
      flag2 = 0
    end
    
    if (not flag) or (flag2 and flag2 > 0) then
      self:gotoState      ( "PREFIGHT_INTRO" )
      self.sprite:change  ( 1, nil )
    else
      self.sprite:change ( 1, "intro-land" )
    end
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end
end

-- §activate
function _CRASH:activate ( )  
  if not self.state.isSpawnBoss then
    GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  end
  
  self.activeLayer  = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
  self.activated    = true
  self.health       = 48
  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "crash", self.health )

  --if self.state.isSpawnBoss then
  --  self:setFallingBlockType ( "metal" )
  --end
end

function _CRASH:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end

  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end

  UnregisterActor ( ACTOR.CRASH, self )
end

function _CRASH:isDrawingWithPalette ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _CRASH:prenotifyBossBattleOver ( )

  self.activeLayer = self.layers.sprite
  local items, len = Physics:queryRect ( Camera:getX()+2, Camera:getY()+2, GAME_WIDTH-4, GAME_HEIGHT-4, self.filters.enemyOrBreakable )
  for i = 1, len do
    if items[i] and items[i].parent ~= self then
      if items[i].parent.stateVars then
        items[i].parent.stateVars.exitedProperly = true
      end
      if items[i].parent:hasState("DESTRUCT") then
        items[i].parent:gotoState("DESTRUCT")
      elseif items[i].parent.despawn then
        items[i].parent:despawn()
      elseif items[i].parent.takeDamage then
        items[i].parent:takeDamage()
      end
    end
  end

  Environment.conveyorBeltSurface(nil,false)
end

function _CRASH:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
  Environment.conveyorBeltSurface(nil,false)
end

function _CRASH:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:isFacingRight() then
    mx = mx + 5
  else
    mx = mx - 4
  end
  my = my - 3
  return mx, my
end

function _CRASH:handleDeathKneeling ( )
  self.sprite:change ( 1, "death-kneel" )
  self.sprite:change ( 2, nil )
  self.sprite:change ( 3, nil )
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _CRASH:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self:updateBossInvulnerability ( )

  if self.chain.shakeY > 0 then
    self.chain.shakeY     = math.max ( self.chain.shakeY - 0.25, 0 )
    self.chain.shakeYDir  = -self.chain.shakeYDir
  end

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

  if self.health > 0 and self.fallingBlockCount > 0 then
    self.fallingBlockTimer = self.fallingBlockTimer + 1
    if self.fallingBlockTimer%8==0 then
      self.fallingBlockCount = self.fallingBlockCount - 1
      self:spawnFallingBlocks ( )
    end
  end

  self:drawSensors()


  self:updateContactDamageStatus ()
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )

  self.conveyorX = 0
  self.conveyorY = 0
end

function _CRASH:tick ()
  self:applyPhysics()
end

-- §addFallingBlocks
function _CRASH:addFallingBlocks ( count, instant )
  count                  = (count or 1) + (self.desperationActivated and 4 or 5)
  self.fallingBlockTimer = 0
  if self.fallingBlockCount > 0 then
    count = 0
  end
  local max = self.desperationActivated and 0 or 0
  if GAMESTATE.mode == 1 then
    max = max * 0
  elseif GAMEDATA.isHardMode() then
    max = max * 0
  end

  self.fallingBlockCount = math.max(self.fallingBlockCount + (count), max)
  if instant then
    self.fallingBlockCount = math.max ( self.fallingBlockCount - 1, 0 )
    self:spawnFallingBlocks ( )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_CRASH.static.ACTIONS = {
  "DESPERATION_ACTIVATION", -- 1
  "STOMP",                  -- 2
  "JUMP",                   -- 3
  "DRILL_CHAIN",            -- 4
  "CEILING_DRILL_SMASH",    -- 5,
  "DRILL_LUNGE",            -- 6,
}

function _CRASH:pickAction ( recursion, px, py, mx, my  )
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 1
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

  --action = 1

  if action <= 0 then
    if not self.firstAction then
      action            = 3
      self.firstAction  = true
      extra             = 1
    else
      if self.lastAction ~= 3 and self.lastAction ~= 1 then
        local dif = math.abs(px-mx)
        if self.lastAction == 4 and RNG:n() > 0.35 and not self.doubleChainUsed then
          action = 4
          self.doubleChainUsed = true
        else
          if dif < 64 and RNG:n() > 0.825 then
            action = 6
          else
            action = 3
          end
        end
      else
        --if self.actionsSinceStomp > 3 and RNG:n() > 0.4 then
        --  action = 2
        --else
          local dif = math.abs(px-mx)
          if dif < 70 and RNG:n() > 0.75 then
            action = 6
          else
            local chance = RNG:n()
            --[[if chance > (0.975 - (self.actionsSinceStomp) * 0.025) then
              action = 2
            else]]if chance > 0.875 then
              action = 3 -- jump
            elseif chance > 0.40 then
              action = 4 -- chain
            elseif chance > 0.07 then
              action = 5 -- ceiling
            else
              action = 6
            end
          end
        --end
      end
    end
  end

  if action <= 0 then return end
  if self.desperationActivated then
    if not self.actionsSinceDesperation then
      self.actionsSinceDesperation = 0
    end
    self.actionsSinceDesperation = self.actionsSinceDesperation + 1
    if self.actionsSinceDesperation > 5 then
      self.forceDesperation = RNG:n() < (0.04 + (self.actionsSinceDesperation-5)*0.125)
    end
  end

  if action ~= 2 then 
    self.actionsSinceStomp = self.actionsSinceStomp + 1
  else
    self.actionsSinceStomp = 0
  end

  if action <= 0 then return end
  --[[
  if self.lastAction == action and action > 1 and not recursion then
    self:pickAction ( true, px, py, mx, my )
    return
  end]]
  if self.doubleChainUsed and action ~= 4 then
    self.doubleChainUsed = false
  end

  self.lastAction = action
  --action = 5
  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §end action ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:endAction ( finishedNormally )
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §locations ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:getLocations ( )
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _CRASH:updateLocations()
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

function _CRASH:handleYBlock(_,__,currentYSpeed)
  if currentYSpeed < 0.75 then
    return
  end

  local x,y   = self:getPos()
  Environment.landingParticle ( x, y+4, self.dimensions, -7, 23, 17 )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §break breakables ---------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:handleCollisions (colsX, lenX, colsY, lenY )
  local other
  for i = 1, lenX do
    other = colsX[i].other
    if other.isBreakable and other.parent.instantBreak and not other.parent.isReflected then
      other.parent:instantBreak ( )
    end
  end 

  for i = 1, lenY do
    other = colsY[i].other
    if other.isBreakable and other.parent.instantBreak and not other.parent.isReflected then
      other.parent:instantBreak ( )
    end
  end
end

_CRASH.handleBounceCollisions = _CRASH.handleCollisions

-- deny crushing
function _CRASH:applyCrush ( )
  -- ...
end

function _CRASH:manageCrushingDamage ( )
  -- ...
end

function _CRASH:bonkReduction ( isSelfDamage )
  if not isSelfDamage then
    Challenges.unlock ( Achievements.RETURN_TO_BOSS )
  end
  return isSelfDamage and GAMEDATA.damageTypes.EMPTY or GAMEDATA.damageTypes.COLLISION_REDUCED
end

function _CRASH:applyPushAftermath ( tile, pushX, pushY )
  self.conveyorX = pushX
  self.conveyorY = pushY
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _CRASH:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Stomp  -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _STOMP = _CRASH:addState ( "STOMP" )

_CRASH.static.BLOCK_DROP_LOCATIONS = {

}

function _STOMP:enteredState ( px, py, mx, my )
  self.sprite:flip    ( px > mx and 1 or -1 )
  self.sprite:change  ( 1, "stomp", 1, true )
  self.timer                = 0
  self.stateVars.spawnCount = 0
  self.stateVars.stomped    = false
end

function _STOMP:exitedState ( )
  self:endAction ( false )
  self.nextActionTime = self.desperationActivated and 20 or 30

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 8
  end
end

function _STOMP:tick ( )
  if not self.stateVars.stomped and (self.sprite:getFrame() == 6) then
    self.stateVars.stomped = true
    local mx, my           = self:getMiddlePoint()
    local sx               = self.sprite:getScaleX()

    Audio:playSound ( SFX.gameplay_crash_impact,     1.2 )
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
    Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and -23 or 10),  my+2,  -sx, 1, -0.25*sx,  -0.1 )
    Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and -7  or 10),  my+2,   sx, 1, -0.25,     -0.1 )
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      1.75,
      -4.5
    )

    Camera:startShake               ( 0, 3, 20, 0.25 )
    Environment.conveyorBeltSurface ( true, true )

    self:addFallingBlocks ( 0, true )
  else
    self.timer = self.timer + 1
  end

  if self.stateVars.stomped then
    self:endAction        ( true )
  end

  self:applyPhysics ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Jump    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _JUMP = _CRASH:addState ( "JUMP" )

function _JUMP:enteredState ( px, py, mx, my, extra )
  --self.sprite:flip    ( px > mx and 1 or -1 )
  self.timer                = 1
  self.stateVars.spawnCount = 0
  self.stateVars.jumped     = false
  self.stateVars.animStart  = false
  self.stateVars.jumpNum    = 0
  self.stateVars.jumpCount  = RNG:range ( 1, 3 )

  if extra == 1 then
    self.stateVars.quickJump = true
  end
end

function _JUMP:exitedState ( )
  self:endAction ( false )
  self.nextActionTime = self.desperationActivated and 7 or 7

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 6
  end
end

function _JUMP:tick ( )
  if not self.stateVars.jumped then
    if not self.stateVars.animStart then
      --local anim = self.sprite:getAnimation()
      --if (anim == "idle" and self.sprite:getFrame() == 1) or anim ~= "idle" then
        self.sprite:change ( 1, "hop" )
        self.stateVars.prejumpFrames = self.stateVars.quickJump and 0 or 0
        self.stateVars.animStart     = true
      --end
    else
      self.stateVars.prejumpFrames = self.stateVars.prejumpFrames + 1
      if self.stateVars.prejumpFrames >= 16 then
        Audio:playSound ( SFX.gameplay_boss_cable_jump )
        self.sprite:change ( 1, "hop", 5, true )
        local px, py, mx, my     = self:getLocations()
        self.stateVars.jumped    = true
        self.stateVars.landed    = false
        self.stateVars.jumpNum   = self.stateVars.jumpNum + 1
        self.nextJumpTime        = 1
        self:jump ( px, py, mx, my )
      end
    end
    self:applyPhysics()
  else
    self:applyPhysics()
    if self.state.isGrounded then
      if not self.stateVars.landed then
        self.velocity.horizontal.current = 0
        self.stateVars.landed            = true

        self.stateVars.prejumpFrames = 1
        self.stateVars.animStart     = true

        self.sprite:change              ( 1, "land" )
        Camera:startShake               ( 0, 3, 20, 0.25 )
        self:setAfterImagesEnabled      ( false )


        Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
        if self.stateVars.jumpCount ~= self.stateVars.jumpNum then
          Audio:playSound                 ( SFX.gameplay_crash_land   )
        else
          Audio:playSound                 ( SFX.gameplay_crash_impact )
        end
        --if self.stateVars.jumpNum ~= self.stateVars.jumpCount then
          local count = 1
          if self.stateVars.jumpNum >= self.stateVars.jumpCount then
            count = count + 1
          end
          self:addFallingBlocks ( count, true )
        --end
      end
    end
  end

  if self.stateVars.landed then
    if self.stateVars.jumpNum >= self.stateVars.jumpCount then
      if self.timer == 1 then
        Environment.conveyorBeltSurface ( true, true )
      end
      self.timer = self.timer + 1
      if self.timer > 10 then
        self:endAction ( true )
      end
    else
      self.nextJumpTime = self.nextJumpTime - 1
      if self.nextJumpTime <= 0 then
        Environment.conveyorBeltSurface ( true, true )
        self.stateVars.jumped    = false
        self.stateVars.landed    = false
      end
    end
  end
end

-- ...heh
function _JUMP:jump ( px, py, mx, my )
  if not self.playerIsKnownToBeAlive then 
    local dir = self.sprite:getScaleX()
    self.velocity.vertical.current      = -4.5
    self.velocity.horizontal.current    = 1.0
    self.velocity.horizontal.direction  = dir
    self.sprite:flip ( dir )
    return 
  end

  if self.stateVars.jumpNum < self.stateVars.jumpCount then
    local dir = px < mx and -1 or 1
    self.velocity.vertical.current      = -4.5 - (self.stateVars.jumpNum == 1 and 0 or 1)
    self.velocity.horizontal.current    = 1.0
    self.velocity.horizontal.direction  = dir
    self.sprite:flip ( dir )
    return
  end
  --[[
  if self.stateVars.jumpNum == 2 then
    local dir = px < mx and -1 or 1
    self.velocity.vertical.current      = -5.0
    self.velocity.horizontal.current    = 1.5
    self.velocity.horizontal.direction  = dir
    self.sprite:flip ( dir )
    return
  end]]

  self:setAfterImagesEnabled( true )
  self.stateVars.jumped = true
  local dif    = math.abs(mx - px)
  local dir    = mx > px and -1 or 1
  self.velocity.horizontal.direction  = dir
  dif = dif / 52
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

  self.velocity.horizontal.direction = dir
  self.velocity.horizontal.current   = dif
  self.velocity.vertical.current     = -7.0
  self.state.isGrounded              = false

  self.sprite:flip ( dir )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Drill chain --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DRILL_CHAIN = _CRASH:addState ( "DRILL_CHAIN" )

function _DRILL_CHAIN:enteredState ( px, py, mx, my )
  self.sprite:flip   ( px > mx and 1 or -1 ) -- ( 1 )
  self.sprite:change ( 1, "drill-shoot",          2, true )
  self.sprite:change ( 2, "drill-shoot-underlay", 2, true )

  self.activeLayer          = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
  self.stateVars.spawned    = false
  self.timer                = 0
  self.stateVars.spawnCount = 0

  self.chain.collider.rect.w = self.chain.drillW
  self.chain.collider.rect.h = self.chain.drillH
end

function _DRILL_CHAIN:exitedState ( )
  self.chain.active = false

  if Physics:hasObject ( self.chain.collider ) then
    Physics:removeObject ( self.chain.collider )
    self.chain.inserted = false
  end

  self.isPreventingPushes = false
  self.sprite:change         ( 2, nil )
  self:endAction             ( false )
  self:setAfterImagesEnabled ( false )

  self.nextActionTime = self.desperationActivated and 7 or 7

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 6
  end
end

function _DRILL_CHAIN:tick ( )
  local hitWall = false
  if not self.stateVars.spawned and self.sprite:getFrameTime() <= 0 and self.sprite:getFrame() == 11 then
    self.stateVars.spawned = true
    hitWall                = self:shootChain()
  end 

  if self.chain.active then
    if not hitWall and not self.stateVars.hitWall then
      local returned    = false
      hitWall, returned = self:moveChain() 
      if returned then
        self.sprite:change  ( 1, "drill-shoot-return" )
        Audio:playSound     ( SFX.gameplay_crane_impact, 0.8 )--SFX.gameplay_crash_drill_reattach )
        self:applyPhysics   ( )
        self:endAction      ( true )
        return
      end
    end
    if hitWall then
      self.stateVars.hitWall = true
      --Camera:startShake ( 0, 3, 20, 0.25 )
    else
      self.stateVars.firstMove = true
    end
  end

  if not self.stateVars.bonked then
    if self.stateVars.spawned and self.stateVars.hitWall then
      self:moveAlongChain()
      if self.velocity.horizontal.current > 0 and GetTime()%2 == 0 then
        local mx, my = self:getMiddlePoint()
        local sx     = self.sprite:getScaleX()
        Particles:addFromCategory ( "landing_dust", mx + (sx < 0 and 9 or -18),  my+4,  sx, 1, -0.25*sx, -0.1 )
      end
    end
  end

  self:applyPhysics ( )
  if self.stateVars.spawned and not self.stateVars.moving and not self.stateVars.bonked and self.stateVars.startX ~= self:getX() then
    local x                 = self:getX()
    local difX              = self.stateVars.startX - x
    self.chain.spawnX       = self.chain.spawnX     - difX
    self.stateVars.startX   = x
  end

  if self.stateVars.spawned and self.chain.spawnX and not self.stateVars.bonked then
    local x,y,w,h
    if self.sprite:getScaleX() > 0 then
      x = self:getX() + 28
      w = self.chain.x - x + 41
      y,h = self.chain.y+3, 8
    else
      x   = self.chain.x - 10
      w   = self:getX() - x + 10
      y,h = self.chain.y+3, 8
    end
    if w > 0 then
      local cols, len = Physics:queryRect ( 
        x,y,w,h,
        self.filters.player
      )
      if len > 0 then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_WEAK, "weak", self.sprite:getScaleX() )
      end

      --GFX:drawRect ( 100000, x,y,w,h, Colors.kai_red )
    end
  end


  if self.stateVars.bonked and self.state.isGrounded then
    self.isPreventingPushes             = false
    self.velocity.horizontal.current    = 0
    self.velocity.horizontal.direction  = 0
    self.sprite:change  ( 1, "land" )
    Audio:playSound     ( SFX.gameplay_crash_land )
    self:endAction      ( true )
    GameObject:spawn ( 
      "plasma_ball", 
      self:getX()+1, 
      self:getY()+1, 
      1
    )
  end
end

function _DRILL_CHAIN:shootChain ( )
  self.chain.x, 
  self.chain.y      = self:getPos()

  self.stateVars.startX,
  self.stateVars.startY  = self:getPos()

  Audio:playSound     ( SFX.gameplay_crash_drill_shoot, 1.25 )
  self.stateVars.chainSfxTime = 0
  
  self.chain.active = true
  self.chain.xSpeed = self.desperationActivated and 15 or 13
  self.chain.ySpeed = 0
  
  if self.sprite:getScaleX() > 0 then
    self.chain.xDir = 1
    self.chain.yDir = 0
    self.chain.xScale = 1

    self.chain.cox    = 43
    self.chain.coy    = -2

    self.chain.spawnX = self.chain.x + 25
    self.chain.spawnY = self.chain.y + 2
    -- ...
  else
    self.chain.xDir = -1
    self.chain.yDir = 0
    self.chain.xScale = -1

    self.chain.cox    = -36 -- ehehehehehe
    self.chain.coy    = -2

    self.chain.spawnX = self.chain.x
    self.chain.spawnY = self.chain.y + 2
    -- ...
  end

  self.chain.reverse    = false
  self.chain.len        = 1
  self.chain.animTip    = "drill-chain-tip"
  self.chain.animMid    = "drill-chain-middle2"
  self.chain.horizontal = true

  self.sprite:change ( 3, self.chain.animTip )

  -- sparks
  local mx, my = self.chain.x, self.chain.y
  my = my + 7
  if self.chain.xDir > 0 then
    mx = mx + self.chain.collider.rect.w + self.chain.cox - 16
  elseif self.chain.xDir < 0 then
    mx = mx + self.chain.cox + 16
  end
  Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )

  -- check if any blocks
  local items, len = Physics:queryRect ( 
    self.chain.x + self.chain.cox,
    self.chain.y + self.chain.coy,
    self.chain.collider.rect.w,
    self.chain.collider.rect.h,
    self.filters.drillSpawn
  )
  if len > 0 then
    return true
  end

  self.chain.inserted = true
  -- insert actual collider
  Physics:insertObject ( self.chain.collider, self.chain.x + self.chain.cox, self.chain.y + self.chain.coy )
  return false
end

function _DRILL_CHAIN:moveChain ( )

  self.stateVars.chainSfxTime = self.stateVars.chainSfxTime + 1
  if self.stateVars.chainSfxTime > 8 then
    if not Audio:isSoundPlaying ( SFX.gameplay_crash_drill_chain ) then
      Audio:playSound ( SFX.gameplay_crash_drill_chain )
    end
  end

  if self.chain.len > 20 then
    self.chain.reverse =  true
  end

  if self.chain.reverse then
    self.chain.xSpeed = math.max(self.chain.xSpeed - 0.5, -10)
  end

  local tx, ty                      = (self.chain.x + self.chain.xSpeed * self.chain.xDir) + self.chain.cox, (self.chain.y + self.chain.ySpeed * self.chain.yDir) + self.chain.coy
  local actualX, actualY, cols, len = Physics:simpleMoveObject ( self.chain.collider, tx, ty, self.filters.bullet )
  
  self.chain.x   = actualX - self.chain.cox
  self.chain.y   = actualY - self.chain.coy
  self.chain.len = math.floor(math.abs(self.chain.x-self.chain.spawnX) / 8) + 3
  if self.chain.xDir > 0 then
    self.chain.len = self.chain.len + 2
  end

  if self.chain.reverse and self.chain.len < 6 then
    local mx, my = self.chain.x, self.chain.y
    my = my + 7
    if self.chain.xDir > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox - 40
    elseif self.chain.xDir < 0 then
      mx = mx + self.chain.cox + 22
    end
    Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )

    return false, true
  end

  for i = 1, len do
    local other = cols[i].other
    if other.isBreakable and other.parent and other.parent.instantBreak then
      other.parent:instantBreak ( )
    end
  end

  if actualX ~= tx or actualY ~= ty then
    local mx, my = self.chain.x, self.chain.y
    my = my + 4
    if self.chain.xDir > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox
    elseif self.chain.xDir < 0 then
      mx = mx + self.chain.cox
    end
    Particles:addSpecial ( "small_white_sparks", mx, my, self.layers.sprite()+1, false )
    self.chain.shakeY     = 2
    self.chain.shakeYDir  = math.rsign()

    self.isPreventingPushes = true
    Audio:playSound ( SFX.gameplay_crash_drill_shoot )
    return true
  end
end

function _DRILL_CHAIN:moveAlongChain ( )
  if not self.stateVars.wait then 
    self.stateVars.wait = 1
    return
  elseif self.stateVars.wait > 0 then
    self.stateVars.wait = self.stateVars.wait - 1
    return
  end

  if not Audio:isSoundPlaying ( SFX.gameplay_crash_drill_chain ) then
    Audio:playSound ( SFX.gameplay_crash_drill_chain )
  end

  if not self.stateVars.moving then
    self.sprite:change ( 1, "drill-shoot-pull", 2 )
    self.sprite:change ( 2, nil )
    self:setAfterImagesEnabled ( true )
    self.velocity.vertical.update       = false
    self.isPreventingPushes             = true
    self.velocity.horizontal.current    = self.desperationActivated and 16 or 17
    self.velocity.horizontal.direction  = self.sprite:getScaleX()
    self.stateVars.moving               = true
  end

  --self.chain.spawnX = self.chain.spawnX + self.velocity.horizontal.current * self.velocity.horizontal.direction
  self.chain.len    = math.floor(math.abs(self.chain.x-self.chain.spawnX) / 8) + 3
  if self.chain.xDir > 0 then
    self.chain.len = self.chain.len + 2
  end
  if self.chain.inserted then
    local x,y,w   = Physics:getRect ( self.chain.collider)
    local mx  = self:getMiddlePoint()
    if (x < mx + 16 and self.velocity.horizontal.direction > 0) or (x + w > mx - 16 and self.velocity.horizontal.direction < 0) then
      self:handleXBlock ()
    end
  end
end

function _DRILL_CHAIN:handleXBlock ()
  if self.stateVars.moving then

    self:setAfterImagesEnabled ( false )
    self.stateVars.moving               = false
    self.stateVars.bonked               = true
    self.velocity.horizontal.current    = 1.5
    self.velocity.horizontal.direction  = -self.velocity.horizontal.direction
    self.velocity.vertical.current      = -3.5
    self.velocity.vertical.update       = true
    self.chain.active                   = false
    self.state.isGrounded               = false

    Environment.conveyorBeltSurface ( true, true )

    self:addFallingBlocks ( 3, true )

    if Physics:hasObject ( self.chain.collider ) then
      Physics:removeObject ( self.chain.collider )
      self.chain.inserted = false
    end

    if self.sensors.WALL_SMASH_SENSOR:check ( self.sprite:getScaleX() ) then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", self.sprite:getScaleX() )
    end

    self.sprite:change              ( 1, "hop", 5 )
    self.sprite:change              ( 2, nil )
    Camera:startShake               ( 0, 3, 20, 0.25 )
    Audio:playSound                 ( SFX.gameplay_crash_impact )
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §ceiling drill smash ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _CEILING_DRILL = _CRASH:addState ( "CEILING_DRILL_SMASH" )

function _CEILING_DRILL:enteredState ( px, py, mx, my )

  local cx = Camera:getX()
  if self.conveyorX ~= 0 then
    local cx = Camera:getX()
    if mx > cx + GAME_WIDTH - 80 then
      self.sprite:flip ( -1 )
    elseif mx < cx + 80 then
      self.sprite:flip ( 1 )
    else
      self.sprite:flip ( px < mx and -1 or 1 )
    end
  else
    local cx = Camera:getX()
    if mx > cx + GAME_WIDTH - 80 then
      self.sprite:flip ( -1 )
    elseif mx < cx + 80 then
      self.sprite:flip ( 1 )
    else
      self.sprite:flip ( px < mx and -1 or 1 )
    end
  end

  self.sprite:change ( 1, "drill-shoot-up-overlay-closed-claw", 2, true )
  self.sprite:change ( 2, "drill-shoot-up", 2, true )

  self.activeLayer          = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
  self.stateVars.spawned    = false
  self.timer                = 0
  self.stateVars.spawnCount = 0
  self.stateVars.exitTimer  = 0

  self.chain.collider.rect.w = self.chain.drillH
  self.chain.collider.rect.h = self.chain.drillW
end

function _CEILING_DRILL:exitedState ()
  self.chain.active = false

  if Physics:hasObject ( self.chain.collider ) then
    Physics:removeObject ( self.chain.collider )
    self.chain.inserted = false
  end

  self.sprite:change         ( 2, nil )
  self:endAction             ( false )
  self:setAfterImagesEnabled ( false )

  self.nextActionTime = self.desperationActivated and 11 or 11


  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 10
  end
end

function _CEILING_DRILL:tick ()
  self.stateVars.exitTimer = self.stateVars.exitTimer + 1
  local hitWall = false
  if not self.stateVars.spawned and self.sprite:getFrameTime() <= 0 and self.sprite:getFrame() == 9 then
    self.stateVars.spawned = true
    hitWall                = self:shootChain()
    if hitWall then
      self.sprite:change  ( 1, "drill-shoot-up-return", 2, true )
      Audio:playSound     ( SFX.gameplay_crane_impact, 0.8 )--SFX.gameplay_crash_drill_reattach )
      self:applyPhysics   ( )
      self:endAction      ( true )
    end
  end 

  if self.chain.active then

    if not hitWall and not self.stateVars.hitWall then
      local returned = false
      hitWall, returned = self:moveChain() 
      if returned then 
        self.sprite:change  ( 1, "drill-shoot-up-return", 2, true )
        Audio:playSound     ( SFX.gameplay_crane_impact, 0.8 )--SFX.gameplay_crash_drill_reattach )
        self:applyPhysics   ( )
        self:endAction      ( true )
        return
      end
    end

    if hitWall then
      self.stateVars.hitWall = true
      self.stateVars.bonked  = true
      self.stateVars.sfxTime = 9
    else
      self.stateVars.firstMove = true
    end
  end

  if self.stateVars.bonked then
    self.stateVars.sfxTime = self.stateVars.sfxTime + 1
    if self.stateVars.sfxTime > 5 and self.stateVars.sfxTime < 80 and self.stateVars.sfxTime % 10 == 0 then
      Audio:playSound ( SFX.gameplay_crash_drill_rock, 0.75 )
    end

    self.timer = self.timer + 1
    if self.timer%6 == 0 then
      if self.stateVars.spawnCount < 8 then
        if self.stateVars.spawnCount < 8 then
          local mx, my = self:getMiddlePoint()
          Camera:startShake       ( 0, 2, 20, 0.25 )
          --self:spawnFallingBlocks ( mx, my )
        end
        self.stateVars.spawnCount = self.stateVars.spawnCount + 2
        if self.stateVars.spawnCount >= 7 then
          if self.playerIsKnownToBeAlive then
            local cx              = Camera:getX()
            local px, py, mx, my  = self:getLocations()
            px                    = px - 6
            px                    = math.multiple ( px, 16 )

            if px <= cx + 16 then
              px = cx + 16
            elseif px >= cx + GAME_WIDTH - 48 then
              px =  cx + GAME_WIDTH - 48
            end

            if self.state.isSpawnBoss then
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px,
                my - 168,
                1,
                true,
                3,
                0
              )
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px - 30,
                my - 168,
                1,
                true,
                3,
                0
              )
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px + 30,
                my - 168,
                1,
                true,
                3,
                0
              )
            else
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px,
                my - 168,
                1,
                true,
                3,
                0
              )
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px - 30,
                my - 168,
                1,
                true,
                3,
                0
              )
              GameObject:spawn ( 
                "shift_downcut_projectile",
                px + 30,
                my - 168,
                1,
                true,
                3,
                0
              )
            end
            if self.desperationActivated then
              if (px + 32) <=  (cx + GAME_WIDTH - 48) then
                if self.state.isSpawnBoss then
                  GameObject:spawn ( 
                    "shift_uppercut_projectile",
                    px - 280,
                    my-30,
                    1
                  )--:setMetalType ( )
                else
                  GameObject:spawn ( 
                    "shift_uppercut_projectile",
                    px + 280,
                    my-30,
                    -1
                  )
                end
              end
              if (px - 32) >=  (cx + 16) then
                if self.state.isSpawnBoss then
                  GameObject:spawn ( 
                    "shift_uppercut_projectile",
                    px - 330,
                    my-30,
                    1,
                    GAMEDATA.isHardMode() and 0 or 1
                  )
                else
                  GameObject:spawn ( 
                    "shift_uppercut_projectile",
                    px + 330,
                    my-30,
                    -1,
                    GAMEDATA.isHardMode() and 0 or 1
                  )
                end
              end
            end
          end
        end
      else
          
        self.stateVars.hitWall = false
        self.chain.reverse     = true
        self.chain.ySpeed      = 0
        self.stateVars.bonked  = false
      end
    end
  end

  self:applyPhysics ( )
  if self.stateVars.spawned and self.stateVars.startX ~= self:getX() then
    local x                 = self:getX()
    local difX              = self.stateVars.startX - x
    self.chain.spawnX       = self.chain.spawnX     - difX
    self.stateVars.startX   = x
    self.chain.x            = x
  end

  if self.stateVars.spawned and self.chain.spawnX then
    local x,y,w,h = self.chain.x-6, self.chain.y-6, 8, self.chain.len * 8

    if h > 0 then
      local cols, len = Physics:queryRect ( 
        x,y,w,h,
        self.filters.player
      )
      if len > 0 then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_WEAK, "weak", self.sprite:getScaleX() )
      end
    end

    --GFX:drawRect ( 100000, x,y,w,h, Colors.kai_red )
  end

  if self.stateVars.exitTimer > 300 then
    self:endAction ( true )
  end
end

function _CEILING_DRILL:shootChain ( )
  self.chain.x, 
  self.chain.y      = self:getPos()

  self.stateVars.startX,
  self.stateVars.startY  = self:getPos()

  Audio:playSound     ( SFX.gameplay_crash_drill_shoot, 1.25 )
  self.stateVars.chainSfxTime = 0

  self.chain.active = true
  self.chain.xSpeed = 0
  self.chain.ySpeed = self.desperationActivated and 10 or 7
  
  if self.sprite:getScaleX() > 0 then
    self.chain.xDir = 0
    self.chain.yDir = -1
    self.chain.xScale = 1

    self.chain.cox    = 26
    self.chain.coy    = -29

    self.chain.spawnX = self.chain.x + 29
    self.chain.spawnY = self.chain.y + 2
    -- ...
  else
    self.chain.xDir   = 0
    self.chain.yDir   = -1
    self.chain.xScale = -1

    self.chain.cox    = -11 -- ehehehehehe
    self.chain.coy    = -29

    self.chain.spawnX = self.chain.x - 7
    self.chain.spawnY = self.chain.y + 2
    -- ...
  end

  self.chain.reverse    = false
  self.chain.len        = 1
  self.chain.animTip    = "drill-chain-tip-vertical-spinning"
  self.chain.animMid    = "drill-chain-middle-vertical2"
  self.chain.horizontal = false

  self.sprite:change ( 3, self.chain.animTip, 1, true )

  -- sparks
  local mx, my = self.chain.x, self.chain.y
  my = my - 5
  if self.sprite:getScaleX() > 0 then
    mx = mx + self.chain.collider.rect.w + self.chain.cox - 6
  else 
    mx = mx + self.chain.cox + 4
  end
  Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )

  -- check if any blocks
  local items, len = Physics:queryRect ( 
    self.chain.x + self.chain.cox,
    self.chain.y + self.chain.coy,
    self.chain.collider.rect.w,
    self.chain.collider.rect.h,
    self.filters.drillSpawn
  )
  if len > 0 then
    return true
  end

  self.chain.inserted = true
  -- insert actual collider
  Physics:insertObject ( self.chain.collider, self.chain.x + self.chain.cox, self.chain.y + self.chain.coy )
  return false
end

local blankFilter = function () return nil end

function _CEILING_DRILL:moveChain ( )

  self.stateVars.chainSfxTime = self.stateVars.chainSfxTime + 1
  if self.stateVars.chainSfxTime > 8 then
    if not Audio:isSoundPlaying ( SFX.gameplay_crash_drill_chain ) then
      Audio:playSound ( SFX.gameplay_crash_drill_chain )
    end
  end

  if self.chain.len > 40 and not self.chain.reverse then
    self.chain.reverse =  true
  end

  if self.chain.reverse then
    self.chain.ySpeed = math.max(self.chain.ySpeed - 0.5, -10)
  end

  local tx, ty                      = (self.chain.x + self.chain.xSpeed * self.chain.xDir) + self.chain.cox, (self.chain.y + self.chain.ySpeed * self.chain.yDir) + self.chain.coy
  --tx                                = tx + self.conveyorX
  local actualX, actualY, cols, len = Physics:simpleMoveObject ( self.chain.collider, tx, ty, self.chain.reverse and blankFilter or self.filters.bullet )
  
  self.chain.x   = actualX - self.chain.cox
  self.chain.y   = actualY - self.chain.coy
  self.chain.len = math.floor(math.abs(self.chain.y-self.chain.spawnY) / 8) + 3

  if self.chain.reverse and self.chain.len < 6 then
    local mx, my = self.chain.x, self.chain.y
    my = my + 7
    if self.sprite:getScaleX() > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox - 6
    else
      mx = mx + self.chain.cox + 31
    end
    Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )
    
    return false, true
  end

  if not self.stateVars.bonked and not self.chain.reverse then
    for i = 1, len do
      local other = cols[i].other
      if other.isBreakable and other.parent and other.parent.instantBreak then
        other.parent:instantBreak ( )
      end
    end
  end

  if actualX ~= tx or actualY ~= ty then
    local mx, my = self.chain.x, self.chain.y
    my = my - 16
    if self.sprite:getScaleX() > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox - 9
    else
      mx = mx + self.chain.cox + 7
    end
    Particles:addSpecial  ( "small_white_sparks", mx, my, self.layers.sprite()+1, false )
    Camera:startShake     ( 0, 2, 20, 0.25 )
    Audio:playSound       ( SFX.gameplay_crash_drill_shoot )
    self.chain.shakeX     = 2
    self.chain.shakeYDir  = math.rsign()
    self.chain.reverse    =  true
    return true
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DRILL LUNGE §lunge -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DRILL_LUNGE = _CRASH:addState ( "DRILL_LUNGE" )

function _DRILL_LUNGE:enteredState ( px, py, mx, my )
  self.sprite:flip ( px < mx and -1 or 1 )
  self.timer                    = 0
  self.stateVars.spawnCount     = 0

  self.sprite:change ( 1, "drill-lunge", 1, true )
  self.velocity.vertical.update = true
end

function _DRILL_LUNGE:exitedState ( )
  self:setAfterImagesEnabled ( false )
  self:endAction             ( false )
  self.nextActionTime = 8

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 7
  end
end

function _DRILL_LUNGE:tick ( )
  self.timer = self.timer + 1
  if self.timer == 24 then
    Audio:playSound ( SFX.gameplay_crash_drill )
    self.stateVars.moving               = true
    self.velocity.horizontal.current    = 10
    self.velocity.horizontal.direction  = self.sprite:getScaleX()
    self:setAfterImagesEnabled ( true )
  end

  if self.stateVars.forceBonk or self.stateVars.bonked then
    Audio:stopSound ( SFX.gameplay_crash_drill )
  else
    if self.timer == 60 then
      Audio:playSound ( SFX.gameplay_crash_drill )
    end
  end

  self:applyPhysics()

  if self.velocity.vertical.current < 0 and (self.velocity.horizontal.current <= 0) and not self.stateVars.forceBonk then
    self.state.isGrounded               = false
    self.stateVars.forceBonk            = true
    self.velocity.horizontal.direction  = -self.sprite:getScaleX()
    self.velocity.horizontal.current    = GAMEDATA.isHardMode() and 2.5 or 1.5
  end

  if self.stateVars.bonked then
    if self.state.isGrounded then
      self.velocity.horizontal.current   = 0
      self.velocity.horizontal.direction = 0
      self.sprite:change  ( 1, "land", 1, true )
      Audio:playSound     ( SFX.gameplay_crash_land )
      GameObject:spawn ( 
        "plasma_ball", 
        self:getX()+1, 
        self:getY()+1, 
        1
      )

      self:endAction      ( true )
      return
    end
  else
    if self.timer > 47 and self.timer < 47+40 then
      if self.sensors.WALL_SMASH_SENSOR:check ( self.sprite:getScaleX() ) then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_LIGHT, "weak", self.sprite:getScaleX() )
      end
    end

    if self.timer > 47+20 then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, 0 )
      if self.velocity.horizontal.current <= 0 then
        self:setAfterImagesEnabled ( false )
        self:endAction(true)
      end
    end
  end
end

function _DRILL_LUNGE:handleXBlock ()
  if self.stateVars.moving then
    self.stateVars.moving               = false
    self.stateVars.bonked               = true
    self.stateVars.bonkedThisFrame      = true
    self.velocity.horizontal.current    = 1.5
    self.velocity.horizontal.direction  = -self.velocity.horizontal.direction
    self.velocity.vertical.current      = -3.5
    self.state.isGrounded               = false

    self.sprite:change              ( 1, "hop", 5 )
    self.sprite:change              ( 2, nil )
    Camera:startShake               ( 0, 3, 20, 0.25 )
    self:setAfterImagesEnabled      ( false )

    self:addFallingBlocks ( 1, true )
    Audio:playSound       ( SFX.gameplay_crash_impact )
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _CRASH:addState ( "DESPERATION_ACTIVATION" )

function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )

  self.stateVars.angerTime = 0
  self.timer               = 0

  self.activeLayer = Layer:get ( "TILES-MOVING-PLATFORMS-1" )

  self.chain.collider.rect.w = self.chain.drillH
  self.chain.collider.rect.h = self.chain.drillW

  self.stateVars.animTime  = 10
  if self.desperationActivated then
    self:handleFlip()
    self.stateVars.animPlaying = true
    self.sprite:change ( 1, "drill-shoot-up-overlay-closed-claw", 2, true )
    self.sprite:change ( 2, "drill-shoot-up", 2, true )
    --self.sprite:change ( 1, "desperation-activation", 1, true )
  else
    self.stateVars.angry      = true
    self.stateVars.angerTime  = 60
    self.sprite:change ( 1, "angry", 1, true )
  end

  self.stateVars.blockSpawnCount = 0 
end

function _DESPERATION_ACTIVATION:exitedState ()
  if self.stateVars.startedSuperFlash then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end
  
  self.isPreventingPushes       = false
  self.velocity.vertical.update = true
  self.fakeOverkilledTimer      = nil
  self.state.isHittable         = true

  self:endAction             ( false, true)
  self:setAfterImagesEnabled ( false )

  if Physics:hasObject ( self.chain.collider ) then
    Physics:removeObject ( self.chain.collider )
    self.chain.inserted = false
  end

  self.nextActionTime           = 1
  self.state.isBossInvulnerable = false

  if GAMEDATA.isHardMode() then
    self.nextActionTime = self.nextActionTime - 9
  end
end

function _DESPERATION_ACTIVATION:handleFlip ()
  local px, py, mx = self:getLocations()
  local cx = Camera:getX()
  if self.conveyorX ~= 0 then
    local cx = Camera:getX()
    if mx > cx + GAME_WIDTH - 80 then
      self.sprite:flip ( -1 )
    elseif mx < cx + 80 then
      self.sprite:flip ( 1 )
    else
      self.sprite:flip ( px < mx and -1 or 1 )
    end
  else
    local cx = Camera:getX()
    if mx > cx + GAME_WIDTH - 80 then
      self.sprite:flip ( -1 )
    elseif mx < cx + 80 then
      self.sprite:flip ( 1 )
    else
      self.sprite:flip ( px < mx and -1 or 1 )
    end
  end
end

function _DESPERATION_ACTIVATION:tick ()
  if not self.stateVars.removed and not self.stateVars.removedColliders then
    self:applyPhysics()
  end

  if self.stateVars.angerTime > 0 then
    self.stateVars.angerTime = self.stateVars.angerTime - 1
    if self.stateVars.angerTime == 0 then
      self:handleFlip ()
      self.stateVars.animPlaying = true
      self.sprite:change ( 1, "drill-shoot-up-overlay-closed-claw", 2, true )
      self.sprite:change ( 2, "drill-shoot-up", 2, true )
    end
    return
  end

  if self.stateVars.animTime > 0 then
    self.stateVars.animTime = self.stateVars.animTime - 1
    return
  end

  if self.stateVars.animPlaying and not self.stateVars.shot then
    if self.sprite:getFrameTime() <= 0 and self.sprite:getFrame() == 9  then
      self:shootChain ( )
      self.stateVars.shot = true
    end
  end

  if self.chain.active then
    if not self.stateVars.hitWall then
      if self:moveChain() then
        self.stateVars.hitWall = true
        self.stateVars.sfxTime = 9
      end
    end
  end

  if self.chain.spawnX and self.stateVars.shot then
    local x,y,w,h = self.chain.x-6, self.chain.y-6, 8, self.chain.len * 8

    if h > 0 then
      local cols, len = Physics:queryRect ( 
        x,y,w,h,
        self.filters.player
      )
      if len > 0 then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_WEAK, "weak", self.sprite:getScaleX() )
      end
    end

    --GFX:drawRect ( 100000, x,y,w,h, Colors.kai_red )
  end

  if self.stateVars.hitWall and not self.stateVars.chainFinished then

    self.stateVars.sfxTime = self.stateVars.sfxTime + 1
    if self.stateVars.sfxTime > 5 and self.stateVars.sfxTime < 80 and self.stateVars.sfxTime % 10 == 0 then
      Audio:playSound ( SFX.gameplay_crash_drill_rock, 0.75 )
    end

    if self:moveAlongChain() then
      self.chain.active              = false
      self.stateVars.chainFinished   = true
      self.velocity.vertical.current = 0
      self.timer                     = 0
    else
      Camera:startShake ( 0, 2, 20, 0.25 )
    end
  end

  if self.stateVars.shot and self.stateVars.startX ~= self:getX() then
    local x                 = self:getX()
    local difX              = self.stateVars.startX - x
    self.chain.spawnX       = self.chain.spawnX     - difX
    self.stateVars.startX   = x
    self.chain.x            = x
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
      Particles:addSpecial ( "super_flash", mx + (dir > 0 and 0 or 2), my-15, self.activeLayer()-2, self.layers.sprite()-1, false, mx, my )
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_START", self ) 
        self:permanentlyDisableContactDamage ( false ) 
        self.stateVars.startedSuperFlash = true
        self.state.isBossInvulnerable    = true
      end
      --self.sprite:change ( 1, "desperation-activation" )
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_crash", 7 )
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
      self.timer                        = 0
      self.stateVars.desperationPoint   = 1
      self.stateVars.last               = 0
    end
  elseif self.stateVars.chainFinished and not self.stateVars.spawnedCrumbles then
    if self:spawnHugeBlocks() then
      self.stateVars.spawnedCrumbles = true
    end
  elseif self.stateVars.spawnedCrumbles and not self.stateVars.finishedAttacking then
    if self:setBossDrop() then
      self.stateVars.finishedAttacking = true
    end
  elseif self.stateVars.finishedAttacking then
    self:endAction(true)
  end
end

function _DESPERATION_ACTIVATION:shootChain ( )
  self.chain.x, 
  self.chain.y      = self:getPos()

  self.stateVars.startX,
  self.stateVars.startY  = self:getPos()
  
  Audio:playSound     ( SFX.gameplay_crash_drill_shoot, 1.25 )
  self.stateVars.chainSfxTime = 0

  self.chain.active = true
  self.chain.xSpeed = 0
  self.chain.ySpeed = self.desperationActivated and 10 or 7
  
  if self.sprite:getScaleX() > 0 then
    self.chain.xDir = 0
    self.chain.yDir = -1
    self.chain.xScale = 1

    self.chain.cox    = 26
    self.chain.coy    = -29

    self.chain.spawnX = self.chain.x + 29
    self.chain.spawnY = self.chain.y + 2
    -- ...
  else
    self.chain.xDir   = 0
    self.chain.yDir   = -1
    self.chain.xScale = -1

    self.chain.cox    = -11 -- ehehehehehe
    self.chain.coy    = -29

    self.chain.spawnX = self.chain.x - 7
    self.chain.spawnY = self.chain.y + 2
    -- ...
  end

  self.chain.reverse    = false
  self.chain.len        = 1
  self.chain.animTip    = "drill-chain-tip-vertical-spinning"
  self.chain.animMid    = "drill-chain-middle-vertical2"
  self.chain.horizontal = false

  self.sprite:change ( 3, self.chain.animTip, 1, true )

  -- sparks
  local mx, my = self.chain.x, self.chain.y
  my = my - 5
  if self.sprite:getScaleX() > 0 then
    mx = mx + self.chain.collider.rect.w + self.chain.cox - 6
  else 
    mx = mx + self.chain.cox + 4
  end
  Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )

  -- check if any blocks
  local items, len = Physics:queryRect ( 
    self.chain.x + self.chain.cox,
    self.chain.y + self.chain.coy,
    self.chain.collider.rect.w,
    self.chain.collider.rect.h,
    self.filters.drillSpawn
  )
  if len > 0 then
    return true
  end

  self.chain.inserted = true
  -- insert actual collider
  Physics:insertObject ( self.chain.collider, self.chain.x + self.chain.cox, self.chain.y + self.chain.coy )
  return false
end

function _DESPERATION_ACTIVATION:moveChain ( )

  if not self.stateVars.hitWall then
    self.stateVars.chainSfxTime = self.stateVars.chainSfxTime + 1
    if self.stateVars.chainSfxTime > 8 then
      if not Audio:isSoundPlaying ( SFX.gameplay_crash_drill_chain ) then
        Audio:playSound ( SFX.gameplay_crash_drill_chain )
      end
    end
  end

  if self.chain.len > 50  then
    return true
  end

  local tx, ty                      = (self.chain.x + self.chain.xSpeed * self.chain.xDir) + self.chain.cox, (self.chain.y + self.chain.ySpeed * self.chain.yDir) + self.chain.coy
  local actualX, actualY, cols, len = Physics:simpleMoveObject ( self.chain.collider, tx, ty, self.filters.bullet )
  
  self.chain.x   = actualX - self.chain.cox
  self.chain.y   = actualY - self.chain.coy
  self.chain.len = math.floor(math.abs(self.chain.y-self.chain.spawnY) / 8) + 3

  if self.chain.reverse and self.chain.len < 6 then
    local mx, my = self.chain.x, self.chain.y
    my = my + 7
    if self.sprite:getScaleX() > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox - 6
    else
      mx = mx + self.chain.cox + 31
    end
    Particles:addSpecial ( "small_white_sparks", mx, my, self.activeLayer()-1, false )

    return false, true
  end

  if not self.stateVars.bonked and not self.chain.reverse then
    for i = 1, len do
      local other = cols[i].other
      if other.isBreakable and other.parent and other.parent.instantBreak then
        other.parent:instantBreak ( )
      end
    end
  end

  if actualX ~= tx or actualY ~= ty then
    local mx, my = self.chain.x, self.chain.y
    my = my - 16
    if self.sprite:getScaleX() > 0 then
      mx = mx + self.chain.collider.rect.w + self.chain.cox - 9
    else
      mx = mx + self.chain.cox + 7
    end
    Particles:addSpecial ( "small_white_sparks", mx, my, self.layers.sprite()+1, false )
    Camera:startShake    ( 0, 2, 20, 0.25 )
    self.chain.shakeX     = 2
    self.chain.shakeYDir  = math.rsign()

    Audio:playSound ( SFX.gameplay_crash_drill_shoot )

    mx, my = self:getMiddlePoint()
    self:spawnFallingBlocks ( mx, my )
    return true
  end
end

function _DESPERATION_ACTIVATION:moveAlongChain ( )
  if not self.stateVars.blockTimer then
    self.stateVars.blockTimer = 0
  end
  self.stateVars.blockTimer = self.stateVars.blockTimer + 1
  if self.stateVars.blockTimer%8 == 0 and self.stateVars.blockTimer < 50 then
    local mx, my = self:getMiddlePoint()
    self:spawnFallingBlocks ( mx, my )
  end

  if not self.stateVars.wait then 
    self.stateVars.wait = 15
    return
  elseif self.stateVars.wait > 0 then
    self.stateVars.wait = self.stateVars.wait - 1
    return
  end


  if not Audio:isSoundPlaying ( SFX.gameplay_crash_drill_chain ) then
  --  Audio:playSound ( SFX.gameplay_crash_drill_chain )
  end

  if not self.stateVars.moving then
    if self.state.isSpawnBoss and not self.changedDirectionOnceWhileSpawn then
      self.changedDirectionOnceWhileSpawn  = true
      Environment.conveyorBeltSurface ( true, true )
    end

    --self.activeLayer  = self.layers.sprite
    --self.sprite:change ( 1, "drill-shoot-pull", 2 )
    --self.sprite:change ( 2, nil )
    self:setAfterImagesEnabled          ( true )
    self.velocity.vertical.update       = false
    self.isPreventingPushes             = true
    self.isIgnoringTiles                = true
    self.velocity.vertical.current      = -0.25
    self.velocity.vertical.update       = false
    self.velocity.horizontal.current    = 0
    self.velocity.horizontal.direction  = 0
    self.stateVars.moving               = true

    if Physics:hasObject ( self.chain.collider ) then
      Physics:removeObject ( self.chain.collider )
      self.chain.inserted = false
    end
  end

  if self.velocity.vertical.current < -0.25 then
    self.sprite:change ( 2, "drill-shoot-up-pull" )
    self.sprite:change ( 1, nil )
  end

  self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.25,-9)

  self.chain.spawnY = self.chain.spawnY + self.velocity.vertical.current
  self.chain.y      = self.chain.y + self.velocity.vertical.current
  self.chain.len    = math.floor(math.abs(self.chain.y-self.chain.spawnY) / 8) + 3

  local mx, my      = self:getMiddlePoint()
  local cy          = Camera:getY()

  if my < cy-128 then
    self.stateVars.removedColliders = true
    self:removeCollidersFromPhysicalWorld ( )
    self:setAfterImagesEnabled            ( false )
    return true
  end
  --[[
  if self.chain.inserted then
    local x,y,w   = Physics:getRect ( self.chain.collider)
    local mx  = self:getMiddlePoint()
    if (x < mx + 16 and self.velocity.horizontal.direction > 0) or (x + w > mx - 16 and self.velocity.horizontal.direction < 0) then
      self:handleXBlock ()
    end
  end]]
end

--[[
_CRASH.static.DESPERATION_Y_OFFSETS = {
  16,
  12,
  8,
  4,
  0,
  4,
  8,
  12,
  16
}]]

_CRASH.static.DESPERATION_SKIP_BEATS = {
  {1, 5, 9},
  {2, 6, 3},
  {9, 5, 1},
  {6, 2, 5},
  {4, 8, 5},
  {8, 4, 7},
}


function _DESPERATION_ACTIVATION:spawnHugeBlocks ()
  self.timer = self.timer + 1
  if not self.stateVars.initialBlockWait then
    self.timer = self.timer + 1
    if self.timer > 2 then
      self.stateVars.initialBlockWait = true
      self.timer = 0
    else
      return false
    end
  end

  if self.timer > 9 and (self.timer)%8 == 0 and self.timer < 66 then
    Audio:playSound ( SFX.gameplay_crash_earthquake_heavy, 0.6 )
  end

  if self.timer < 20 then
    Camera:startShake ( 0, 2, 20, 0.25 )
    return false
  end

  if self.timer >= 21 then
    if self.timer < 50 then
      Camera:startShake ( 0, 2, 20, 0.25 )
    end
    local finalTime = 95
    if GAMESTATE.mode == 1 then
      finalTime = 125 -- easy
    elseif GAMEDATA.isHardMode() then
      finalTime = 78 -- hard
    end

    if self.timer >= 100 then
      self.stateVars.blockSpawnCount = self.stateVars.blockSpawnCount + 1
      if self.stateVars.blockSpawnCount == 3 then
        return true
      else
        self.timer = 1
        return false
      end
    end
    return false
  end

  local sx = Camera:getX()
  sx       = sx + 16

  if not self.stateVars._lastDropId then
    self.stateVars._lastDropId = 1

    local len = #self.class.DESPERATION_SKIP_BEATS
    if not self.desperationDropPattern then
      self.desperationPatternId   = RNG:range ( 1, len )
      self.desperationDropPattern = self.class.DESPERATION_SKIP_BEATS[ self.desperationPatternId ]
    else
      self.desperationPatternId = self.desperationPatternId + RNG:range(1,2)
      if self.desperationPatternId > len then
        self.desperationPatternId = self.desperationPatternId - len
      end
      self.desperationDropPattern = self.class.DESPERATION_SKIP_BEATS[ self.desperationPatternId ]
      -- ...
    end

  else
    self.stateVars._lastDropId = self.stateVars._lastDropId + 1
  end

  local skipBeat = self.desperationDropPattern[self.stateVars._lastDropId]

  --[[
  -- old random
  local skipBeat = RNG:range ( 1, 9 )
  if not self.lastDropSkip then
    self.lastDropSkip = skipBeat
  elseif (self.lastDropSkip <= skipBeat+1) or (self.lastDropSkip >= skipBeat-1) then
    skipBeat = skipBeat+RNG:range ( 3,5 )*RNG:rsign()
    if skipBeat > 9 then
      skipBeat = skipBeat - 9
    elseif skipBeat < 1 then
      skipBeat = 1
    end
    self.lastDropSkip = skipBeat
  else
    self.lastDropSkip = skipBeat
  end]]
  local lastSkippedBeat = false
  for i = 1, 9 do

    if i == skipBeat then
      self.stateVars.smallBlockX = sx + 56
      sx                         = sx + 112
    else
      if (i-1 == skipBeat or i+1 == skipBeat) and GAMESTATE.mode ~= 2 then
        GameObject:spawn ( 
          "shift_downcut_projectile",
          sx,
          self.ogSpawnY - 244,--self.class.DESPERATION_Y_OFFSETS[i],
          1,
          true,
          2,
          1,--(self.stateVars.blockSpawnCount >= 2) and (((i > skipBeat-1) and (i < skipBeat+2)) and 1 or 1) or 2,
          0--self.class.DESPERATION_Y_OFFSETS[i]
        )
      else
        GameObject:spawn ( 
          "shift_downcut_projectile",
          sx,
          self.ogSpawnY - 244,--self.class.DESPERATION_Y_OFFSETS[i],
          1,
          true,
          2,
          0,--(self.stateVars.blockSpawnCount >= 2) and (((i > skipBeat-1) and (i < skipBeat+2)) and 1 or 1) or 2,
          0--self.class.DESPERATION_Y_OFFSETS[i]
        )
      end
      sx = sx + 32
    end
  end
end

function _DESPERATION_ACTIVATION:setBossDrop ()

  if not self.stateVars.fallingFromCeiling then
    self.stateVars.removedColliders = false
    self:insertCollider ( "collision" )
    self:insertCollider ( "grabbox"   )
    self:insertCollider ( "grabbed"   )
    self:setAfterImagesEnabled        ( false )
    self.isIgnoringTiles               = true
    self.state.isGrounded              = false
    self.stateVars.fallingFromCeiling  = true
    self.timer                         = 0

    local px, py = self:getLocations()
    local cx     = Camera:getX()
    local w      = self.dimensions.w

    if not self.stateVars.smallBlockX then
      px = cx + GAME_WIDTH/2
      py = self.ogSpawnY
    else
      if self.stateVars.smallBlockX < (cx+w+4) then
        self.stateVars.smallBlockX = cx+w+4
      elseif self.stateVars.smallBlockX > (cx+GAME_WIDTH-16-w-4) then
        self.stateVars.smallBlockX = (cx+GAME_WIDTH-16-w-4)
      end
    end

    self.stateVars.smallBlockY = py

    self:setActualPos       ( self.stateVars.smallBlockX, self.ogSpawnY-GAME_HEIGHT/2-64 )
    self:spawnFallingBlocks ( self.stateVars.smallBlockX, py )
    Camera:startShake       ( 0, 3, 20, 0.25 )
    self.sprite:change      ( 1, nil )
    self.sprite:change      ( 2, nil )
    return false
  end

  self.timer = self.timer + 1

  if self.timer > 5 and (self.timer)%8 == 0 and self.timer < 60 then
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
  end

  if self.timer < 60 then
    if GetTime()%10==0 then
      self:spawnFallingBlocks ( self.stateVars.smallBlockX , self.stateVars.smallBlockY )
      Camera:startShake ( 0, 3, 20, 0.25 )
    end
    return false
  elseif self.timer == 60 then
    self:spawnFallingBlocks ( self.stateVars.smallBlockX, self.stateVars.smallBlockY )
    self.velocity.vertical.update = true
    self.isPreventingPushes       = false
    self.sprite:change      ( 1, "hop", 7 )

    --[[
    local px, py = self:getLocations()
    local cx     = Camera:getX()
    local w      = self.dimensions.w

    if not px then
      px = cx + GAME_WIDTH/2
      py = self.ogSpawnY
    else
      if px < (cx+w+4) then
        px = px 
      elseif px > (cx+GAME_WIDTH-16-w-4) then
        px = (cx+GAME_WIDTH-16-w-4)
      end
    end

    self:setActualPos       ( px, self.ogSpawnY-GAME_HEIGHT/2-46 )]]
  end

  if self.isIgnoringTiles then
    local x,y,w,h = self:getPos()
    x,y,w,h       = x + self.dimensions.x,
                    y + self.dimensions.y,
                    self.dimensions.w,
                    self.dimensions.h

    local items, len = Physics:queryRect ( x, y, w, h, self.filters.tileNonObject ) 
    if not len or len <= 0 then
      self.isIgnoringTiles = false
    end
  end

  if not self.state.isGrounded then
    return false
  end

  Environment.conveyorBeltSurface ( true, true )

  Audio:playSound ( SFX.gameplay_crash_impact )
  Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )

  self.sprite:change ( 1, "land" )
  self.nextActionTime = 60
  Camera:startShake ( 0, 3, 20, 0.25 )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _CRASH:addState ( "TECH_RECOVER" )

function _TECH:enteredState (  )
  self.fakeOverkilledTimer      = GAMEDATA.boss.getTechRecoverFrames ( self )
  self.state.isBossInvulnerable = true

  self._lastBurstAttackId  = nil
  self.timer               = 20
  self:disableContactDamage ( 35 )
  local mx, my = self:getMiddlePoint()
  mx = mx - 8
  my = my - 24
  Particles:add ( "circuit_pickup_flash_large", mx, my, 1, 1, 0, 0, self.layers.sprite()+1 )

  Audio:playSound ( SFX.hud_mission_start_shine )

  self.sprite:flip   ( nil, 1 )
  self.sprite:change ( 1, "hop", 5 )

  self.state.isGrounded           = false
  self.velocity.vertical.current  = -20
  self.velocity.vertical.update   = true
  self.stateVars.decrement        = false
  self.stateVars.landed           = false
end

function _TECH:exitedState ( )
  self:endAction             ( false )
  self:setAfterImagesEnabled ( false )
  if self.forceDesperation then
    self.nextActionTime = 1
  end
end

function _TECH:tick ( )
  self:applyPhysics()

  if self.state.isGrounded then
    if not self.stateVars.landed then
      Audio:playSound    ( SFX.gameplay_crash_land   )
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

function _CRASH:manageTeching ( timeInFlinch )
  if (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  return false
end

function _CRASH:manageGrab ()
  self:gotoState ( "FLINCHED" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    return
  end
  if self.health - dmg <= (24) then
    Audio:playSound ( SFX.gameplay_boss_phase_change )
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

function _CRASH:pull ()
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and 1 or -33), -31
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _CRASH:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self.timer             = 0
  self.stateVars.sfxTime = 7
  self.activeLayer = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )
  -- ...
end

function _CRASH:_runAnimation ( )
  if not self.isInState ( self, "PREFIGHT_INTRO" ) then
    self:gotoState ( "PREFIGHT_INTRO" )
    return false
  end

  if GetTempFlag ( "crash-boss-prefight-background-drill" ) == 1 then
    SetTempFlag ( "crash-boss-prefight-background-drill", 2)
    return false
  elseif GetTempFlag ( "crash-boss-prefight-background-drill" ) < 3 then
    return false
  end

  if not self.stateVars.started then
    self.isIgnoringTiles    = true
    self.state.isGrounded   = false
    self.stateVars.started  = true

    self:setActualPos       ( self.ogSpawnX, self.ogSpawnY-GAME_HEIGHT/2-64 )
    self:spawnFallingBlocks ( self.ogSpawnX, self.ogSpawnY )
    Camera:startShake       ( 0, 3, 20, 0.25 )
    self.sprite:change      ( 1, "hop", 7 )
    return false
  end
  self.stateVars.sfxTime = self.stateVars.sfxTime + 1
  if self.stateVars.sfxTime > 5 and self.stateVars.sfxTime < 80 and self.stateVars.sfxTime % 10 == 0 then
  --if self.stateVars.sfxTime < 80 then
    --if not Audio:isSoundPlaying ( SFX.gameplay_crash_earthquake ) then
      Audio:playSound ( SFX.gameplay_crash_earthquake, 0.5 )
    --end
  end

  self.timer = self.timer + 1
  if self.timer < 60 then
    if GetTime()%10==0 then
      self:spawnFallingBlocks ( self.ogSpawnX, self.ogSpawnY )
      Camera:startShake ( 0, 3, 20, 0.25 )
    end
    return false
  elseif self.timer == 60 then
    self:spawnFallingBlocks ( self.ogSpawnX, self.ogSpawnY )
  end

  self:applyPhysics()

  if self.isIgnoringTiles then
    local x,y,w,h = self:getPos()
    x,y,w,h       = x + self.dimensions.x,
                    y + self.dimensions.y,
                    self.dimensions.w,
                    self.dimensions.h

    local items, len = Physics:queryRect ( x, y, w, h, self.filters.tile ) 
    if not len or len <= 0 then
      self.isIgnoringTiles = false
    end
  end

  if not self.state.isGrounded then
    return false
  end

  if not self.state.landed then
    self.state.landed = true
    self.sprite:change ( 1, "land" )
    self.nextActionTime = 30
    Camera:startShake ( 0, 3, 20, 0.25 )
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.3 )

    GameObject:spawn ( 
      "falling_block", 
      self:getX()+5,
      self:getY()-144,
      nil,
      nil,
      true,
      true
    )

    Audio:playSound ( SFX.gameplay_crash_impact )
    Audio:playSound ( SFX.gameplay_crash_earthquake, 0.6 )
  end

  if not self.stateVars.hurt then
    if self.timer < 800 then -- this timer is a failsafe
      return false
    else
      self.sprite:change ( 1, "intro-land" )
    end
  end

  if self.sprite:isPlaying() then
    return false
  end

  self:gotoState    ( "CUTSCENE" )
  return true
end

function _PREFIGHT:takeDamage ()
  self.stateVars.hurt = true
  self.sprite:change ( 1, "intro-land" )
end

function _CRASH:_setSpawnPosition ()
  self:setActualPos       ( self.ogSpawnX, self.ogSpawnY )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §§S HOP -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _S_HOP = _CRASH:addState ( "S_HOP" )

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

  self.stateVars.angryDelay       = 40
  self.timer                      = 60
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

function _CRASH:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 then return end
  local x, y = self:getPos            ( )
  local l    = self.hazeParticleLayer ( )
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

  Particles:addFromCategory ( "warp_particle_crash", x, y,   1,  1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRASH:drawSpecialCollisions ( )
  if self.chain.active then
    if Physics:hasObject ( self.chain.collider ) then
      local x,y,w,h = Physics:getRect ( self.chain.collider )
      GFX:drawRect ( Layer:get("DEBUG", "HITBOX")(), x, y, w, h, Colors.rgb_red, false, 0.5 )
    end
  end
end

function _CRASH:customEnemyDraw ( x, y, scaleX )
  if self.chain.active then
    if self.chain.horizontal then
      for i = -2, self.chain.len do
        local tx = self.chain.spawnX + self.chain.xDir * 8 *i
        if tx > self.chain.x + 40 and scaleX > 0 then
          break
        elseif tx < self.chain.x - 24 and scaleX < 0 then
          break
        end
        if scaleX > 0 then
          tx = tx + 2
        end
        if (tx > x + 4 and scaleX > 0) or (tx < x + 10 and scaleX < 0 ) then
          self.sprite:drawFrameInstant ( self.chain.animMid, 1, tx, self.chain.spawnY )
        end
      end
    else
      for i = 0, self.chain.len do
        if i > 1 then
          local ty = self.chain.spawnY + self.chain.yDir * 8 *i
          self.sprite:drawFrameInstant ( self.chain.animMid, 1, self.chain.spawnX, ty )
        end
      end
    end
  end

  if not self.isDestructed  then 
    self.sprite:drawInstant ( 2, x, y )
    if self.chain.active then
      self.sprite:drawInstant   ( 3, self.chain.x, self.chain.y + self.chain.shakeY * self.chain.shakeYDir )
    end
  end
  self.sprite:drawInstant ( 1, x, y )
end

return _CRASH