-- Wrecker tank, opening stage boss
local _WTANK    = BaseObject:subclass ( "WRECKER_TANK" )
_WTANK:attach ( "enemyDrawSprite"  )
_WTANK:attach ( "shake"            )
_WTANK:attach ( "contactDamage"    )
_WTANK:attach ( "particleSpawning" )
_WTANK:attach ( "spawnRewards"     )
_WTANK:attach ( "applyPhysics"     )

_WTANK.static.EDITOR_DATA = {
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

_WTANK.static.preload = function ( ) 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.enemies,     "wrecker-tank"  )

  if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then return end
  Audio:loadBgmAsync ( BGM.boss_intro )
  Audio:loadBgmAsync ( BGM.tension    )
end

_WTANK.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_WTANK.static.DIMENSIONS = {
  x            =   7,
  y            =   6,
  w            =  110,
  h            =  44,
  -- these basically oughto match or be smaller than player
  grabX        =  10,
  grabY        =   6,
  grabW        =  14,
  grabH        =  26,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_WTANK.static.PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_WTANK.static.HURTBOX_PROPERTIES = { 
  isGrabbable   = true, 
  isLaunchable  = true, 
  isGrabBox     = true,
  isSolid       = false,
  isEnemy       = true,
  isDamaging    = true,
  isHeavy       = true,
}

_WTANK.static.FILTERS = {
  collision = Filters:get ( "enemyCollisionFilter" ),
}

_WTANK.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  real_gibs = Layer:get ( "FOREGROUND"                ),
}

_WTANK.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_WTANK.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_WTANK.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Palettes            ------------------------]]--
--[[----------------------------------------------------------------------------]]--

_WTANK.static.BASE_PALETTE = createColorVector (
  Colors.black,
  Colors.kai_dark_red,
  Colors.kai_red,
  Colors.bruiser_lighter_body,
  Colors.kai_yellow,
  Colors.white
)
_WTANK.static.PALETTE = _WTANK.static.BASE_PALETTE

_WTANK.static.ACTIVE_PALETTE = createColorVector (
  Colors.black,
  Colors.laser_dark_purple,
  Colors.laser_purple,
  Colors.kai_off_orange,
  Colors.kai_yellow,
  Colors.white
)

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:finalize ( parameters, bossSpawn )
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )

  self.velocity.vertical.gravity.maximum = 7.00
  self.invulBuildup = 0

  self.IS_IGNORING_PASSABLES = true

  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "wrecker-tank", 1 )
  self.sprite:addInstance ( "treads-front"     )
  self.sprite:addInstance ( "treads-back"      )
  self.sprite:addInstance ( "cannon"           )
  self.sprite:addInstance ( "midriff"          )
  self.sprite:addInstance ( "torso"            )
  self.sprite:addInstance ( "torso-back"       )
  self.sprite:addInstance ( "shoulder-front"   )
  self.sprite:addInstance ( "shoulder-back"    )
  self.sprite:addInstance ( "head"             )
  self.sprite:addInstance ( "eyes"             )
  self.sprite:addInstance ( "arms-close"       )
  self.sprite:addInstance ( "arms-far"         )  
  self.sprite:addInstance ( "thruster"         )
  self.sprite:addInstance ( "laser-overlay"    )
  self.sprite:addInstance ( "huge-laser"       )
  self.sprite:addInstance ( "huge-laser-ender" )

  self.sprite:change ( "treads-front",    "treads-front", 1, false )
  self.sprite:change ( "treads-back",     "treads-back",  1, false )
  self.sprite:change ( "cannon",          "body",         1, false )
  self.sprite:change ( "midriff",         "body",         2, false )
  self.sprite:change ( "torso",           "body",         3, false )
  self.sprite:change ( "torso-back",      "body",         6, false )
  self.sprite:change ( "shoulder-front",  "body",         5, false )
  self.sprite:change ( "shoulder-back",   "body",         4, false )
  self.sprite:change ( "head",            "head",         1, false )
  self.sprite:change ( "eyes",            "eyes",         1, false )
  self.sprite:change ( "arms-close",      "arms-anim",    1, false )
  self.sprite:change ( "arms-far",        "arms-anim",    1, false )

  self.angle        = 0
  self.treadFrame   = 1

  self.isFlinchable = false

  self.beams                = {}
  self.beamsToCallDown      = 0
  self.beamsToCallDownTimer = 0
  self.actionsWithoutRest   = 0
  self.nextActionTime       = 1
  self.desperationActivated = false

  self.layers  = self.class.LAYERS
  self.filters = self.class.FILTERS

  self.sensors = {
    
  }

  self.actionsSinceShuffle       = 0
  self.alwaysUsePaletteShader    = true
  self.BASE_PALETTE              = self.class.BASE_PALETTE
  self.ACTIVE_PALETTE            = self.class.ACTIVE_PALETTE

  self.HIT_SPARKS_DO_NOT_EMIT_FROM_MIDDLE = true

  self.HAS_IGNORED_TILES = {}

  if parameters then
    self.sprite:flip ( parameters.scaleX, nil )
  end

  self.bop          = { }
  self.bop.cannon   = 0
  self.bop.mid      = 0
  self.bop.torso    = 0
  self.bop.head     = 0
  self.bop.shoulderC= 0
  self.bop.shoulderF= 0
  self.bop.arms     = 0

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "grabbox", -1, -2, 126, 60, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")

  self:addCollider            ( "torsobox", 32, -42, 58, 50, self.class.HURTBOX_PROPERTIES )
  self:insertCollider         ( "torsobox" )

  self:addCollider            ( "headbox",  44, -58, 29, 32, self.class.HURTBOX_PROPERTIES )
  self:insertCollider         ( "headbox" )

  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.fistPos = {
    far = {
      total         = 0,
      fistX         = 0,
      fistY         = 0,
      bodyConnectX  = -90,
      bodyConnectY  = 39,
      wristConnectX = 0,
      wristConnectY = 0,
      shoulderX     = 0,
      shoulderY     = 0,
      baseX         = 2,
      baseY         = -30,
      x             = -170,
      y             = 14,
      min           = -300,
      max           = -100,
      posMod        = 27,
      posMod2       = 40,
      extraLeanX    = 0,
      shakeX        = 0,
      shakeDir      = 0,
      shakeY        = 0,
      side          = 1,
      wristShakeY   = 0,
      leanX         = 0,
      close         = false,
      arm_instance  = "arms-far",
      sh_instance   = "shoulder-back",
      --col = self.colliders.fistbox_left
    },
    close = {
      total         = 0,
      fistX         = 0,
      fistY         = 0,
      bodyConnectX  = 16,
      bodyConnectY  = 39,
      wristConnectX = 0,
      wristConnectY = 0,
      shoulderX     = 0,
      shoulderY     = 0,
      baseX         = -55,
      baseY         = -30,
      x             = 130,
      y             = 14,
      min           = 55,
      max           = 300,
      posMod        = 27,
      posMod2       = -40,
      extraLeanX    = 0,
      shakeX        = 0,
      shakeDir      = 0,
      shakeY        = 0,
      side          = -1,
      wristShakeY   = 0,
      leanX         = 0,
      close         = true,
      arm_instance  = "arms-close",
      sh_instance   = "shoulder-front",
      --col = self.colliders.fistbox_right
    },
  }

  self.leanX = 0
  self.leanY = 0

  self.defaultStateFromFlinch = nil
  self.state.isBoss           = true
  if parameters and parameters.bossRush then
    self.state.isBossRushSpawn = true

    self.bossRushDropX = 59
    self.bossRushDropY = -8
  end

  self.listener               = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)
  self.state.isOpeningStageBoss = true

  self._IS_TARGET_OBJECT = true

  if bossSpawn then
    self.CLEAR_FLAG   = bossSpawn.flag
    self.CLEAR_SCRIPT = bossSpawn.script
  end

  self:gotoState ( "PRELOAD_STATE" )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Misc                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:activate ( )
  self.health      = 96
  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "opening", self.health )
  self.activated   = true
end

function _WTANK:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end
end

