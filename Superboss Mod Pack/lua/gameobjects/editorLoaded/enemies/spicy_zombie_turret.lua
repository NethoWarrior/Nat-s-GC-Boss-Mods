-- VIRUS TURRETY ZOMBIE
local _ZOMBIE_TURRET = BaseObject:subclass ( "VIRUS_ZOMBIE_TURRET"):INCLUDE_COMMONS ( )
Mixins:attach ( _ZOMBIE_TURRET, "pullObject"      )
Mixins:attach ( _ZOMBIE_TURRET, "gravityFreeze"   )

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Static     ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_ZOMBIE_TURRET.static.EDITOR_DATA = {
  width     = 2,
  height    = 2,
  ox        = -17,
  oy        = -17,
  mx        = 30,
  order     = 9975,
  category  = "enemies",
  properties = {
    isSolid     = true,
    isFlippable = true,
    isDamaging  = true,
  },
  variants = {
    {
      ox          = -17,
      oy          = -17,
      mx          = 30,
      parameters  = {
        proximityGarbageSpawn = true
      },
    }
  },
}

_ZOMBIE_TURRET.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.enemies,     "virus-zombie-turret" )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"   )
end

_ZOMBIE_TURRET.static.DIMENSIONS = {
  x            =   4,
  y            =  12,
  w            =  20,
  h            =  20,
  -- these basically oughto match or be smaller than player
  grabX        =   7,
  grabY        =  12,
  grabW        =  14,
  grabH        =  20,

  grabPosX     =  -2,
  grabPosY     =   3,

  -- visual middle point
  vx  =  3,
  vmx = -2,
  vy  = -2,
}

_ZOMBIE_TURRET.static.PROPERTIES = {
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_ZOMBIE_TURRET.static.FILTERS = {
  tile      = Filters:get ( "queryTileFilter"       ),
  collision = Filters:get ( "enemyCollisionFilter"  ),
  damaged   = Filters:get ( "enemyDamagedFilter"    ),
  player    = Filters:get ( "queryPlayer"           ),
}

_ZOMBIE_TURRET.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
}

_ZOMBIE_TURRET.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_ZOMBIE_TURRET.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_ZOMBIE_TURRET.static.PALETTE = createColorVector ( 
  Colors.black, 
  Colors.fix_dark_blue,
  Colors.engineer_green_1,
  Colors.light_gray_blue_2,
  Colors.white,
  Colors.whitePlus
)
_ZOMBIE_TURRET.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_blue,
  Colors.fix_dark_blue, 
  Colors.fix_dark_blue, 
  Colors.engineer_green_1, 
  Colors.engineer_green_1,
  Colors.engineer_green_1
)

