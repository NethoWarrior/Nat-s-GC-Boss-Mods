-- BATTIE, the bat that flies
local _BATTIE, _, __, _FLINCHED = BaseObject:subclass ( "VIRUS_BATTIE" ):INCLUDE_COMMONS()
Mixins:attach ( _BATTIE, "pullObject"     )
Mixins:attach ( _BATTIE, "gravityFreeze"  )

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Static     ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_BATTIE.static.EDITOR_DATA = {
  width   = 1,
  height  = 1,
  ox      = -25,
  oy      = -32,
  order   = 9970,
  category = "enemies",
  properties = {
    isSolid     = true,
  }
}

_BATTIE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.enemies, "battie" )
end

_BATTIE.static.GIB_DATA = {
  max    = 3,
  frames = 5
}

_BATTIE.static.DIMENSIONS = {
  x   =   0,
  y   =   0,
  w   =  16,
  h   =  16,

  -- these basically oughto match or be smaller than player
  grabX        =   1,
  grabY        =   0,
  grabW        =  14,
  grabH        =  16,

  grabPosX     =  -3,
  grabPosY     =  10,

  -- visual middle point
  vx  =  3,
  vmx = -3,
  vy  = -2,
}

_BATTIE.static.PROPERTIES = {
  isEnemy    = true,
  isDamaging = true,
}

_BATTIE.static.FILTERS = {
  collision  = Filters:get("enemyCollisionFilter"),
  damaged    = Filters:get("enemyDamagedFilter"),
  player     = Filters:get("queryPlayer"),
}

_BATTIE.static.LAYERS = {
  sprite    = Layer:get ( "ENEMIES", "SPRITE"   ),
  particles = Layer:get ( "PARTICLES" ),
  gibs      = Layer:get ( "GIBS"      )
}

_BATTIE.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE  = true,
  FLINCHING_DISABLED    = true,
}

_BATTIE.static.PALETTE = createColorVector ( 
  Colors.black, 
  Colors.fix_dark_blue,
  Colors.medium_gray_2,
  Colors.light_gray_2,
  Colors.white,
  Colors.whitePlus
)
_BATTIE.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue, 
  Colors.fix_dark_blue,
  Colors.fix_dark_blue,
  Colors.medium_gray_2,
  Colors.medium_gray_2,
  Colors.medium_gray_2
)

_BATTIE.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_BATTIE.static.DROP_TABLE = {
  MONEY = 8,
  BURST = 2,
  DATA  = 0.2,
}


--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Init       ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BATTIE:finalize ( parameters )
  self.initialPositionX, self.initialPositionY = self:getPos()
  self.plasma_ball_count = 80
  self.wait_timer = 80

  self:setDefaultValues(2)

  self.defaultStateFromFlinch = "FLY_UP"

  self.sprite = Sprite:new ( SPRITE_FOLDERS.enemies, "battie", 1 )
  self.sprite:change ( 1, "awaken", 1, false )

  local garbageSpawn = false
  if parameters then
    if parameters.spawnFromGarbage then
      --self.sprite:change ( 1, "spawn" )
      garbageSpawn = true
      self.state.isContactDamageDisabled = true
    end
    self.MONEY_SPAWN_DISABLED = parameters.disableMoney
    self.BURST_SPAWN_DISABLED = parameters.disableBurst
  end

  self.state.isAttacking  = false
  self.state.isMoving     = false

  self.sensors = {
    player = 
      Sensor
        :new               ( self, self.filters.player, -164, -15, 312, 140 )
        :isScaleAgnostic   ( true )
        :expectOnlyOneItem ( true )
  }

  self:addCollider ( "collision", self.dimensions.x,  self.dimensions.y,  self.dimensions.w,   self.dimensions.h, self.properties )
  self:addCollider ( "grabbox",   -4,   -6, 24,  23, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW,  self.dimensions.grabH )

  self.playerTargetX = 0

  self:insertCollider ( "collision" )
  self:insertCollider ( "grabbox"   )
  self:insertCollider ( "grabbed"   )

  if garbageSpawn then
    self:gotoState ( "GARBAGE_SPAWN", parameters.summonDelay )
  else
    self:gotoState ( "SLEEPING" )
  end
end

function _BATTIE:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  local mx, my = self:getMiddlePoint()
  if self.wait_timer == 0 then
    if self.plasma_ball_count > 0 then
      GameObject:spawn ( 
        "plasma_ball", 
        mx-8, 
        my-10, 
        0, 
        1
      )
      self.plasma_ball_count = self.plasma_ball_count - 1
    else
      self:gotoState("DESTRUCT")
    end
  else
    self.wait_timer = self.wait_timer - 1
  end
  if not self.isChainedByHookshot then
    self:tick    ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:updateContactDamageStatus ( )
  self:updateShake        ()
  self:handleAfterImages  ()
  self.sprite:update      ()
