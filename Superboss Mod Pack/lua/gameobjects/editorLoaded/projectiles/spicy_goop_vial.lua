--> [GoopVial - spawns a Sticky Bubble upon collision]
local _SGV = BaseObject:subclass ( "STICKY_GOOP_VIAL" )
Mixins:attach( _SGV, "applyPhysics"    )
Mixins:attach( _SGV, "shake"           )
Mixins:attach( _SGV, "enemyDrawSprite" )
Mixins:attach( _SGV, "spawnShards"     )

Mixins:attach ( _SGV, "grabObject"        )
Mixins:attach ( _SGV, "pullObject"        )

_SGV.static.USES_POOLING          = true
_SGV.static.HAS_DESPAWN_MECHANISM = true
_SGV.static.NO_DATA_CHIP          = true

_SGV.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles" )
end

_SGV.static.DIMENSIONS = {
  x = 3,
  y = 3,
  w = 10,
  h = 12,

  grabPosX  = -8,
  grabPosMX = -4, 
  grabPosY  = 5,
}

_SGV.static.PROPERTIES = {
  isHittableProjectile  = true,
  isDamaging            = true,
  isBulletType          = true,
}

_SGV.static.FILTERS = {
  collision          = Filters:get ( "bulletFilter" ),
  crushingBlockSpawn = Filters:get ( "querySolidOrCrushable"  ),
  player             = Filters:get ( "queryPlayer" )
}

_SGV.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.TINY_PROJECTILE,
  HIT     = GAMEDATA.damageTypes.TINY_PROJECTILE,
}

_SGV.static.LAYERS = {
  sprite = Layer:get ( "ENEMIES", "PROJECTILES"    ),
  bottom = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
}