function _WTANK:isDrawingWithPalette ( )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Animation handling -------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:manageChainAnimation ( )
  if self.state.isLaunched then
    self.sprite:change ( 1, "spin", 1 )
    self.sprite:stop   ( 1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _WTANK:getDeathMiddlePoint ( )
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
function _WTANK:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  self.bop.cannon   = math.max ( self.bop.cannon   - 0.5, 0 )
  if self.bop.cannon == 0 then
    self.bop.mid      = math.max ( self.bop.mid      - 0.5, 0 )
  end
  if self.bop.mid == 0 then
    self.bop.torso    = math.max ( self.bop.torso    - 0.5, 0 )
  end
  if self.bop.torso == 0 then
    self.bop.head     = math.max ( self.bop.head     - 0.5, 0 )
    self.bop.shoulderC= math.max ( self.bop.shoulderC- 0.5, 0 )
    self.bop.shoulderF= math.max ( self.bop.shoulderF- 0.5, 0 )
  end
  if self.bop.shoulderF == 0 or self.bop.shoulderC == 0 then
    self.bop.arms = math.max ( self.bop.arms - 0.5, 0 )
  end

  if not self.sprite:getAnimation ( "huge-laser" ) then
    self.state.hugeLaser = false
  end

  self:updateTread ( )

  --[[
  if UI.game.isUpDown ( ) then
    self.fistPos.close.fistY = self.fistPos.close.fistY - 2
  elseif UI.game.isDownDown ( ) then
    self.fistPos.close.fistY = self.fistPos.close.fistY + 2
  end

  if UI.game.isLeftDown ( ) then
    self.fistPos.close.fistX = self.fistPos.close.fistX - 2
  elseif UI.game.isRightDown ( ) then
    self.fistPos.close.fistX = self.fistPos.close.fistX + 2
  end]]

  --[[
  if BUILD_FLAGS.DEBUG_BUILD then
    if UI.kb.isPress ( "f" ) then
      self.sprite:mirrorX ( )
      if not self.translatedFirst then
        self.translatedFirst = true
        self:translate ( -100, 0 )
      end
    end
  end]]

  self.sprite:setFrame ( "treads-front", math.ceil ( self.treadFrame ), false )
  self.sprite:setFrame ( "treads-back",  math.ceil ( self.treadFrame ), false )

  if not self.isStunned then
    if self.sprite:getScaleX() > 0 then
      self.colliders.torsobox.rect.x =  34
      self.colliders.torsobox.rect.y = -42

      self.colliders.headbox.rect.x  =  55
      self.colliders.headbox.rect.y  = -62
    else
      self.colliders.torsobox.rect.x =  32
      self.colliders.torsobox.rect.y = -42

      self.colliders.headbox.rect.x  =  47
      self.colliders.headbox.rect.y  = -62
    end
  end

  if self.stateVars and self.stateVars.finalKillTimer then
    self.stateVars.finalKillTimer = self.stateVars.finalKillTimer -1
    if self.stateVars.finalKillTimer == 19 then
      local mx, my = self:getMiddlePoint()

      local sx = self.sprite:getScaleX()
      if sx == 1 then
        mx = mx + 65 
        my = my - 19
      else
        mx = mx + 55
        my = my - 19
      end

      local l      = self.layers.sprite()+14
      mx,my        = mx + self.velocity.horizontal.current * self.velocity.horizontal.direction ,
                     my + self.velocity.vertical.current
      GAMESTATE.addFreezeFrames ( 20, Colors.kai_dark_red, mx, my )
    end

    if self.stateVars.finalKillTimer == 0 then
      GameObject:stopSlowdown ()
      self.stateVars.finalKillTimer = nil
    end
  end

  self:updateLocations           ( )

  if self.activated and self:isInState ( nil ) then
    --self.timer = self.timer + 1
    --if self.nextActionTime < self.timer then
    self:pickAction()
    --end
  end

  if not (self.isChainedByHookshot) then
    self:tick    ( dt )
  end

  if not self.isStunned then
    self:applyFistDamage ( )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:updateContactDamageStatus ( )
  self:updateShake               ( )
  self.sprite:update             ( dt )
end

function _WTANK:tick ( )
  self:applyPhysics  ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_WTANK.static.ACTIONS = {
  "DESPERATION_ACTIVATION", -- 1 , why is there a desperation?
  "PUNCH",                  -- 2
  "JUMP",                   -- 3
  "MOUTH_CANNON",           -- 4
  "BEAM_CANNON",            -- 5
  "DASH",                   -- 6
  "SHUFFLE",                -- 7
}

_WTANK.static.ACTION_GROUP = {
  ground = { 4, 5, 6 },
  middle = { 2, 4, 3 },
  top    = { 2, 4, 3 },
}

function _WTANK:pickAction (recursion, px, py, mx, my)
  if not self.playerIsKnownToBeAlive then return end
  if self.forcedDesperation then
    if not self.actionsSinceDesperation then
      self.actionsSinceDesperation = 0
    end
    self.actionsSinceDesperation = self.actionsSinceDesperation + 1
    if self.actionsSinceDesperation > 5 then
      self.forceDesperation = RNG:n() < (0.04 + (self.actionsSinceDesperation-5)*0.125)
    end
  end
  if (self.forceDesperation) then
    -- Desperation phase
    self.forceDesperation         = false
    self.actionsSinceDesperation  = 0
    action                        = 1
  end

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
  local forcedAction      = false

  if not self.startingY then
    self.startingY = self:getY()
  end


  -- these are action groups, not actions themselves
  if not self.pickedActionsList then
    self.actionsPerformed     = 0
    self.pickedActionsList    = { 
      1,
      1,
      2,
      2,
      3,
    }
  elseif #self.pickedActionsList == 0 then
    self.pickedActionsList[1] = 1
    self.pickedActionsList[2] = 1
    self.pickedActionsList[3] = 2
    self.pickedActionsList[4] = 2
    self.pickedActionsList[5] = 3
  end

  local action = 0
  if self.lastAction ~= 3 then
    if self.sprite:getScaleX ( ) > 0 then
      if mx > px - 8 then
        action       = 3
        forcedAction = true
      end
    else
      if mx < px - 107 then
        action       = 3
        forcedAction = true
      end
    end 
  end

  --if action ~= 3 then
  --  action = 3 -- debug value goes here
  --end

  if action <= 0 then
    local actionGroup = table.remove ( self.pickedActionsList, RNG:range ( 1, #self.pickedActionsList ) )
    if py > my + 8 then -- ground
      --print("ground")
      action = self.class.ACTION_GROUP.ground[actionGroup]
      if action == 4 and RNG:n() > 0.525 then
        action = 2
      end
    elseif py > my - 42 then
      --print("middle")
      action = self.class.ACTION_GROUP.middle[actionGroup]
    else
      --print("top")
      action = self.class.ACTION_GROUP.top[actionGroup]
    end
  end

  if action == 3 then
    if py > my then
      action = 6
    end
  end

  if recursion then
    self.actionsSinceLastShuffle = 0
    self.lastAction              = 7
  end

  if not self.lastAction then
    self.lastAction = action
    action          = 7
  else
    self.lastAction          = action
    self.actionsSinceShuffle = self.actionsSinceShuffle + 1
    if self.actionsSinceShuffle > 1 and action ~= 3 then
      self.actionsSinceShuffle = 0
      action = 7
    end
  end

  if not forcedAction then
    if action < 7 then
      if self.actionsPerformed < 4 and (action == 3 or action == 6) then
        self.actionsSinceShuffle = 0
        self.lastAction          = 7
        --print("repick", self.actionsPerformed)
        self:pickAction ( true, px, py, mx, my )
        return
      end

      self.actionsPerformed = self.actionsPerformed + 1
    end
  end
  self:gotoState( self.class.ACTIONS[action], px, py, mx, my )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end
end

function _WTANK:endAction ( finishedNormally, forceWait, clearActions )
  if clearActions then
    self.actionsWithoutRest = 0
  end
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest < 3 and not forceWait then
      self.nextActionTime     = self.desperationActivated and 12 or 18
    else
      self.nextActionTime     = self.desperationActivated and 17 or 23
      self.actionsWithoutRest = 0
    end
  end
end

function _WTANK:getLocations ()
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _WTANK:updateLocations()
  local x, y = GlobalObserver:single ("GET_PLAYER_MIDDLE_POINT" )
  if x then
    self.lastPlayerX, self.lastPlayerY = x, y
  end
  self.playerIsKnownToBeAlive                  = GlobalObserver:single ("IS_PLAYER_ALIVE")
  self.lastKnownPlayerX, self.lastKnownPlayerY = self.lastPlayerX, self.lastPlayerY
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Punch --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PUNCH = _WTANK:addState ( "PUNCH" )

function _PUNCH:enteredState ( px, py, mx, my )
  my = my - 20
  py = py - 10

  self.stateVars.lean = {
    f_fistX     = 0,
    f_fistY     = 0,
    c_fistX     = 0,
    c_fistY     = 0,
    f_shoulderX = 0,
    f_shoulderY = 0,
    c_shoulderX = 0,
    c_shoulderY = 0,
    leanX       = 0,
    leanY       = 0,
  }
  local sx = self.sprite:getScaleX()
  self.stateVars.lean.tween 
    = Tween.new ( 
        24, 
        self.stateVars.lean, 
        { 
          f_fistX     = sx > 0 and 10 or -10, 
          f_fistY     = 8, 
          f_shoulderX = sx > 0 and 4 or -4,
          f_shoulderY = 2,
          c_fistX     = sx > 0 and -20 or 20, 
          c_fistY     = -8,
          leanX       = -4,
          leanY       = -2,
        }, 
        "outQuad" 
      ) 

  self.stateVars.shakyHandTargetX = sx > 0 and 10 or -10
  self.stateVars.shakyHandTargetY = 8

  self.stateVars.fist = self.fistPos.close

  self.sprite:change ( self.stateVars.fist.arm_instance, "arms-anim", 2, true )
  self.sprite:resume ( self.stateVars.fist.arm_instance, true )

  self.stateVars.fist.active = true

  self.bop.torso     = 1
  self.bop.head      = 1
  self.bop.shoulderC = 2

  self.stateVars.reachX = 0
  self.stateVars.reachY = 0

  self.velocity.horizontal.direction = sx

  Audio:playSound ( SFX.gameplay_crane_impact, 0.8 )
end

function _PUNCH:exitedState ( )
  self.stateVars.fist.active = false

  if self.health <= 0 then return end
  self.fistPos.close.fistX = 0
  self.fistPos.close.fistY = 0

  self.fistPos.close.shoulderX  = 0
  self.fistPos.close.shoulderY  = 0

  self.fistPos.far.fistX = 0
  self.fistPos.far.fistY = 0

  self.fistPos.far.shoulderX = 0
  self.fistPos.far.shoulderY = 0

  self.leanX = 0
  self.leanY = 0

  self.stateVars.reachX = 0
  self.stateVars.reachY = 0
end

function _PUNCH:tick ( )
  self.fistPos.close.fistX = self.stateVars.lean.c_fistX
  self.fistPos.close.fistY = self.stateVars.lean.c_fistY

  self.fistPos.close.shoulderX  = self.stateVars.lean.c_shoulderX 
  self.fistPos.close.shoulderY  = self.stateVars.lean.c_shoulderY

  self.fistPos.far.fistX = self.stateVars.lean.f_fistX
  self.fistPos.far.fistY = self.stateVars.lean.f_fistY

  self.fistPos.far.shoulderX = self.stateVars.lean.f_shoulderX 
  self.fistPos.far.shoulderY = self.stateVars.lean.f_shoulderY

  self.leanX = self.stateVars.lean.leanX
  self.leanY = self.stateVars.lean.leanY

  -- update tween
  self.stateVars.lean.tween:update(1)

  self.timer = self.timer - 1

  if not self.stateVars.startedSwing then
    if self.stateVars.lean.tween:isFinished() then
      local sx   = self.sprite:getScaleX ( )

      if not self.stateVars.shakyHand then
        self.stateVars.shakyHand = 0
      end
      self.stateVars.shakyHand = self.stateVars.shakyHand + -sx * 0.5
      if self.stateVars.shakyHand < -2 or self.stateVars.shakyHand > 2 then
        self.stateVars.shakyHand = 0
      end
      self.fistPos.close.fistX  = self.fistPos.close.fistX + self.stateVars.shakyHand 
    end

    if self.timer > -54 then
      return
    end

    self.stateVars.startedSwing = true
    self:calcPunchDir ( )
    self.timer = 30

    local sx = self.sprite:getScaleX()
    self.stateVars.lean.tween 
      = Tween.new ( 
          30, 
          self.stateVars.lean, 
          { 
            f_fistX     = sx > 0 and -8 or 8, 
            f_fistY     = -2, 
            f_shoulderX = sx > 0 and -2 or 2,
            f_shoulderY = -2,
            c_fistX     = sx > 0 and 20 or -20, 
            c_fistY     = 4,
            leanX       = 4,
            leanY       = 2,
          }, 
          "outBack" 
        ) 
    --return

    Audio:playSound ( SFX.gameplay_scrap_golem_attack, 1.1 )
    self.stateVars.shakyHandTargetX = self.fistPos.close.fistX
    self.stateVars.shakyHandTargetY = self.fistPos.close.fistY
  end

  if not self.stateVars.reachedMaxReach then
    self.stateVars.reachX = self.stateVars.reachX + self.stateVars.speedX 
    self.stateVars.reachY = self.stateVars.reachY + self.stateVars.speedY

    if self.stateVars.reachY > 50 then
      local px, py, mx, my = self:getLocations()
      GameObject:spawn ( 
        "laser_beam", 
        px, 
        py, 
        1,
        420
      )
      GameObject:spawn ( 
        "laser_beam", 
        px, 
        py, 
        9,
        420
      )
      self.stateVars.reachedMaxReach = true
      Camera:startShake ( 0, 3, 20, 0.25 )
      self.timer = 1
      Audio:playSound ( SFX.gameplay_crane_impact )
      Audio:playSound ( SFX.gameplay_crash_impact, 0.9 )
    elseif self.timer <= 0 then
      Audio:playSound ( SFX.gameplay_crane_impact )
      local px, py, mx, my = self:getLocations()
      GameObject:spawn ( 
        "laser_beam", 
        px, 
        py, 
        1,
        420
      )
      GameObject:spawn ( 
        "laser_beam", 
        px, 
        py, 
        9,
        420
      )
      self.stateVars.reachedMaxReach = true
      self.timer           = 1
    end

    if not self.stateVars.reachedMaxReach and GetLevelTime()%4 == 0 then
      Audio:playSound ( SFX.gameplay_crane_chain )
    end

    self.fistPos.close.fistX = self.stateVars.reachX + self.stateVars.shakyHandTargetX
    self.fistPos.close.fistY = self.stateVars.reachY + self.stateVars.shakyHandTargetY

  elseif not self.stateVars.retracting then
    local sx   = self.sprite:getScaleX ( )
    if not self.stateVars.shakyHand then
      self.stateVars.shakyHand = 0
    end
    self.stateVars.shakyHand = self.stateVars.shakyHand + -sx * 0.5
    if self.stateVars.shakyHand < -2 or self.stateVars.shakyHand > 2 then
      self.stateVars.shakyHand = 0
    end
    self.fistPos.close.fistX  = self.stateVars.reachX + self.stateVars.shakyHandTargetX + self.stateVars.shakyHand 
    self.fistPos.close.fistY  = self.stateVars.reachY + self.stateVars.shakyHandTargetY

    if self.timer <= 0 then
      self.stateVars.retracting = true

      self.stateVars.lean.reachX = self.stateVars.reachX
      self.stateVars.lean.reachY = self.stateVars.reachY

      local sx = self.sprite:getScaleX ( )
      self.stateVars.lean.tween 
        = Tween.new ( 
            25, 
            self.stateVars.lean, 
            { 
              f_fistX     = 0, 
              f_fistY     = 0, 
              f_shoulderX = 0,
              f_shoulderY = 0,
              c_fistX     = 0,--sx > 0 and 20 or -20, 
              c_fistY     = 0,--8,
              leanX       = 0,
              leanY       = 0,
              reachX      = -self.stateVars.shakyHandTargetX,
              reachY      = -self.stateVars.shakyHandTargetY,
            }, 
            "inQuad" 
          ) 
    end
  elseif not self.stateVars.bopped then
    self.stateVars.reachX = self.stateVars.lean.reachX
    self.stateVars.reachY = self.stateVars.lean.reachY

    self.fistPos.close.fistX = self.stateVars.reachX + self.stateVars.shakyHandTargetX
    self.fistPos.close.fistY = self.stateVars.reachY + self.stateVars.shakyHandTargetY

    if not self.stateVars.reachedMaxReach and GetLevelTime()%4 == 0 then
      Audio:playSound ( SFX.gameplay_crane_chain )
    end

    --self.fistPos.close.fistX = self.fistPos.close.fistX + self.stateVars.reachX + self.stateVars.shakyHandTargetX
    --self.fistPos.close.fistY = self.fistPos.close.fistY + self.stateVars.reachY + self.stateVars.shakyHandTargetY

    if self.stateVars.lean.tween:isFinished ( ) then 
      self.sprite:rewind ( self.stateVars.fist.arm_instance, true )
      Audio:playSound ( SFX.gameplay_crane_impact, 0.8 )
      self:smallBop  ( )
      self.stateVars.bopped = true
      self.timer            = 1
    end
  else
    if self.timer <= 0 then
      self:gotoState ( nil )
    end
  end

end

function _PUNCH:calcPunchDir ( )

  local px, py, mx, my = self:getLocations()
  if not px then
    return
  end

  my = my - 20 + self.stateVars.fist.fistY
  py = py - 18

  local sx            = self.sprite:getScaleX ( )
  if sx > 0 then
    mx = mx - 32 - self.stateVars.fist.fistX
  else
    mx = mx + 55 + self.stateVars.fist.fistX
    py = py + 7
  end

  self.stateVars.fistMidpointX = mx
  self.stateVars.fistMidpointY = my

  local angle          = math.angle ( mx, my, px, py )
  local speedX, speedY = math.cos   ( angle ), math.sin ( angle )

  local speedX = speedX * 5.75
  local speedY = speedY * 5.75

  if sx > 0 then
    if speedX < 0.5 then
      speedX = 0.5
      speedY = 4.5 * math.sign(speedY)
    end
  else
    if speedX > -0.5 then
      speedX = -0.5
      speedY = 4.5 * math.sign(speedY)
    end
  end

  self.stateVars.speedX    = speedX
  self.stateVars.speedY    = speedY
  self.stateVars.speedDir  = self.sprite:getScaleX ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §fist damage --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:applyFistDamage ( )
  local x,y = self:getPos()
  local sx  = self.sprite:getScaleX()
  if self.fistPos.far.active then
    self:applySingleFistDamage ( self.fistPos.far,   x, y, sx )
  end
  if self.fistPos.close.active then
    self:applySingleFistDamage ( self.fistPos.close, x, y, sx )
  end
end

function _WTANK:applySingleFistDamage ( fist, x, y, sx )
  local x, y = x+fist.fistX + fist.baseX * sx + (sx > 0 and 82 or 0),
               y+fist.fistY + fist.baseY - 4

  local cols, len
  if sx > 0 then
    --GFX:drawRect ( self.layers.sprite() + 100, x+6, y+14, 21, 21, Colors.kai_red ) 
    cols, len = Physics:queryRect (
      x+6, 
      y+14, 
      21, 
      21
    )
  else
    --GFX:drawRect ( self.layers.sprite() + 100, x+14, y+14, 21, 21, Colors.kai_red )
    cols, len = Physics:queryRect (
      x+6, 
      y+14, 
      21, 
      21
    ) 
  end

  if len and len > 0 then
    for i = 1, len do
      if cols[i].isPlayer then
        GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_WEAK, "weak", self.sprite:getScaleX ( ) )
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Jump ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _JUMP = _WTANK:addState ( "JUMP" )

function _JUMP:enteredState ( )
  self.bop.mid       = 1
  self.bop.torso     = 1
  self.bop.head      = 0
  self.bop.shoulderF = 1
  self.bop.shoulderC = 1

  self.velocity.vertical.update = false

  self.velocity.horizontal.direction = self.sprite:getScaleX ( )

  self.stateVars.initialDelay = 1

  self.timer = 1

  self.flySfx = 0

  self.sprite:change ( "thruster", "thuster", 1, true )
  Audio:playSound    ( SFX.gameplay_lava_dumper_drop, 1.1 )
end

function _JUMP:exitedState ( )
  self.sprite:change ( "thruster", nil )
  self.velocity.vertical.update    = true
  self.velocity.vertical.current   = 0
  self.velocity.horizontal.current = 0
  self.angle                       = 0

  if self.health <= 0 then 
    Audio:stopSound ( SFX.gameplay_wrecker_tank_fly )
    return 
  end

  self.fistPos.close.fistX = 0
  self.fistPos.close.fistY = 0

  self.fistPos.far.fistX = 0
  self.fistPos.far.fistY = 0
end

function _JUMP:tick ( )
  local mx,my = self:getMiddlePoint   ( )
  local sx    = self.sprite:getScaleX ( )
  if sx < 0 then
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx+44+self.velocity.horizontal.current*self.velocity.horizontal.direction, 
      my+42, 
      math.rsign(), 
      1, 
      RNG:n()*0.7,
      1.5+RNG:n()*1.0
    )
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx+77+self.velocity.horizontal.current*self.velocity.horizontal.direction, 
      my+42, 
      math.rsign(), 
      1, 
      RNG:n()*0.7,
      1.5+RNG:n()*1.0
    )
  else
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx+23+self.velocity.horizontal.current*self.velocity.horizontal.direction, 
      my+44, 
      math.rsign(), 
      1, 
      RNG:n()*0.7,
      1.5+RNG:n()*1.0
    )
    Particles:addFromCategory ( 
      "directionless_dust", 
      mx+53+self.velocity.horizontal.current*self.velocity.horizontal.direction, 
      my+44, 
      math.rsign(), 
      1, 
      RNG:n()*0.7,
      1.5+RNG:n()*1.0
    )
  end

  if self.stateVars.initialDelay > 0 then
    self.stateVars.initialDelay = self.stateVars.initialDelay - 1
    return
  end

  self.timer = self.timer - 1
  if not self.stateVars.initialBop then
    self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.5, -2 )
    if self.timer <= 0 then
      self.stateVars.initialBop = true
      self.timer = 30
    end
  elseif not self.stateVars.startForwardMovement then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, -1 )
    self.velocity.vertical.current   = self.velocity.vertical.current + 0.125
    if self.timer <= 0 then
      self.stateVars.startForwardMovement = true
      self.timer = 40
    end
  elseif not self.stateVars.startFalling then
    if self.velocity.horizontal.current < 0 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 9 )
    else
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 9 )
    end

    self.velocity.vertical.current   = math.max ( self.velocity.vertical.current   - 0.125, 0 )

    local x   = self:getX    ( )
    local cx  = Camera:getX  ( )
    local pos = x - cx

    if self.velocity.horizontal.direction > 0 then
      self.angle = self.angle - 0.001

      self.fistPos.close.fistX = self.fistPos.close.fistX - 0.125
      self.fistPos.close.fistY = self.fistPos.close.fistY + 0.125

      self.fistPos.far.fistX = self.fistPos.far.fistX - 0.125
      self.fistPos.far.fistY = self.fistPos.far.fistY + 0.125

    else
      self.angle = self.angle + 0.001

      self.fistPos.close.fistX = self.fistPos.close.fistX + 0.125
      self.fistPos.close.fistY = self.fistPos.close.fistY + 0.125

      self.fistPos.far.fistX = self.fistPos.far.fistX + 0.125
      self.fistPos.far.fistY = self.fistPos.far.fistY + 0.125
    end

    if not Camera:inView ( self, 120 ) then
      self:gotoState ( "DASH", nil, nil, nil, nil, true )
    end
  else
    if self.leanX < 0 then
      self.leanX = math.min ( self.leanX + 0.5, 0 )
    elseif self.leanX > 0 then
      self.leanX = math.max ( self.leanX - 0.5, 0 )
    end

    if self.angle < 0 then
      self.angle = math.min ( self.angle + 0.002, 0 )
    elseif self.angle > 0 then
      self.angle = math.max ( self.angle - 0.002, 0 )
    end

    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    self.velocity.vertical.current   = self.velocity.vertical.current + 0.25
  end

  self:applyPhysics ( )

  if _JUMP.hasQuitState(self) then return end

  if self.flySfx % 70 == 0 then
    Audio:playSound ( SFX.gameplay_wrecker_tank_fly )
  end

  self.flySfx = self.flySfx + 1

  if self.stateVars.startFalling and self.state.isGrounded then
    self:gotoState ( nil )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Dash ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DASH = _WTANK:addState ( "DASH" )

