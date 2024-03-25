-- BLADE, THE COOLER CIRCUIT, ICE AREA BOSS
local _BLADE    = BaseObject:subclass ( "BLADE_COOLER_CIRCUIT" ):INCLUDE_COMMONS ( )
FSM:addState  ( _BLADE, "CUTSCENE"             )
FSM:addState  ( _BLADE, "BOSS_CIRCUIT_PICKUP"  )
Mixins:attach ( _BLADE, "gravityFreeze"        )
Mixins:attach ( _BLADE, "bossTimer"            )

_BLADE.static.IS_PERSISTENT     = true
_BLADE.static.SCRIPT            = "dialogue/boss/cutscene_bladeConfrontation" 
_BLADE.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-blade"

_BLADE.static.EDITOR_DATA = {
  width   = 2,
  height  = 2,
  ox      = -19,
  oy      = -17,
  mx      = 28,
  order   = 9990,
  category = "bosses",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isUnique      = true,
    isTargetable  = true,
  }
}

_BLADE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "blade"         )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
  CutsceneManager.preload   ( _BLADE.SCRIPT )
end

_BLADE.static.PALETTE             = Colors.Sprites.blade
_BLADE.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue,
  Colors.cooler_purple, 
  Colors.cooler_purple, 
  Colors.cooler_blue, 
  Colors.cooler_blue, 
  Colors.cooler_blue
)

_BLADE.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_BLADE.static.DIMENSIONS = {
  x            =   7,
  y            =   6,
  w            =  20,
  h            =  26,
  -- these basically oughto match or be smaller than player
  grabX        =  10,
  grabY        =   4,
  grabW        =  14,
  grabH        =  28,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_BLADE.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_BLADE.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
  warningTile       = Filters:get ( "queryWarningTile"            ),
  signalTile        = Filters:get ( "querySignalTile"             ),

  pushable          = Filters:get ( "query_movingPlatform_pushable_filter" ),
}

_BLADE.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  behind    = Layer:get ( "BEHIND-TILES", "SPRITES"   ),
  behind2   = Layer:get ( "BEHIND-TILES", "SPRITES-2" ),
}

_BLADE.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_BLADE.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE,
  FREEZE  = GAMEDATA.damageTypes.FREEZE_HARDER,
}

_BLADE.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_BLADE.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--


function _BLADE:finalize ( parameters )
  RegisterActor ( ACTOR.BLADE, self )

  self.originalSpawnX, self.originalSpawnY = self:getPos()
  
  self.invulBuildup = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )
  self.velocity.vertical.gravity.maximum = 6.5

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "blade", 1 )
  self.sprite:addInstance  ( 2 )
  self.sprite:addInstance  ( 3 )
  self.sprite:addInstance  ( 4 )
  self.sprite:addInstance  ( 5 )
  self.sprite:change       ( 2, "idle", 1, false )
  self.sprite:change       ( 1, "idle-spinner", 1, false )

  self.hopsInRow              = 0
  self.actionsWithoutWind     = 0

  self.activeAfterImagesLayer = Layer:get ( "TILES-MOVING-PLATFORMS-1" )

  self.isFlinchable           = false
  self.isImmuneToLethalTiles  = true

  self.floatTimer             = 0
  
  self.actionsWithoutRest     = 0
  self.nextActionTime         = 10
  self.desperationActivated   = false

  self.lastSfx = -1

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.sensors = {
    WARNING_SENSOR = 
      Sensor
        :new                ( self, self.filters.warningTile,   2,  -10, -24, 10 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    ABOVE_PIT = 
      Sensor
        :new                ( self, self.filters.warningTile,   2,  -120, -24, 130 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    -- this sensor is for checking pit status while not teching or being launched, ie. neutral
    ABOVE_PIT_EXTENDED = 
      Sensor
        :new                ( self, self.filters.warningTile,   2,  -60, -24, 90 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    WALL_SENSOR =
      Sensor
        :new                ( self, self.filters.tile,  20,   -25,  -60,  16 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    --[[
    FLOOR_IMMEDIATELY_BELOW_SENSOR =
      Sensor
        :new                ( self, self.filters.tile, 2,  -10, -24, 25 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),
    FLOOR_FURTHER_BELOW_SENSOR =
      Sensor
        :new                ( self, self.filters.tile, 2,  -10, -24, 90 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),
    TURN_AROUND_SENSOR         =
      Sensor
        :new                ( self, self.filters.signalTile, -20,  -28, 20, 28 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),]]
    TORNADO =
      Sensor
        :new                ( self, self.filters.player, -42,  -200, 64, 260 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    BIG_TORNADO =
      Sensor
        :new                ( self, self.filters.player, -58,  -200, 96, 260 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :disableDraw        ( true ),
    GROUND_SLAM =
      Sensor
        :new                ( self, self.filters.player, -27,  -20, 34, 20 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true ),
  }

  self:setAfterImageStack ( 2, 2 )

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -4, -5, 40, 44, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil
  if parameters and parameters.bossRush then
    if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
      local bx, by = self:getPos()
      self:setActualPos  ( bx, by-28.5 )

      self.sprite:flip   ( nil, 1 )
      self.sprite:change ( 1, "flying-spinner" )
      self.sprite:change ( 2, "flying-idle"    )

      self.overrideSpinSfx            = false
      self.hasStartedToFloat          = true
      self.velocity.vertical.current  = 0
    end
    self.state.isBossRushSpawn  = true
    self.state.isBoss           = true
    self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
  elseif parameters and parameters.isTarget then
    self.state.isBoss   = true
    self.listener       = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
  else
    self.state.isBoss   = false 
    self:gotoState ( nil )
  end
end

_BLADE.static.EDGES = { left = 0, right = 0, middle = 0}

function _BLADE:activate ( )  
  if not self.state.isSpawnBoss then
    GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )
  end
  
  --print(self:getX()-self.originalSpawnX, self:getY()-self.originalSpawnY)
  -- determine edges
  local cx, cy    = Camera:getPos()
  local cols, len = Physics:queryRect ( cx-200, cy-100, GAME_WIDTH+400, GAME_HEIGHT+200, self.filters.signalTile )

  if len == 2 then
    local left,right = math.smaller2 ( cols[1].rect.x, cols[2].rect.x )
    self.class.EDGES.left  = left
    self.class.EDGES.right = right+16
  else
    print("[BLADE] Did not detect edges properly. Needs to be fixed!")
    self.class.EDGES.left  = cx
    self.class.EDGES.right = cx+400
  end
  self.class.EDGES.middle = self.class.EDGES.right - 12*16 - 28

  self.activeLayer            = self.layers.sprite
  self.activeAfterImagesLayer = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
  self.health                 = 48
  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "blade", self.health )
  self.activated              = true
  self.grenadeSpam = false
  self.missileSpam = false
  self.fastMissiles = false
end

function _BLADE:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end

  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end

  UnregisterActor ( ACTOR.BLADE, self )
end

function _BLADE:isDrawingWithPalette ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BLADE:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _BLADE:prenotifyBossBattleOver ( )
  GlobalObserver:none ( "TOGGLE_FORCED_FLOATING_PLATFORM_FLOATING"  )
end

function _BLADE:notifyBossBattleOver ( )
  SetBossDefeatedFlag ( self.class.name )
  GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
end

function _BLADE:getDeathMiddlePoint ( )
  local mx, my = self:getMiddlePoint()
  if self.sprite:isFacingRight() then
    mx = mx + 1
  else
    mx = mx - 4
  end
  my = my - 1
  return mx, my
end

function _BLADE:handleDeathKneeling ( )
  self.sprite:change ( 1, "death-kneel" )
  self.sprite:change ( 2, nil ) 
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Update §Tick -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
function _BLADE:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end
  if self.grenadeSpam == true then
    self.grenadeSpamTimer = self.grenadeSpamTimer - 1
    if self.grenadeSpamTimer == 0 then
      Audio:playSound ( SFX.gameplay_enemy_throw )
      local mx, my = self:getMiddlePoint()
      GameObject:spawn ( 
        "spicy_grenade",
        mx-8-4, 
        my-10,
        1,
        -2,
        -2.0
      )
      GameObject:spawn ( 
        "spicy_grenade",
        mx-8+4, 
        my-10,
        -1,
        -2,
        -2.0
      )
      self.grenadeSpamTimer = 30
    end
  end
  if self.missileSpam == true then
    self.missileSpamTimer = self.missileSpamTimer - 1
    if self.fastMissiles == true then
      self.missileSpamTimer = self.missileSpamTimer - 1
    end
    if self.missileSpamTimer < 1 then
      Audio:playSound ( SFX.gameplay_missile_shot )
      local mx, my = self:getMiddlePoint()
      GameObject:spawn ( 
        "spicy_missile",
        mx-14,
        my-15,
        nil,
        0,
        self,
        true
      )
      self.missileSpamTimer = 50
    end
  end

  local nilling = self:isInState ( nil )
  --[[if self.hitFlash.current > 0 and nilling then
    if self.hopsInRow < 2 then
      self.lastAction = 3 
      self.hopsInRow  = self.hopsInRow + 1
      self:gotoState ( x, nil, nil, nil, nil, nil, true )
    end
  else]]if nilling and self:checkIsPlayerFrozen ( ) then
    self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, 2 )
  else
    if self.activated and self:canPickAction() then
      
      --self.nextActionTime = self.nextActionTime - (self.state.isSpawnBoss and 1.10 or 1)
      --if self.nextActionTime <= 0 then
      if self:updateBossTimer ( 0.10 ) then
        self:pickAction()
      end
    end
  end

  -- §sfx
  local t = GetLevelTime() 
  if self.health > 0 and 
    not self.overrideSpinSfx
    and self.sprite:getAnimation ( 1 ) == "flying-spinner" 
    and self.sprite:isPlaying ( 1 ) 
    and self.lastSfx+7 < t then
    self.lastSfx = t
    if self.fasterSpinSfx then
      self.fasterSpinSfx = false
      Audio:playSound ( SFX.gameplay_blade_propeller, 0.15 )
    else
      Audio:playSound ( SFX.gameplay_blade_propeller_slow, 0.15 )
    end
  end

  -- vertical update
  self:manageVerticalUpdate ()

  -- sprite float offset
  self.floatTimer = self.floatTimer + 1

  -- make unhittable
  self:updateBossInvulnerability ( )

  self:updateLocations ( )

  if not (self.isChainedByHookshot) then
    self:tick ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  --self:drawSensors(true)

  self:updateContactDamageStatus  ( )
  self:updateShake                ( )
  self:handleAfterImages          ( )
  self.sprite:update              ( dt )
end

function _BLADE:tick ()

  if math.abs(self.velocity.vertical.current) > 0 then
    self.velocity.vertical.current = self.velocity.vertical.current - 0.25 * math.sign(self.velocity.vertical.current)
  end

  self:applyPhysics()
end

function _BLADE:canPickAction ()
  return self:isInState ( nil )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action §actions -----------------------]]--
--[[----------------------------------------------------------------------------]]--

_BLADE.static.ACTIONS = {
  "DESPERATION_ACTIVATION",   -- 1
  "FLOAT",                    -- 2 -- unused, removed, deleted, didn't feel good
  "FLOAT_ARC_HOP",            -- 3
  "ICICLE_ARC",               -- 4
  "HORIZONTAL_ICICLES",       -- 5
  "WIND_PUSH",                -- 6
  "DASH_THROUGH",             -- 7
  "FREEZE_PUNISH",            -- 8
  "VERTICAL_ICICLES",         -- 9 -- why does he have so many actions, did he steal them from Bit?
}

function _BLADE:pickAction ( recursion, px, py, mx, my )

  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 10
      return
    end
  end

  local chance          = RNG:n()
  local action          = 0
  local extra           = 0

  if not self.actionList then
    self.actionList  = { 4, 4, 5, 5, 7, 9 }
    self.loopActions = {}
    for i = 1, 3 do
      self.loopActions[i] = self.actionList[i]
    end
  end

  if (self.forceDesperation) then
    -- Desperation phase
    self.forceDesperation         = false
    self.actionsSinceDesperation  = 0
    action                        = 1
  end

  if action <= 0 then
    if self:checkIsPlayerFrozen ( ) then
      action = 8
      extra  = 12
    else
      if (self.lastAction == 4 or (self.lastAction ~= 3 and self.hopsInRow == 0 and chance > 0.6)) then
        self.hopsInRow = self.hopsInRow  +1
        action         = 3
      else
        if self.actionsWithoutWind > (3 + RNG:range(1,2)-1) then
          action                  = 6
          self.actionsWithoutWind = 0
        else
          chance = RNG:range(1,#self.loopActions)           -- yes I'm discarding the previous result, how could you tell?
          action = self.loopActions[chance] -- :)

          table.remove(self.loopActions, chance)
          if #self.loopActions <= 0 then
            for i = 1, #self.actionList do
              self.loopActions[i] = self.actionList[i]
            end
          end
        end
      end
    end
  end

  if not action or action <= 0 then return end
  if action ~= 3 then
    self.hopsInRow        = 0
    self.lastAttackAction = action
  end

  if action > 3 and action ~= 6 and action ~= 8 then
    self.actionsWithoutWind = self.actionsWithoutWind  + 1
  end

  --if not recursion and self.lastAttackAction == action and action > 1 then
  --  self:pickAction ( true, px, py, mx, my )
  --  return
  --end

  if self.desperationActivated and action ~= 1 and action ~= 3 then
    if not self.actionsSinceDesperation then
      self.actionsSinceDesperation = 0
    end
    self.actionsSinceDesperation = self.actionsSinceDesperation + 1
    if self.actionsSinceDesperation > 5 then
      self.forceDesperation = RNG:n() < (0.15 + (self.actionsSinceDesperation-5)*0.15)
    end
  end

  --action = 7
  self.lastAction = action
  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end

end

function _BLADE:endAction ( finishedNormally, restDesperation, restNormal )
  if GAMESTATE.mode == 0 then
    restDesperation = restDesperation and (restDesperation + 12) or 0
    restNormal      = restNormal      and (restNormal      + 16) or 0
  elseif GAMESTATE.mode == 1 then
    restDesperation = restDesperation and (restDesperation + 12) or 0
    restNormal      = restNormal      and (restNormal      + 16) or 0
  end

  if finishedNormally then
    if not self.actionsWithoutRest then
      self.actionsWithoutRest = 0
    end
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest > 3 then
      self.nextActionTime = 1
    else
      self.nextActionTime = 1
    end

    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    if self.desperationActivated then
      self.nextActionTime = 1
    else
      self.nextActionTime = 1
    end
  end

  if GAMEDATA.isHardMode() then
    if self.desperationActivated then
      self.nextActionTime = 1
    else
      self.nextActionTime = 1
    end
  end
end

function _BLADE:getLocations ( )
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _BLADE:updateLocations()
  local x, y = GlobalObserver:single ("GET_PLAYER_MIDDLE_POINT" )
  if x then
    self.lastPlayerX, self.lastPlayerY = x, y
  end
  self.playerIsKnownToBeAlive                  = GlobalObserver:single ("IS_PLAYER_ALIVE")
  self.lastKnownPlayerX, self.lastKnownPlayerY = self.lastPlayerX, self.lastPlayerY
end

function _BLADE:checkIsPlayerFrozen ( )
  if self.playerIsKnownToBeAlive then
    local f = GlobalObserver:single ( "IS_PLAYER_FROZEN" )
    if f then
      local px = self:getLocations ( )
      if px > (self.class.EDGES.left + 16) and px < (self.class.EDGES.right - 24) then
        return true
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _BLADE:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

function _IDLE:canPickAction ()
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §FLOAT ARC §HOP -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _FLOAT_HOP = _BLADE:addState ( "FLOAT_ARC_HOP" )

function _FLOAT_HOP:enteredState ( _, _, _, _, _, instant, instantInstant )
  self.timer = self.desperationActivated and -5 or -10
  if instant then
    self.timer = 1
  end
  if instantInstant then
    self.timer = 1
  end
end

function _FLOAT_HOP:exitedState ( )
  self:setAfterImagesEnabled(false)
  self.velocity.horizontal.current = 0
  self.velocity.vertical.current   = 0
  self:endAction ( false, 8, 10 )
end

function _FLOAT_HOP:forceDirection ( dir )
  self.stateVars.forceDir = dir
end

function _FLOAT_HOP:tick ( )
  self.timer = self.timer + 1
  if self.timer >= 2 and not self.stateVars.moved then
    if not self.stateVars.moveStarted then
      self.stateVars.moveStarted  = true

      local px, py, mx, my = self:getLocations()

      self.stateVars.curX,
      self.stateVars.curY    = mx, my
      self.stateVars.bounce  = RNG:range (3,5) *-1
      self.stateVars.upward  = true
      local goalX
      if not self.stateVars.forceDir then
        goalX            = math.multiple ( RNG:range ( Camera:getX()+8, Camera:getX()+GAME_WIDTH-8 ), 16 )
        local br = 0
        while (math.abs ( self.stateVars.curX - goalX ) < 48) do
          goalX = math.multiple ( RNG:range ( Camera:getX()+8, Camera:getX()+GAME_WIDTH-8 ), 16 )
          br = br + 1
          if br == 6 then
            break
          end
        end
        if goalX < self.class.EDGES.left then
          goalX = self.class.EDGES.left + (RNG:range(1,3)-1) * 12
        elseif goalX > self.class.EDGES.right then
          goalX = self.class.EDGES.right - (RNG:range(1,4)-1) * 12
        end
        if math.abs(px-goalX) < 28 then
          goalX = goalX + RNG:rsign() * 32
        end
      else
        goalX = mx + (RNG:range(2,5) * 16)*self.stateVars.forceDir
      end

      if goalX > (px-16) and goalX < (px+16) then
        if math.abs((goalX+20) - mx) < math.abs((goalX-20) - mx) then
          goalX = goalX+24
        else
          goalX = goalX-24
        end
      end

      local goal                  = Camera:getY() + 152 + (RNG:range(2,6)-1) * 8
      local time                  = self.desperationActivation and 30 or 45
      time                        = time + math.floor(math.abs ( self.stateVars.curX - goalX ) / 35)
      self:disableContactDamage   ( 14 ) 
      self.stateVars.xtween       = Tween.new ( time, self.stateVars, { curX   = goalX                  }, "inOutQuad" )
      self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal                   }, "inOutQuad" )
      self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = -self.stateVars.bounce }, "inOutQuad" )

      self:setAfterImagesEnabled(true)

      local f = self.sprite:getFrame(2)
      self.sprite:change ( 2, "vertical-icicles", f, true )
      --if goalX < self.stateVars.curX then
      --  if self.sprite:getScaleX() == -1 then
      --    self.sprite:change ( 2, "flying-forward" )
      --  else
     --     self.sprite:change ( 2, "flying-backward" )
     --   end
     -- else
      --  if self.sprite:getScaleX() == 1 then
      --    self.sprite:change ( 2, "flying-forward" )
      --  else
      --    self.sprite:change ( 2, "flying-backward" )
      --  end
      --end
      self.sprite:flip ( self.stateVars.curX < goalX and 1 or -1 )

    else

      if GetLevelTime()%3==0 then
        local mx, my = self:getMiddlePoint()
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx-4+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, 0, -0.5-math.random()*0.75, 
          self.layers.sprite()-1, 
          false, nil, true 
        )
      end
    

      --------------
      -- x        --
      --------------
      local cur = self.stateVars.curX 
      self.stateVars.xtween:update(1)
      local diff = cur - self.stateVars.curX 
      self.velocity.horizontal.current   = math.abs   ( diff )
      self.velocity.horizontal.direction = -math.sign ( diff )

      --------------
      -- y        --
      --------------
      cur  = self.stateVars.curY
      self.stateVars.ytween:update ( 1 )
      if self.stateVars.upward then
        if self.stateVars.btween:update ( 1 ) then

          self.sprite:change ( 2, "vertical-icicle-v3", 2, true )
          self.stateVars.upward   = false
          self.stateVars.iceDelay = 2
          --self:spawnIce ()
        end
      else
        self.stateVars.btween:update ( -1 )
      end

      diff = cur - self.stateVars.curY 
      self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

      if self.stateVars.ytween:getTime() > 0.9 then
        local px, _, mx = self:getLocations()
        self.sprite:flip ( px < mx and -1 or 1 ) 
        --self.sprite:change ( 2, "flying-idle" )
      end

      if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
        self.timer = 0
        self.stateVars.moved = true
        self.velocity.horizontal.current = 0
        self.velocity.vertical.current   = 1.25
      end
    end
  elseif self.timer > (self.desperationActivated and 10 or 18) and self.stateVars.spawnedIce then
    if not self.stateVars.allowedAnimationEnd then
      self.stateVars.allowedAnimationEnd = true
      --self.sprite:change ( 2, "vertical-icicles-end", 4, true )
    end
    self:endAction ( true )
  end

  if self.stateVars.iceDelay and self.stateVars.iceDelay > 0 then
    self.stateVars.iceDelay = self.stateVars.iceDelay - 1
    if self.stateVars.iceDelay <= 0 then
      self.stateVars.spawnedIce = true
      self:spawnIce ()
    end
  end

  if self.stateVars.moved then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.25 - 0.125, -0.5)
  end

  self:applyPhysics ()

  if self:checkIsPlayerFrozen ( ) then
    self.stateVars.punish = true
    self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, -1 )
    return 
  end