_SGV.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true
_SGV.static.PALETTE = createColorVector(
  Colors.black,
  Colors.purple_2, 
  Colors.hacker_purple_1,
  Colors.virus_purple_1, 
  Colors.amadeus_lightest_brown,
  Colors.white
)

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Initialize ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _SGV:finalize( )
  self.sprite         = Sprite:new ( SPRITE_FOLDERS.projectiles, "projectiles", 1 )
  self.updatePhysics  = true
  self.splitOffset    = 0
  
  self.onFreezeDirX           = 0
  self.onFreezeDirY           = 0
  self.onFreezeVerticalUpdate = true
  self.stickToPlayer          = true

  self:addCollider ( "collision", self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h,    self.properties )
  self:addCollider ( "grabbox",   self.dimensions.x-8,   self.dimensions.y-8, self.dimensions.w+16, self.dimensions.h+16, self.class.GRABBOX_PROPERTIES )
  self:addCollider ( "grabbed",   self.dimensions.x,     self.dimensions.y,   self.dimensions.w,    self.dimensions.h )

  self:setShardData           ( "break", 3, "sticky-bubble-gibs" )
  self:setShardSpawnOffset    ( "break", -1, 6    )
  self:setShardFrameData      ( "break", 3, true )
  self:setShardCustomDust     ( "break", self.spawnShardDust, self )
  self:setShardFlickering     ( "break", false )

  self:setShardData           ( "break2", 3, "sticky-goop-vial-gibs" )
  self:setShardSpawnOffset    ( "break2", -1, 6   )
  self:setShardFrameData      ( "break2", 5, true )
  self:setShardFlickering     ( "break2", true    )
  self:setShardDustOffset     ( "break2", -10, 0  )

  --self:setShardCollision      ( "break", false )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Reset --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _SGV:reset ( directionX, directionY, velX, velY )
  self.updatePhysics = true
  self.age           = GetSuperTime()

  self.sprite:change  ( 1, "sticky-goop-vial-spin" )  

  self:insertCollider ( "collision" ) 
  self:insertCollider ( "grabbox"   )
  self:insertCollider ( "grabbed"   )
  
  self.isDestroyed        = false
  self.destroyImmediately = false
  self.shakes             = 8
  self.invulDelay         = 4

  self.isReflected        = false

  local vy,vx = self.velocity.vertical, self.velocity.horizontal
  vy.direction = directionY and math.sign(directionY) or 1
  vy.current   = velY or -4.25
  vy.update    = true
  vx.direction = directionX and math.sign(directionX) or RNG:rsign()
  vx.current   = velX or RNG:n() * 4.25

  self.sprite:flip ( vx.direction < 0 and 1 or -1 )

  self:clearShards  ("break")
  self:disableShards("break")  
  self:clearShards  ("break2")
  self:disableShards("break2")

  local hits, len = Physics:queryRect ( self:getX()+self.dimensions.x, self:getY()+self.dimensions.y, self.dimensions.w, self.dimensions.h, self.filters.crushingBlockSpawn )
  local numOfHits = 0
  if len > 0 then
    for i = 1, len do
      if hits[i].isTile then
        self.sprite:change ( 1, nil )
        self.isDestroyed        = true
        self.destroyImmediately = true
        break
      end 
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Rest ---------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _SGV:lateUpdate(dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end
  if self.invulDelay > 0 then
    self.invulDelay = self.invulDelay - 1
  end

  local x, y = self:getPos()
  if not Camera:isWithinView ( x, y, 96 ) then
    self:delete()
    return
  end
  self:tick(dt,x,y)
  self.sprite:update(dt)
  self:updateShake()
end

function _SGV:tick (dt,x,y)  
  if not self.isDestroyed then
    self:applyPhysics()
  else
    self:updateShards( "break"  )
    self:updateShards( "break2" )
    if not self:hasSpawnedShards ( "break" ) and not self:hasSpawnedShards( "break2" ) then
      self.destroyImmediately = true
    end
  end

  if self.destroyImmediately then
    self:delete()
  end
end

function _SGV:handleYBlock ()
  if self.isDestroyed then return end
  self:spawnBubble()
end

function _SGV:handleXBlock ()
  if self.isDestroyed then return end
  self.velocity.horizontal.current = -self.velocity.horizontal.current
  if self.isReflected then
    self:spawnBubble()
  end
end

function _SGV:takeDamage (damage, direction, knockbackX, knockbackY, launchingAttack)
  if self.isDestroyed or self.invulDelay > 0 then return end

  if self.hasBeenGrabbed then
    direction                          = direction or RNG:rsign()
    self.velocity.vertical.current     = knockbackY or -3
    self.velocity.vertical.direction   = 1
    self.velocity.horizontal.current   = knockbackX or 2
    self.velocity.horizontal.direction = direction
  else
    direction = direction or RNG:rsign()
    if math.abs(direction) < 1 then
      direction = RNG:rsign()
    end
    knockbackX = knockbackX or 2
    knockbackY = knockbackY or -3

    local vy = math.abs(knockbackY)*1
    vy = vy - vy%0.25 
    self.velocity.vertical.current = -(vy)
    local vx = math.max( self.velocity.horizontal.current - 0.25, 1 )

    self.velocity.horizontal.current   = knockbackX > vx and knockbackX or vx
    self.velocity.horizontal.direction = direction
  end
  self.sprite:flip(-direction)
  return true
end

function _SGV:manageThrowAnimation ( )
  self.sprite:change  ( 1, "sticky-goop-vial-spin" )  
end

function _SGV:manageReleaseFromGrab(wasChained) 
  self.sprite:change  ( 1, "sticky-goop-vial-spin" )  
end

function _SGV:chain ( )
  if self.isDestroyed or self.invulDelay > 0 then return false end
  self.hasBeenGrabbed      = true

  self.isReflected         = true
  self.updatePhysics       = false
  self.isChainedByHookshot = true
  self.sprite:change ( 1, "sticky-goop-vial-grabbed" )
  self:applyShake(3)
  return true
end

function _SGV:isSuplexable ( )
  return false
end

function _SGV:isGrabbable ( )
  if self.isDestroyed or self.invulDelay > 0 then return false end
  return true
end

function _SGV:applyCrush ()
  self.health = 0       
  self:takeDamage ()    
end

function _SGV:callObserver (obj)
  if not (obj.isPlayer or (obj.isTile and obj.isDamaging) or (obj.isBreakable) or (self.isReflected and obj.isEnemy) or (obj.parent and obj.parent.class == self.class)) then return end
  if obj.isPlayer and not self.isReflected then
    local ret = GlobalObserver:single ( "PLAYER_TAKES_DAMAGE", self.class.DAMAGE.HIT, "weak", self.velocity.horizontal.direction )
    return ret and 1 or 0
  elseif obj.isBreakable then
    if obj.parent and obj.parent.takeDamage then
      Audio:playSound ( SFX.gameplay_punch_hit )
      obj.parent:takeDamage()
      return 1
    end
  elseif obj.isTile then
    return 2
  elseif self.isReflected and obj.isEnemy and obj.parent and obj.parent.takeDamage then
    Audio:playSound ( SFX.gameplay_punch_hit )
    if obj.parent:takeDamage (GAMEDATA.damageTypes.BOSS_BONK_SMALL, self.velocity.horizontal.direction, 2, -1 ) then
      if obj.parent.state and obj.parent.state.isBoss then
        Challenges.unlock ( Achievements.RETURN_TO_BOSS )
      end
    end
    return 1
  end
end

function _SGV:handleCollisions ( colsX, lenX, colsY, lenY )
  for i = 1, lenX do
    local ret = self:callObserver(colsX[i].other)
    if ret then
      self:spawnBubble(ret==1)
      return
    end
  end
  for i = 1, lenY do
    local ret = self:callObserver(colsY[i].other)
    if ret then
      self:spawnBubble(ret==1)
      return
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Behaviors ----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _SGV:spawnBubble ( hitPlayer )
  Audio:playSound ( SFX.gameplay_ice_clink )
  self.isDestroyed = true
  GameObject:spawn ( 
    "sticky_bubble", 
    self:getX(), 
    self:getY(),
    hitPlayer and -self.velocity.horizontal.direction or 0,
    1,
    1,
    -2,
    hitPlayer
  )
  --self:spawnShards ( "break" )
  self:spawnShards ( "break2" )
  self.sprite:change ( 1, nil )
  Audio:playSound ( SFX.gameplay_enemy_explosion      )
  Audio:playSound       ( SFX.gameplay_big_guy_bomb_explode, 0.75 )
  local x, y       = self:getPos ( )
  local cols, len = Physics:queryRect ( x-20, y-20, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y+7, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y+7, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y+37, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y+37, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y+7, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y-27, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y-27, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y+37, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y-27, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y-57, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y-57, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y-57, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y-87, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y-87, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y-87, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x-27, y-117, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+37, y-117, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  local cols, len = Physics:queryRect ( x+7, y-117, 40, 40 )
  for i = 1, len do
    if cols[i] and cols[i].isPlayer then
      GlobalObserver:none ( "PLAYER_TAKES_DAMAGE", GAMEDATA.damageTypes.EXPLOSIVE_PROJECTILE_LIGHT, "weak", RNG:rsign() )
      break
    end
  end
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y+7, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y+7, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y+37, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y+37, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y+7, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y-27, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y+37, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y-27, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y-27, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y-57, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y-57, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y-57, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y-87, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y-87, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y-87, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+37, y-117, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x-27, y-117, self.layers.bottom()+2, false, 1 )
  Particles:addSpecial("small_explosions_in_a_circle", x+7, y-117, self.layers.bottom()+2, false, 1 )

end

function _SGV:spawnShardDust ( x, y, l )
  Particles:addFromCategory ( 
    "sticky_bubble_splat", 
    x-8, 
    y-7, 
    1, 
    1, 
    0, 
    0,
    self.layers.bottom(),
    false,
    nil,
    true
  )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Draw    ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _SGV:drawSpecial()
  self:drawShards ( "break"  )
  self:drawShards ( "break2" )
end

function _SGV:isDrawingWithPalette()
  return self.hitFlash.current > 0
end

return _SGV