function _DASH:enteredState ( px, py, mx, my, outOfJump )
  self.shuffledPosition    = false
  self.actionsSinceShuffle = 0

  self.fistPos.close.fistX = 0
  self.fistPos.close.fistY = 0

  self.fistPos.far.fistX = 0
  self.fistPos.far.fistY = 0

  if outOfJump then
    local x = self:getX()
    self.sprite:mirrorX ( )
    self.velocity.horizontal.direction = self.sprite:getScaleX ( )

    self:setActualPos ( x, self.startingY )
    self.timer = 15

    self.stateVars.returnTrip = true
    self.stateVars.volLevel   = 1
    return
  end

  Audio:playSound ( SFX.gameplay_bit_dash_1, 0.90 )

  self.bop.mid       = 1
  self.bop.torso     = 1
  self.bop.head      = 0
  self.bop.shoulderF = 1
  self.bop.shoulderC = 1

  self.velocity.horizontal.direction = self.sprite:getScaleX ( )
  self.timer           = 30
  self.stateVars.tread = 0

  self.stateVars.trulyStartedMoving = 1
end

function _DASH:exitedState ( )
  self.velocity.horizontal.current = 0
end

function _DASH:tick ( )
  if self.stateVars.returnTrip and self.stateVars.volLevel then
    self.stateVars.volLevel = math.max ( self.stateVars.volLevel - 0.1, 0 )
    Audio:setSoundVolumeIndividually   ( SFX.gameplay_wrecker_tank_fly, self.stateVars.volLevel ) 
  end

  if self.stateVars.stopped then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:gotoState ( nil )
    end
  elseif self.stateVars.returnTrip then
    self:returnTripFunc ()
  else
    self:goingTripFunc ( )
  end

  self:applyPhysics ( )