end

function _FLOAT_HOP:spawnIce ()
  --self.sprite:change ( 2, "vertical-icicle-v3", 1, true )
  local px, py, mx, my = self:getLocations()

  local sx = self.sprite:getScaleX()
  local l = Layer:get( "ENEMIES", "PROJECTILES")() + 14
  for i = 1, 5 do
    if i ~= 3 then 
      Particles:addFromCategory ( 
        "directionless_dust", 
        mx + (sx > 0 and -20 or -7), 
        my-49, 
        math.rsign(), 
        1, 
        (-0.75+i*0.25), 
        0.25+(i%2==0 and 0.25 or 0),
        l,
        false,
        nil,
        true,
        1.0
      )
    end
  end

  Audio:playSound ( SFX.gameplay_mortar_shot )


  if GAMEDATA.isHardMode() then
    if self.desperationActivated then
      GameObject:spawn ( 
        "ice_ball", 
        mx + (sx > 0 and -14 or -6), 
        my-35, 
        self.sprite:getScaleX(), 
        self,
        1.75,
        -4.5
      )
      GameObject:spawn ( 
        "ice_ball", 
        mx + (sx > 0 and -14 or -6), 
        my-35, 
        self.sprite:getScaleX(), 
        self,
        -1.75,
        -4.5
      )
    end

    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      2.25,
      -4
    )
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      -2.25,
      -4
    )
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      1.25,
      -3.5
    )
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      -1.25,
      -3.5
    )
  else
    if self.desperationActivated then
      GameObject:spawn ( 
        "ice_ball", 
        mx + (sx > 0 and -14 or -6), 
        my-35, 
        self.sprite:getScaleX(), 
        self,
        2.25,
        -4
      )
      GameObject:spawn ( 
        "ice_ball", 
        mx + (sx > 0 and -14 or -6), 
        my-35, 
        self.sprite:getScaleX(), 
        self,
        -2.25,
        -4
      )
    end
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      1.5,
      -3.5
    )
    GameObject:spawn ( 
      "ice_ball", 
      mx + (sx > 0 and -14 or -6), 
      my-35, 
      self.sprite:getScaleX(), 
      self,
      -1.5,
      -3.5
    )
  end
end

_FLOAT_HOP.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _BLADE:addState ( "DESPERATION_ACTIVATION" )

function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )
  self.sprite:change ( 2, "angry" )
  self.positionRoundingDisabled = true
  self.grenadeSpamTimer = 30
  self.grenadeSpam = true
  self.missileSpamTimer = 50
  self.missileSpam = true

  self.stateVars.shots = 0
  self.timer           = 0
  self.foolProofTimer  = 60
  self.velocity.vertical.update = false
  if self.desperationActivated then
    self.stateVars.angry = false
  else
    self.sprite:flip( px < mx and -1 or 1 )
    self.stateVars.angry              = true
    self.sprite:change ( 2, "angry", 8, true )
  end

  self:setAfterImagesEnabled(false)
end

function _DESPERATION_ACTIVATION:exitedState ( )
  if self.stateVars.startedSuperFlash then
    GlobalObserver:none ( "SUPER_FLASH_END" )
  end

  self.tornado                      = false
  self.positionRoundingDisabled     = false
  self.velocity.horizontal.current  = 0

  self.fakeOverkilledTimer = nil
  self.state.isHittable    = true
  self:endAction(false, 42, 42)

  self.sprite:change ( 3, nil )
  self.sprite:change ( 4, nil )

  self:permanentlyDisableContactDamage ( false )

  self.state.isBossInvulnerable = false
end