end

function _BATTIE:drawSpecialCollisions () 
  if not self.colliders.collision then return end
  self.sensors.player:draw ( self.state.isAttacking )
end

function _BATTIE:handleCollisionWithPlayer ( )
  self:gotoState ( "FLY_UP", true )
end

function _BATTIE:manageDestructEnter ( )
  if self._emitSmoke then
    self._emitSmoke = false
    Environment.smokeEmitter ( self, true )
  end
end

function _BATTIE:cleanup ( )
  if self._emitSmoke then
    self._emitSmoke = false
    Environment.smokeEmitter ( self, true )
  end
end

function _BATTIE:manageChainAnimation ( )
  self.sprite:change ( 1, "take-damage-1", 1 )
end

function _BATTIE:manageGrab ( )
  self.velocity.vertical.update = true
end

function _BATTIE:manageFlinchedEnter ( )
  self.velocity.vertical.update = true
end

function _BATTIE:manageStunAnimation ( )
  self.velocity.vertical.update = true
end

function _BATTIE:setSpawnVariant ( )
  self._isSpawnVariant = true
  self._emitSmoke      = true
  Environment.smokeEmitter ( self )
end

function _BATTIE:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 or self.isDestructed or self.IS_GARBAGE_SPAWNING then return end
  local x, y = self:getPos            ( )
  local l    = self.layers.bottom     ( )
  local sx   = self.sprite:getScaleX  ( )

  x = x + love.math.random(0,6)*math.rsign()
  y = y + love.math.random(1,2)
  --if sx < 0 then
    x = x + 8
    y = y - 14
  --else
  --  x = x + 14
  --  y = y - 15
  --end

  Particles:addFromCategory ( "warp_particle_trace", x, y, 1, 1, 0, -0.5, l, false, nil, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Sleeping  ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SLEEPING = _BATTIE:addState ( "SLEEPING" )

function _SLEEPING:enteredState ( fromFlying )
  if not fromFlying then
    self.sprite:change ( 1, "awaken", 1, false )
  else
    self.sprite:change ( 1, "awaken", 4 )
    self.sprite:rewind ( 1, true )
  end
  self.timer                    = 0
  self.stateVars.awakened       = false
  self.velocity.vertical.update = false
end

function _SLEEPING:tick ()
  if not self.stateVars.awakened then
    local hit, player = self.sensors.player:check(self.sprite:getScaleX())
    if hit then
      local x = player.parent:getMiddlePoint()
      self.sprite:change ( 1, "awaken", 2, true )
      self.sprite:stopRewind ( 1, true )
      self.stateVars.awakened = true
    end
  else
    self.timer = self.timer + 1
    if self.timer > 20 then
      self:gotoState ( "ATTACKING" )
    end
  end
  if self.stateVars.awakened then
    self:applyPhysics()
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Attacking  ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _ATTACKING = _BATTIE:addState ( "ATTACKING" )

function _ATTACKING:enteredState ( )
  self.velocity.vertical.current  = 0
  self.velocity.vertical.update   = false
  self.playerTargetX              = math.round(RNG.n() * 3) * 6 - 7
  self.timer                      = 0
end

function _ATTACKING:tick ( )
  local x,  y                        = self:getPos()
  local px, py                       = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  x = x + self.playerTargetX
  

  local diff                         = math.abs(px-x) / 2
  local dir                          = (px-10 > x) and 1 or (px+10 < x and -1 or 0 )
  self.velocity.horizontal.direction = 1
  if dir ~= 0 then
    self.velocity.horizontal.current = math.min ( math.max ( self.velocity.horizontal.current + dir*0.125, -1.25), 1.25 )
  else
    local sign                       = math.sign ( self.velocity.horizontal.current )
    self.velocity.horizontal.current = math.max ( math.abs  ( self.velocity.horizontal.current ) - 0.125, 0 )
    self.velocity.horizontal.current = self.velocity.horizontal.current * sign
  end

  self.velocity.vertical.current     = math.min ( self.velocity.vertical.current + 0.125, 0.75 )

  self:applyPhysics ()


  if not self:isInState ( "ATTACKING" ) then return end

  self.timer = self.timer + 1

  if py-4 < y and self.timer > 10 then
    self:gotoState ( "FLY_UP", false )
  end
end

function _ATTACKING:handleXBlock ( )
  self.velocity.horizontal.current = self.velocity.horizontal.current + math.sign(self.velocity.horizontal.current) * -1
end

function _ATTACKING:handleYBlock ( )
  self.velocity.vertical.current = -1
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §FLY UP  ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _FLY_UP = _BATTIE:addState ( "FLY_UP" )

function _FLY_UP:enteredState ( fromContact )
  self.sprite:change ( 1, "fly-up" )
  self.velocity.vertical.update     = false

  self.timer                        = 0
  self.stateVars.fromContact        = fromContact
  self.stateVars.targetY            = math.floor(RNG.n() * 16)

  self.stateVars.foundAltitude      = false
end

function _FLY_UP:tick ( )
  if not self.stateVars.foundAltitude then
    self.velocity.vertical.current  = math.max(self.velocity.vertical.current-0.25, -2)
  else
    self.velocity.vertical.current  = math.min(self.velocity.vertical.current+0.125, 0 )
  end

  local sign                       = math.sign ( self.velocity.horizontal.current )
  self.velocity.horizontal.current = math.max ( math.abs  ( self.velocity.horizontal.current ) - 0.125, 0 )
  self.velocity.horizontal.current = self.velocity.horizontal.current * sign

  local x,  y                     = self:getPos()
  local px, py                    = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")

  self:applyPhysics ()

  if not self:isInState ( "FLY_UP" ) then return end
  
  if not self.stateVars.fromContact then
    if py-40-self.stateVars.targetY > y then
      self.stateVars.foundAltitude = true
    end
  else
    self.timer = self.timer + 1
    if self.timer > 30 then
      self.stateVars.foundAltitude = true
    end
  end

  if self.stateVars.foundAltitude and self.velocity.vertical.current == 0 then
    self.sprite:change ( 1, "flap-loop", 5, true )
    self:gotoState ( "ATTACKING" )
  end
end

function _FLY_UP:handleYBlock ( )
  local px, py = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  if py+6 > self:getY() then
    self.sprite:change ( 1, "flap-loop", 5, true )
    self:gotoState ( "ATTACKING" )
  else
    self:gotoState ( "SLEEPING", true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Garbage spawn ------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _GARBAGE_SPAWN = _BATTIE:addState ( "GARBAGE_SPAWN" )

function _GARBAGE_SPAWN:enteredState ( delay )
  if not delay then
    self.sprite:change ( 1, "fly-up" )
  else
    self.sprite:change ( 1, nil )
  end

  self.stateVars.delay            = delay or 0
  self.timer                      = 0
  self.sprite.isDisabled          = true
  self.velocity.vertical.update   = false
  self.IS_GARBAGE_SPAWNING        = true
end

function _GARBAGE_SPAWN:exitedState ( )
  self.IS_GARBAGE_SPAWNING      = false
  self.velocity.vertical.update = true
  self.sprite.isDisabled        = false
  self.sprite:change ( 1, "flap-loop", 5, true )
  self.state.isContactDamageDisabled = false
end

function _GARBAGE_SPAWN:tick ( )
  if self.stateVars.delay > 0 then
    self.stateVars.delay = self.stateVars.delay - 1
    if self.stateVars.delay <= 0 then
      Audio:playSound ( SFX.gameplay_zombie_spawn )
      self.sprite:change ( 1, "fly-up" )
    else
      return
    end
  end
  self.timer = self.timer + 1
  if self.timer < 30 and GetTime()%10==0 then
    local x,y = self:getPos()
    Environment.landingParticle ( x, y, self.dimensions, 4, 8, 8 )
  end
  if self.timer == 30 then
    self.sprite.isDisabled         = false
    self.velocity.vertical.current = -5
  end

  if self.timer > 45 then
    self.velocity.vertical.current = self.velocity.vertical.current + 0.25
  end

  if self.velocity.vertical.current > 0.25 then
    self:gotoState("ATTACKING")
    return
  end
  self:applyPhysics()
  if self.stateVars.bonked then
    self:gotoState("ATTACKING")
  end
end

function _GARBAGE_SPAWN:handleYBlock ( )
  self.stateVars.bonked = true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _BATTIE:customEnemyDraw ( x, y, scaleX )
  if not self._isSpawnVariant then
    self.sprite:drawInstant ( 1, x, y )
    return
  end


  local offset                        = self.hitFlash.current/self.hitFlash.max *5
  offset                              = Shader:calculateShift ( math.floor(offset + ((self.stunTimer or 0))%10/2.25 +0.4), 3 )

  local col = self.isOverkilled and Colors.Sprites.enemy_overkilled or (self.isStunned and Colors.Sprites.enemy_stunned or self.class.PALETTE)
  local hit = self.hitFlash.current/self.hitFlash.max *5
  col = (self.isStunned and hit > 2 and Colors.Sprites.enemy_stunned_hit) or col

  if self.hitFlash.current > 0 or self.isStunned or self.isOverkilled then
    Shader:setColorSwapperWithHaze ( self.class.PALETTE, col, offset, 3 )
  else
    Shader:setColorSwapperWithHaze ( self.class.PALETTE, col, offset-2, 3, 4 )
  end

  self.sprite:drawInstant ( 1, x, y )

  love.graphics.setShader ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §return              ------------------------]]--
--[[----------------------------------------------------------------------------]]--


return _BATTIE