end

function _DASH:updateTread ( )
  if self.stateVars.tread then
    self:updateTreadActual ( self.stateVars.tread )
  else
    self:updateTreadActual ( )
  end
end

function _DASH:goingTripFunc ( )

  local x,y = self:getPos( )
  local sx  = self.sprite:getScaleX()
  if sx > 0 then
    for i = 1, math.ceil(self.stateVars.trulyStartedMoving) do
      if i % 2 == 1 then
        Particles:addFromCategory ( "landing_dust", x+(i-1)*12+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  0.25, -0.1 )
      end
    end
  else
    for i = 1, math.ceil(self.stateVars.trulyStartedMoving) do
      if i % 2 == 1 then
        Particles:addFromCategory ( "landing_dust", x+110-(i-1)*12+RNG:range(1,4)*RNG:rsign(), y+39, -1, 1, -0.25, -0.1 )
      end
    end
  end

  if not self.stateVars.startedMoving then
    self.stateVars.tread = math.min ( self.stateVars.tread + 0.125, 1.0 )

    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.stateVars.startedMoving = true
      self.timer                   = 1
    end
  else

    self.stateVars.tread = math.min ( self.stateVars.tread + 0.25, 3.0 )
    self.timer = self.timer -1
    if self.timer > 10 then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, -2 )
    elseif self.timer > 0 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 9 )
    else
      self.stateVars.trulyStartedMoving = math.min ( self.stateVars.trulyStartedMoving + 0.5, 8 )
      self.velocity.horizontal.current  = math.min ( self.velocity.horizontal.current + 0.125, 9 )
    end

    --if self.timer == -5 then
    --  Audio:playSound ( SFX.gameplay_bit_dash_3 )
    --end

    if self.velocity.horizontal.current > 0 and Camera:inView ( self, 80 ) and math.abs(self.timer) % 4 == 0 then
      Camera:startShake ( 0, 1, 20, 0.25 )
    end

    if self.velocity.horizontal.direction > 0 then
      if self.velocity.horizontal.current > 4 then
        self.leanX               = self.leanX + 0.125
      end
      self.fistPos.close.fistX = self.fistPos.close.fistX - 0.125
      self.fistPos.close.fistY = self.fistPos.close.fistY + 0.125

      self.fistPos.far.fistX = self.fistPos.far.fistX - 0.125
      self.fistPos.far.fistY = self.fistPos.far.fistY + 0.125
    else
      if self.velocity.horizontal.current > 4 then
        self.leanX               = self.leanX + 0.125
      end
      self.fistPos.close.fistX = self.fistPos.close.fistX + 0.125
      self.fistPos.close.fistY = self.fistPos.close.fistY + 0.125

      self.fistPos.far.fistX = self.fistPos.far.fistX + 0.125
      self.fistPos.far.fistY = self.fistPos.far.fistY + 0.125
    end

    if not Camera:inView ( self, 120 ) then
      self.stateVars.returnTrip = true
      self.stateVars.tread      = nil

      self.sprite:mirrorX ( )
      self.velocity.horizontal.direction = -self.velocity.horizontal.direction

      self.fistPos.close.fistX = 0
      self.fistPos.close.fistY = 0

      self.fistPos.far.fistX = 0
      self.fistPos.far.fistY = 0
      self.leanX             = 0
      self.timer             = 10
    end
  end
end

function _DASH:returnTripFunc ( )
  self.timer = self.timer - 1
  if self.timer > 0 then
    return
  end

  local x,y = self:getPos( )
  local sx  = self.sprite:getScaleX()
  if sx > 0 then
    Particles:addFromCategory ( "landing_dust", x+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  0.25, -0.1 )
  else
    Particles:addFromCategory ( "landing_dust", x+110+RNG:range(1,4)*RNG:rsign(), y+39, -1, 1, -0.25, -0.1 )
  end

  local x  = self:getX   ( )
  local cx = Camera:getX ( )

  --if (x < (cx + 15)) 
  --or (x > (cx + GAME_WIDTH - 15 - 126)) then
  if (x < (cx - 11)) 
  or (x > (cx + GAME_WIDTH + 14 - 126)) then
    self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 3 )
  else
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    if not self.stateVars.slowingDown then
      self:smallBop ( )
    end
    self.stateVars.slowingDown = true
  end

  if self.velocity.horizontal.current > 0 and Camera:inView ( self, 80 ) and math.abs(self.timer) % 4 == 0 then
    Camera:startShake ( 0, 1, 20, 0.25 )
  end

  if (self.velocity.horizontal.current <= 0) and self.stateVars.slowingDown then
    self.stateVars.stopped = true
    self.timer             = 1
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shuffle             ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SHUFFLE = _WTANK:addState ( "SHUFFLE" )

function _SHUFFLE:enteredState ( )
  self.shuffledPosition = not self.shuffledPosition
  local sx              = self.sprite:getScaleX()

  if sx > 0 then
    self.velocity.horizontal.direction = self.shuffledPosition and sx or -sx
  else
    self.velocity.horizontal.direction = self.shuffledPosition and sx or -sx
  end

  self.timer = 5
end

function _SHUFFLE:exitedState ( )

end

function _SHUFFLE:tick ( )
  self.timer = self.timer - 1
  if self.timer > 0 and not self.stateVars.init then
    return
  end
  if not self.stateVars.init then
    self.stateVars.init = true
    self.timer          = self.shuffledPosition and 34 or 32
  end

  if self.velocity.horizontal.direction > 0 then
    local bl = self.layers.bottom     ( )
    local x,y = self:getPos           ( )
    local sx  = self.sprite:getScaleX ( )
    if sx > 0 then
      Particles:addFromCategory ( "landing_dust", x+RNG:range(1,4)*RNG:rsign(),    y+39,  1, 1,   0.25, -0.1 )
    else
      Particles:addFromCategory ( "landing_dust", x+13+RNG:range(1,4)*RNG:rsign(), y+39,  1, 1,  -0.25, -0.1 )
      Particles:addFromCategory ( "landing_dust", x-3+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  -0.25, -0.1, bl )
    end
  elseif self.velocity.horizontal.direction < 0 then
    local bl = self.layers.bottom     ( )
    local x,y = self:getPos( )
    local sx  = self.sprite:getScaleX()
    if sx > 0 then
      Particles:addFromCategory ( "landing_dust", x+100+RNG:range(1,4)*RNG:rsign(),  y+39,  -1, 1,  0.25, -0.1 )
      Particles:addFromCategory ( "landing_dust", x+124+RNG:range(1,4)*RNG:rsign(),  y+39,  -1, 1,  0.25, -0.1, bl )
    else
      Particles:addFromCategory ( "landing_dust", x+110+RNG:range(1,4)*RNG:rsign(),  y+39,  -1, 1, -0.25, -0.1 )
    end
  end

  if not self.stateVars.stopping then
    self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 2 )
    if math.abs(self.timer) % 4 == 0 then
      Camera:startShake ( 0, 1, 20, 0.25 )
    end

    if self.timer <= 0 then
      self:smallBop ( )
      self.stateVars.stopping = true
    end
  else
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )

    if self.velocity.horizontal.current == 0 then
      self:gotoState ( nil )
    end
  end

  self:applyPhysics()
end

function _SHUFFLE:updateTread ( ) 
  if self.sprite:getScaleX ( ) > 0 then
    if self.velocity.horizontal.direction > 0 then
      self:updateTreadActual ( self.velocity.horizontal.current )
    else
      self:updateTreadActual ( -self.velocity.horizontal.current )
    end
  else
    if self.velocity.horizontal.direction > 0 then
      self:updateTreadActual ( -self.velocity.horizontal.current )
    else
      self:updateTreadActual ( self.velocity.horizontal.current )
    end
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §MOUTH CANNON -------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _MOUTH = _WTANK:addState ( "MOUTH_CANNON" )

function _MOUTH:enteredState ( )
  self.stateVars.lean = {
    fistX     = 0,
    fistY     = 0,
    shoulderX = 0,
    shoulderY = 0,
    leanX     = 0,
    leanY     = 0,
  }
  local sx = self.sprite:getScaleX()
  self.stateVars.lean.tween 
    = Tween.new ( 
        35, 
        self.stateVars.lean, 
        { 
          fistX     = sx > 0 and -13 or 13, 
          fistY     = 10, 
          shoulderX = sx > 0 and -2 or 2,
          shoulderY = 2,
          leanX     = 3,
          leanY     = 2,
        }, 
        "outBack" 
      ) 


  self.timer           = 1
  self.stateVars.shots = 0

  self.sprite:change ( "head", "mouth-cannon", 2, true )
  self.sprite:change ( "eyes", nil )

  Audio:playSound ( SFX.gameplay_cannon_open )