function _DESPERATION_ACTIVATION:tick ( )
  -----------------------
  -- reduce move speed --
  -----------------------
  if not self.stateVars.finishedFlash then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    if self.velocity.vertical.current < 0 then
      self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.25, 0 )
    elseif self.velocity.vertical.current > 0 then
      self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.25, 0 )
    end
  end

  ---------------
  -- angry     --
  ---------------
  if self.stateVars.angry then
    self.timer = self.timer + 1
    if self.timer > 60 then
      self.stateVars.angry = false
      self.timer = 0
    end

  --------------
  -- flash    --
  --------------
  elseif not self.stateVars.superFlash then
    self.timer = self.timer + 1
    if not self.stateVars.activated then
      self.stateVars.activated           = true
      self.timer                         = 0
      local dir                          = self.sprite:getScaleX  ( )
      local mx, my                       = self:getMiddlePoint    ( )
      Particles:addSpecial ( "super_flash", mx + (dir > 0 and 0 or 2), my-15, self.layers.sprite()-2, self.layers.sprite()-1, false, mx, my )
      if self.playerIsKnownToBeAlive then
        GlobalObserver:none ( "SUPER_FLASH_START", self ) 
        self:permanentlyDisableContactDamage ( false )
        self.stateVars.startedSuperFlash = true
      end
      self.sprite:change ( 2, "desperation-activation", 2, true )
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_blade", 3 )
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
      self.stateVars.superFlash         = true
      self.timer                        = 0
    end
  --------------
  -- premove  --
  --------------
  elseif not self.stateVars.premoveTimer then
    self.timer = self.timer + 1
    if self.timer > 16 then
      self.stateVars.premoveTimer = true
      self.timer                  = 0
    end
  ----------------------
  -- move to position --
  ----------------------

  elseif not self.stateVars.movedToPosition then
    if not self.stateVars.moveStarted then
      Audio:playSound ( SFX.gameplay_blade_dive_attack_slow, 0.625 )
      self.stateVars.moveStarted  = true
      self.stateVars.curX,
      self.stateVars.curY         = self:getMiddlePoint    ( )
      self.stateVars.bounce       = -4
      self.stateVars.upward       = true
      local goalX                 = self.class.EDGES.middle --+ ((self.sprite:getScaleX() < 0) and 16 or -16)
      local goal                  = Camera:getY() + 150
      self.stateVars.xtween       = Tween.new ( 45, self.stateVars, { curX   = goalX }, "inOutQuad" )
      self.stateVars.ytween       = Tween.new ( 45, self.stateVars, { curY   = goal  }, "inOutQuad" )
      self.stateVars.btween       = Tween.new ( 45, self.stateVars, { bounce = 4     }, "inOutQuad" )

      self.sprite:flip ( self.stateVars.curX < self.class.EDGES.middle and 1 or -1 )
    else
      if GetLevelTime()%3==0 then
        local mx, my = self:getMiddlePoint()
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx-4+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, 0, -0.5-math.random()*0.75, 
          self.layers.sprite()-1, 
          false, nil, true 
        )
      end
      --------------
      -- x        --
      --------------
      local cur = self.stateVars.curX 
      self.stateVars.xtween:update(1)
      local diff = cur - self.stateVars.curX 
      self.velocity.horizontal.current   = math.abs   ( diff )
      self.velocity.horizontal.direction = -math.sign ( diff )

      --------------
      -- y        --
      --------------
      cur  = self.stateVars.curY
      self.stateVars.ytween:update ( 1 )
      if self.stateVars.upward then
        if self.stateVars.btween:update ( 1 ) then
          self.stateVars.upward = false
        end
      else
        self.stateVars.btween:update ( -1 )
      end
      diff = cur - self.stateVars.curY 
      self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

      if self.stateVars.ytween:getTime() > 0.75 then
        self.sprite:change ( 2, "burst-tornado" )
      end

      if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
        self.stateVars.movedToPosition   = true
        self.velocity.horizontal.current = 0
        self.velocity.vertical.current   = 1.25
        self.timer                       = 0
        self.tornado                     = false
      end
    end
  elseif not self.stateVars.finishedAttacking then
    
    self.timer = self.timer + 1
    if self.timer == 16 then
      if GAMEDATA.isHardMode() then
        self.sprite:change ( 3, "burst-tornado-top-big"    )
        self.sprite:change ( 4, "burst-tornado-bottom-big" )
      else
        self.sprite:change ( 3, "burst-tornado-top"    )
        self.sprite:change ( 4, "burst-tornado-bottom" )
      end
      self.tornado                        = true
      self.tornadoY                       = Camera:getY()
      if GAMEDATA.isHardMode() then
        self.tornadoPush                    = 0.25
      else
        self.tornadoPush                    = 0.125  
      end
      self.velocity.horizontal.direction  = self.sprite:getScaleX()
      self.tornadoVel                     = 0.05
      self.tornadoDisplacement            = 0
      self.tornadoDisplacementInc         = 0
      self.tornadoAccelerate              = true
      self.tornadoDeaccelStart            = false
    elseif self.timer < 16 then
      self.velocity.vertical.current   = math.max(self.velocity.vertical.current - 0.25 - 0.125, -0.5)
    else
      self.velocity.vertical.current   = math.min(self.velocity.vertical.current + 0.125, 0)
    end

    if self.tornado then
      if self.timer > 16 and self.timer % 3 == 0 then
        self.tornadoPush = math.min(self.tornadoPush + 0.125, ((GAMEDATA.isHardMode()) and 1.5 or 1.0))
      end

      if self.tornadoAccelerate then
        if self.timer > 26 then
          self.tornadoDisplacementInc      = math.min ( self.tornadoDisplacementInc + 0.01, 0.05 )
          self.tornadoDisplacement         = self.tornadoDisplacement + self.tornadoDisplacementInc
          if self.timer > 36 then
            self.tornadoVel                  = math.min(self.tornadoVel + 0.05, 8)
          end
          local last                       = self.velocity.horizontal.current
          self.velocity.horizontal.current = math.sin(self.tornadoDisplacement) * self.tornadoVel

          if self.tornadoDeaccelStart then
            if math.abs(last) > math.abs(self.velocity.horizontal.current) then
              self.tornadoAccelerate              = false
              self.velocity.horizontal.direction  = self.sprite:getScaleX()
              self.velocity.horizontal.current    = math.abs  ( self.velocity.horizontal.current )
            end
          end
        end
      elseif self.tornado and not self.tornadoAccelerate then
        self.velocity.horizontal.current = math.max(self.velocity.horizontal.current - 0.25 - 0.125, 0)
        if self.velocity.horizontal.current <= 0 then
          self.velocity.horizontal.current = 0
          self.timer = 1001
        end
      end

      if self.timer == 286 then
        self.tornadoDeaccelStart = true
      end

      if self.timer > 999 then
        self.sprite:change ( 2, "burst-tornado-end" )
        self.stateVars.finishedAttacking = true
        self.timer                       = 40
      end
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:endAction(true)
      self.missileSpam = false
      self.grenadeSpam = false
    end
  end

  if self.stateVars.finishedAttacking and not self.stateVars.dissipating then
    if self.sprite:getFrame(3) == 6 and self.sprite:getFrameTime(3) == 0 then
      self.stateVars.dissipating = true
      if GAMEDATA.isHardMode() then
        self.sprite:change ( 3, "burst-tornado-top-big-dissipate",    2, true )
        self.sprite:change ( 4, "burst-tornado-bottom-big-dissipate", 2, true )
      else
        self.sprite:change ( 3, "burst-tornado-top-dissipate",    2, true )
        self.sprite:change ( 4, "burst-tornado-bottom-dissipate", 2, true )
      end
    end
  end

  self:applyPhysics()

  if self.tornado and not self.stateVars.dissipating then
    if not self.stateVars.sfxTime then
      self.stateVars.sfxTime = -1
    end
    local t = GetLevelTime()
    if t > self.stateVars.sfxTime+10 then
      self.stateVars.sfxTime = t
      self.fasterSpinSfx     = true
      Audio:playSound ( SFX.gameplay_blade_wind_push, 0.5 )
    end

    if self.playerIsKnownToBeAlive then
      local obj = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
      if obj then
        local px, _, mx = self:getLocations()
        if px < mx then
          obj:applyPush ( self.tornadoPush,   0, self )
        else
          obj:applyPush ( -self.tornadoPush,  0, self )
        end
      end

      local sensorToUse = (GAMEDATA.isHardMode()) and self.sensors.BIG_TORNADO or self.sensors.TORNADO

      local hit, col  = sensorToUse:check ( )
      if hit and not self.stateVars.frozeThisContact then
        local px, _, mx = self:getLocations()
        if col.parent.state.isIced then
          GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE, "weak", px < mx and -1 or 1 )
        else
          self.isIce = true
          col.parent:freeze ( self, px < mx and -1 or 1)
          --GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_MEDIUM, "weak", px < mx and -1 or 1 )
          self.stateVars.frozeThisContact = true
          self.stateVars.frozeTime        = 30
        end
      end
      if self.stateVars.frozeTime then
        self.stateVars.frozeTime = self.stateVars.frozeTime - 1
        if self.stateVars.frozeTime <= 0 then
          self.stateVars.frozeThisContact = false
        end
      end

      if not hit then
        self.stateVars.frozeThisContact = false
      end
    end

    
    if GetLevelTime ( ) % 3 == 0 then
      Particles:addFromCategory ( "dust_particle", self:getX()+44,  self.tornadoY+214, -1, 1,  2, -0.25 )
      Particles:addFromCategory ( "dust_particle", self:getX()-24,  self.tornadoY+214,  1, 1, -2, -0.25 )
      Particles:addFromCategory ( "dust_particle", self:getX()+48,  self.tornadoY+214, -1, 1,  2, -0.25 )
      Particles:addFromCategory ( "dust_particle", self:getX()-32,  self.tornadoY+214,  1, 1, -2, -0.25 )


      local mx, my = self:getMiddlePoint   ( )
      local sx     = 1
      local diff   = math.abs(mx-self.class.EDGES.right)
      for i = 1, 4 do
        local x,y = mx, my
        y         = Camera:getY() + 213
        x = x + sx * (RNG:range ( 0, diff ))
        if x < self.class.EDGES.left + 16 then
          x = self.class.EDGES.left + 16
        elseif x > self.class.EDGES.right - 16 then
          x = self.class.EDGES.right - 16
        end

        Particles:addFromCategory ( "landing_dust", x, y, sx, 1, -sx*2.5, -0.25, Layer:get ( "ENEMIES", "BOTTOMEST" )() )
      end
      local mx, my = self:getMiddlePoint   ( )
      local sx     = -1
      local diff   = math.abs(mx-self.class.EDGES.left)
      for i = 1, 2 do
        local x,y = mx, my
        y         = Camera:getY() + 213
        x = x + sx * (RNG:range ( 0, diff ))
        if x < self.class.EDGES.left + 16 then
          x = self.class.EDGES.left + 16
        elseif x > self.class.EDGES.right - 16 then
          x = self.class.EDGES.right - 16
        end

        Particles:addFromCategory ( "landing_dust", x, y, sx, 1, -sx*2.5, -0.25, Layer:get ( "ENEMIES", "BOTTOMEST" )() )
      end
    end
  end
end

_DESPERATION_ACTIVATION.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §ICICLE ARC §ARC ----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _ICICLE_ARC = _BLADE:addState ( "ICICLE_ARC" )

function _ICICLE_ARC:enteredState ( px, py, mx, my )
  self.positionRoundingDisabled      = true
  self.timer                         = 0
  self.stateVars.shot                = false
  self.velocity.vertical.update      = false
  self.stateVars.acc                 = px < mx and -1 or 1

  local f = self.sprite:getFrame(2)
  self.sprite:change ( 2, "icicle-arc-start", f, true )

  self.stateVars.init                = false
end

function _ICICLE_ARC:exitedState ( )
  self:endAction ( false, self.forceDesperation and 20 or 5, 9 )
  self.positionRoundingDisabled = false
end

