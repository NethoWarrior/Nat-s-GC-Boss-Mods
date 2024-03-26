-- VIRUS ZOMBIE
local _VIRUS_ZOMBIE = BaseObject:subclass ( "VIRUS_ZOMBIE"):INCLUDE_COMMONS ( )
Mixins:attach ( _VIRUS_ZOMBIE, "ledgeChecker" )
Mixins:attach ( _VIRUS_ZOMBIE, "pullObject"   )
Mixins:attach ( _VIRUS_ZOMBIE, "gravityFreeze"  )

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Static     ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

_VIRUS_ZOMBIE.static.EDITOR_DATA = {
  width     = 2,
  height    = 2,
  ox        = -16,
  oy        = -17,
  mx        = 30,
  order     = 9980,
  category  = "enemies",
  properties = {
    isSolid       = true,
    isFlippable   = true,
    isDamaging    = true,
    isTargetable  = true,
  },
  variants = {
    {
      ox          = -16,
      oy          = -17,
      mx          = 30,
      parameters  = {
        proximityGarbageSpawn = true
      },
    }
  },
}

_VIRUS_ZOMBIE.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.enemies,     "virus-zombie" )
end

_VIRUS_ZOMBIE.static.DIMENSIONS = {
  x            =   4,
  y            =   4,
  w            =  20,
  h            =  28,
  -- these basically oughto match or be smaller than player
  grabX        =   7,
  grabY        =   4,
  grabW        =  14,
  grabH        =  28,


  grabPosX     =  -7,
  grabPosMX    =  -5, -- player facing left
  grabPosY     =   0,

  -- visual middle point
  vx  =  3,
  vmx = -2,
  vy  = -2,
}

_VIRUS_ZOMBIE.static.PROPERTIES = {
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_VIRUS_ZOMBIE.static.FILTERS = {
  tile      = Filters:get ( "queryTileFilter"       ),
  collision = Filters:get ( "enemyCollisionFilter"  ),
  damaged   = Filters:get ( "enemyDamagedFilter"    ),
  player    = Filters:get ( "queryPlayer"           ),
}

_VIRUS_ZOMBIE.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
}

_VIRUS_ZOMBIE.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
}

_VIRUS_ZOMBIE.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.MEDIUM_CONTACT_DAMAGE
}

_VIRUS_ZOMBIE.static.PALETTE = createColorVector ( 
  Colors.black, 
  Colors.fix_dark_blue,
  Colors.virus_purple_1,
  Colors.light_gray_blue_2,
  Colors.white,
  Colors.whitePlus
)

_VIRUS_ZOMBIE.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_red_than_kai,
  Colors.hacker_purple_2, 
  Colors.hacker_purple_2, 
  Colors.virus_purple_1, 
  Colors.virus_purple_1,
  Colors.virus_purple_1
)

_VIRUS_ZOMBIE.static.DROP_TABLE = {
  MONEY = 10,
  BURST = 3,
  DATA  = 0.15,
}

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Init       ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _VIRUS_ZOMBIE:finalize ( parameters )

  self:setPos(self:getX()+1,self:getY())
  self:setDefaultValues(4)
  self.plasma_ball_count = 55
  self.wait_timer = 80

  self.sprite = Sprite:new ( SPRITE_FOLDERS.enemies, "virus-zombie", 1 )
  self.sprite:change ( 1, "idle" )

  local garbageSpawn, prox = false, false
  if parameters then
    self.sprite:flip ( parameters.scaleX, nil)
    if parameters.scaleX < 0 then
        self:setPos(self:getX()+4,self:getY())
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

  self.randomChanceToFlinch = 0.3
  self.facingDirection      = self.sprite:getScaleX()

  self:addCollider ( "collision", self.dimensions.x, self.dimensions.y, self.dimensions.w, self.dimensions.h, self.properties )
  self:addCollider ( "grabbox",   0,   2, 28,  28, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )

  local l = Layer:get("DEBUG", "HITBOX")
  self.sensors = {
    vision =
      Sensor
        :new                ( self, self.filters.player, -80, -60, 170, 70 )
        :expectOnlyOneItem  ( true )
        :setLayer           ( l    ),
    explosion =
      Sensor
        :new                ( self, self.filters.player, -35, -30, self.dimensions.w + 30, self.dimensions.h )
        :isScaleAgnostic    ( true ),
    spawn =
      Sensor
        :new                ( self, self.filters.player, -140, -70, 20+120*2, 105 )
        :expectOnlyOneItem  ( true )
        :isScaleAgnostic    ( true )
        :setLayer           ( l  ),

  }
  self:enableHorizontalLedgeCheck ( 22, 4, nil, 3, 4 )

  self:insertCollider ( "collision" )
  self:insertCollider ( "grabbox"   )
  self:insertCollider ( "grabbed"   )

  if garbageSpawn then
    self:gotoState ( "GARBAGE_SPAWN", parameters.summonDelay, prox )
  else
    self:gotoState ( "IDLE" )
  end