end

function _MOUTH:exitedState ( )

  if self.health <= 0 then return end

  self.fistPos.close.fistX = 0
  self.fistPos.close.fistY = 0

  self.fistPos.far.fistX = 0
  self.fistPos.far.fistY = 0

  self.fistPos.far.shoulderX = 0
  self.fistPos.far.shoulderY = 0

  self.leanX = 0
  self.leanY = 0
end

function _MOUTH:tick ( )
  self.fistPos.close.fistX = self.stateVars.lean.fistX
  self.fistPos.close.fistY = self.stateVars.lean.fistY

  self.fistPos.close.shoulderX  = self.stateVars.lean.shoulderX 
  self.fistPos.close.shoulderY  = self.stateVars.lean.shoulderY

  self.fistPos.far.fistX = self.stateVars.lean.fistX
  self.fistPos.far.fistY = self.stateVars.lean.fistY

  self.fistPos.far.shoulderX = self.stateVars.lean.shoulderX 
  self.fistPos.far.shoulderY = self.stateVars.lean.shoulderY

  self.leanX = self.stateVars.lean.leanX
  self.leanY = self.stateVars.lean.leanY

  if not self.stateVars.started then
    self.stateVars.lean.tween:update ( 1 )

    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.stateVars.started = true
    end
  elseif not self.stateVars.finished then
    self.timer = self.timer + 1
    if self.timer > 0 then
      self:shoot ()
      self.bop.head    = 2
      self.bop.torso   = 1
      self.timer           = 0
      self.stateVars.shots = self.stateVars.shots + 1
      if self.stateVars.shots >= 184-self.health*2+12 and not self.stateVars.finished then
        self.stateVars.lean.tween 
          = Tween.new ( 
              35, 
              self.stateVars.lean, 
              { 
                fistX     = 0, 
                fistY     = 0, 
                shoulderX = 0,
                shoulderY = 0,
                leanX     = 0,
                leanY     = 0,
              }, 
              "inOutQuad" 
            ) 

        Audio:playSound ( SFX.gameplay_cannon_close )
        self.sprite:change ( "head", "mouth-cannon-close" )
        self.stateVars.finished = true
        self.timer              = 1
      end
    end
  end

  if self.stateVars.finished then
    self.stateVars.lean.tween:update ( 1 )
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self:gotoState ( nil )
    end
  end
end

function _MOUTH:shoot ()
  local sx          = self.sprite:getScaleX()
  local x, y        = self:getMiddlePoint()
  x                 = x - 6
  y                 = y - 49
  if sx > 0 then
    x = x + 76
  else
    x = x + 45
  end

  local dirX, dirY  = 0, 1
  local px, py, psx, p = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  if px then
    py = py - 2

    px = px + p.velocity.horizontal.current * p.velocity.horizontal.direction * 2
    local ang = math.angle ( x, y, px, py )
    dirX, dirY = math.cos(ang), math.sin(ang)
  end

  --dirY       = math.min ( dirY, 0.125)
  dirX, dirY = math.normalize(dirX, dirY)
  if Camera:isObjectInView ( self, 32 ) then
    Audio:playSound ( SFX.gameplay_enemy_laser_shot )
  end

  GameObject
    :spawn                ( "oval_projectile", x, y, 3.0, 3.0, dirX, dirY, "big" )
    :setIgnoringPassables ( )
  Particles:add    ( "oval_shot_shoot_neutral", x-4, y-6, 1 )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Beam cannon §cannon ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _BEAM = _WTANK:addState ( "BEAM_CANNON" )

function _BEAM:enteredState ( )
  self.timer            = 1
  self.stateVars.init   = false
  self.state.isGrounded = true

  self.stateVars.lean = {
    fistX     = 0,
    fistY     = 0,
    shoulderX = 0,
    shoulderY = 0,
    leanX     = 0,
  }
  local sx = self.sprite:getScaleX()
  self.stateVars.lean.tween 
    = Tween.new ( 
        20, 
        self.stateVars.lean, 
        { 
          fistX     = sx > 0 and 10 or -10, 
          fistY     = -8, 
          shoulderX = sx > 0 and 4 or -4,
          shoulderY = -2,
          leanX     = sx > 0 and -2 or 2
        }, 
        "outQuad" 
      ) 

  self:smallBop ( )
end

function _BEAM:exitedState ( )
  if not self.stateVars.endedNormally then
    self.sprite:change ( "huge-laser",       "huge-laser-end",       1, true )
    self.sprite:change ( "huge-laser-ender", "huge-laser-end-ender", 1, true )
  end

  if self.stateVars.laser then
    self.stateVars.laser:delete()
    self.stateVars.laser = nil
  end

  if self.health <= 0 then return end

  self.fistPos.close.fistX = 0
  self.fistPos.close.fistY = 0

  self.fistPos.far.fistX = 0
  self.fistPos.far.fistY = 0

  self.fistPos.far.shoulderX = 0
  self.fistPos.far.shoulderY = 0

  self.leanX = 0

  self.velocity.horizontal.current = 0
end

function _BEAM:tick ( )

  self.fistPos.close.fistX = self.stateVars.lean.fistX
  self.fistPos.close.fistY = self.stateVars.lean.fistY

  self.fistPos.close.shoulderX  = self.stateVars.lean.shoulderX 
  self.fistPos.close.shoulderY  = self.stateVars.lean.shoulderY

  self.fistPos.far.fistX = self.stateVars.lean.fistX
  self.fistPos.far.fistY = self.stateVars.lean.fistY

  self.fistPos.far.shoulderX = self.stateVars.lean.shoulderX 
  self.fistPos.far.shoulderY = self.stateVars.lean.shoulderY

  self.leanX = self.stateVars.lean.leanX


  if self.velocity.horizontal.current < 0 then
    local bl = self.layers.bottom     ( )
    local x,y = self:getPos           ( )
    local sx  = self.sprite:getScaleX ( )
    if sx > 0 then
      Particles:addFromCategory ( "landing_dust", x+100+RNG:range(1,4)*RNG:rsign(),  y+39,  -1, 1,  0.25, -0.1 )

      Particles:addFromCategory ( "landing_dust", x+124+RNG:range(1,4)*RNG:rsign(),  y+39,  -1, 1,  0.25, -0.1, bl )
    else
      Particles:addFromCategory ( "landing_dust", x+13+RNG:range(1,4)*RNG:rsign(), y+39, 1, 1, -0.25, -0.1 )

      Particles:addFromCategory ( "landing_dust", x-3+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  -0.25, -0.1, bl )
    end
  elseif self.velocity.horizontal.current > 0 then
    local x,y = self:getPos( )
    local sx  = self.sprite:getScaleX()
    if sx > 0 then
      Particles:addFromCategory ( "landing_dust", x+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  0.25, -0.1 )
    else
      Particles:addFromCategory ( "landing_dust", x+110+RNG:range(1,4)*RNG:rsign(), y+39, -1, 1, -0.25, -0.1 )
    end
  end


  self.timer = self.timer - 1
  if not self.stateVars.init and self.timer > 0 then
    return
  end
  if not self.stateVars.init then
    self.timer          = 42
    self.stateVars.init = true
    local sx = self.sprite:getScaleX ( )
    self.stateVars.laser = 
      GameObject:spawn ( 
        "laser_beam", 
        self:getX()+(sx < 0 and -8 or 132), 
        self:getY()+18, 
        sx < 0 and 4 or 6,
        180
      )
    self.stateVars.laser:setInitialSpawnTimer ( 50 )
    return
  end

  self.stateVars.lean.tween:update ( 1 )

  if self.stateVars.shoot and not self.stateVars.despawned then

    local sx   = self.sprite:getScaleX ( )

    if not self.stateVars.shakyHand then
      self.stateVars.shakyHand = 0
    end

    self.stateVars.shakyHand = self.stateVars.shakyHand + -sx * 0.5
    if self.stateVars.shakyHand < -2 or self.stateVars.shakyHand > 2 then
      self.stateVars.shakyHand = 0
    end

    self.fistPos.close.fistX  = self.fistPos.close.fistX + self.stateVars.shakyHand 
    self.fistPos.far.fistX    = self.fistPos.far.fistX   + self.stateVars.shakyHand

    local x, y = self:getPos ( )

    y = y - 4
    if sx < 0 then
      x = x - GAME_WIDTH
    else
      x = x + 124
    end

    local cols, len = Physics:queryRect (
      x, 
      y, 
      GAME_WIDTH, 
      80
    ) 

    if len and len > 0 then
      for i = 1, len do
        if cols[i].isPlayer then
          GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.BOSS_MELEE_DAMAGE_MEDIUM, "weak", self.sprite:getScaleX ( ) )
        end
      end
    end

  end

  if not self.stateVars.shoot then
    if self.timer > 0 then
      return
    end
    self.stateVars.laser:delete()
    self.stateVars.laser = nil

    self.state.hugeLaser = true
    self.stateVars.shoot = true

    Audio:playSound ( SFX.gameplay_ray_big_laser_shoot )
    self.sprite:change ( "huge-laser",       "huge-laser",       1, true )
    self.sprite:change ( "huge-laser-ender", "huge-laser-ender", 1, true )

    self:smallBop ( )
    self.velocity.horizontal.direction = self.sprite:getScaleX()
    self.timer = 60

    local sx = self.sprite:getScaleX()
    self.stateVars.lean.tween 
      = Tween.new ( 
          20, 
          self.stateVars.lean, 
          { 
            fistX = sx > 0 and -10 or 10, 
            fistY = 4, 
            shoulderX = sx > 0 and -4 or 4,
            shoulderY = 2,
            leanX = sx > 0 and 3 or -3
          }, 
          "outBack" 
        ) 
  elseif not self.stateVars.stoppedShooting then
    if self.timer <= 0 then
      if self.timer == 0 then
        self.stateVars.despawned = true
        self:smallBop ( )
        self.sprite:change ( "huge-laser",       "huge-laser-end",       1, true )
        self.sprite:change ( "huge-laser-ender", "huge-laser-end-ender", 1, true )
      end
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 0 )

      if self.timer < -25 and self.velocity.horizontal.current == 0 then
        self.timer = 37
        self.stateVars.stoppedShooting = true
        
        self.stateVars.lean.tween 
          = Tween.new ( 15, self.stateVars.lean, { fistX = 0, fistY = 0, shoulderX = 0, shoulderY = 0, leanX = 0}, "outQuad" ) 
      end
    else
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.125, -1.0 )
    end
  else
    if self.timer > 0 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 2.0 )
    else
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
      if self.timer <= 0 then
        self.stateVars.endedNormally   = true
        self:gotoState ( nil )
      end
    end
  end

  if self.stateVars.shoot and not self.stateVars.despawned then
    if not self.sprite:getAnimation ( "laser-overlay" ) then
      self.sprite:change ( "laser-overlay", "laser-overlay", 1, true )
    end
  end

  if self.velocity.horizontal.current ~= 0 then
    Camera:startShake ( 0, 1, 20, 0.25 )
  end

  self:applyPhysics ( )