function _ICICLE_ARC:tick ( )
  local change = false

  local px, py, mx, my = self:getLocations()
  local cy             = Camera:getY()

  if not self.stateVars.init then
    self:disableContactDamage   ( 22 ) 
    self.stateVars.init = true
    self.stateVars.x    = px
    self.stateVars.y    = py

    local initDir                      = self.velocity.horizontal.direction
    self.velocity.horizontal.direction = px < mx and -1 or 1
    if initDir ~= self.velocity.horizontal.direction then
      self.velocity.horizontal.current = -self.velocity.horizontal.current 
    end
  end

  if not self.stateVars.shot and not self.stateVars.yreduce then
    self:setAfterImagesEnabled(true)
    if self.velocity.horizontal.direction > 0 then
      if self.stateVars.x > mx then
        self.velocity.horizontal.current = math.min(self.velocity.horizontal.current+(math.abs(px-mx) > 100 and 1 or 0.5), 4)
        if self.velocity.horizontal.current > 3 and mx > self.class.EDGES.right then
          self.stateVars.x          = self.stateVars.x - 800
        end
        change = true
      else
        self.velocity.horizontal.current = math.max(self.velocity.horizontal.current-(0.25), -4)
      end
    else
      if self.stateVars.x < mx then
        self.velocity.horizontal.current = math.min(self.velocity.horizontal.current+(math.abs(px-mx) > 100 and 1 or 0.5), 4)
        if self.velocity.horizontal.current > 3 and mx < self.class.EDGES.left then
          self.stateVars.x = self.stateVars.x + 800
        end
        change = true
      else
        self.velocity.horizontal.current = math.max(self.velocity.horizontal.current-0.25, -4)
      end
    end
  else
    self:setAfterImagesEnabled(false)
    if self.stateVars.yreduce then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    else
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, 0 )
    end
  end

  if my > cy + (self.desperationActivated and 103 or 110) then
    self.velocity.vertical.current = math.max ( self.velocity.vertical.current - (self.desperationActivated and 0.45 or 0.35), -4 )
    change = true
  else
    self.stateVars.yreduce         = true
    if self.timer < 9 then
      self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.125,  1 )
    else
      self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.125, 0 )
    end
  end

  if self.timer < 2 then
    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end
  end

  if not change then
    self.timer = self.timer + 1
  end

  if not self.stateVars.shot and self.timer <= 1 then
    self.sprite:flip ( px < mx and -1 or 1 )
  end
  
  if not self.stateVars.shot and self.timer == (self.desperationActivated and 1 or 4) then
    self.sprite:change ( 2, "icicle-arc-end" )
    self.stateVars.animChanged = true
  end

  if not self.stateVars.shot and self.timer >= (self.desperationActivated and 4 or 7) then
    --self.sprite:change ( 2, "icicle-arc-end" )
    self.stateVars.shot = true
    self.timer          = 0

    local x, y = self:getPos()
    y = y - (self.desperationActivated and 8 or 12)

    local speed = GAMEDATA.isHardMode() and 4.00 or 3.5
    
    --Audio:playSound ( SFX.gameplay_blade_ice_projectile )
    if self.sprite:getScaleX() < 0 then
      x = x - 10
      --if self.desperationActivated then
        GameObject:spawn ( 
          "freezing_projectile", 
          x - 10, 
          y + 6, 
          1,
          12,
          speed * 2
        )
      --end
      GameObject:spawn ( 
        "freezing_projectile", 
        x - 4, 
        y + 10, 
        11,
        9,
        speed * 2
      )
      GameObject:spawn ( 
        "freezing_projectile", 
        x + 2, 
        y + 13, 
        2,
        6,
        speed * 2
      )
      if self.desperationActivated then
      GameObject:spawn ( 
        "freezing_projectile", 
        x + 7, 
        y + 10, 
        14,
        3,
        speed * 2
      )
      end
      --[[
      if self.desperationActivated then
        GameObject:spawn ( 
          "freezing_projectile", 
          x + 11, 
          y + 6, 
          3,
          0,
          speed * 2
        )
      end]]
    else
      x = x + 26
      --[[
      if self.desperationActivated then
        GameObject:spawn ( 
          "freezing_projectile", 
          x - 10, 
          y + 6, 
          1,
          0,
          speed * 2
        )
      end]]

      if self.desperationActivated then
      GameObject:spawn ( 
        "freezing_projectile", 
        x - 4, 
        y + 10, 
        11,
        3,
        speed * 2
      )
      end
      GameObject:spawn ( 
        "freezing_projectile", 
        x + 2, 
        y + 13, 
        2,
        6,
        speed * 2
      )
      GameObject:spawn ( 
        "freezing_projectile", 
        x + 7, 
        y + 10, 
        14,
        9,
        speed * 2
      )
      --if self.desperationActivated then
        GameObject:spawn ( 
          "freezing_projectile", 
          x + 11, 
          y + 6, 
          3,
          12,
          speed * 2
        )
      --end
    end
    
    --[[
    GameObject:spawn ( 
      "freezing_projectile", 
      x, 
      y + 5, 
      14
    )]]
  elseif self.stateVars.shot and self.timer >= (self.desperationActivated and 15 or 25) then
    if self:checkIsPlayerFrozen ( ) then
      self.stateVars.punish = true
      self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, 12 )
      return 
    end
    self:endAction ( true )
  end

  self:applyPhysics()
end

_ICICLE_ARC.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §HORIZONTAL ICICLES -------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HORI_ICE = _BLADE:addState ( "HORIZONTAL_ICICLES" )

function _HORI_ICE:enteredState ( )
  self.timer                     = 0
  self.velocity.vertical.current = 0
  self.velocity.vertical.update  = false
  self.positionRoundingDisabled  = true
  self.stateVars.shots           = 0
  self.stateVars.lastHeight      = -1
  self.sprite:change ( 2, "icicle-arc-start", 1, true )
end

function _HORI_ICE:exitedState ( )
  self:endAction ( false, self.forceDesperation and 20 or 4, 8 )
  self.positionRoundingDisabled = false
end

function _HORI_ICE:tick ( )
if not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer >= 12 then
      self.timer                = 40
      self.stateVars.moveWaited = true
      self.sprite:change ( 2, "horizontal-icicle", 1, true )
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then

    self.timer = self.timer + 1

    local px, py, mx, my  = self:getLocations()
    local sx              = self.sprite:getScaleX()
    local targetShots     = (self.desperationActivated and 4 or 3)
    local tTime           = self.desperationActivation and 15 or 24

    if self.stateVars.shots >= 1 then
      if self:checkIsPlayerFrozen ( ) then
        self.stateVars.panicMove = true
        self.sprite:change ( 2, "horizontal-icicle", 6, true )
        self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, 12 )
        return 
      end
    end

    if (self.stateVars.shots < targetShots) then
      if self.timer >= tTime then
        --Audio:playSound ( SFX.gameplay_blade_ice_projectile )
        local sx    = self.sprite:getScaleX()
        local speed = GAMEDATA.isHardMode() and 4.50 or 3.5
        local x,y   = self:getMiddlePoint()
        if sx == 1 then
          x = x + 26
          y = y - 8
          if self.desperationActivated then
            GameObject:spawn ( 
              "freezing_projectile", 
              x, 
              y-4, 
              9,
              12,
              speed * 2
            )
          end
          GameObject:spawn ( 
            "freezing_projectile", 
            x+1, 
            y-2, 
            18,
            9,
            speed * 2
          )
          GameObject:spawn ( 
            "freezing_projectile", 
            x + 3, 
            y, 
            6,
            6,
            speed * 2
          )
          GameObject:spawn ( 
            "freezing_projectile", 
            x+2, 
            y-1, 
            13,
            3,
            speed * 2
          )

          if self.desperationActivated then
          GameObject:spawn ( 
            "freezing_projectile", 
            x + 1, 
            y + 2, 
            3,
            0,
            speed * 2
          )
          end
          --[[
          if self.desperationActivated then
            GameObject:spawn ( 
              "freezing_projectile", 
              x, 
              y + 4, 
              2,
              0,
              speed * 2
            )
          end]]
        else
          x = x - 32
          y = y - 8
          if self.desperationActivated then
            GameObject:spawn ( 
              "freezing_projectile", 
              x, 
              y-4, 
              7,
              12,
              speed * 2
            )
          end
          GameObject:spawn ( 
            "freezing_projectile", 
            x-1, 
            y-2, 
            17,
            9,
            speed * 2
          )
          GameObject:spawn ( 
            "freezing_projectile", 
            x - 3, 
            y, 
            4,
            6,
            speed * 2
          )
          GameObject:spawn ( 
            "freezing_projectile", 
            x-2, 
            y-1, 
            12,
            3,
            speed * 2
          )

          if self.desperationActivated then
          GameObject:spawn ( 
            "freezing_projectile", 
            x - 1, 
            y + 2, 
            1,
            0,
            speed * 2
          )
          end
          --[[
          if self.desperationActivated then
            GameObject:spawn ( 
              "freezing_projectile", 
              x, 
              y + 4, 
              2,
              0,
              speed * 2
            )
          end]]
        end
        self.timer           = 0
        self.stateVars.shots = self.stateVars.shots + 100
      end
    else
      if self.timer >= 33 then
        self.stateVars.finishedAttacking  = true
        self.timer                        = 0
        self.sprite:change ( 2, "horizontal-icicle", 6, true )
      end
    end
  elseif self.stateVars.finishedAttacking then
    self.timer = self.timer + 1
    self:setAfterImagesEnabled(false)
    if self.timer > (self.desperationActivated and 8 or 16) then
      self:endAction ( true )
    end
  end

  if self.stateVars.moved then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.25 - 0.125, 0)
  end

  self:applyPhysics ()
end

function _HORI_ICE:move ( )
  if not self.stateVars.moveStarted then

    self:setAfterImagesEnabled(true)

    self.stateVars.moveStarted  = true
    self.stateVars.curX,
    self.stateVars.curY         = self:getMiddlePoint    ( )
    self.stateVars.bounce       = -3.5
    self.stateVars.upward       = true


    local obj = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
    local dir = 0
    if obj then
      dir = -obj.velocity.horizontal.direction
    else
      dir = RNG:rsign()
    end
    if math.abs(dir) < 1 then
      dir = RNG:rsign()
    end

    local px, py, mx, my        = self:getLocations ( )
    local goalX                 = math.multiple ( px + dir * RNG:range(4,7) * 16 )
    if goalX < self.class.EDGES.left - 32 then
      goalX = self.class.EDGES.left - 32
    elseif goalX > self.class.EDGES.right + 32 then
      goalX = self.class.EDGES.right + 32
    end

    if math.abs(mx-goalX) < 16 then
      goalX = goalX + RNG:rsign() * 16
    end
    local goal                  = Camera:getY() + 205 - 40
    local time                  = self.desperationActivation and 37 or 49
    time                        = time + math.floor(math.abs ( self.stateVars.curX - goalX ) / 35)
    self:disableContactDamage   ( 22 ) 
    self.stateVars.xtween       = Tween.new ( time, self.stateVars, { curX   = goalX }, "inOutQuad"   )
    self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal  }, "inOutQuad"   )
    self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = 3.5   }, "inOutCubic"  )

  else
    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    --------------
    -- x        --
    --------------
    local cur = self.stateVars.curX 
    self.stateVars.xtween:update(1)
    local diff = cur - self.stateVars.curX 
    self.velocity.horizontal.current   = math.abs   ( diff )
    self.velocity.horizontal.direction = -math.sign ( diff )

    --------------
    -- y        --
    --------------
    cur  = self.stateVars.curY
    self.stateVars.ytween:update ( 1 )
    if self.stateVars.upward then
      if self.stateVars.btween:update ( 1 ) then
        self.stateVars.upward = false
      end
    else
      self.stateVars.btween:update ( -1 )
    end
    diff = cur - self.stateVars.curY 
    self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

    if self.stateVars.ytween:getTime() > 0.6 then
      local px, _, mx = self:getLocations()
      self.sprite:flip   ( px < mx and -1 or 1 ) 
    end

    if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
      self.timer                        = 0
      self.stateVars.moved              = true
      self.velocity.horizontal.current  = 0
      self.velocity.vertical.current    = 2
      self:setAfterImagesEnabled(false)
    end
  end
end

_HORI_ICE.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §VERTICAL ICICLE ----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _VERTICAL = _BLADE:addState ( "VERTICAL_ICICLES" )

function _VERTICAL:enteredState ( px, py, mx, my )
  self.positionRoundingDisabled  = true
  self.grenadeSpamTimer = 20
  self.grenadeSpam = true

  local f = self.sprite:getFrame(2)
  self.sprite:change ( 2, "vertical-icicles", f, true )
end

function _VERTICAL:exitedState ( )
  self:endAction ( false, 8, 14 )
  self.positionRoundingDisabled  = false
  self.grenadeSpam = false
end
--[[
function _VERTICAL:tick ( )
  if not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer == (self.desperationActivated and 3 or 6) then
      --self.sprite:change ( 2, "vertical-icicles-end", 1, true )
      self:setAfterImagesEnabled(true)
      self.timer                = 0
      self.stateVars.moveWaited = true

      local px, py, mx, my = self:getLocations()

      self.velocity.horizontal.direction = 1
      self.stateVars.dir                 = px < mx and -1 or 1
      self.velocity.vertical.current     = 0.125
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then
    local px, py, mx, my = self:getLocations()

    if self.stateVars.dir < 0 then
      if px < mx then
        self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, -5 )
      else
        if self.velocity.horizontal.current <= -2 then
          self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25
          self.stateVars.dir               = 1
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.25
        end
      end
    else
      if px > mx then
        self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 5 )
      else
        if self.velocity.horizontal.current >= 2 then
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.25
          self.stateVars.dir               = -1
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25
        end
      end
    end
    self.timer = self.timer + 1
    if self.timer > 160 then
      self.stateVars.finishedAttacking    = true
      self.velocity.horizontal.direction  = math.sign(self.velocity.horizontal.current)
      self.velocity.horizontal.current    = math.abs( self.velocity.horizontal.current)
      self.sprite:change ( 2, "vertical-icicles-end", 4, true )
    end

    if self.timer % (self.desperationActivated and 20 or 24) == 0 then
      local speed = self.desperationActivated and 4.0 or 3.5
      
      --Audio:playSound ( SFX.gameplay_blade_ice_projectile )
      
      GameObject:spawn ( 
        "freezing_projectile", 
        mx + 2 + (self.sprite:getScaleX() < 0 and -5 or -15) + self.velocity.horizontal.current * 2, 
        my + 10, 
        2,
        0,
        speed
      )
    end

    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

  elseif self.stateVars.finishedAttacking then

    self.velocity.vertical.current    = math.max ( self.velocity.vertical.current   - 0.125, 0 )
    self.velocity.horizontal.current  = math.max ( self.velocity.horizontal.current - 0.25,  0 )

    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    if self.velocity.horizontal.current <= 2 then
      self.timer = self.timer + 1
      if self.timer > (self.desperationActivated and 16 or 20) then
        self:setAfterImagesEnabled(false)
        self:gotoState ( "FLOAT_ARC_HOP" )
        self.timer = -8
      end
    end
  end

  if self.stateVars.moved and not self.stateVars.moveWaited then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.125, 0)
  end

  if not self.stateVars.punishTime and self:checkIsPlayerFrozen ( ) then
    self.stateVars.punishTime = 0
  end

  if self.stateVars.punishTime then
    self.stateVars.punishTime = self.stateVars.punishTime + 1
    if self.stateVars.punishTime > 5 then
      self.velocity.horizontal.current = 0
      self.stateVars.punish            = true
      self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, -1 )
      return 
    end
  end

  self:applyPhysics ()