_ZOMBIE_TURRET.static.DROP_TABLE = {
  MONEY = 10,
  BURST = 3,
  DATA  = 0.17,
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Init       ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _ZOMBIE_TURRET:finalize ( parameters )

  self:setPos(self:getX()+1,self:getY())
  self:setDefaultValues(4)
  self.wait_timer = 80
  self.plasma_ball_count = 55

  self.sprite = Sprite:new ( SPRITE_FOLDERS.enemies, "virus-zombie-turret", 1 )
  self.sprite:change ( 1, "idle" )

  local garbageSpawn, prox = false, false
  if parameters then
    self.sprite:flip ( parameters.scaleX, nil)
    if parameters.scaleX < 0 then
       -- self:setPos(self:getX()+4,self:getY())
    end
    if parameters.spawnFromGarbage then
      self.sprite:change ( 1, "spawn" )
      garbageSpawn = true
      self.state.isContactDamageDisabled = true
    elseif parameters.proximityGarbageSpawn then
      self.sprite:change ( 1, "spawn" )
      garbageSpawn = true
      self.state.isContactDamageDisabled = true
      prox = true
    end
    self.MONEY_SPAWN_DISABLED = parameters.disableMoney
    self.BURST_SPAWN_DISABLED = parameters.disableBurst
  end

  self.sensors = {
    spawn =
      Sensor
        :new                ( self, self.filters.player, -140, -70, 20+120*2, 105 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :setLayer           ( Layer:get("DEBUG", "HITBOX")   ),
  }

  self.randomChanceToFlinch = 0.2
  self.facingDirection      = self.sprite:getScaleX()

  self:addCollider ( "collision", self.dimensions.x, self.dimensions.y, self.dimensions.w, self.dimensions.h, self.properties )
  self:addCollider ( "grabbox",   0,   10, 28,  20, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )

  self:insertCollider ( "collision" )
  self:insertCollider ( "grabbox"   )
  self:insertCollider ( "grabbed"   )

  if garbageSpawn then
    self:gotoState ( "GARBAGE_SPAWN", parameters.summonDelay, prox )
  else
    self:gotoState ( "IDLE" )
  end
end

function _ZOMBIE_TURRET:setSpawnVariant ( )
  self._isSpawnVariant  = true
  self._emitSmoke       = true
  Environment.smokeEmitter ( self )
end

function _ZOMBIE_TURRET:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 or self.isDestructed or self.IS_IGNORING_BONKS then return end
  local x, y = self:getPos            ( )
  local l    = self.layers.bottom     ( )
  local sx   = self.sprite:getScaleX  ( )

  x = x + love.math.random(0,6)*math.rsign()
  y = y + love.math.random(1,2)
  --if sx < 0 then
    x = x + 8
    y = y - 3
  --else
  --  x = x + 14
  --  y = y - 15
  --end

  Particles:addFromCategory ( "warp_particle_trace", x, y, 1, 1, 0, -0.5, l, false, nil, true )
end

function _ZOMBIE_TURRET:manageDestructEnter ( )
  if self._emitSmoke then
    self._emitSmoke = false
    Environment.smokeEmitter ( self, true )
  end
end

function _ZOMBIE_TURRET:cleanup ( )
  if self._emitSmoke then
    self._emitSmoke = false
    Environment.smokeEmitter ( self, true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Update     ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _ZOMBIE_TURRET:update ( dt )
    
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
  self:tick    ( dt )
  
  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  self:updateContactDamageStatus ( )
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ Tick functionS ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _ZOMBIE_TURRET:tick ( dt ) 

  if self.health <= 0 then
    self:delete()
    return
  end

  self:gotoState ( "IDLE" )
  self:applyPhysics()
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _ZOMBIE_TURRET:addState ( "IDLE" )

function _IDLE:enteredState ( fromProxSpawn )
  self.sprite:change ( 1, "idle" )
  self.stateVars.loops = math.floor(RNG.n() * 3)+2
  if fromProxSpawn then
    self.stateVars.loops = math.max ( self.stateVars.loops - 3, 2 )
  end
  self.stateVars.added = false
end

function _IDLE:tick ( dt )

  local x,y = self:getPos()
  x = x+8
  if not Camera:isWithinView ( x, y+8, 64 ) then 
    self.stateVars.loops = 1
    return 
  end
  if self.velocity.vertical.current > 0.25 or GetTime() % 6 == 0 then
    self:applyPhysics()
  end

  if not self:isInState ( "IDLE" ) then return end
  if self.sprite:getAnimation ( ) == "idle" then
    local f = self.sprite:getFrame()
    if not self.stateVars.added then
      if f == 1 then
        self.stateVars.added = true
        self.stateVars.loops = self.stateVars.loops - 1
      end
    else
      if f > 1 then
        self.stateVars.added = false
      end
    end
  end

  local px = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  if px and ((px > x and self.sprite:getScaleX() == -1) or (px < x and self.sprite:getScaleX() == 1)) then
    self.stateVars.loops = math.floor(RNG.n() * 2)
    self.sprite:change ( 1, "turn-around" )
  elseif self.stateVars.loops <= 0 then
    self:gotoState ( "SHOOT" )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Shoot --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SHOOT = _ZOMBIE_TURRET:addState ( "SHOOT" )

function _SHOOT:enteredState ( )
  self.sprite:change ( 1, "shoot", 2 )
  self.timer = 0
end

function _SHOOT:tick ( dt )
  if self.velocity.vertical.current > 0.25 or GetTime() % 6 == 0 then
    self:applyPhysics()
  end

  if not self:isInState ( "SHOOT" ) then return end
  self.timer = self.timer + 1
  if self.timer == 35 then
    local x, y        = self:getMiddlePoint()
    local sx          = self.sprite:getScaleX()
    local dirX, dirY  = sx, 0
    local px, py      = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
    if px then
      local ang = math.angle ( x, y, px, py )
      dirX, dirY = math.cos(ang), math.sin(ang)
    end

    if sx == 1 then
      math.max(dirX, 0.25)
    else
      math.min(dirX, -0.25)
    end
    dirY = math.min ( dirY, 0.125)
    dirX, dirY = math.normalize(dirX, dirY)
    Audio:playSound ( SFX.gameplay_enemy_laser_shot )
    local x = x+ (sx < 0 and -12 or -1)
    GameObject:spawn ( "oval_projectile", x, y-2, 2.5, 2.5, dirX, dirY, "big" )
    Particles:add    ( "oval_shot_shoot_neutral", x-4, y-8, 1 )
  end

  if not self.sprite:isPlaying() then
    self:gotoState ( "IDLE")
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Garbage spawn §spawn -----------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SPAWN = _ZOMBIE_TURRET:addState ( "GARBAGE_SPAWN" )

function _SPAWN:enteredState ( delay, proximity )
  if not delay then
    self.sprite:change ( 1, "spawn" )
  else
    self.sprite:change ( 1, nil )
  end
  if proximity then
    self.sprite:change ( 1, nil )
    self.stateVars.proximity       = true
    self.stateVars.startedWithProx = true
  end

  self.IS_IGNORING_BONKS              = true
  self.stateVars.delay                = delay or 0
  self.state.isHittable               = false
  self.state.isContactDamageDisabled  = true
end

function _SPAWN:exitedState ( )
  self.IS_IGNORING_BONKS              = false
  self.state.isHittable               = true
  self.state.isContactDamageDisabled  = false
end

function _SPAWN:tick ()
  if self.stateVars.proximity then
    local hit = self.sensors.spawn:check ( )
    if hit then
      local px = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
      if px then
        self.sprite:flip ( px > self:getX() and 1 or -1 )
      end
      self.stateVars.delay = 2
      self.stateVars.proximity = false
    else
      return
    end
  end

  if not self.state.isGrounded then
    self:applyPhysics()
  end

  if self.stateVars.delay > 0 then
    self.stateVars.delay = self.stateVars.delay - 1
    if self.stateVars.delay <= 0 then
      Audio:playSound ( SFX.gameplay_zombie_spawn )
      self.sprite:change ( 1, "spawn" )
    else
      return
    end
  end
  if GetTime()%13 == 0 then
    local x,y   = self:getPos()
    Environment.landingParticle ( x, y, self.dimensions, 2, 16, 8, nil, nil, "garbage" )
  end
  if self.sprite:getFrame () > 7 then
    self.state.isHittable               = true
    self.state.isContactDamageDisabled  = false
  end
  if self.sprite:getAnimation() == "idle" then
    self:gotoState("IDLE", self.stateVars.startedWithProx)
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _ZOMBIE_TURRET:customEnemyDraw ( x, y, scaleX )
  if not self._isSpawnVariant then
    self.sprite:drawInstant ( 1, x, y )
    return
  end
  
  local offset  = self.hitFlash.current/self.hitFlash.max *5
  offset        = Shader:calculateShift ( math.floor(offset + ((self.stunTimer or 0))%10/2.25 +0.4), 3 )

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


return _ZOMBIE_TURRET