end

function _BEAM:updateTread ( )
  self:updateTreadActual ( self.velocity.horizontal.current )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _WTANK:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
-- this boss isn't a circuit why does it have desperation
--[[
local _DESPERATION_ACTIVATION = _WTANK:addState ( "DESPERATION_ACTIVATION" )
function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )

end

local px, py, mx, my = self:getLocations()
GameObject:spawn ( 
  "laser_beam", 
  px, 
  py, 
  3,
  99999
)
GameObject:spawn ( 
  "laser_beam", 
  px, 
  py, 
  6,
  99999
)
function _DESPERATION_ACTIVATION:exitedState ()
  
end

function _DESPERATION_ACTIVATION:tick ()

end]]


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Death               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DEATH = _WTANK:addState ( "DEATH" )

_WTANK.static.DEATH_EXPLOSION_LOCATIONS = {
  { 20, 9 },
  { 110, 18 },
  { 68, 30  },
  { 55, -45 },
  { 70, -65 },
  { 34, 25 },
  { 80, 10 },
  { 50, -25 },
}

function _DEATH:enteredState ( )
  StageClearStats.addKill ()

  if self.state.isBossRushSpawn then
    self.stateVars.bossRushTimer = 180
    MapData.BossRush.markCleared      ( self.class.name )
    GameObject:startFinalKillSlowdown ( nil, nil, GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush )
    self:spawnBossRushRewards         ( )
  else
    GlobalObserver:single         ( "DESTROYED_TARGET_OBJECT", self )
  end
  self.state.isFinalKill            = true
  self.stateVars.finalKillTimer     = 20
  self.isStunned                    = true
  self.stunTimer                    = 0
  self.velocity.horizontal.current  = 0
  self.velocity.vertical.update     = true
  self.angle                        = 0
  self.ACTIVE_PALETTE               = Colors.Sprites.enemy_stunned
  self.timer                        = 0

  self:applyShake                      ( 3, 0.125, -self.sprite:getScaleX ( ) )

  self.sprite:change                   ( "eyes", nil )
  self.sprite:change                   ( "head", "death-face", 1, false )
  self:permanentlyDisableContactDamage ( true )

  self.stateVars.lean = {
    f_fistX     = self.fistPos.far.fistX,
    f_fistY     = self.fistPos.far.fistY,
    c_fistX     = self.fistPos.close.fistX,
    c_fistY     = self.fistPos.close.fistY,
    f_shoulderX = self.fistPos.far.shoulderX,
    f_shoulderY = self.fistPos.far.shoulderY,
    c_shoulderX = self.fistPos.close.shoulderX,
    c_shoulderY = self.fistPos.close.shoulderY,
    leanX       = self.leanX,
    leanY       = self.leanY,
  }
  local sx = self.sprite:getScaleX()
  self.stateVars.lean.tween 
    = Tween.new ( 
        30, 
        self.stateVars.lean, 
        { 
          f_fistX     = sx > 0 and 10 or -10, 
          f_fistY     = 6, 
          f_shoulderX = sx > 0 and 4 or -4,
          f_shoulderY = 2,
          c_shoulderX = sx > 0 and -4 or 4,
          c_shoulderY = 2,
          c_fistX     = sx > 0 and -15 or 15, 
          c_fistY     = 6,
          leanX       = -4,
          leanY       = -2,
        }, 
        "outQuad" 
      ) 

  self.stateVars.explosionIndex = RNG:range ( 1, #self.class.DEATH_EXPLOSION_LOCATIONS )
  self:addRandomExplosion ( ) 
  self:addRandomExplosion ( ) 
  self:addRandomExplosion ( ) 

  local sx     = self.sprite:getScaleX  ( )
  local mx, my = self:getMiddlePoint    ( )
  if sx == 1 then
    mx = mx + 65 
    my = my - 19
  else
    mx = mx + 55
    my = my - 19
  end

  DataChip.nextSpawnIgnoresPassables ( true )
  DataChip.spawn ( self.class.name, mx, my, true, true )
  DataChip.nextSpawnIgnoresPassables ( false )
end

function _DEATH:exitedState ( )

end

function _DEATH:tick ( )
  if self.stateVars.bossRushTimer then
    self.stateVars.bossRushTimer = self.stateVars.bossRushTimer - 1
    if self.stateVars.bossRushTimer <= 0 then
      if not self._notifiedBossRushHandler then
        self._notifiedBossRushHandler   = true
        if not (GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush) then
          GAMESTATE.bossRushMode.defeated = true
          GlobalObserver:none ( "CUTSCENE_START", "special/cutscene_bossRushHandler" )
        end
      end
    end
  end
  self.stunTimer = self.stunTimer + 1
  if self.stateVars.bossRushTimer then
    if self.stunTimer < 240 then
      if self.stunTimer % 20 == 0 then
        self:addRandomExplosion ( ) 
      end
    end
    if self.stunTimer == 80 then
      Audio:playSound    ( SFX.gameplay_scrap_golem_death_growl )
      self.sprite:resume ( "head" ) 
      self.stateVars.yelling = true
      self:applyShake ( 1, 0 )
    end
  else
    if self.stunTimer < 120 then
      if self.stunTimer % 20 == 0 then
        self:addRandomExplosion ( ) 
      end
    elseif self.stunTimer < 160 then
      if not self.stateVars.yelling then
        Audio:playSound    ( SFX.gameplay_scrap_golem_death_growl )
        self.sprite:resume ( "head" ) 
        self.stateVars.yelling = true
        self:applyShake ( 1, 0 )
      end
      if self.stunTimer % 15 == 0 then
        self:addRandomExplosion ( ) 
      end
    elseif self.stunTimer < 220 then
      if self.stunTimer % 10 == 0 then
        self:addRandomExplosion ( ) 
      end
    elseif self.stunTimer < 280 then
      if self.stunTimer % 3 == 0 then
        self:addRandomExplosion ( ) 
      end
    elseif self.stunTimer == 280 then
      self.isOverkilled = true
      self:applyShake ( 4, 0.25  )

      local sx     = self.sprite:getScaleX  ( )
      local mx, my = self:getMiddlePoint    ( )
      if sx == 1 then
        mx = mx + 65 
        my = my - 19
      else
        mx = mx + 55
        my = my - 19
      end

      Audio:playSound ( SFX.gameplay_player_death_trigger, 0.75 )

      local l = self.layers.sprite()+20
      
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:add ( "death_trigger_flash", mx,  my, math.rsign(), 1, 0, 0, l )

      self.stateVars.mx = mx
      self.stateVars.my = my
    elseif self.stunTimer == 320 then
      self.timer = 160
    elseif self.stunTimer > 320 then
      self:whiteCircle()

      if self.timer > 350 then
        self:updateGarbage ( )
      end
    end
  end

  if self.stateVars.yelling then
    self.stateVars.lean.tween:update ( 1 )

    self.fistPos.close.fistX = self.stateVars.lean.c_fistX
    self.fistPos.close.fistY = self.stateVars.lean.c_fistY

    self.fistPos.close.shoulderX  = self.stateVars.lean.c_shoulderX 
    self.fistPos.close.shoulderY  = self.stateVars.lean.c_shoulderY

    self.fistPos.far.fistX = self.stateVars.lean.f_fistX
    self.fistPos.far.fistY = self.stateVars.lean.f_fistY

    self.fistPos.far.shoulderX = self.stateVars.lean.f_shoulderX 
    self.fistPos.far.shoulderY = self.stateVars.lean.f_shoulderY

    self.leanX = self.stateVars.lean.leanX
    self.leanY = self.stateVars.lean.leanY
  end



  self:applyPhysics ( )
end

function _DEATH:whiteCircle ( )
  self.timer  = self.timer + 1
  local mx,my = self.stateVars.mx, self.stateVars.my

  local l = self.layers.death()
  if self.stateVars.whiteBox then
    self.stateVars.whiteBox.tween1:update(1)
    if self.stateVars.whiteBox.tween2:update(1) and not self.stateVars.whiteBox.inverse then
      self.stateVars.whiteBox.tween1  = Tween.new ( 92, self.stateVars.whiteBox, {circleR2=-40}, "inCubic" )
      self.stateVars.whiteBox.tween2  = Tween.new ( 90, self.stateVars.whiteBox, {circleR=-30}, "inCubic" )
      self.stateVars.whiteBox.inverse = true
      self:spawnGarbage ( )
    end
    if self.timer < 400+1 then
      local r = self.stateVars.whiteBox.circleR2 + (self.timer%3*4) + 8 + (self.timer%4*4)
      if r > 0 then
        GFX:setColor  ( l-4, false, Colors.kai_red )
        GFX:push      ( l-4, love.graphics.circle, "fill", self.stateVars.whiteBox.x, self.stateVars.whiteBox.y, r+2 )
        GFX:setColor  ( l-4, false, Colors.kai_orange )
        GFX:push      ( l-4, love.graphics.circle, "fill", self.stateVars.whiteBox.x, self.stateVars.whiteBox.y, r-1 )
        GFX:defColor  ( l-4, false )
      end
      Particles:addSpecial ( "emit_green_beam", mx,my, l-3, false, true )
      r = self.stateVars.whiteBox.circleR + (self.timer%3*4)
      if r > 0 then
        GFX:setColor  ( l-2, false, Colors.kai_yellow )
        GFX:push      ( l-2, love.graphics.circle, "fill", self.stateVars.whiteBox.x, self.stateVars.whiteBox.y, r+5 )
        GFX:defColor  ( l-2, false )
        GFX:push      ( l-2, love.graphics.circle, "fill", self.stateVars.whiteBox.x, self.stateVars.whiteBox.y, r-2 )
      end
      if self.timer == 360 then
        Audio:playSound ( SFX.gameplay_boss_death_crackle )
      end
      if self.timer == 370+1 then
        Particles:addSpecial("small_explosions_in_a_circle", mx, my, l-3, false, 1.5 )
      end
      
      --if self.timer % 3 == 0 then
      --end
    end
  end
  --[[
  if self.timer == 30 then
    Audio:playSound ( SFX.gameplay_boss_death_prelude )
  end

  if self.timer > 30 and self.timer < 120 then
    if self.timer % 3 == 0 then
      Particles:addSpecial ( "streak_of_light", mx,my, l, false )
    end
    if self.timer % 2 == 0 then
      Particles:addSpecial ( "emit_green_beam", mx, my, l, false )
    end
  elseif self.timer == 120 then

    Audio:playSound ( SFX.gameplay_player_death_explosion )
    Particles:add ( "beam_palm_purge_flash", mx,my, math.rsign(), 1, 0, 0, l+1 )
    self:applyShake(3)
  else]]if self.timer == 160+1 then
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, l+1, false, 3.25, 1.75, 0.005 )
  elseif self.timer == 167+1 then
    --Audio:playSound ( SFX.gameplay_player_death_sweeping_explosion_2 )
    
    Audio:playSound ( SFX.gameplay_player_death_explosion_2 )
    Particles:addSpecial("small_explosions_in_a_circle", mx, my, l, false, 4.5, 2.0, 0, 0.5, 1 )
    self.stateVars.whiteBox = {
      x      = mx,
      y      = my-1,
      circleR = 10,
      circleR2= 10,
      inverse = false,
    }
    self.stateVars.whiteBox.tween1= Tween.new ( 40, self.stateVars.whiteBox, {circleR2=15}, "outCubic" )
    self.stateVars.whiteBox.tween2= Tween.new ( 40, self.stateVars.whiteBox, {circleR=15}, "outCubic" )
  elseif self.timer == 170+1 then

    Audio:playSound ( SFX.gameplay_boss_death_sweep )
  elseif self.timer == 195+1 then
    self.stateVars.whiteBox.tween1= Tween.new ( 90, self.stateVars.whiteBox, {circleR2=290}, "outCubic" )
    self.stateVars.whiteBox.tween2= Tween.new ( 90, self.stateVars.whiteBox, {circleR=280}, "outCubic" )
  elseif self.timer > 450+1 then
    self.stateVars.finished = true
  end