end]]


function _VERTICAL:tick ( )
  if not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer == (self.desperationActivated and 3 or 6) then
      --self.sprite:change ( 2, "vertical-icicles-end", 1, true )
      self:setAfterImagesEnabled(true)
      self.timer                = 0
      self.stateVars.moveWaited = true

      local px, py, mx, my = self:getLocations()

      self.velocity.horizontal.direction = 1
      self.stateVars.dir                 = px < mx and -1 or 1
      self.velocity.vertical.current     = -0.125
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then
    local px, py, mx, my = self:getLocations()

    if self.stateVars.dir < 0 then
      if px < mx then
        self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, -5 )
      else
        if self.velocity.horizontal.current <= -2 then
          self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25
          self.stateVars.dir               = 1
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.25
        end
      end
    else
      if px > mx then
        self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 5 )
      else
        if self.velocity.horizontal.current >= 2 then
          self.velocity.horizontal.current = self.velocity.horizontal.current - 0.25
          self.stateVars.dir               = -1
        else
          self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25
        end
      end
    end
    self.timer = self.timer + 1
    if self.timer > 160 then
      self.stateVars.finishedAttacking    = true
      self.velocity.horizontal.direction  = math.sign(self.velocity.horizontal.current)
      self.velocity.horizontal.current    = math.abs( self.velocity.horizontal.current)
      self.sprite:change ( 2, "vertical-icicles-end", 4, true )
    end

    local reduction = GAMEDATA.isHardMode() and 6 or 0

    if self.timer % ((self.desperationActivated and 22 or 30)-reduction) == 0 then
      local speed = self.desperationActivated and 4.0 or 3.5
      
      --Audio:playSound ( SFX.gameplay_blade_ice_projectile )
      local sx = self.sprite:getScaleX()

      local l = Layer:get( "ENEMIES", "PROJECTILES")() + 14
      for i = 1, 5 do
        if i ~= 3 then 
          Particles:addFromCategory ( 
            "directionless_dust", 
            mx + (sx > 0 and -18 or -9), 
            my+1, 
            math.rsign(), 
            1, 
            (-0.75+i*0.25), 
            0.25+(i%2==0 and 0.25 or 0),
            l,
            false,
            nil,
            true,
            1.0
          )
        end
      end

      Audio:playSound ( SFX.gameplay_mortar_shot )
      GameObject:spawn ( 
        "ice_ball", 
        mx + (sx > 0 and -14 or -6), 
        my+6, 
        self.sprite:getScaleX(), 
        self,
        0,
        -0.75
      )
      self.sprite:change ( 2, "vertical-icicles-end", 2, true )
    end

    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

  elseif self.stateVars.finishedAttacking then

    self.velocity.vertical.current    = math.max ( self.velocity.vertical.current   - 0.125, 0 )
    self.velocity.horizontal.current  = math.max ( self.velocity.horizontal.current - 0.25,  0 )

    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    if self.velocity.horizontal.current <= 2 then
      self.timer = self.timer + 1
      if self.timer > (self.desperationActivated and 16 or 20) then
        self:setAfterImagesEnabled(false)
        self:gotoState ( "FLOAT_ARC_HOP" )
        self.timer = -8
      end
    end
  end

  if self.stateVars.moved and not self.stateVars.moveWaited then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.125, 0)
  end

  if not self.stateVars.punishTime and self:checkIsPlayerFrozen ( ) then
    self.stateVars.punishTime = 0
  end

  if self.stateVars.punishTime then
    self.stateVars.punishTime = self.stateVars.punishTime + 1
    if self.stateVars.punishTime > 5 then
      self.velocity.horizontal.current = 0
      self.stateVars.punish            = true
      self:gotoState     ( "FREEZE_PUNISH", nil, nil, nil, nil, -1 )
      return 
    end
  end

  --self.velocity.horizontal.current = 0

  self:applyPhysics ()
end

function _VERTICAL:move ( )
  if not self.stateVars.moveStarted then

    self:setAfterImagesEnabled(true)

    self.stateVars.moveStarted  = true
    self.stateVars.curX,
    self.stateVars.curY         = self:getMiddlePoint    ( )
    self.stateVars.bounce       = -2.25
    self.stateVars.upward       = true

    local px, py, mx, my        = self:getLocations ( )
    self.stateVars.left         = (math.abs(mx - self.class.EDGES.left) < math.abs(mx - self.class.EDGES.right)) and true or false
    local goalX                 = self.stateVars.left and (px - 128) or (px + 128)

    if goalX < self.class.EDGES.left - 48 then
      goalX = self.class.EDGES.left - 48
    elseif goalX > self.class.EDGES.right + 48 then
      goalX = self.class.EDGES.right + 48
    end

    local goal                  = Camera:getY() + 90--85
    local time                  = self.desperationActivation and 40  or 50
    self:disableContactDamage   ( 22 ) 
    self.stateVars.xtween       = Tween.new ( time, self.stateVars, { curX   = goalX }, "inOutCubic"  )
    self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal  }, "inOutCubic"  )
    self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = 2.25   }, "inOutCubic"  )
    --self.sprite:flip ( self.stateVars.curX < goalX and 1 or -1 )

  else
    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    --------------
    -- x        --
    --------------
    local cur  = self.stateVars.curX 
    self.stateVars.xtween:update(1)
    local diff = cur - self.stateVars.curX 
    self.velocity.horizontal.current   = math.abs   ( diff )
    self.velocity.horizontal.direction = -math.sign ( diff )

    --------------
    -- y        --
    --------------
    cur  = self.stateVars.curY
    self.stateVars.ytween:update ( 1 )
    if self.stateVars.upward then
      if self.stateVars.btween:update ( 1 ) then
        self.stateVars.upward = false
      end
    else
      self.stateVars.btween:update ( -1 )
    end
    diff = cur - self.stateVars.curY 
    self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

    if self.stateVars.ytween:getTime() > 0.6 then
      local px, _, mx = self:getLocations()
      self.sprite:flip   ( px < mx and -1 or 1 ) 
    end

    if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
      self.sprite:change ( 2, "vertical-icicles-end", 1, true )
      self.timer                        = 0
      self.stateVars.moved              = true
      self.velocity.horizontal.current  = 0
      self.velocity.vertical.current    = 1
      self:setAfterImagesEnabled(false)
    end
  end
end

_VERTICAL.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §WIND PUSH ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _WIND_PUSH = _BLADE:addState ( "WIND_PUSH" )

function _WIND_PUSH:enteredState ( px, py, mx, my )
  self.missileSpamTimer = 50
  self.missileSpam = true
  self.fastMissiles = true
  self.timer                     = self.desperationActivated and -4 or -8
  self.velocity.vertical.current = 0
  self.velocity.vertical.update  = false
  self.positionRoundingDisabled  = true
  self.stateVars.shots           = 0
  self.tornadoPush               = 0
  self.stateVars.blocks1         = {}
  self.stateVars.blocks2         = {}
  self.stateVars.randAngle       = RNG:n() * math.pi
  self.stateVars.spinDir         = RNG:rsign()
  self.stateVars.randAngle2      = RNG:n() * math.pi
end

function _WIND_PUSH:exitedState ( )
  self:endAction ( false, self.forceDesperation and 20 or 8, 16 )
  self.tornadoPush              = 0
  self.positionRoundingDisabled = false
  self.missileSpam = false
  self.fastMissiles = false

  if not self.stateVars.finishedPushingBlocks then
    for i = 1, #self.stateVars.blocks1 do
      self.stateVars.blocks1[i]:instantBreak ( )
      self.stateVars.blocks2[i]:instantBreak ( )
    end
  end
end

function _WIND_PUSH:tick ( )
  if not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer == 0 then
      self.stateVars.moveWaited = true
    end
  elseif self.stateVars.moved and not self.stateVars.spawned then
    local mx, my = self:getMiddlePoint()
    self.timer   = self.timer + 1
    if self.timer == (self.stateVars.shots < 1 and 30 or 25) then
      self.timer           = 0
      self.stateVars.shots = self.stateVars.shots + 1
      Audio:playSound ( SFX.gameplay_ice_block_spawn )
      self.stateVars.blocks1[self.stateVars.shots] = GameObject:spawn (
        "frozen_block",
        mx-(self.sprite:getScaleX() < 0 and 53 or 58),
        my-128,
        nil,
        true,
        true
      )
      self.stateVars.blocks2[self.stateVars.shots] = GameObject:spawn (
        "frozen_block",
        mx+(self.sprite:getScaleX() < 0 and 24 or 17), 
        my-128,
        nil,
        true,
        true
      )
      if self.stateVars.shots == (self.desperationActivated and 3 or 2) then
        self.stateVars.spawned = true
        self.timer             = 0
        self.stateVars.waiting = true
      end
    elseif self.timer < (self.stateVars.shots < 1 and 30 or 25) then
      self.stateVars.randAngle  = self.stateVars.randAngle  + 0.06
      self.stateVars.randAngle2 = self.stateVars.randAngle2 - 0.06
      if GetLevelTime()%4==0 then
        for i = 1, 8 do
          local xang = math.sin(self.stateVars.randAngle)
          local yang = math.cos(self.stateVars.randAngle)
          Particles:addFromCategory ( 
            "directionless_dust", 
            mx+xang*1.5+2-(self.sprite:getScaleX() < 0 and 53 or 58), 
            my+yang*1.5+3-128,
            1, 
            1, 
            xang*(i%2==0 and 1.25 or 2.75), 
            yang*(i%2==0 and 1.25 or 2.75), 
            Layer:get ( "ENEMIES", "BOTTOMEST" )(),
            false,
            nil,
            true
          )
          local xang = math.sin(self.stateVars.randAngle2)
          local yang = math.cos(self.stateVars.randAngle2)
          Particles:addFromCategory ( 
            "directionless_dust", 
            mx+xang*1.5+2+(self.sprite:getScaleX() < 0 and 24 or 17), 
            my+yang*1.5+3-128,
            1, 
            1, 
            xang*(i%2==0 and 1.25 or 2.75), 
            yang*(i%2==0 and 1.25 or 2.75), 
            Layer:get ( "ENEMIES", "BOTTOMEST" )(),
            false,
            nil,
            true
          )
          self.stateVars.randAngle  = self.stateVars.randAngle  + math.quarterPi
          self.stateVars.randAngle2 = self.stateVars.randAngle2 + math.quarterPi
        end
        --[[
        Particles:addFromCategory ( 
          "directionless_dust", 
          mx+2+((self.sprite:getScaleX() < 0) and -56 or 25), 
          my+3-128,--(self.stateVars.shots-1)*24,
          1, 
          1, 
          math.rsign()*math.random(), 
          math.rsign()*math.random(), 
          Layer:get ( "ENEMIES", "BOTTOMEST" )(),
          false,
          nil,
          true
        )]]
      end
    end

    if GetLevelTime()%5==0 then
      local mx, my = self:getMiddlePoint()
      local sx     = self.sprite:getScaleX()
      my = my - 21
      if sx < 0 then
        mx = mx - 16
      else
        mx = mx + 8
      end
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,2)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

  elseif self.stateVars.waiting then
    self.timer = self.timer + 1
    if self.timer > (36) then
      self.stateVars.waiting = false
      self.timer             = -5
      self.sprite:change ( 2, "wind-push-end", 2, true )
    end

    if GetLevelTime()%5==0 then
      local mx, my = self:getMiddlePoint()
      local sx     = self.sprite:getScaleX()
      my = my - 21
      if sx < 0 then
        mx = mx - 16
      else
        mx = mx + 8
      end
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,2)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then

    if self.timer < 0 then
      self.timer = self.timer + 1
    end

    local mx, my = self:getMiddlePoint()
    local sx     = self.sprite:getScaleX()

    if GetLevelTime()%4==0 then
      if sx == 1 then
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx-32+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, -0.25, -0.5-math.random()*0.75, 
          self.layers.sprite()+1, 
          false, nil, true 
        )
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx+23+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, 0.25, -0.5-math.random()*0.75, 
          self.layers.sprite()+1, 
          false, nil, true 
        )
      else
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx-35+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, -0.25, -0.5-math.random()*0.75, 
          self.layers.sprite()+1, 
          false, nil, true 
        )
        Particles:add ( "circuit_pickup_flash_small_blade", 
          mx+19+(math.random(0,5)*math.rsign()),
          my-12, 1, 1, 0.25, -0.5-math.random()*0.75, 
          self.layers.sprite()+1, 
          false, nil, true 
        )
      end
    end

    self.tornadoPush = math.min ( self.tornadoPush + 0.125, self.desperationActivated and 2.5 or 2.25 )

    local lx = self.class.EDGES.left-8
    local w  = self.class.EDGES.right - self.class.EDGES.left+8

    local p  = nil
    local px = 0

    local cols, len = Physics:queryRect ( lx, Camera:getY(), w, GAME_HEIGHT+16, self.filters.pushable )
    local hits      = 0
    for i = 1, len do
      if cols[i] and cols[i].parent and cols[i].parent.applyPush and cols[i].parent ~= self then
        if cols[i].parent.setWindPush then
          cols[i].parent:setWindPush ( self.tornadoPush * (cols[i].parent:getX() < mx and -1 or 1), 0 )
          hits = hits + 1
        elseif cols[i].isPlayer then
          p  = cols[i].parent
          px = p:getX()
        end
      end
    end

    if p then
      if px == p:getX() then
        if GAMEDATA.isHardMode() then
          p:applyPush ( self.tornadoPush * (p:getMiddlePoint() < mx and -1.5 or 1.5), 0, self )
        else
          p:applyPush ( self.tornadoPush * (p:getMiddlePoint() < mx and -1 or 1), 0, self )
        end
      end
    end

    if hits <= 0 then
      self.stateVars.finishedPushingBlocks = true
      self.timer = self.timer + 1
    end
    if self.timer >= 30 then

      self.sprite:change ( 2, "wind-push-end", 6, true )
      self.stateVars.finishedAttacking = true
      self.timer                       = 0

      self:setAfterImagesEnabled(false)
    end
    if not self.stateVars.sfxTime then
      self.stateVars.sfxTime = -1
    end
    local t = GetLevelTime()
    if t > self.stateVars.sfxTime+10 then
      self.stateVars.sfxTime = t
      Audio:playSound ( SFX.gameplay_blade_wind_push, 0.5 )
    end

    if GetLevelTime ( ) % 3 == 0 then
      local mx, my = self:getMiddlePoint   ( )

      if sx < 0 then
        mx = mx - 1
      else
        mx = mx - 8
      end

      local sx     = self.sprite:getScaleX ( )
      local diff   = math.abs(mx-self.class.EDGES.left)
      for i = 1, 3 do
        local x,y = mx, my
        y         = Camera:getY() + 213
        local sx  = -1
        x = x + sx * (RNG:range ( 0, diff )) - 8
        if x < self.class.EDGES.left + 16 then
          x = self.class.EDGES.left + 16
        elseif x > self.class.EDGES.right - 16 then
          x = self.class.EDGES.right - 16
        end

        Particles:addFromCategory ( "landing_dust", x, y, -sx, 1, sx*2, -0.25, Layer:get ( "ENEMIES", "BOTTOMEST" )() )
      end

      local diff   = math.abs(mx-self.class.EDGES.right)
      for i = 1, 3 do
        local x,y = mx, my
        y         = Camera:getY() + 213
        local sx  = 1
        x = x + sx * (RNG:range ( 0, diff ))
        if x < self.class.EDGES.left + 16 then
          x = self.class.EDGES.left + 16
        elseif x > self.class.EDGES.right - 16 then
          x = self.class.EDGES.right - 16
        end

        Particles:addFromCategory ( "landing_dust", x, y, -sx, 1, sx*2, -0.25, Layer:get ( "ENEMIES", "BOTTOMEST" )() )
      end
    end

  elseif self.stateVars.finishedAttacking then
    self.timer = self.timer + 1
    self:setAfterImagesEnabled(false)
    if self.timer > (self.desperationActivated and 8 or 16) then
      self:endAction ( true )
    end
  end

  if self.stateVars.moved then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.25 - 0.125, 0)
  end

  self:applyPhysics ()