end

function _VIRUS_ZOMBIE:setSpawnVariant ( )
  self._isSpawnVariant = true
  self._emitSmoke      = true
  Environment.smokeEmitter ( self )
end

function _VIRUS_ZOMBIE:env_emitSmoke ( )
  if GetTime() % 3 ~= 0 or self.isDestructed or self.IS_IGNORING_BONKS then return end
  local x, y = self:getPos            ( )
  local l    = self.layers.bottom     ( )
  local sx   = self.sprite:getScaleX  ( )

  x = x + love.math.random(0,6)*math.rsign()
  y = y + love.math.random(1,2)
  --if sx < 0 then
    x = x + 8
    y = y - 8
  --else
  --  x = x + 14
  --  y = y - 15
  --end

  Particles:addFromCategory ( "warp_particle_trace", x, y, 1, 1, 0, -0.5, l, false, nil, true )
end

function _VIRUS_ZOMBIE:manageDestructEnter ( )
  if self._emitSmoke then
    self._emitSmoke = false
    Environment.smokeEmitter ( self, true )
  end
end

function _VIRUS_ZOMBIE:cleanup ( )
  if self._emitSmoke then
    Environment.smokeEmitter ( self, true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------     Update     ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _VIRUS_ZOMBIE:update ( dt )

  if self.isStunned then
    self.state.isContactDamageDisabled = true
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
    
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  if self.destructTimer then
    self.destructTimer = self.destructTimer - 1
    if self.destructTimer > 0 then
      local hit, cols, len = self.sensors.explosion:check()
      if hit then
        local other
        for i = 1, len do
          other = cols[i]
          if other and (other.isPlayer or other.isEnemy) and not self.explosionHitTable[other.ID] then
            if self:callObserver(other) then
              self.explosionHitTable[other.ID] = true
            end
          end
        end
      end
    end
  end

  self:tick    ( dt )
  
  if self.secondaryTick then
    self:secondaryTick ( dt )
  end

  if self.fakeOverkilledTimer then
    self.fakeOverkilledTimer = self.fakeOverkilledTimer + 1
  end

  if not self.isStunned then
    if self.timeToBlowUp and not self:isInState ( "DESTRUCT" ) then
      local mx, my = self:getMiddlePoint("collision")
      mx = mx + (self.sprite:getScaleX() > 0 and 2 or -10 )
      my = my + 9
      Particles:add ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.sprite()+1 )
      Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

      Particles:add ( "beam_palm_purge_explosion", mx,my, 1, 1, 0, 0, self.layers.particles() )
      if self.stateVars then
        self.stateVars.exitedProperly = true
      end
      self:gotoState ( "DESTRUCT" )
      self.destructTimer      = 10
      self.explosionHitTable  = {}
    end
  end

  self:updateContactDamageStatus ( )
  self:updateShake()
  self:handleAfterImages ()
  self.sprite:update ( dt )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ Tick functionS ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _VIRUS_ZOMBIE:tick ( dt ) 
  if self.health <= 0 then
    self:delete()
    return
  end

  self:gotoState    ( "IDLE" )
  self:applyPhysics ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Etc     ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _VIRUS_ZOMBIE:handleXBlock ()
  if not (self.hasHurled or self.fakeOverkilled) then return end
  self.timeToBlowUp = true
end

function _VIRUS_ZOMBIE:handleYBlock ()
  if not (self.hasHurled or self.fakeOverkilled) then return end
  if self.velocity.vertical.current > 0 then
    self.timeToBlowUp = true
  end
end

function _VIRUS_ZOMBIE:handleBounce ()
  if not (self.hasHurled or self.fakeOverkilled) then return end
  self.timeToBlowUp = true
end

function _VIRUS_ZOMBIE:callObserver (obj)
  if not (obj.isPlayer) then return end
  if obj.isPlayer then
    return GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSION, "weak", self.velocity.horizontal.direction )
  end
end

function _VIRUS_ZOMBIE:handleCollisions ( colsX, lenX, colsY, lenY )
  if self.state.isContactDamageDisabled then return end
  for i = 1, lenX do
    self:callObserver(colsX[i].other)
  end

  for i = 1, lenY do
    self:callObserver(colsY[i].other)
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _VIRUS_ZOMBIE:addState ( "IDLE" )