end

function _DEATH:addRandomExplosion ( )
  Audio:playSound ( SFX.gameplay_enemy_explosion )

  local l      = self.layers.particles ( )
  local sx     = self.sprite:getScaleX ( )
  local mx, my = self:getPos           ( )

  mx = mx + RNG:range ( 1, 5 ) * RNG:rsign ( )
  my = my + RNG:range ( 1, 5 ) * RNG:rsign ( )

  mx = mx + self.class.DEATH_EXPLOSION_LOCATIONS[self.stateVars.explosionIndex][1]
  my = my + self.class.DEATH_EXPLOSION_LOCATIONS[self.stateVars.explosionIndex][2]

  self.stateVars.explosionIndex = self.stateVars.explosionIndex + RNG:range ( 1, 3 )
  if self.stateVars.explosionIndex > #self.class.DEATH_EXPLOSION_LOCATIONS then
    self.stateVars.explosionIndex = self.stateVars.explosionIndex - #self.class.DEATH_EXPLOSION_LOCATIONS

    if self.stateVars.explosionIndex < 1 then
      self.stateVars.explosionIndex = 1
    end
  end

  Audio:playSound      ( SFX.gameplay_enemy_explosion, 0.8 )
  Particles:addSpecial ( "small_explosions_in_a_circle", mx, my, l, false, 0.7, 0.6 )
end

function _DEATH:spawnGarbage ( )
  self.sprite:nilAll ( )
  self._noSpriteDraw = true

  self.fallingGibs = {}
  local cx, cy = Camera:getPos ( )

  for i = 1, 16 do
    --[[if i > 1 then
      self.sprite:addInstance ( i )
    end
    self.sprite:change ( i, "gibs", i, false )]]
    self.fallingGibs[i] = {
      x = cx + RNG:range ( 25, GAME_WIDTH-25 ) - 32,
      y = cy - 32 - (16-i)*60 - ((i == 1) and 20 or (RNG:range ( 15, 40 ))),
      speedX = 0,
      speedY = 8,
      accelY = 0.25,
      flicker = i%2,
      active = true,
    }
  end
end

function _DEATH:updateGarbage ( )
  if not self.fallingGibs then return end
  local cy = Camera:getY ( )
  for i = 1, 16 do
    if self.fallingGibs[i].active then
      self.fallingGibs[i].x = self.fallingGibs[i].x + self.fallingGibs[i].speedX
      self.fallingGibs[i].y = self.fallingGibs[i].y + self.fallingGibs[i].speedY
      self.fallingGibs[i].speedY = math.min(self.fallingGibs[i].speedY + self.fallingGibs[i].accelY, 6)
      self.fallingGibs[i].flicker = (self.fallingGibs[i].flicker+1)%2

      if self.fallingGibs[i].y > cy + GAME_HEIGHT + 42 then
        self.fallingGibs[i].active = false
        Camera:startShake ( 0, 3, 5, 0.25 )
        Audio:playSound   ( SFX.gameplay_enemy_bounces_on_ground, 1.1 )
      end
    end
  end

  if not self.fallingGibs[1].active then
    self.fallingGibs = nil
    if self.CLEAR_FLAG then
      SetStageFlag ( self.CLEAR_FLAG )
    end
    if self.CLEAR_SCRIPT then
      if self.rightw then
        Physics:removeObject ( self.rightw ) 
      end
      GlobalObserver:none  ( "CUTSCENE_START", self.CLEAR_SCRIPT )
    end
    self:delete ( )
  end
end

function _DEATH:drawSpecial ( )
  if not self.fallingGibs then return end
  local l = self.layers.real_gibs()

  Shader:pushColorSwapper ( l, false, self.BASE_PALETTE, Colors.Sprites.enemy_stunned )
  GFX:push                ( l, self.drawRealGibs, self )
  Shader:set              ( l, false )
end

function _DEATH:drawRealGibs ( )
  for i = 1, 16 do
    if self.fallingGibs[i].flicker == 0 then
      self.sprite:drawFrameInstant ( "gibs", i, self.fallingGibs[i].x, self.fallingGibs[i].y )
    end
  end
end

function _DEATH:takeDamage ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §preload_state ------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PRELOAD = _WTANK:addState ( "PRELOAD_STATE" )

function _PRELOAD:enteredState ( )
  --Audio:loadBgmAsync ( BGM.boss_intro )
  GlobalObserver:say ( "BOSS_KNOCKOUT_SCREEN_PRELOAD" )

  --Audio:playSound   ( SFX.gameplay_earthquake_intense, 0.50 )
  --self.stateVars.quakeIntensity = 0.50

  self.state.isGrounded      = true
  self.stateVars.audioPlayed = false

  local x = self:getX()
  if self.state.isBossRushSpawn then
    self.sprite:flip ( -1, nil )
    local x, y = self:getPos()
    self:setActualPos ( x + 600, y )
  end
  self.velocity.horizontal.direction = self.sprite:getScaleX ( )
  --self.stateVars.factor     = 0
  self.stateVars.spawnDelay = 71+60
  self.timer                = 0--15 + 40
  self.stateVars.returnTrip = true
  self.stateVars.volLevel   = 1
  self.stateVars.maxVol     = 0.0

  self.stateVars.eyeTimer = (GetStageFlag ( "seen-opening-boss-appearance-once" ) == 1) and 10 or 30
  if self.state.isBossRushSpawn then
    self.stateVars.eyeTimer = 10
  end
  self.isPrefight = true
end

function _PRELOAD:exitedState ( )
  self.isPrefight = false
end

function _PRELOAD:tick ( )
  self:applyPhysics ( )

  --if self.state.isGrounded then
  if self.stateVars.stopped then
    if not self.stateVars.blockaded then
      self:createBlockades ( )
    end
    self.timer = self.timer + 1
    --if self.timer == 0 then
      --Audio:unscrewAudio  ( )
     -- Audio:playTrack     ( BGM.boss_intro, true )
    --end
    if self.timer > self.stateVars.eyeTimer then
      if not self.stateVars.sfx then
        self.stateVars.sfx = true
        Audio:playSound     ( SFX.gameplay_scrap_golem_eye_shine )  
      end
      self.sprite:resume ( "eyes" )
    end
  else
    if self.stateVars.spawnDelay > 1 then
      --self.stateVars.factor = math.min ( self.stateVars.factor + 0.05, 1 )
      if not self.stateVars.playThisThingOnce and self.stateVars.spawnDelay == 70 then 
        self.stateVars.playThisThingOnce = true
          --if not self.treadSfx then
          --  self.treadSfx  = 1
          --  self.treadSfxT = 1
          --end

        --Audio:unscrewAudio  ( )
        if not (GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush) then
          Audio:fadeMusicVolume ( 0, 1 )
          Audio:playTrack     ( BGM.boss_intro, true )
        end
      end
        self.stateVars.maxVol = math.min ( self.stateVars.maxVol + 0.005, 1 )
      self.stateVars.spawnDelay  = self.stateVars.spawnDelay  - 1
    else
      if not self.stateVars.speedSet then
        self.velocity.horizontal.current = 3
        self.stateVars.speedSet          = true
      end
      self:returnTripFunc ( )
      local x,y = self:getPos ( )
      x = x + self.dimensions.x
      y = y + self.dimensions.y
      local cols, len = Physics:queryRect ( x, y, self.dimensions.w, self.dimensions.h )
      for i = 1, len do
        if cols[i] and cols[i].isEnemy and cols[i].parent ~= self then
          cols[i].parent:gotoState ( "DESTRUCT" )
        end
      end
    end
  end

  if self.timer > 80 then
    CutsceneManager.CONTINUE  ( )
    self:gotoState            ( nil )
  end
end

function _PRELOAD:updateTread ( )
  --if self.stateVars.spawnDelay <= 1 then
  self.state.isGrounded = true
    self:updateTreadActual ( self.velocity.horizontal.current )
  --end
end

function _PRELOAD:returnTripFunc ( )
  self.timer = self.timer - 1
  if self.timer > 0 then
    return
  end

  local x,y = self:getPos( )
  local sx  = self.sprite:getScaleX()
  if sx > 0 then
    Particles:addFromCategory ( "landing_dust", x+RNG:range(1,4)*RNG:rsign(),  y+39,  1, 1,  0.25, -0.1 )
  else
    Particles:addFromCategory ( "landing_dust", x+110+RNG:range(1,4)*RNG:rsign(), y+39, -1, 1, -0.25, -0.1 )
  end

  local x  = self:getX   ( )
  local cx = Camera:getX ( )

  --if (x < (cx + 15)) 
  --or (x > (cx + GAME_WIDTH - 15 - 126)) then
  if (x < (cx - 11)) 
  or (x > (cx + GAME_WIDTH + 14 - 146)) then
    self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.125, 3 )
  else
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    if not self.stateVars.slowingDown then
      self:smallBop ( )
    end
    self.stateVars.slowingDown = true
  end

  if self.velocity.horizontal.current > 0 and Camera:inView ( self, 80 ) and math.abs(self.timer) % 4 == 0 then
    Camera:startShake ( 0, 1, 20, 0.25 )
  end

  if (self.velocity.horizontal.current <= 0) and self.stateVars.slowingDown then
    self.stateVars.stopped = true
    self.timer             = -30
  end
end