end

function _WIND_PUSH:move ( )
  if not self.stateVars.moveStarted then

    self:setAfterImagesEnabled(true)

    self.stateVars.moveStarted  = true
    self.stateVars.curX,
    self.stateVars.curY         = self:getMiddlePoint    ( )
    self.stateVars.bounce       = -4.25
    self.stateVars.upward       = true

    local px, py, mx, my        = self:getLocations ( )
    local goalX                 = self.class.EDGES.left + math.floor((self.class.EDGES.right-self.class.EDGES.left)/2)--math.multiple ( px + (px < mx and -1 or 1) * RNG:range(4,7) * 16 )
    if goalX < self.class.EDGES.left + 108 then
      goalX = self.class.EDGES.left + 108
    elseif goalX > self.class.EDGES.right - 108 then
      goalX = self.class.EDGES.right - 108
    end
    local goal                  = Camera:getY() + 205 - 32
    local time                  = self.desperationActivation and 45 or 55
    time                        = time + math.floor(math.abs ( self.stateVars.curX - goalX ) / 35)
    self:disableContactDamage   ( 22 ) 
    self.stateVars.xtween       = Tween.new ( time, self.stateVars, { curX   = goalX }, "inOutQuad" )
    self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal  }, "inOutQuad" )
    self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = 4.25  }, "inOutQuad" )

    if goalX < self.stateVars.curX then
      if self.sprite:getScaleX() == -1 then
        self.sprite:change ( 2, "flying-forward" )
      else
        self.sprite:change ( 2, "flying-backward" )
      end
    else
      if self.sprite:getScaleX() == 1 then
        self.sprite:change ( 2, "flying-forward" )
      else
        self.sprite:change ( 2, "flying-backward" )
      end
    end
    --self.sprite:flip ( self.stateVars.curX < goalX and 1 or -1 )

  else
    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    --------------
    -- x        --
    --------------
    local cur = self.stateVars.curX 
    self.stateVars.xtween:update(1)
    local diff = cur - self.stateVars.curX 
    self.velocity.horizontal.current   = math.abs   ( diff )
    self.velocity.horizontal.direction = -math.sign ( diff )

    --------------
    -- y        --
    --------------
    cur  = self.stateVars.curY
    self.stateVars.ytween:update ( 1 )
    if self.stateVars.upward then
      if self.stateVars.btween:update ( 1 ) then
        self.stateVars.upward = false
      end
    else
      self.stateVars.btween:update ( -1 )
    end
    diff = cur - self.stateVars.curY 
    self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

    if self.stateVars.ytween:getTime() > 0.8 then
      local px, _, mx = self:getLocations()
      self.sprite:flip   ( px < mx and -1 or 1 ) 
      self.sprite:change ( 2, "wind-push-start", 4 )
    end

    if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
      self.timer                        = -6
      self.stateVars.moved              = true
      self.velocity.horizontal.current  = 0
      self.velocity.vertical.current    = 1

      self:setAfterImagesEnabled(false)
    end
  end
end

_WIND_PUSH.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DASH THROUGH -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DASH = _BLADE:addState ( "DASH_THROUGH" ) -- 7

function _DASH:enteredState ( )
  self.positionRoundingDisabled = true
  self.failsafeTimer = 60 * 4
  self.missileSpamTimer = 1
  self.missileSpam = true
end

function _DASH:exitedState ( )
  self.overrideSpinSfx = false
  Audio:stopSound ( SFX.gameplay_blade_dive_attack )
  self.positionRoundingDisabled = false
  self.sprite:change ( 5, nil )
  self.missileSpam = false
end

function _DASH:tick ( )
  if not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer == (self.desperationActivated and 3 or 6) then
      Audio:playSound ( SFX.gameplay_blade_dive_attack, 0.75 )
      self.overrideSpinSfx = true

      self:setAfterImagesEnabled(true)
      self.timer                = 0
      self.stateVars.moveWaited = true

      self.sprite:change ( 5, "dash-trail", 1, true )

      --[[
      if self.stateVars.left then
        self.velocity.horizontal.direction = 1
      else
        self.velocity.horizontal.direction = -1
      end]]
      self.velocity.horizontal.direction = self.sprite:getScaleX()
      if not self.velocity.horizontal.direction or math.abs(self.velocity.horizontal.direction) < 1 then
        self.velocity.horizontal.direction = 1
      end

      if self.velocity.horizontal.direction > 0 then
         self.stateVars.left = false
      else
         self.stateVars.left = true
      end
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then
    local mult = (GAMEDATA.isHardMode()) and 2 or 1
    if self.velocity.horizontal.current < 2.2 then
      self.velocity.horizontal.current = self.velocity.horizontal.current + 0.125 --* mult
    elseif self.velocity.horizontal.current < 4 then
      self.velocity.horizontal.current = self.velocity.horizontal.current + 0.25 * mult
    elseif self.velocity.horizontal.current < 6 then
      self.velocity.horizontal.current = self.velocity.horizontal.current + 0.5 * mult
    else 
      self.velocity.horizontal.current = math.min(self.velocity.horizontal.current + 1 * mult,14)
    end

    self.timer            = self.timer + 1
    local px, py, mx, my  = self:getLocations ( )

    if not self.stateVars.left then
      if mx > self.class.EDGES.right-64-24 then
        self.stateVars.finishedAttacking = true
        self.sprite:change ( 2, "flying-forward-back-to-neutral", 1, true )
        self.sprite:change ( 5, nil )
      end
    else
      if mx < self.class.EDGES.left+64+18 then
        self.stateVars.finishedAttacking = true
        self.sprite:change ( 2, "flying-forward-back-to-neutral", 1, true )
        self.sprite:change ( 5, nil )
      end
    end

    if not self.stateVars.finishedAttacking then
      self.failsafeTimer = self.failsafeTimer - 1
      if self.failsafeTimer <= 0 then
        self.sprite:change ( 2, "flying-forward-back-to-neutral", 1, true )
        self.sprite:change ( 5, nil )
      end
    end

    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

  elseif self.stateVars.finishedAttacking then
    if GetLevelTime()%2==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    if self.velocity.horizontal.current > 8 then
      self.overrideSpinSfx = false
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 1,  0 )
    elseif self.velocity.horizontal.current > 4 then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.5,  0 )
    else 
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25,  0 )
    end
    self.velocity.vertical.current   = math.min ( self.velocity.vertical.current   + 0.125, 0 ) 
    if self.velocity.horizontal.current <= 2 then
      self.timer = self.timer + 1
      if self.timer > (self.desperationActivated and 16 or 20) then
        self:setAfterImagesEnabled(false)
        self:gotoState ( "FLOAT_ARC_HOP" )
        self.timer = 1
      end
    end
  end

  if self.stateVars.moved then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.125, 0)
  end

  self:applyPhysics ()
end

function _DASH:move ( )
  if not self.stateVars.moveStarted then

    self:setAfterImagesEnabled(true)

    self.stateVars.moveStarted  = true
    self.stateVars.curX,
    self.stateVars.curY         = self:getMiddlePoint    ( )
    self.stateVars.bounce       = -2.25
    self.stateVars.upward       = true

    local px, py, mx, my        = self:getLocations ( )
    self.stateVars.left         = (math.abs(mx - self.class.EDGES.left) < math.abs(mx - self.class.EDGES.right)) and true or false
    local goalX                 = self.stateVars.left and (px - 128) or (px + 128)

    if goalX < self.class.EDGES.left - 48 then
      goalX = self.class.EDGES.left - 48
    elseif goalX > self.class.EDGES.right + 48 then
      goalX = self.class.EDGES.right + 48
    end

    local goal                  = Camera:getY() + 150 +18--+ (RNG:range(1,2)-1) * 18
    local time                  = self.desperationActivation and 38  or 48
    self:disableContactDamage   ( 20 ) 
    self.stateVars.xtween       = Tween.new ( time, self.stateVars, { curX   = goalX }, "inOutCubic"  )
    self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal  }, "inOutCubic"  )
    self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = 2.25   }, "inOutCubic"  )

    if goalX < self.stateVars.curX then
      if self.sprite:getScaleX() == -1 then
        self.sprite:change ( 2, "flying-forward" )
      else
        self.sprite:change ( 2, "flying-backward" )
      end
    else
      if self.sprite:getScaleX() == 1 then
        self.sprite:change ( 2, "flying-forward" )
      else
        self.sprite:change ( 2, "flying-backward" )
      end
    end
    --self.sprite:flip ( self.stateVars.curX < goalX and 1 or -1 )

  else
    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    --------------
    -- x        --
    --------------
    local cur  = self.stateVars.curX 
    self.stateVars.xtween:update(1)
    local diff = cur - self.stateVars.curX 
    self.velocity.horizontal.current   = math.abs   ( diff )
    self.velocity.horizontal.direction = -math.sign ( diff )

    --------------
    -- y        --
    --------------
    cur  = self.stateVars.curY
    self.stateVars.ytween:update ( 1 )
    if self.stateVars.upward then
      if self.stateVars.btween:update ( 1 ) then
        self.stateVars.upward = false
      end
    else
      self.stateVars.btween:update ( -1 )
    end
    diff = cur - self.stateVars.curY 
    self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

    if self.stateVars.ytween:getTime() > 0.6 then
      local px, _, mx = self:getLocations()
      self.sprite:flip   ( px < mx and -1 or 1 ) 
      if not self.stateVars.icicleAnimSet then
        self.stateVars.icicleAnimSet = true
        self.sprite:change ( 2, "flying-forward" )
      end
    end

    if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
      self.timer                        = 0
      self.stateVars.moved              = true
      self.velocity.horizontal.current  = 0
      self.velocity.vertical.current    = 3
      self:setAfterImagesEnabled(false)
    end
  end
end

_DASH.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §FREEZE PUNISH §PUNISH ----------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PUNISH = _BLADE:addState ( "FREEZE_PUNISH" ) -- 8

function _PUNISH:enteredState ( px, py, mx, my, time )
  self.timer                  = 0
  self.stateVars.initialTimer = time or 0
  self.stateVars.initialTimer = self.stateVars.initialTimer + 6