function _IDLE:enteredState ( )
  self.sprite:change ( 1, "idle" )
  self.velocity.horizontal.current    = 0
  self.velocity.horizontal.direction  = self.sprite:getScaleX()

  self.timer = 10 + RNG.n() * 30
end

function _IDLE:tick ( dt )
  self:applyPhysics()
  self.timer = self.timer - 1
  if self.timer <= 0 then
    if self.sprite:getFrame() == 1 then
      self:gotoState ( "ROAM" )
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Roam  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _ROAM = _VIRUS_ZOMBIE:addState ( "ROAM" )

function _ROAM:enteredState ( )
  self.sprite:change ( 1, "walk" )
  self.velocity.horizontal.direction  = self.sprite:getScaleX()
  self.stateVars.stepsToTake          = 2 + math.floor(RNG.n() * 3)
  self.stateVars.stepsTaken           = 0
  self.stateVars.startedStep          = false
  self.stateVars.turnAroundTimer      = 0
end

function _ROAM:tick ( dt )
  if self.sensors.vision:check ( self.sprite:getScaleX(), 1 ) then
    if not self.isChainedByHookshot then
      self:gotoState ( "HURL" )
    end
    return
  end

  if self.stateVars.turnAroundTimer <= 0 then
    self:_walk()
  else
    self.stateVars.turnAroundTimer = self.stateVars.turnAroundTimer - 1
    if self.stateVars.turnAroundTimer <= 0 then
      self.stateVars.turnAround           = false
    end
  end
end

function _ROAM:_walk ()
  if self.sensors.vision:check ( self.sprite:getScaleX(), 1 ) then
    if not self.isChainedByHookshot then
      self:gotoState ( "HURL" )
    end
    return
  end

  if self.sprite:getFrame() == 1 and self.sprite:getAnimation() == "idle" then
    self.sprite:change ( 1, "walk" )
  end

  if not self.stateVars.turnAround then
    self.velocity.horizontal.direction  = self.sprite:getScaleX()
    local f = self.sprite:getFrame ()
    if f == 2 then
      self.stateVars.startedStep = true
    elseif f == 3 then
      self.velocity.horizontal.current = 0.0
    elseif f == 4 then
      self.velocity.horizontal.current = 0
    elseif f == 5 then
      self.velocity.horizontal.current = 0.25
    elseif f == 6 then
      self.velocity.horizontal.current = 0.75
    elseif f == 7 then
      self.velocity.horizontal.current = 0.5
    else
      if f==1 and self.stateVars.startedStep then
        self.stateVars.startedStep = false
        self.stateVars.stepsTaken  = self.stateVars.stepsTaken + 1
        if self.stateVars.stepsTaken > self.stateVars.stepsToTake then
          self:gotoState("IDLE")
        end
      end
      self.velocity.horizontal.current = 0
    end
  end


  if _ROAM.hasQuitState(self) then return end
  local sp = self.velocity.horizontal.current
  self:checkFloorLedgesAndStop  ( 0.25 )
  self:applyPhysics             ( )
  if not self.stateVars.turnAround then
    if sp ~= self.velocity.horizontal.current then
      self.stateVars.turnAround = true
      self.sprite:change ( 1, "turn-around")
    end
  elseif self.velocity.horizontal.current == 0 then
    self.stateVars.turnAroundTimer = 30
  end
end

function _ROAM:handleXBlock ()
  self.velocity.horizontal.current = 0
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Hurl  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HURL = _VIRUS_ZOMBIE:addState ( "HURL" )

function _HURL:enteredState ( )
  self.sprite:change ( 1, "idle" )
  self.velocity.horizontal.current    = 0
  self.velocity.horizontal.direction  = self.sprite:getScaleX()
  self.stateVars.jumped               = false
  self.stateVars.changedAnim          = false
  self.timer                          = 10

  local px = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  if px then
    self.sprite:flip( px > self:getX() and 1 or -1 )
  end
end

function _HURL:tick ( dt )
  if not self.stateVars.jumped then
    self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    self.timer = self.timer - 1

    if self.timer <= 0 then
      if self.sprite:getFrame() == 1 and not self.stateVars.changedAnim then
        self.stateVars.changedAnim = true
        self.sprite:change ( 1, "jump")
      end
      if self.sprite:getFrame() == 8 and self.stateVars.changedAnim then
        self:_jump()
      end
    end
  end

  if self.stateVars.jumped then
    if self.velocity.horizontal.current <= 2 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 1.5 )
    end
  end
  self:applyPhysics()

  if self.stateVars.blowUp then
    self:gotoState ( "BLOW_UP" )
  end