function _WTANK:createBlockades ( )
  local isOfficial, map = MapTracker:isOfficialMap ( )
  if not self.state.isBossRushSpawn and (not isOfficial or map ~= "OPENING") then return end

  local cx, cy = Camera:getPos()
  local h      = 96*8+GAME_HEIGHT*6
  --[[
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
  end]]

  local prop = { isTile = true, isWallJumpPreventing = true, isSolid = true, noCollisionWithHookshot = true }
  local leftw, rightw = Physics:newObject ( "left_bit_wall",  0, 0, 16, h, prop ),
                        Physics:newObject ( "right_bit_wall", 0, 0, 16, h, prop )

  Physics:insertObject ( leftw,  cx - 16,          cy - 96*6 - 1200 )
  Physics:insertObject ( rightw, cx + GAME_WIDTH,  cy - 96*6 - 1200 )

  self.HAS_IGNORED_TILES[leftw]  = true
  self.HAS_IGNORED_TILES[rightw] = true

  self.rightw = rightw
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _WTANK:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self:setActualPos ( self:getX()-2, self:getY())
  self.sprite:change ( 1, nil )
  self.timer = 1
  self.stateVars.beams = 0
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )
  self:applyPhysics ( )
end

function _WTANK:_runAnimation ( )
  self:gotoState ( "CUTSCENE" )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Misc                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:takeDamage ( damage, direction, _, __, launchingAttack )
  if self.health <= 0 then return end
  damage       = damage or 1
  direction    = direction or RNG:rsign()

  Audio:playSound ( SFX.gameplay_scrap_golem_damage, 0.65 )

  if isFunction(damage) then
    damage = damage()
  end

  local floored = math.floor( damage )
  if floored ~= damage then
    local dif = damage - floored
    damage    = floored

    if not self._halfPipHealth then
      self._halfPipHealth = 0
    end
    self._halfPipHealth = self._halfPipHealth + dif

    if self._halfPipHealth >= 1 then
      self._halfPipHealth = 0
      damage              = damage + 1
    end
  end

  self.hitFlash.current = self.hitFlash.max
  self.health           = self.health - damage
  self:notifyBossHUD ( damage, direction )

  if self.health <= 0 then
    if (launchingAttack or self._wasStruckByASpiritualBurst) then
      print("[Wrecker Tank] Unlock flashy finish!")
      Challenges.unlock ( Achievements.BOSS_FLASHY )
    end

    self:gotoState ( "DEATH", direction )
  end
  return true
end

function _WTANK:chain ( )
  if self.health > 0 then
    self:takeDamage ( )
  end
  return false
end

function _WTANK:isGrabbable ( )
  return false
end

function _WTANK:pull ( )
  return false
end

function _WTANK:manageLaunchingHit ( )
  return false
end

function _WTANK:isSuplexable ( )
  return false
end

function _WTANK:gravityFreeze ( )
  if self.health > 0 then
    self:takeDamage ( )
  end
  return
end

function _WTANK:getMiddlePoint ( )
  local x,y   = self:getPos ( )
  --local headX = x + self.headPos.x + self.bodyPos.leanX/2 - 20
  --local headY = y + self.headPos.y + round ( self.bodySin * 6 ) + self.bodyPos.leanY + 32
  --return headX, headY
  return x,y
end

function _WTANK:manageDespawn ( )
  return false
end

function _WTANK:addBop ( )
  self.bop.cannon   = 2.5
  self.bop.mid      = 2
  self.bop.torso    = 2
  self.bop.head     = 2
  self.bop.shoulderC= 2
  self.bop.shoulderF= 2
  self.bop.arms     = 4
end

function _WTANK:smallBop ( )

  self.bop.cannon   = 1
  self.bop.mid      = 1
  self.bop.torso    = 1
  self.bop.head     = 1
  self.bop.shoulderC= 1
  self.bop.shoulderF= 1
  self.bop.arms     = 1
end

function _WTANK:updateTread ( )
  self:updateTreadActual ( self.velocity.horizontal.current )
end

-- §tread
function _WTANK:updateTreadActual ( factor )
  local factor = factor or self.velocity.horizontal.current
  if self.state.isGrounded then
    self.treadFrame = self.treadFrame + factor
    if self.treadFrame <= 1 then
      self.treadFrame = math.min(8 + self.treadFrame,8)
    elseif self.treadFrame > 8 then
      self.treadFrame = math.max(self.treadFrame - 8,1)
    end
  end

  if not self.treadSfx then
    self.treadSfx  = 0
    self.treadSfxT = 0
  end

  --factor = self.velocity.horizontal.current
  local maxVol = 1
  if self.velocity.horizontal.current > 0 then
    maxVol = maxVol + (self.velocity.horizontal.current / 17)
  end


  if self.isPrefight then
    if not self.stateVars.stopped then
      maxVol = self.stateVars.maxVol
      factor = 1
    end
  end
  if self.state.isGrounded and math.abs(factor) > 0 then
    self.treadSfx = maxVol--math.min ( self.treadSfx + 1.0, 1.0 )
    if self.treadSfxT % 70 == 0 then 
      Audio:playSound ( SFX.gameplay_wrecker_tank_move )
    end
    Audio:setSoundVolumeIndividually ( SFX.gameplay_wrecker_tank_move, maxVol )
    self.treadSfxT = self.treadSfxT + 1
  else
    self.treadSfx = math.max ( self.treadSfx - 0.05, 0 )
    Audio:setSoundVolumeIndividually ( SFX.gameplay_wrecker_tank_move, self.treadSfx )
    self.treadSfxT = 0
  end

  if self.treadFrame > 8 then
    self.treadFrame = 8
  elseif self.treadFrame < 1 then
    self.treadFrame = 1
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Landing dust -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:handleYBlock(_,__,currentYSpeed)
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
  
  self:addBop       ( )
  if Camera:inView ( self, 100 ) then
    Camera:startShake ( 0, 3, 20, 0.25 )
    Audio:playSound ( SFX.gameplay_crash_impact, 1.0 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _WTANK:customEnemyDraw ( x, y, scaleX )
  if self._noSpriteDraw then return end
  local ox, oy = x, y
  if self.angle ~= 0 then
    love.graphics.translate ( x, y )
    love.graphics.rotate    ( -self.angle )

    x = 0
    y = 0
  end

  self:drawFist ( self.fistPos.far, x, y + math.ceil(self.bop.cannon + self.bop.mid + self.bop.torso + self.bop.shoulderF),  self.leanX *scaleX )

  local ogY = y
  self.sprite:drawInstant ( "treads-back",  x, y )

  y = ogY + math.ceil(self.bop.cannon + self.bop.mid + self.bop.torso)
  self.sprite:drawInstant ( "torso-back",        x + self.leanX *scaleX, y )

  y = ogY + math.ceil(self.bop.cannon + self.bop.mid)
  self.sprite:drawInstant ( "midriff",      x, y )

  y = ogY + math.ceil(self.bop.cannon)
  self.sprite:drawInstant ( "cannon",       x, y )

  y = ogY + math.ceil(self.bop.cannon + self.bop.mid + self.bop.torso + self.bop.head + self.leanY)
  self.sprite:drawInstant ( "head",         x + self.leanX *scaleX, y )
  self.sprite:drawInstant ( "eyes",         x + self.leanX *scaleX, y )

  y = ogY + math.ceil(self.bop.cannon + self.bop.mid + self.bop.torso + self.leanY)
  self.sprite:drawInstant ( "torso",        x + self.leanX *scaleX, y )

  y = ogY
  self.sprite:drawInstant ( "treads-front", x,    y )
  self.sprite:drawInstant ( "thruster",     x,    y )

  if scaleX > 0 then
    self.sprite:drawInstant ( "thruster",     x+32, y )
  else
    self.sprite:drawInstant ( "thruster",     x-32, y )
  end

  self:drawFist ( self.fistPos.close, x, y + math.ceil(self.bop.cannon + self.bop.mid + self.bop.torso + self.bop.shoulderC),  self.leanX *scaleX )


  if self.angle ~= 0 then
    love.graphics.rotate    ( self.angle )
    love.graphics.translate ( -ox, -oy )
  end

  if not self.state.hugeLaser then return end

  love.graphics.setShader ( )
  self.sprite:drawInstant ( "laser-overlay", x, y )
  self.sprite:drawInstant ( "huge-laser",    x, y )
  if scaleX < 0 then
    self.sprite:drawFrameInstant ( 
      self.sprite:getAnimation ( "huge-laser-ender" ), 
      self.sprite:getFrame     ( "huge-laser-ender" ), 
      x - 150 - GAME_WIDTH*2, 
      y, 
      GAME_WIDTH 
    )
  else
    self.sprite:drawFrameInstant ( 
      self.sprite:getAnimation ( "huge-laser-ender" ), 
      self.sprite:getFrame     ( "huge-laser-ender" ), 
      x + 60 - GAME_WIDTH, 
      y, 
      GAME_WIDTH 
    )
  end
end

function _WTANK:drawFist ( fist, x, y, leanX )
  local sx = self.sprite:getScaleX ( )

  if fist.active then
    x = x + leanX
  end

  x = x + sx * fist.total

  local chainX = x
  local chainY = y
  if not fist.close then
    chainX = chainX + sx * 40
  end
  chainX = chainX + fist.fistX/20
  chainY = chainY + fist.fistY/20

  local difX, difY
  if fist.close then
    difX = (( x     +fist.fistX + fist.baseX * sx  +  0 + ((sx > 0) and 55 or -60 ) ) - x+fist.shoulderX + fist.fistX/20) / 9
    difY = (( y     +fist.fistY + fist.baseY       + 50                             ) - y+fist.shoulderY + fist.fistY/20) / 9
  else
    difX = (( x     +fist.fistX + fist.baseX * sx  +  0 + ((sx > 0) and  5 or -10 ) ) - x+fist.shoulderX + fist.fistX/20) / 9
    difY = (( y     +fist.fistY + fist.baseY       + 50                             ) - y+fist.shoulderY + fist.fistY/20) / 9
  end

  for i = 2, 9 do
    self.sprite:drawFrameInstant ( 
      "arms", 
      i%2==0 and 2 or 3, 
      chainX+fist.shoulderX + (sx > 0 and 20 or 63) + (i-1) * difX + (fist.close and 0 or (9 * sx)), 
      chainY+fist.shoulderY - 49                    + (i-1) * difY
    )
  end

  self.sprite:drawInstant ( fist.sh_instance,  math.round(x+fist.shoulderX + fist.fistX/20),                                                                       math.round(y+fist.shoulderY + fist.fistY/20 + self.leanY)  )
  self.sprite:drawInstant ( fist.arm_instance, math.round(x+fist.fistX     + fist.baseX     * sx + (sx > 0 and 82 or 0) + math.ceil(fist.shakeX) * fist.shakeDir), math.round(y+fist.fistY     + fist.baseY - 4) )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Return -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--



return _WTANK