end

function _PUNISH:exitedState ( )
  Audio:stopSound ( SFX.gameplay_blade_dive_attack )
  self.overrideSpinSfx = false
  self:setAfterImagesEnabled(false, 16, 24)
  self:endAction(false)
end

function _PUNISH:tick ( )
  if self.stateVars.initialTimer > 0 then
    self.stateVars.initialTimer = self.stateVars.initialTimer - 1
  elseif not self.stateVars.moved then
    self.timer = self.timer + 1
    if self.timer >= 2 then
      self:move ()
    end
  elseif self.stateVars.moved and not self.stateVars.moveWaited then
    self.timer = self.timer + 1
    if self.timer >= (self.desperationActivated and 14 or 20) then
      self:setAfterImagesEnabled(true)
      self.timer                       = 0
      self.stateVars.moveWaited        = true
      self.velocity.horizontal.current = 0

      Audio:playSound ( SFX.gameplay_blade_dive_attack, 0.75 )
      self.overrideSpinSfx = true
    end
  elseif self.stateVars.moved and not self.stateVars.finishedAttacking then
    if GAMEDATA.isHardMode() then
      self.velocity.vertical.current = self.velocity.vertical.current + 2.5
    else
      self.velocity.vertical.current = self.velocity.vertical.current + 2.0
    end

    if self.state.isGrounded then
      Audio:playSound ( SFX.gameplay_boss_cable_landing )
      Audio:stopSound ( SFX.gameplay_blade_dive_attack )
      self.overrideSpinSfx = false

      self.sprite:change ( 2, "frozen-punish-end", 1, true )
      self.stateVars.finishedAttacking = true
      self.velocity.vertical.current   = 0

      local hit = self.sensors.GROUND_SLAM:check ( )
      if hit then
        local px, _, mx = self:getLocations()
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE, "weak", px < mx and -1 or 1 )
      end
    end

    if GetLevelTime()%3==0 then
      local mx, my = self:getMiddlePoint()
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(self.sprite:getScaleX()<0 and 0 or -8)+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end
  elseif self.stateVars.finishedAttacking then

    self.timer = self.timer + 1
    if self.timer > 4 and self.timer <= 10 then
      self.velocity.vertical.current = self.velocity.vertical.current - 0.125
    elseif self.timer > 10 then
      self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.125, 0 )
    end

    self:setAfterImagesEnabled(false)
    if self.timer > (self.desperationActivated and 16 or 24) then
      self:endAction ( true )
    end
  end

  if self.stateVars.moved and not self.stateVars.moveWaited then
    self.velocity.vertical.current = math.min(self.velocity.vertical.current + 0.125, 0)
  end

  self:applyPhysics ()
end

function _PUNISH:move ( )
  if not self.stateVars.readjustment and self.stateVars.xtween and self.stateVars.xtween:getTime() > 0.4 then
    self.stateVars.readjustment = true
    local px, py, mx, my        = self:getLocations   ( )
    local goalX                 = px < mx and (px - 10) or (px + 18)

    if math.abs(mx - px) < 20 then
      goalX = px
    end

    if goalX < self.class.EDGES.left + 20 then
      goalX = self.class.EDGES.left + 20
    elseif goalX > self.class.EDGES.right - 20 then
      goalX = self.class.EDGES.right - 20
    end

    self.stateVars.xtween       = Tween.new ( self.desperationActivation and 17 or 21, self.stateVars, { curX   = goalX }, "outQuad"  )
  end

  if not self.stateVars.moveStarted then

    self:setAfterImagesEnabled(true)

    self.stateVars.moveStarted  = true
    self.stateVars.curX,
    self.stateVars.curY         = self:getMiddlePoint    ( )
    self.stateVars.bounce       = -2.0
    self.stateVars.upward       = true

    local px, py, mx, my        = self:getLocations ( )
    local goalX                 = px < mx and (px - 10) or (px + 18)

    if math.abs(mx - px) < 20 then
      goalX = px
    end

    if goalX < self.class.EDGES.left + 20 then
      goalX = self.class.EDGES.left + 20
    elseif goalX > self.class.EDGES.right - 20 then
      goalX = self.class.EDGES.right - 20
    end

    local goal                  = Camera:getY() + 118
    local time                  = self.desperationActivation and 30 or 38
    self:disableContactDamage   ( 14 ) 
    self.stateVars.xtween       = Tween.new ( time-4, self.stateVars, { curX   = goalX }, "linear"  )
    self.stateVars.ytween       = Tween.new ( time, self.stateVars, { curY   = goal  }, "inOutCubic"  )
    self.stateVars.btween       = Tween.new ( time, self.stateVars, { bounce = 2.0   }, "inOutCubic"  )

    self.sprite:change  ( 2, "frozen-punish-start", 5, true )
    self.sprite:flip    ( self.stateVars.curX < goalX and 1 or -1 )
  else
    local px, py, mx, my = self:getLocations ( )
    if GetLevelTime()%3==0 then
      Particles:add ( "circuit_pickup_flash_small_blade", 
        mx-4+(math.random(0,5)*math.rsign()),
        my-12, 1, 1, 0, -0.5-math.random()*0.75, 
        self.layers.sprite()-1, 
        false, nil, true 
      )
    end

    --------------
    -- x        --
    --------------
    local cur  = self.stateVars.curX 
    self.stateVars.xtween:update(1)
    local diff = cur - self.stateVars.curX 
    self.velocity.horizontal.current   = math.abs   ( diff )
    self.velocity.horizontal.direction = -math.sign ( diff )

    --------------
    -- y        --
    --------------
    cur  = self.stateVars.curY
    self.stateVars.ytween:update ( 1 )
    if self.stateVars.upward then
      if self.stateVars.btween:update ( 1 ) then
        self.stateVars.upward = false
      end
    else
      self.stateVars.btween:update ( -1 )
    end
    diff = cur - self.stateVars.curY 
    self.velocity.vertical.current   = -diff + ((self.stateVars.bounce))

    if self.stateVars.ytween:isFinished() and self.stateVars.xtween:isFinished() then
      self.timer                        = 0
      self.stateVars.moved              = true
      self.velocity.horizontal.current  = 0
      self.velocity.vertical.current    = 0
      self:setAfterImagesEnabled(false)
    end
  end
end

_PUNISH.manageVerticalUpdate = NoOP

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _BLADE:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self.stateVars.playSfx           = false
  self.overrideSpinSfx             = true
  self.prefightAnimation           = {}
  self.prefightAnimation.layer     = self.layers.sprite
  self.activeLayer                 = self.layers.behind--2
  self.activeAfterImagesLayer      = self.layers.behind
  self.prefightAnimation.originalX,
  self.prefightAnimation.originalY = self:getPos()

  self.sprite:change ( 1, nil )
  self.sprite:change ( 2, nil )
end

function _PREFIGHT:exitedState ( )
  self.overrideSpinSfx         = false
  self.prefightAnimation       = nil
  self.activeLayer             = self.layers.sprite
  self.activeAfterImagesLayer  = Layer:get ( "TILES-MOVING-PLATFORMS-1" )
end

function _PREFIGHT:tick ( )
  local t = GetTime()
  if self.stateVars.playSfx
    and self.lastSfx+7 < t then
    self.lastSfx = t
    if self.fasterSpinSfx then
      self.fasterSpinSfx = false
      Audio:playSound ( SFX.gameplay_blade_propeller, self.stateVars.vol or 0.15 )
    else
      Audio:playSound ( SFX.gameplay_blade_propeller_slow, self.stateVars.vol or 0.15 )
    end
  end
  --if not self.prefightAnimation.started then return end
end

function _PREFIGHT:_runAnimation ( )
  if not self.prefightAnimation.started then
    self.prefightAnimation.started  = true
    self.prefightAnimation.finished = false


    self.prefightAnimation.phases = {
      self._phase0,
      self._phase1,
      self._phase2,
      self._phase3,
      self._phase4,
    }
    self.prefightAnimation.phases.vars    = {}
    self.prefightAnimation.phases.index   = 2
    self.prefightAnimation.phases.current = self.prefightAnimation.phases[self.prefightAnimation.phases.index]
    self.prefightAnimation.phases.init    = true
    return false
  end

  if self.prefightAnimation.phases.current ( self, self.prefightAnimation.phases.vars, self.prefightAnimation.phases.init ) then
    self.prefightAnimation.phases.index   = self.prefightAnimation.phases.index + 1
    self.prefightAnimation.phases.current = self.prefightAnimation.phases[self.prefightAnimation.phases.index]
    self.prefightAnimation.phases.init    = true
    cleanTable ( self.prefightAnimation.phases.vars )
  else
    self.prefightAnimation.phases.init    = false
  end


  if not self.prefightAnimation.phases.current then
    self.prefightAnimation.finished = true
  end
  
  return self.prefightAnimation.finished
end

function _PREFIGHT:_phase0 ( vars, init )
  if init then
    local cx, cy = Camera:getPos()
    self.sprite:change ( 2, "blade-beam-of-light" )
    self.sprite:mirrorX()
    self:setPos ( cx + 210, cy+150 )
    vars.timer = 0
    self:setAfterImagesEnabled(true)

    Particles:add ( "circuit_pickup_flash_large", self:getX()-60, self:getY()-90, 1, 1, 0, 0, Layer:get ( "PARTICLES" )() )
  end

  local x, y = self:getPos()
  self:setPos ( x + 8, y )
  local cx, cy = Camera:getPos()
  if x > cx + GAME_WIDTH then
    vars.timer = vars.timer + 1
  end

  if vars.timer > 80 then
    self:setAfterImagesEnabled(false)
    self.sprite:mirrorX()
    return true
  end
end

-- initial line in the sky and swoop
function _PREFIGHT:_phase1 ( vars, init )
  if init then
    local cx, cy = Camera:getPos()
    self.sprite:change ( 2, "mini-blade" )
    self:setPos ( cx + GAME_WIDTH, cy+125 )

    vars.reboundX = self.prefightAnimation.originalX - 10
    vars.middleX  = self.prefightAnimation.originalX - 93
    vars.speedDir = -1
    vars.speed    = 2.5
    vars.deaccel  = 0.25
    vars.ySpeed   = -0.125
    vars.sparkleTimer = 1
    self.stateVars.playSfx = true
    self.stateVars.vol     = 0.08
  end

  vars.sparkleTimer = vars.sparkleTimer - 1
  if vars.sparkleTimer <= 0 then
    local mx, my = self:getMiddlePoint()
    Particles:add ( "circuit_pickup_flash_small_blade", mx-4+(math.random(0,5)*math.rsign()), my-12, 1, 1, 0, -0.5-math.random()*0.75, self.layers.behind()-1, false, nil, true )
    vars.sparkleTimer = vars.reboundInc and 1 or 3
  end

  local x, y = self:getPos()
  self:setPos ( x + vars.speed * vars.speedDir, y + vars.ySpeed )

  if x < vars.reboundX and not vars.rebounded then
    vars.rebounded = true
  end

  if vars.rebounded and not vars.reboundFinish then
    if not vars.reboundInc then
      if vars.speed > -1.5 then
        vars.speed = vars.speed - 0.25
        if vars.speed <= -1.5 then
          vars.reboundInc = true
        end
      end
    else
      if vars.speed < 0 then
        vars.speed = vars.speed + 0.125
        if vars.speed >= 0 then

          Audio:playSound ( SFX.gameplay_blade_dive_attack_slow, 0.325 )
          self.sprite:change ( 1, "mini-blade-trail-start" )
          self:setAfterImagesEnabled(true)
        end
      else
        vars.speed = vars.speed + 0.5
      end
      if vars.speed > 5 then
        vars.speed         = 5
        vars.reboundFinish = true
      end
    end
  end

  if x < vars.middleX then
    if not vars.changedAnim then
      vars.changedAnim = true
      self.sprite:change ( 2, "mini-blade-turn" )
      self.stateVars.vol     = 0.1
    end
    vars.speed  = vars.speed  - vars.deaccel
    vars.ySpeed = vars.ySpeed + 0.125
    if vars.speed <= 0 then
      self.sprite:change ( 1, nil )
      Particles:add ( "circuit_pickup_flash_large_blade", self:getX()-4, self:getY()-6, 1, 1, 0, 0, self.layers.sprite()-1 )

      return true
    end
  end
end