end

function _HURL:_jump ( )
  local direction = 1
  local px        = GlobalObserver:single("GET_PLAYER_MIDDLE_POINT")
  local vx        = 3
  if px then
    vx = math.abs(self:getX() - px)/38
    vx = math.min(vx - vx%0.25,3.75)
    if vx < 1 then
      vx = 1
    end

    vx = vx + 0.5
    local x, y = self:getMiddlePoint ()
    direction = x > px and -1 or 1
  end

  Audio:playSound ( SFX.gameplay_boss_cable_jump )

  self.sprite:flip( direction)
  self.velocity.horizontal.current    = vx
  self.velocity.horizontal.direction  = direction
  self.velocity.vertical.current      = -4

  self.spawnAfterImages               = true
  self.stateVars.jumped               = true
  
  self:permanentlyDisableContactDamage ( true )
end

function _HURL:handleXBlock ()
  if not self.stateVars.jumped then return end
  self.velocity.horizontal.current = 0
end

function _HURL:handleYBlock ()
  if not self.stateVars.jumped then return end
  if self.velocity.vertical.current > 0 then
    Audio:playSound ( SFX.gameplay_boss_cable_landing )
    self.stateVars.blowUp = true
    self.velocity.horizontal.current = 0
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Blow up ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _BLOW = _VIRUS_ZOMBIE:addState ( "BLOW_UP" )

function _BLOW:enteredState ( )
  self.sprite:change ( 1, "land-from-hurl", 2, true )
  self.stateVars.blow = false
  self.timer  = 90
end

function _BLOW:exitedState ( )
  -- ...
end

function _BLOW:tick ( )
  if self.sprite:isPlaying() then return end
  self.timer = self.timer - 1
  if self.timer == 80 then
    self:startBoom()
  elseif self.timer <= 0 then
    self.timeToBlowUp = true
  end
end

function _BLOW:isGrabbable ( )
  return false
end

function _BLOW:startBoom ( )
  local mx, my = self:getMiddlePoint("collision")
  mx = mx + (self.sprite:getScaleX() > 0 and 0 or -7 )
  my = my + 9

  Audio:playSound ( SFX.gameplay_stun )

  Particles:add ( "death_trigger_flash", mx,my, math.rsign(), 1, 0, 0, self.layers.sprite()+1 )
  Particles:addSpecial("small_explosions_in_a_circle", mx, my, self.layers.particles(), false, 0.75 )

  self.fakeOverkilledTimer            = 0
  self.fakeOverkilled                 = true

  self.health = 1000
  self:applyShake ( 3, 0.25 )

  self.MONEY_SPAWN_DISABLED = true
  self.BURST_SPAWN_DISABLED = true

  self.hasHurled = true
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Garbage spawn §spawn -----------------------]]--
--[[----------------------------------------------------------------------------]]--
local _SPAWN = _VIRUS_ZOMBIE:addState ( "GARBAGE_SPAWN" )

function _SPAWN:enteredState ( delay, proximity )
  if not delay then
    self.sprite:change ( 1, "spawn" )
  else
    self.sprite:change ( 1, nil )
  end
  if proximity then
    self.sprite:change ( 1, nil )
    self.stateVars.proximity = true
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
    Environment.landingParticle ( x, y, self.dimensions, -2, 15, 17, nil, nil, "garbage" )
  end
  if self.sprite:getFrame () > 9 then
    self.state.isHittable               = true
    self.state.isContactDamageDisabled  = false
  end
  if self.sprite:getAnimation() == "idle" then
    self:gotoState(nil)
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _VIRUS_ZOMBIE:customEnemyDraw ( x, y, scaleX )
  if not self._isSpawnVariant then
    self.sprite:drawInstant ( 1, x, y )
    return
  end


  local offset                        = self.hitFlash.current/self.hitFlash.max *5
  offset                              = Shader:calculateShift ( math.floor(offset + (self.fakeOverkilledTimer or (self.stunTimer or 0))%10/2.25 +0.4), 3 )

  local col = (self.isOverkilled or self.fakeOverkilled) and Colors.Sprites.enemy_overkilled or (self.isStunned and Colors.Sprites.enemy_stunned or self.class.PALETTE)
  local hit = self.hitFlash.current/self.hitFlash.max *5
  col = (self.isStunned and hit > 2 and Colors.Sprites.enemy_stunned_hit) or col

  if self.hitFlash.current > 0 or self.isStunned or self.isOverkilled or self.fakeOverkilledTimer then
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

return _VIRUS_ZOMBIE