-- circle and get into view
function _PREFIGHT:_phase2 ( vars, init )
  if init then
    vars.ySpeed   = 1.5
    vars.xSpeed   = 0
    vars.yTarget  = self:getY() - 3
    vars.ySlow    = false

    self.activeLayer  = self.prefightAnimation.layer 
    vars.sparkleTimer   = 1
  end

  if not vars.spawnSpinner and self.sprite:getAnimation ( 2 ) == "mini-blade-turn" and self.sprite:getCurrentFrame ( 2 ) == 5 then
    self.stateVars.vol     = 0.15
    self.sprite:change ( 1, "flying-spinner" )
    vars.spawnSpinner = true
  end

  vars.sparkleTimer = vars.sparkleTimer - 1
  if vars.sparkleTimer <= 0 then
    local mx, my = self:getMiddlePoint()
    Particles:add ( "circuit_pickup_flash_small_blade", mx-4+(math.random(0,5)*math.rsign()), my-12, 1, 1, 0, -0.5-math.random()*0.75, self.layers.sprite()-1, false, nil, true )
    vars.sparkleTimer = 2
  end

  local x, y  = self:getPos()
  x,y         = x + vars.xSpeed, y + vars.ySpeed
  self:setPos ( x, y )

  if not vars.ySlow then
    if y > vars.yTarget then
      vars.ySpeed = vars.ySpeed - 0.125
      if vars.xSpeed < 5.5 then
        vars.xSpeed = vars.xSpeed + 0.25
      end
    else
      vars.ySlow = true
    end
  else
    if not vars.mirrored and vars.xSpeed < 1 then
      self.sprite:mirrorX()
      vars.mirrored = true
    end

    if vars.xSpeed > 0 then
      vars.xSpeed = vars.xSpeed - 0.25
    end
    if vars.ySpeed < 0 then
      vars.ySpeed = vars.ySpeed + 0.05
    end

    if vars.xSpeed <= 0 and vars.ySpeed >= 0 then
      return true
    end
  end
end

-- drop
function _PREFIGHT:_phase3 ( vars, init )
  if init then
    vars.ySpeed = 0
  end

  if not vars.stopSpinner and self.sprite:getCurrentFrame ( 1 ) == 4 then
    self.stateVars.playSfx = false
    self.sprite:change ( 1, "flying-spinner-stop"    )
    self:setAfterImagesEnabled(false)
    vars.stopSpinner = true
  end

  if not vars.animChanged and vars.ySpeed > 1.5 then
    self.sprite:change ( 2, "flying-idle-to-falling" )
    vars.animChanged = true
  end

  if vars.ySpeed < 1 then
    vars.ySpeed = vars.ySpeed + 0.125
  else
    vars.ySpeed = vars.ySpeed + 0.5
  end
  
  local x, y  = self:getPos()
  x,y         = x + 0, y + vars.ySpeed
  self:setPos ( x, y )

  if self.prefightAnimation.originalY < y then
    Audio:playSound ( SFX.gameplay_boss_cable_landing )
    self.sprite:change ( 2, "intro-land"   )
    self.sprite:change ( 1, nil            )

    self:setPos ( self.prefightAnimation.originalX, self.prefightAnimation.originalY )

    Particles:addFromCategory ( "landing_dust", self:getX()+28, self:getY()+self.dimensions.h-7, -1, 1,  0.25, -0.1 )
    Particles:addFromCategory ( "landing_dust", self:getX()-6,  self:getY()+self.dimensions.h-7,  1, 1, -0.25, -0.1 )
    return true
  end
end

-- lol just wait, I hope you are not reading this
function _PREFIGHT:_phase4 ( vars, init )
  if init then
    vars.timer = 60
  end

  vars.timer = vars.timer - 1
  if vars.timer <= 0 then
    return true
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §fight intro --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local _FIGHT = _BLADE:addState ( "FIGHT_INTRO" )

function _FIGHT:enteredState ( )
  self.lastSfx = -1
  self.sprite:change ( 2, "battle-intro" )
  self.stateVars.maxVel = -4
  self.overrideSpinSfx  = true
end

function _FIGHT:exitedState ( )
  self.lastSfx = -1
  self.overrideSpinSfx            = false
  self.hasStartedToFloat          = true
  self.velocity.vertical.current  = 0
  self.nextActionTime             = 6
  --self.gotoFloatNext              = true
end

function _FIGHT:tick ( )
  if not self.stateVars.startedPropeller and self.sprite:getFrame ( 2 ) == 9 then
    self.stateVars.startedPropeller = true
    self.sprite:change ( 1, "flying-spinner" )
    self.overrideSpinSfx = false
    --self:setAfterImagesEnabled(true)
  end

  if not self.overrideSpinSfx then
    local t = GetTime()
    if self.lastSfx+7 < t then
      self.lastSfx = t
      if self.fasterSpinSfx then
        self.fasterSpinSfx = false
        Audio:playSound ( SFX.gameplay_blade_propeller, self.stateVars.vol or 0.15 )
      else
        Audio:playSound ( SFX.gameplay_blade_propeller_slow, self.stateVars.vol or 0.15 )
      end
    end
  end

  if not self.stateVars.floating and self.sprite:getFrame ( 2 ) > 12 then
    self.stateVars.floating = true
  end

  if self.stateVars.startDecrement then
    self.stateVars.maxVel = math.min ( self.stateVars.maxVel + 0.25, -0.25 )
  end
  
  if self.stateVars.floating then
    --if not self.stateVars.startDecrement then
      self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.5, self.stateVars.maxVel )
    --end
    self:applyPhysics ()
  end

  if self.velocity.vertical.current <= -1.75 then
    self.stateVars.startDecrement = true
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Teching  -----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TECH = _BLADE:addState ( "TECH_RECOVER" )
  
function _TECH:enteredState (  )  
  self.fakeOverkilledTimer      = GAMEDATA.boss.getTechRecoverFrames ( self )
  self.state.isBossInvulnerable = true
  
  self._lastBurstAttackId  = nil
  self:disableContactDamage ( 30 )
  self.timer               = 10
  local mx, my = self:getMiddlePoint()
  mx = mx - 8
  my = my - 24
  Particles:add ( "circuit_pickup_flash_large_blade", mx, my, 1, 1, 0, 0, self.layers.sprite()+1 )

  Audio:playSound ( SFX.hud_mission_start_shine )

  self.sprite:flip   ( nil, 1 )
  self.sprite:change ( 1, "flying-spinner" )
  self.sprite:change ( 2, "flying-idle"    )

  self.velocity.vertical.update = false
  self.stateVars.decrement      = false
end

function _TECH:exitedState ( )
  self.velocity.horizontal.current = 0
  self.velocity.vertical.current   = 0
end

function _TECH:tick ( )
  if self.timer < 20 then
    if self.sprite:getAnimation(1) ~= "flying-spinner" then
      self.sprite:change ( 1, "flying-spinner" )
    end
  end

  if self.sensors.WALL_SENSOR:check() then
    self.velocity.horizontal.current = math.max(self.velocity.horizontal.current - 0.25,0)
  else
    self.velocity.horizontal.current = math.max(self.velocity.horizontal.current - 0.125,0)
  end

  if self.sensors.ABOVE_PIT:check() then
    self.velocity.vertical.current = math.max(self.velocity.vertical.current - 1, -2 )
    self.timer = 15
  else
    self.timer = self.timer + 1
    if self.timer < 20 then
      self.velocity.vertical.current = math.max(self.velocity.vertical.current - 0.5, -2 )
    else
      self.velocity.vertical.current = math.min(self.velocity.vertical.current + 0.125, 0 )
    end
    self.stateVars.decrement  = true
  end

  if self.stateVars.decrement then
    if self.timer > 40 then
      if self.velocity.vertical.current <= 0 then
        self.nextActionTime = 6
        self:gotoState ( nil )
      end
    end
  end

  self:applyPhysics()
end

_TECH.manageVerticalUpdate = NoOP

function _BLADE:manageTeching ( timeInFlinch )
  if self.health <= 0 then
    return false
  end

  if timeInFlinch and (timeInFlinch > 90 or (self.state.hasBounced and self.state.hasBounced >= BaseObject.MAX_BOUNCES)) then
    self:gotoState ( "TECH_RECOVER" )
    return true
  end

  if self.velocity.vertical.current < -0.5 then
    return false
  end
  if not self.sensors.WARNING_SENSOR:check() then
    return false
  end

  self:gotoState ( "TECH_RECOVER" )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Managers -----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BLADE:manageReleaseFromGrab ( wasChained )
  --if not wasChained then
    self:gotoState ( "TECH_RECOVER" )
  --end
end

function _BLADE:manageThrowAnimationAfterMath ( )
  if self.sprite:getAnimation(1) ~= "flying-spinner" then
    self.sprite:change ( 1, "flying-spinner" )
  end
end

function _BLADE:manageGrab ( )
  self.sprite:change ( 2, nil )
end

function _BLADE:manageLaunchingHit ( )
  self.velocity.vertical.update = true
  return true
end

function _BLADE:manageVerticalUpdate ( )
  if not self.isTeching and not self.state.isLaunched and not self.isStunned and not self.state.isGrabbedByPlayer then
    self.velocity.vertical.update  = false
    self.velocity.vertical.current = 0
  end
end

function _BLADE:manageStunAnimation ( )
  self.sprite:change ( 2, nil )
end

function _BLADE:manageFlinchAnimation ( anim, launched )
  if launched then
    self.sprite:change ( 2, nil )
  end
end

function _BLADE:manageChainAnimation ( )
  self.sprite:change ( 2, nil )
end

function _BLADE:pull ()
  return false
end

function _BLADE:manageGravityFreeze()
  if self.isTeching or self.health <= 0 then return end
  self.sprite:change ( 2, nil )
  self.sprite:change ( 1, "spin", 1, false )
  return true
end

function _BLADE:bonkReduction ( isSelfDamage )
  -- old
  --return isSelfDamage and GAMEDATA.damageTypes.BOUNCE_REDUCED or GAMEDATA.damageTypes.COLLISION_REDUCED
  if not isSelfDamage then
    Challenges.unlock ( Achievements.RETURN_TO_BOSS )
  end
  -- new, less fun, but it rpevents boss from dying instantly
  return GAMEDATA.damageTypes.COLLISION_REDUCED --GAMEDATA.damageTypes.COLLISION_REDUCED_MINIMAL
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shield offsets during invul ----------------]]--
--[[----------------------------------------------------------------------------]]--

function _BLADE:getShieldOffsets ( scaleX )
  return ((scaleX > 0) and -4 or -28), -33
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Forced launch ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BLADE:manageForcedLaunch ( dmg )
  if self.forceLaunched then return end
  if self.health - dmg <= 0 then
    self.velocity.vertical.update = true
    return
  end
  if self.health - dmg <= (24) then
    self.velocity.vertical.update = true
    Audio:playSound ( SFX.gameplay_boss_phase_change )
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

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §§S HOP -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _S_HOP = _BLADE:addState ( "S_HOP" )

function _S_HOP:enteredState ( spawner )
  self.state.isHittable            = false
  self.state.isBossInvulnerable    = true

  self.SPAWNER_OBJ                 = spawner
  self.USES_PALETTIZED_HAZE_SHADER = true
  self.alwaysUsePaletteShader      = true
  self.BASE_PALETTE                = self.class.PALETTE
  self.ACTIVE_PALETTE              = self.class.PALETTE

  self._flashingShader            = true
  self.velocity.vertical.current  = -2.5
  self.velocity.vertical.update   = true
  self.state.isGrounded           = false

  self.stateVars.angryDelay       = 45
  self.timer                      = 55
  self.sprite:flip   ( -1, 1 )
  --self.sprite:change ( 1, "idle" )

  self.sprite:change ( 1, "flying-spinner" )
  self.sprite:change ( 2, "flying-idle"    )

  self._emitSmoke = true
  Environment.smokeEmitter ( self )
end

function _S_HOP:exitedState ( )
  self:endAction ( false )
end

function _S_HOP:tick ( )
  self:applyPhysics ( )

  if self.stateVars.angryDelay > 0 then
    self.stateVars.angryDelay = self.stateVars.angryDelay - 1
    if self.stateVars.angryDelay <= 0 then
      self.sprite:change ( 2, "angry", 8, true )
    end
    return
  end

  self.timer = self.timer - 1
  if self.timer <= 0 then
      --self:endAction ( true )
    if not self.playerIsKnownToBeAlive then return end
    local px, py, mx, my = self:getLocations()
    self:gotoState ( "DESPERATION_ACTIVATION", px, py, mx, my )
    self.actionsSinceDesperation = -1
  end
end

function _BLADE:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 then return end
  local x, y = self:getPos            ( )
  local l    = self.layers.bottom     ( )
  local sx   = self.sprite:getScaleX  ( )

  x = x + love.math.random(0,6)*math.rsign()
  y = y + love.math.random(1,2)
  if sx < 0 then
    x = x + 14
    y = y - 15
  else
    x = x + 14
    y = y - 15
  end

  Particles:addFromCategory ( "warp_particle_blade", x, y,   1,  1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BLADE:customEarlyEnemyDraw ( x, y )
  if not self.tornado then return end
  for i = 1, 14 do
    self.sprite:drawInstant ( 4, x, self.tornadoY + i *16 )
  end
end

function _BLADE:customEnemyDraw ( x, y, scaleX )
  if self.health > 0 and not self.state.isLaunched and not self.state.isGrabbedByPlayer and self.hasStartedToFloat then
    y = y - math.abs(2 - math.floor(self.floatTimer / 12 % 4)) 
  end
  if not self.isDestructed  then 
    self.sprite:drawInstant ( 5, x, y )
  end
  self.sprite:drawInstant ( 1, x, y )
  if self.isDestructed then return end
  self.sprite:drawInstant ( 2, x, y )

  if not self.tornado then return end
  love.graphics.setShader ( )

  for i = 1, 14 do
    self.sprite:drawInstant ( 3, x, self.tornadoY + i *16 )
  end

end

return _BLADE