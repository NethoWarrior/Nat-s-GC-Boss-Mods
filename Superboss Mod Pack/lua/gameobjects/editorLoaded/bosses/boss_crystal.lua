-- CRYSTAL, final stage 2 boss
local _CRYSTAL    = BaseObject:subclass ( "CRYSTAL_CIRCUIT_BANK" )
FSM:addState  ( _CRYSTAL, "CUTSCENE"  )
_CRYSTAL:attach ( "enemyDrawSprite"     )
_CRYSTAL:attach ( "shake"               )
_CRYSTAL:attach ( "contactDamage"       )
_CRYSTAL:attach ( "particleSpawning"    )
_CRYSTAL:attach ( "spawnRewards"        )
_CRYSTAL:attach ( "applyPhysics"        )
_CRYSTAL:attach ( "spawnFallingBlocks"  )

_CRYSTAL.static.IS_PERSISTENT     = true
_CRYSTAL.static.SCRIPT            = "dialogue/boss/cutscene_final_2_boss" 
_CRYSTAL.static.BOSS_CLEAR_FLAG   = "boss-defeated-flag-refight"

_CRYSTAL.static.EDITOR_DATA = {
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

_CRYSTAL.static.preload = function () 
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "circuit-crystal" )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.npc,         "kernel_boss"     )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.projectiles, "projectiles"     )
  AnimationLoader:loadAsync ( SPRITE_FOLDERS.obstacles,   "obstacles"       )
  CutsceneManager.preload   ( _CRYSTAL.SCRIPT                               )

  SetFlag ( "kernel-disappeared" )
end

_CRYSTAL.static.BASE_PALETTE        = Colors.Sprites.crystal
_CRYSTAL.static.PALETTE             = Colors.Sprites.crystal
_CRYSTAL.static.AFTER_IMAGE_PALETTE = createColorVector ( 
  Colors.darkest_red_than_kai, 
  Colors.kai_dark_red,
  Colors.kai_dark_red,
  Colors.kai_red,
  Colors.kai_red,
  Colors.kai_red
)

--[[
    Colors.black,
    Colors.kai_dark_red,
    Colors.kai_red,
    Colors.pink,
    Colors.white,
    Colors.whitePlus
]]

_CRYSTAL.static.HIDDEN_PALETTE_1 = createColorVector (
  Colors.black,
  Colors.darkest_red_than_kai,
  Colors.kai_dark_red,
  Colors.darker_red_than_kai,
  Colors.kai_red,
  Colors.kai_orange
)
_CRYSTAL.static.HIDDEN_PALETTE_2 = createColorVector (
  Colors.black,
  Colors.darkest_red_than_kai,
  Colors.kai_dark_red,
  Colors.kai_red,
  Colors.kai_red,
  Colors.kai_orange
)
_CRYSTAL.static.HIDDEN_PALETTE_3 = createColorVector (
  Colors.black,
  Colors.kai_dark_red,
  Colors.kai_dark_red,
  Colors.kai_red,
  Colors.kai_red,
  Colors.kai_orange
)
_CRYSTAL.static.HIDDEN_PALETTE_4 = createColorVector (
  Colors.black,
  Colors.kai_dark_red,
  Colors.kai_red,
  Colors.kai_red,
  Colors.pink,
  Colors.white
)

_CRYSTAL.static.GIB_DATA = {
  max      = 7,
  variance = 10,
  frames   = 7,
}

_CRYSTAL.static.DIMENSIONS = {
  x            =   7,
  y            =   9,
  w            =  34,
  h            =  53,
  -- these basically oughto match or be smaller than player
  grabX        =  10,
  grabY        =   6,
  grabW        =  14,
  grabH        =  26,

  grabPosX     =  11,
  grabPosY     =  -6,
}

_CRYSTAL.static.PROPERTIES = {
  --isSolid    = false,
  --isEnemy    = true,
  --isDamaging = true,
  --isHeavy    = true,
}

_CRYSTAL.static.ATTACK_PROPERTIES = {
  isSolid    = false,
  isEnemy    = true,
  isDamaging = true,
  isHeavy    = true,
}

_CRYSTAL.static.FILTERS = {
  tile              = Filters:get ( "queryTileFilter"             ),
  collision         = Filters:get ( "enemyCollisionFilter"        ),
  damaged           = Filters:get ( "enemyDamagedFilter"          ),
  player            = Filters:get ( "queryPlayer"                 ),
  elecBeam          = Filters:get ( "queryElecBeamBlock"          ),
  landablePlatform  = Filters:get ( "queryLandableTileFilter"     ),
}

_CRYSTAL.static.LAYERS = {
  bottom    = Layer:get ( "ENEMIES", "SPRITE-BOTTOM"  ),
  sprite    = Layer:get ( "ENEMIES", "SPRITE"         ),
  particles = Layer:get ( "PARTICLES"                 ),
  gibs      = Layer:get ( "GIBS"                      ),
  collision = Layer:get ( "ENEMIES", "COLLISION"      ),
  particles = Layer:get ( "ENEMIES", "PARTICLES"      ),
  death     = Layer:get ( "DEATH"                     ),
  real_gibs = Layer:get ( "FOREGROUND"                ),
}

_CRYSTAL.static.BEHAVIOR = {
  DEALS_CONTACT_DAMAGE              = true,
  FLINCHING_FROM_HOOKSHOT_DISABLED  = true,
  IS_MULTI_PARTED                   = true,
}

_CRYSTAL.static.DAMAGE = {
  CONTACT = GAMEDATA.damageTypes.LIGHT_CONTACT_DAMAGE
}

_CRYSTAL.static.DROP_TABLE = {
  MONEY = 0,
  BURST = 0,
  DATA  = 1,
}

_CRYSTAL.static.CONDITIONALLY_DRAW_WITHOUT_PALETTE = true


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Essentials ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:finalize ( parameters )
  self.canNotDestructToTelefrag = true
  self.isChainDashable = true

  RegisterActor ( ACTOR.ACTOR_1, self )
  self:translate ( 0, -4 )
  
  self.invulBuildup  = 0
  self:setDefaultValues ( GAMEDATA.boss.getMaxHealth ( true ) )

  self.updatePhysics = false
  self.extraFloat    = 0


  self.sprite = Sprite:new ( SPRITE_FOLDERS.npc, "circuit-crystal", 1 )
  self.sprite:addInstance  ( 2 )
  self.sprite:addInstance  ( 3 )
  self.sprite:addInstance  ( 4 )
  self.sprite:addInstance  ( 5 )
  self.sprite:addInstance  ( 6 )
  self.sprite:addInstance  ( 7 )

  self.sprite:addInstance  ( "spawn_ball" )
  self.sprite:addInstance  ( "kernel"     )
  self.sprite:addInstance  ( "cursor"     )

  self.sprite:change ( 1, "crystal-top",        3, true )
  self.sprite:change ( 2, "crystal-bottom",     1, true )
  self.sprite:change ( 3, "crystal-attachment", 1, true )
  self.sprite:change ( 4, "crystal-bg",         1, true )
  self.sprite:change ( 5, nil )
  self.sprite:change ( 6, nil )
  self.sprite:change ( 7, nil )

  self.screenShader = Shader:get ( "rowOffsetShader" )

  self.alwaysUsePaletteShader    = true
  self.BASE_PALETTE              = self.class.BASE_PALETTE
  self.ACTIVE_PALETTE            = self.class.HIDDEN_PALETTE -- ACTIVE_PALETTE

  self.lidPosition  = { 
    top     = 0,
    bottom  = 1,
    shake   = 0,
    opening = false,
    pal     = 1,
    palUpdate = false,

    summonTop = 0,
    summonBot = 0,
    summoning = false,
  }

  self.activeLayer        = Layer:get ( "PIT-WARNING"     )
  self.spawnBallLayer     = Layer:get ( "FOREGROUND"      )
  self.screenEffectLayer  = Layer:get ( "SCREEN_EFFECTS"  )

  self.sumTween = Tween.new (  8, self.lidPosition, { summonTop = 4, summonBot = -4 },  "linear"  )
  self.lidTween = Tween.new ( 16, self.lidPosition, { top       = 8, bottom    = -8 },  "outQuad" )
  self.palTween = Tween.new ( 32, self.lidPosition, { pal       = 5 },                  "linear"  )
  self.lidTween:finish      ( )

  self.isFlinchable = false

  self.beams                = { }
  self.beamsToCallDown      = 0
  self.beamsToCallDownTimer = 0
  self.actionsWithoutRest   = 0
  self.nextActionTime       = 10
  self.desperationActivated = false

  self.layers     = self.class.LAYERS
  self.filters    = self.class.FILTERS
  self.floatY     = 0

  self.spawnBallX   = 0
  self.spawnBallY   = 0
  self.spawnBallOX  = 8
  self.spawnBallOY  = 25

  self.spawnBallPos = {
    pos = 0,
  }

  self.spawnBallPos.tween = Tween.new ( 45, self.spawnBallPos, { pos = 1 }, "inOutQuad" )

  self.hazeShader = Shader:get ( "heatHazeShaderWithPaletteDeluxe" )

  self:addAndInsertCollider   ( "collision" )
  self:addCollider            ( "attackbox", self.dimensions.x+3, self.dimensions.y+5, self.dimensions.w-6, self.dimensions.h-12, self.class.ATTACK_PROPERTIES )
  self:insertCollider         ( "attackbox" )
  self:addCollider            ( "grabbox", self.dimensions.x-8, self.dimensions.y-11, self.dimensions.w+16, self.dimensions.h+19, self.class.GRABBOX_PROPERTIES )
  self:insertCollider         ( "grabbox")
  self:addCollider            ( "grabbed",   self.dimensions.grabX, self.dimensions.grabY, self.dimensions.grabW, self.dimensions.grabH )
  self:insertCollider         ( "grabbed" )

  self.defaultStateFromFlinch = nil

  self.state.isBoss  = true
  self.listener      = GlobalObserver:listen ( "START_BOSS_BATTLE", function() self:activate() end)

  self.kernelX, self.kernelY = 46,47

  if parameters and parameters.bossRush then
    if parameters.simpleCrystalFight then
      print("[CRYSTAL BOSS] Simple!")
      self.state.isBossRushSpawn_id = "CIRCUIT_CRYSTAL_SIMPLE"
      self.state.isSimpleVersion    = true

      if GAMESTATE.bossRushMode and GAMESTATE.bossRushMode.fullRush then
        self.sprite:change ( 5, "crystal-eye-light-up-simple", 5, false )
        self.sprite:change ( 6, nil )
        self.lidPosition.opening = true

        self.lidTween:update(-999)
        self.lidPosition.shaken = true
        self.lidPosition.shake  = 0
      end
    else
      print("[CRYSTAL BOSS] Full!")
      self.state.isBossRushSpawn_id = "CIRCUIT_CRYSTAL_FULL"
    end
    self.state.isBossRushSpawn = true
  else
    local dialAgain = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" )
    if not GAMESTATE.speedrun then
      if (dialAgain and dialAgain > 0) or (not GetFlag ( "final-2-boss-prefight-dialogue" )) then
        self.drawKernel = true
        self.kernelLayer = Layer:get("FOREGROUND")
        self.sprite:change ( "kernel", "kernel-stand-idle", RNG:range(1,6), true )
      end
    end
  end

  Environment.smokeEmitter ( self )

  if not self._unusedProjections then
    self._unusedProjections = {
      --1, 2, 3, 4, 5, 6, 7, 8
    }
    --if not GetStageFlag ( "subboss-saved-1" ) then
    for i = 1, 8 do
      if not GetStageFlag ( "subboss-saved-" .. i ) then
        table.insert ( self._unusedProjections, i )
      else
        -- achievement failed, we'll get 'em next time
        SetStageFlag ( "crystal-boss-boss-challenge", 1 )

        SetTempFlag ( self.class.PROJECTIONS[i].flag, 1 )
        SetTempFlag ( self.class.PROJECTIONS[i].flag .. "-explosion", 1 )
      end
    end
  end
end

local _ogMiddlePoint = _CRYSTAL.getMiddlePoint
_CRYSTAL.getMiddlePoint = function ( self )
  local mx, my = _ogMiddlePoint ( self )
  return mx, my - 3
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Misc                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:activate ( )
  GlobalObserver:none ( "BOSS_KNOCKOUT_SCREEN_SET_GOLD_STAR_ID", self.class.BOSS_CLEAR_FLAG )

  GAMEDATA.boss.setNextSpawnToHalfHealth        ( false )
  self.health      = GAMEDATA.boss.getMaxHealth ( )  
  self.activated   = true

  self.baseX, self.baseY = self:getPos ( )

  SetTempFlag ( "boss-fight-started", 1 )

  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "crystal", self.health )
end

function _CRYSTAL:cleanup()
  if self.listener then
    self.listener:destroy()
    self.listener = nil
  end
  --GAMESTATE.applyShaderOnGameScreen = nil
  if self.SPAWNED_BOSS then
    self.SPAWNED_BOSS = nil
  end
  Environment.smokeEmitter ( self, true )
  UnregisterActor ( ACTOR.ACTOR_1, self )
end

function _CRYSTAL:isDrawingWithPalette ( )
  return true
end

function _CRYSTAL:specialEndOfBossBehavior ( )
  GlobalObserver:none      ( "FORCE_UNDIM_BACKGROUNDS" )
  CutsceneManager.CONTINUE ( )
  self:delete              ( )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Animation handling -------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:manageChainAnimation ( )
  if self.state.isLaunched then
    self.sprite:change ( 1, "spin", 1 )
    self.sprite:stop   ( 1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cutscene stuff -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:notifyBossHUD ( dmg, dir )
  GlobalObserver:none ( "REDUCE_BOSS_HP_BAR", dmg, dir, self.health  )
  GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
end

function _CRYSTAL:getDeathMiddlePoint ( )
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
function _CRYSTAL:update (dt)
  if self.hitFlash.current > 0 then
    self.hitFlash.current = self.hitFlash.current - 1
  end

  --self:updateBossInvulnerability ( )
  self:updateLocations           ( )

  if self.activated and self:isInState ( nil ) then
    self.timer = self.timer + 1
    if self.nextActionTime < self.timer then
      self:pickAction()
    end
  end

  if self.activated and BUILD_FLAGS.DEBUG_BUILD and UI.kb.isDown ("a") and UI.kb.isDown ( "1" ) then
    if not self.isDying then
      self:gotoState ( "DEATH" )
    end
    --[[
    if not self.notifiedBossBattleOver then
      self.notifiedBossBattleOver = true
      self:notifyBossBattleOver ( )
    end]]
  end

  if not (self.isChainedByHookshot) then
    self:tick    ( dt )
  end

  if self.secondaryTick then
    self:secondaryTick ( dt )
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
      mx           = mx - 63
      my           = my + 19 + math.sin(self.floatY)
      GAMESTATE.addFreezeFrames ( 20, Colors.kai_dark_red, mx, my )
    end

    if self.stateVars.finalKillTimer == 0 then
      GameObject:stopSlowdown ()
      self.stateVars.finalKillTimer = nil
    end
  end

  --self:updateContactDamageStatus ( )
  self:updateShake               ( )
  if self.fakeOverkilledTimer then
    self.fakeOverkilledTimer = self.fakeOverkilledTimer - 1
    if self.fakeOverkilledTimer <= 0 then
      self.fakeOverkilledTimer      = nil
      self.state.isBossInvulnerable = false
    end
  end
  --self:handleAfterImages         ( )
  --self.sprite:update             ( dt )
end

---------------------------------------------------------
-- use this for handling the crystal sprite ------------
--------------------------------------------------------
-- this feels like abuse of systems, but should work! --
--------------------------------------------------------

_CRYSTAL.static.PALETTE_LIST = {
  _CRYSTAL.HIDDEN_PALETTE_1,
  _CRYSTAL.HIDDEN_PALETTE_2,
  _CRYSTAL.HIDDEN_PALETTE_3,
  _CRYSTAL.HIDDEN_PALETTE_4,
  _CRYSTAL.PALETTE,
}

function _CRYSTAL:env_emitSmoke ( )
  local fl = GetTempFlag ( "circuit-crystal-lid" )
  if fl then
    self.lidPosition.opening = fl == 1
    self.lidPosition.shaken  = false
    SetTempFlag ( "circuit-crystal-lid", false )
    Audio:playSound ( SFX.gameplay_cannon_open )
  end

  if self.lidPosition.shake > 0 then
    self.lidPosition.shake = math.max ( self.lidPosition.shake - 0.25, 0 )
  elseif self.lidPosition.shake < 0 then
    self.lidPosition.shake = math.min ( self.lidPosition.shake + 0.25, 0 )
  end

  if self.lidPosition.opening then
    self.lidTween:update(-1)
    if not self.lidPosition.shaken and self.lidTween:isAtStart ( ) then
      self.lidPosition.shaken = true
      self.lidPosition.shake  = 2
    end
  else
    self.lidTween:update(1)
  end

  --[[
  if not self.isDying then
    self.palTween:update ( self.lidPosition.palUpdate and 1 or -1 )
    local pal           = math.round ( self.lidPosition.pal )
    self.ACTIVE_PALETTE = self.class.PALETTE_LIST[pal]
  end]]

  if self.dropKernelT then
    self:cutscene_dropKernelToHole ( )
  end

  self.sprite:update  (  )
  if not self.isOverkilled and not self.floatingDisabled then
    self.floatY = self.floatY + 0.05
  end

  if self.hazeShader and self.activated then
    Shader:updateExtern ( self.hazeShader, "time",    0.004, true )
    Shader:updateExtern ( self.hazeShader, "cellDensity", 25 )
    --if self.SPAWNED_BOSS and self.SPAWNED_BOSS.hitFlash then
    --  Shader:updateExtern ( self.hazeShader, "strength",    0.0075 + (self.SPAWNED_BOSS.hitFlash.current/self.SPAWNED_BOSS.hitFlash.max) * 0.025 )
    --end
  end
end

function _CRYSTAL:tick ()

end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Drop kernel --------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:cutscene_dropKernelToHole ( )
  if not self.dropKernelT then
    self.dropKernelT = {
      timer = 0,
      grav  = -1.0,
    }
  end

  self.dropKernelT.timer = self.dropKernelT.timer + 1
  if self.dropKernelT.timer >= 16 then
    self.sprite:change ( "kernel", "kernel-fall-hole" )
  end
  if self.dropKernelT.timer >= 22 then
    self.kernelX = self.kernelX - 0.25
  end
  if self.dropKernelT.timer >= 27 then
    self.kernelX = self.kernelX - 0.25
  end
  if self.dropKernelT.timer >= 37 then
    self.kernelX = self.kernelX - 0.5
  end
  if self.dropKernelT.timer >= 42 then
    self.dropKernelT.grav = self.dropKernelT.grav + 0.25
    self.kernelY          = self.kernelY + self.dropKernelT.grav
  end
  if self.dropKernelT.timer >= 100 then
    self.drawKernel  = false
    self.dropKernelT = nil
    return true
  end
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight anim ------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:cutscene_runPrefightDialogueAnimation ( )
  if not self.prefightAnimation then
    self.sprite:change ( "kernel", nil )
    local fl = GetFlag ( "final-2-boss-prefight-dialogue" )

    local dialAgain = GetFlagAbsoluteValue ( "re-enable-boss-prefight-dialogue-on-next-stage" )
    if (dialAgain and dialAgain > 0) then
      fl = false
    end
    self.prefightAnimation = {
      timer   = 0,
      target1 = fl and 5  or 45,
      target2 = fl and 40 or 80,
      target3 = fl and 90 or 110,
    }
  end

  self.prefightAnimation.timer = self.prefightAnimation.timer + 1
  if self.prefightAnimation.timer == self.prefightAnimation.target1 then
    Audio:playSound ( SFX.gameplay_cannon_open )
    self.lidPosition.opening = true
    self.lidPosition.shaken  = false
    self.lidPosition.palUpdate = true
  end

  if self.prefightAnimation.timer == self.prefightAnimation.target2 then
    Audio:playSound    ( SFX.gameplay_scrap_golem_eye_shine )
    self.sprite:change ( 6, "crystal-eye-light-up", 1, true )
  end

  if self.prefightAnimation.timer == self.prefightAnimation.target3 then
    self.prefightAnimation = nil
    return true
  end

  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Pick action §action ------------------------]]--
--[[----------------------------------------------------------------------------]]--

_CRYSTAL.static.ACTIONS = {
  "DESPERATION_ACTIVATION",  -- 1, doesn't exist!
  "PROJECTION",              -- 2, working
  "DEFAULT",                 -- 3,
  "RAY",                     -- 4,
  "TRACE",                   -- 5,
  "BLADE",                   -- 6,
  "CABLE",                   -- 7,
  "BIT",                     -- 8,
  "MEDLEY",                  -- 9,
  "CRASH",                   -- 10,
  "HASH",                    -- 11
  "PICKING",                 -- 12,
  "DEFAULT_2",               -- 13
}

_CRYSTAL.static.PROJ_ACTIONS = {
  [1] = 4,
  [2] = 5,
  [3] = 6,
  [4] = 7,
  [5] = 8,
  [6] = 9,
  [7] = 10,
  [8] = 11,
}

------------------------
-- bosses implemented --
------------------------
-- 1, ray,    working
-- 2, fix,    working
-- 3, blade,  working
-- 4, cable,  working
-- 5, bit,    working
-- 6, medley, working
-- 7, crash,  working
-- 8, hash,   working

function _CRYSTAL:pickAction (recursion, px, py, mx, my)
  if not self.playerIsKnownToBeAlive then return end
  if not px then
    px, py, mx, my = self:getLocations()
    if not px then
      self.nextActionTime = 10
      return
    end
  end
  
  local action     = 0
  local extra      = 0 -- projection, usually

  if self.forceProjection then
    if #self._unusedProjections > 0 then
      action = self.forcePicking and 12 or 2
      extra  = 0
      local static = 0 -- use this to force a particular one
      if static <= 0 then
        local len = #self._unusedProjections
        if len == 1 then
          extra = table.remove ( self._unusedProjections, 1 )
        else
          extra = table.remove ( self._unusedProjections, RNG:range ( 1, #self._unusedProjections ) )
        end
        if GAMESTATE.bossRushMode and not GAMESTATE.bossRushMode.fullRush then--self.state.isSimpleVersion then
          if not GAMESTATE.bossRushMode.resultsScreenTable_alt then
            GAMESTATE.bossRushMode.resultsScreenTable_alt = {11}
          end
          table.insert ( GAMESTATE.bossRushMode.resultsScreenTable_alt, extra )
        end
      else
        extra = static
        table.remove ( self._unusedProjections, 1 )
      end
    end
  elseif self.pickedProjection then
    action = self.class.PROJ_ACTIONS[self.pickedProjection]
  else
    for i = 1, 3 do
      if RNG:n() < 0.5 then
        action = 3 -- default
      else
        action = 13
      end
      if action ~= self.lastAction then
        break
      end
    end
  end

  if action <= 0 then
    return
  end

  self.lastAction = action
  self:gotoState( self.class.ACTIONS[action], px, py, mx, my, extra )

  if BUILD_FLAGS.BOSS_STATE_CHANGE_MESSAGES then
    print("[BOSS] Picking new action:", self:getState())
  end
end

function _CRYSTAL:endAction ( finishedNormally, forceWait, clearActions )
  if clearActions then
    self.actionsWithoutRest = 0
  end
  if finishedNormally then
    self.stateVars.finishedNormally = true
    self:gotoState ( nil )
  else
    self.actionsWithoutRest = self.actionsWithoutRest + 1
    if self.actionsWithoutRest < 3 and not forceWait then
      self.nextActionTime     = self.desperationActivated and 8 or 14
    else
      self.nextActionTime     = self.desperationActivated and 13 or 19
      self.actionsWithoutRest = 0
    end
  end
end

function _CRYSTAL:getLocations ()
  local px, py = self.lastPlayerX, self.lastPlayerY
  local mx, my = self:getMiddlePoint()
  return px, py, mx, my
end

function _CRYSTAL:updateLocations()
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

function _CRYSTAL:handleYBlock(_,__,currentYSpeed)
  if not self.landingGeneratesDustNow then return end
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
    Particles:addFromCategory ( "landing_dust", cx + 45, cy + 51, -1, 1,  0.25, -0.1 )
  end

  if lenL > 0 then
    Particles:addFromCategory ( "landing_dust", cx - 6, cy + 51,  1, 1, -0.25, -0.1 )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Idle  --------------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _IDLE = _CRYSTAL:addState ( "IDLE" )

function _IDLE:exitedState ()
  self.bossMode = true
end

function _IDLE:tick () end

local protectedTakeDamage = function ( self, _, direction )
  local mx,my = self:getMiddlePoint ( )
  direction   = direction or 0
  direction   = math.abs(direction) > 0 and direction or 1


  local ox, oy = ((direction > 0) and -31 or -5), -24

  Particles:addSpecial( 
    "guard_flash", 
    mx+(ox), 
    my+(oy)+math.sin ( self.floatY ) * 3, 
    direction, 
    1, 
    2, 
    self.layers.particles() 
  )
  return true, true, true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Desperation activation ---------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DESPERATION_ACTIVATION = _CRYSTAL:addState ( "DESPERATION_ACTIVATION" )
function _DESPERATION_ACTIVATION:enteredState ( px, py, mx, my )

end

function _DESPERATION_ACTIVATION:exitedState ()
  
end

function _DESPERATION_ACTIVATION:tick ()

end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Picking circuit     ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PICKING = _CRYSTAL:addState ( "PICKING" )

function _PICKING:enteredState ( px, py, mx, my, bossToProject )

  if self.state.isSimpleVersion then
    if self.firstTimeHandled then
      local len   = #self._unusedProjections
      local extra = 0
      print("[CIRCUIT CRYSTAL] Phases left:", len-1 )
      if len == 1 then
        extra = table.remove ( self._unusedProjections, 1 )
        self.state.lastPickPerformed = true
      else
        extra = table.remove ( self._unusedProjections, RNG:range ( 1, #self._unusedProjections ) )
      end
      if GAMESTATE.bossRushMode and not GAMESTATE.bossRushMode.fullRush then--not self.state.isSimpleVersion then
        if not GAMESTATE.bossRushMode.resultsScreenTable_alt then
          GAMESTATE.bossRushMode.resultsScreenTable_alt = {11}
        end
        table.insert ( GAMESTATE.bossRushMode.resultsScreenTable_alt, extra )
      end
      bossToProject                = extra
      self.stateVars.bossToProject = extra

      self.state.nextBoxToBlowUp   = extra
    else
      print("[CIRCUIT CRYSTAL] Phases left:", 7 )
      self.firstTimeHandled = true
      local extra = bossToProject
      bossToProject                = extra
      self.stateVars.bossToProject = extra
      self.state.nextBoxToBlowUp   = extra
    end
  end

  self.timer                    = 0
  self.stateVars.shaken         = 0
  self.stateVars.bossToProject  = bossToProject
  self.pickedProjection         = bossToProject  

  self.fakeOverkilledTimer      = 10000
  self.state.isBossInvulnerable = true

  
  self.fakeOverkilledTimer      = 10000
  self.state.isHittable         = false
  self.state.isBossInvulnerable = true

  SetTempFlag ( "circuit-refight-bg-palette-to-use", self.stateVars.bossToProject )

  Audio:playSound     ( SFX.gameplay_cannon_close )
end

function _PICKING:exitedState ( )
  self.fakeOverkilledTimer      = 32
  self.state.isBossInvulnerable = false

  self:permanentlyDisableContactDamage ( false )

  self.forceProjection = false
  self.forcePicking    = false

  self:endAction ( false )
  self.nextActionTime = 1

  if (self.health < 16) then
    print("[CircuitCrystal] For some reason health was below 16?", self.health)
  end
end

function _PICKING:tick ( )

  self.timer = self.timer + 1
  if self.timer < 60 then
    self.sumTween:update(1)
    if self.stateVars.shaken == 0 and self.sumTween:isFinished ( ) then
      self.stateVars.shaken     = 1
      self.lidPosition.shaken   = true
      self.lidPosition.shake    = -2
      self.stateVars.pulses     = 1
      self.stateVars.pulseTime  = 17
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )

      self.cursorBounce = 3
      self:randomizeCursor ( )
      Audio:playSound      ( SFX.gameplay_final2_hologram_projectile_1 )
    end
  elseif self.timer < 90 then
    if self.timer == 60 then

      Audio:playSound                      ( SFX.gameplay_final2_hologram_spawn )
      Audio:playSound                      ( SFX.gameplay_cannon_open )

      --Audio:playSound    ( SFX.gameplay_scrap_golem_eye_shine )
      self.sprite:change ( 7, "crystal-spawn-pulse",  2, true )
      self.sprite:change ( 6, "crystal-eye-light-up", 4, true )

      self.stateVars.ball   = true
      self.stateVars.btx    = self.class.PROJECTIONS[self.stateVars.bossToProject].px
      self.stateVars.bty    = self.class.PROJECTIONS[self.stateVars.bossToProject].py
      self.stateVars.part   = self.class.PROJECTIONS[self.stateVars.bossToProject].pp

      --if self.havePickedFirstPalette then
        self._halfPipHealth = nil
        GlobalObserver:none ( "BOSS_HP_BAR_HALF_PIP", self._halfPipHealth  )
        local health = GlobalObserver:single ( "FILL_HEALTH_BAR_FOR_BOSS", 1 )
        self.health  = health
      --end

      --self.havePickedFirstPalette = true

      self.hitFlash.current = 16
      self.ACTIVE_PALETTE   = self.class.PROJECTIONS[self.stateVars.bossToProject].pal
    end
    if self.timer == 62 then
      Audio:playSound    ( SFX.gameplay_final2_hologram_projectile_2 )
    end
    self.sumTween:update(-1)
    if self.stateVars.shaken == 1 and self.sumTween:isAtStart ( ) then
      self.stateVars.shaken   = 2
      self.lidPosition.shaken = true
      self.lidPosition.shake  = 2

      self:endAction ( true )
    end
  end

  if self.stateVars.pulses and self.stateVars.pulses < 3 then
    self.stateVars.pulseTime = self.stateVars.pulseTime - 1
    if self.stateVars.pulseTime <= 0 then
      self.stateVars.pulseTime  = 17
      self.stateVars.pulses     = self.stateVars.pulses + 1
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )

      self:randomizeCursor ( )
    end
  end
end

_PICKING.takeDamage = protectedTakeDamage

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §PROJECTION ---------------------------------]]--
--[[----------------------------------------------------------------------------]]--
-- this state went through so many variations that I genuinely don't know how it works anymore

local _PROJECTION = _CRYSTAL:addState ( "PROJECTION" )

function _PROJECTION:enteredState ( px, py, mx, my, bossToProject )
  
  self.timer                    = 0
  self.stateVars.shaken         = 0
  self.stateVars.bossToProject  = bossToProject
  Audio:playSound     ( SFX.gameplay_cannon_close )

  self.pickedProjection    = nil
  self.stateVars.flashTime = -1

  if not self.spawnWarpRing then
    self.spawnWarpRing = {
      r = 0,
      t = 45,
    }
    self.spawnWarpRing.circleTween    = Tween.new ( 24, self.spawnWarpRing, { r  = 45, t  = 0 },   "outQuad"   )
  else
    self.spawnWarpRing.circleTween:reset()
  end

  self.stateVars.alpha = 0

  self.spawnBallPos.tween:reset()
end

function _PROJECTION:exitedState ( )
  if self.SPAWNED_BOSS then
    self.SPAWNED_BOSS:delete ( )
    self.SPAWNED_BOSS = nil
  end
  self.lidPosition.shake = 0
  self:endAction ( false )
end


----------------
-- §§§spawns  --
----------------
_CRYSTAL.static.PROJECTIONS = {
  { 
    obj = "boss_ray", 
    pal = Colors.Sprites.ray,
    x   = 34, 
    y   = 66,
    px  = -151,
    py  = -40,
    cx  = -151,
    cy  = -40,
    pa  = "crystal-spawn-ball-ray",
    pp  = "warp_particle_ray",

    cellX        = 23,
    cellY        =  5,
    playerSpawnX = 88,
    playerSpawnY = 176-16,
    playerSpawnD = 1,

    -- relative to camera
    bossSpawnX   = 283,
    bossSpawnY   = 176,
    hudName      = "ray",
    flag         = "subboss-defeated-ray",
  },
  { 
    obj = "boss_fix", 
    pal = Colors.Sprites.fix,
    x   = 48, 
    y   = 64,
    px  = -87,
    py  = -40,
    cx  = -87,
    cy  = -40,
    pa  = "crystal-spawn-ball-trace",
    pp  = "warp_particle_trace",

    cellX        = 25,
    cellY        =  5,
    playerSpawnX = 88,
    playerSpawnY = 176-16,
    playerSpawnD = 1,

    -- relative to camera
    bossSpawnX   = 283,
    bossSpawnY   = 180-16,
    hudName      = "fix",
    flag         = "subboss-defeated-trace",
  },
  { 
    obj = "boss_blade", 
    pal = Colors.Sprites.blade,
    x   = 48, 
    y   = 64,
    px  = 85,
    py  = -40,
    cx  = 83,
    cy  = -40,
    pa  = "crystal-spawn-ball-blade",
    pp  = "warp_particle_blade",

    cellX        = 27,
    cellY        =  5,
    playerSpawnX = 240+32,
    playerSpawnY = 176,
    playerSpawnD = -1,

    -- relative to camera
    bossSpawnX   = 390+32,
    bossSpawnY   = 150,
    hudName      = "blade",
    flag         = "subboss-defeated-blade",
  },
  { 
    obj = "boss_cable", 
    pal = Colors.Sprites.cable,
    x   = 48, 
    y   = 64,
    px  = 149,
    py  = -40,
    cx  = 147,
    cy  = -40,
    pa  = "crystal-spawn-ball-cable",
    pp  = "warp_particle_cable",

    cellX        = 30,
    cellY        =  5,
    playerSpawnX = 72+24+17,
    playerSpawnY = 176-16,
    playerSpawnD = -1,

    -- relative to camera
    bossSpawnX   = 280-25,
    bossSpawnY   = 176,
    hudName      = "cable",
    flag         = "subboss-defeated-cable",
  },
  { 
    obj = "boss_bit", 
    pal = Colors.Sprites.bit,
    x   = 48, 
    y   = 64,
    px  = -151,
    py  = 32,
    cx  = -151,
    cy  = 32,
    pa  = "crystal-spawn-ball-bit",
    pp  = "warp_particle_bit",

    cellX        = 23,
    cellY        =  9,
    playerSpawnX = 88,
    playerSpawnY = 176-32,
    playerSpawnD = 1,

    -- relative to camera
    bossSpawnX   = 283,
    bossSpawnY   = 150,
    hudName      = "bit",
    flag         = "subboss-defeated-bit",
  },
  { 
    obj = "boss_medley", 
    pal = Colors.Sprites.medley,
    x   = 48, 
    y   = 64,
    px  = -87,
    py  = 32,
    cx  = -87,
    cy  = 32,
    pa  = "crystal-spawn-ball-medley",
    pp  = "warp_particle_medley",

    cellX        = 25,
    cellY        =  9,
    playerSpawnX = 72+32,
    playerSpawnY = 176-32,
    playerSpawnD = 1,

    -- relative to camera
    bossSpawnX   = 285-18,
    bossSpawnY   = 150,
    hudName      = "medley",
    flag         = "subboss-defeated-medley",
  },
  { 
    obj = "boss_crash", 
    pal = Colors.Sprites.crash,
    x   = 48, 
    y   = 64,
    px  = 85,
    py  = 32,
    cx  = 83,
    cy  = 32,
    pa  = "crystal-spawn-ball-crash",
    pp  = "warp_particle_crash",

    cellX        = 27,
    cellY        =  9,
    playerSpawnX = 88,
    playerSpawnY = 176-16,
    playerSpawnD = -1,

    -- relative to camera
    bossSpawnX   = 283,
    bossSpawnY   = 164,
    hudName      = "crash",
    flag         = "subboss-defeated-crash",
  },
  { 
    obj = "boss_hash", 
    pal = Colors.Sprites.hash,
    x   = 48, 
    y   = 64,
    px  = 149,
    py  = 32,
    cx  = 147,
    cy  = 32,
    pa  = "crystal-spawn-ball-hash",
    pp  = "warp_particle_hash",

    cellX        = 30,
    cellY        =  9,
    playerSpawnX = 88-16,
    playerSpawnY = 176-16,
    playerSpawnD = -1,

    -- relative to camera
    bossSpawnX   = 296+8,
    bossSpawnY   = 172+4,
    hudName      = "hash",
    flag         = "subboss-defeated-hash",
  },
}

_CRYSTAL.static.HEALTH_PICKUP = {
  size = "large"
}

local function _drawThing ( x, y, w, h, a )
  love.graphics.setColor     ( 1, 1, 1, a )
  love.graphics.setBlendMode ( "add" )

  love.graphics.rectangle    ( "fill", x, y, w, h )

  love.graphics.setColor     ( 1, 1, 1, 1 )
  love.graphics.setBlendMode ( "alpha" )
end

function _PROJECTION:tick ( )

  if self.stateVars.tryLater then
    self:signal()
  end

  if self.SPAWNED_BOSS then
    if self.SPAWNED_BOSS.health <= 0 then
      if not self.stateVars.bossDeathDelayTime then
        self.stateVars.bossDeathDelayTime = 180
      else
        self.stateVars.bossDeathDelayTime = self.stateVars.bossDeathDelayTime - 1
        if self.stateVars.bossDeathDelayTime == 0 then
          self:signal ( )
        end
      end
    end
  end

  if self:shaderShenanigans ( ) then return end

  if self.stateVars.spawnDeadStart then
    self:handleWhiteCircle ( )
    if not self.stateVars.shaderPhase1 then
      if not self.stateVars.flashTween then
        self.stateVars.spawnDeadStart = false
        self:midSignal ( )
      end
    end
    return
  end

  if self.stateVars.spawnDead then
    if not self.stateVars.spawnDeadAcknowledged then
      self.stateVars.spawnDeadAcknowledged = true
      self.timer = 0
      self.stateVars.handleBallDelay = 16
    end

    self:handleWhiteCircle ( )
    if self.stateVars.handleBallDelay > 0 then
      self.stateVars.handleBallDelay = self.stateVars.handleBallDelay - 1
    else
      self:handleBall        ( )
    end

    if self.spawnBallPos.tween:getTime() < 0.3 then
      self.timer = self.timer + 1
    end

    if self.timer == 8 then
      --Audio:playSound ( SFX.gameplay_cannon_open )
      if (self._unusedProjections and #self._unusedProjections > 0) then
        self.lidPosition.opening = true
        self.lidPosition.shaken  = false
      end
    elseif self.timer > 8 then
      self.sumTween:update(-1)
    end

    if self.timer == 12 then


      -- §§checkpoint
      ----------------
      -- hard mode  --
      ----------------
      if self.state.isBossRushSpawn then
        self:blowUpCircuitBox ( self.stateVars.bossToProject )
      elseif GAMEDATA.isHardMode() then
        if not self._savedProgressFlag then
          self._savedProgressFlag = self.stateVars.bossToProject
        else
          SetStageFlag ( "subboss-saved-" .. self._savedProgressFlag,      1 )
          SetStageFlag ( "subboss-saved-" .. self.stateVars.bossToProject, 1 )

          self:blowUpCircuitBox ( self._savedProgressFlag      )
          self:blowUpCircuitBox ( self.stateVars.bossToProject )

          self._savedProgressFlag = nil
        end

        --[[
        if not self._savedProgressFlag then
          self._savedProgressFlag = {}
        end

        table.insert ( self._savedProgressFlag, self.stateVars.bossToProject )

        if #self._savedProgressFlag >= 4 then
          for i = 1, #self._savedProgressFlag do
            SetStageFlag ( "subboss-saved-" .. self._savedProgressFlag[i], 1 )
            self:blowUpCircuitBox ( self._savedProgressFlag[i] )

          end
          self._savedProgressFlag = nil
        end]]

      ----------------
      -- easy mode  --
      ----------------
      elseif GAMESTATE.mode == 1 then
        SetStageFlag ( "subboss-saved-" .. self.stateVars.bossToProject, 1 )
        self._savedProgressFlag = nil

        self:blowUpCircuitBox ( self.stateVars.bossToProject )

      -----------------
      -- normal mode --
      -----------------
      else
        if not self._savedProgressFlag then
          self._savedProgressFlag = self.stateVars.bossToProject
        else
          SetStageFlag ( "subboss-saved-" .. self._savedProgressFlag,      1 )
          SetStageFlag ( "subboss-saved-" .. self.stateVars.bossToProject, 1 )

          self:blowUpCircuitBox ( self._savedProgressFlag      )
          self:blowUpCircuitBox ( self.stateVars.bossToProject )

          self._savedProgressFlag = nil
        end
      end

      if (self._unusedProjections and #self._unusedProjections <= 0) or (BUILD_FLAGS.DEBUG_BUILD and UI.kb.isDown ( "a" ))  then
        self.health = 0
        self:notifyBossHUD ( 999, RNG:rsign() )
        self:gotoState     ( "DEATH" )
        return
      end

      self:applyShake         ( 5, 0.25 )
      Audio:playSound         ( SFX.gameplay_portal_enter )
      self:addRandomExplosion ( )
      self:addRandomExplosion ( )
      self:addRandomExplosion ( )

      self.fakeOverkilledTimer      = 10000
      self.state.isBossInvulnerable = true

      GameObject:spawn ( 
        "health_pickup", 
        self:getX()+16, 
        self:getY()+32, 
        self.class.HEALTH_PICKUP, 
        true 
      )

      self.hitFlash.current = 16
      --self.ACTIVE_PALETTE   = self.class.PALETTE
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )
      self.sprite:change ( "spawn_ball", nil )
      self.sprite:change ( 5, "crystal-eye-light-up-simple", 2, true )
    end

    if self.timer >= 60 then
      --self:endAction ( true )
      self.forceProjection = true
      self.forcePicking    = true
      self:pickAction ( )
    end
    return
  end

  self.timer = self.timer + 1
  if self.timer < 45 then
    self.sumTween:update(1)
    if self.stateVars.shaken == 0 and self.sumTween:isFinished ( ) then
      GlobalObserver:none ( "SUPER_FLASH_START", self ) 
      GlobalObserver:none ( "BOSS_BURST_ATTACK_USED", "boss_burst_attacks_crystal", 10 )

      local mx, my = self:getMiddlePoint ( )
      local l      = self.activeLayer    ( )
      Particles:addSpecial ( "super_flash", mx-2, my-3, l-2, l-1, false, mx, my )

      self.stateVars.shaken     = 1
      self.lidPosition.shaken   = true
      self.lidPosition.shake    = -2
      self.stateVars.pulses     = 1
      self.stateVars.pulseTime  = 17
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )
      self.sprite:change ( 5, "crystal-eye-quick-blink",1, true )

      --Audio:playSound      ( SFX.gameplay_final2_hologram_projectile_1 )
    end
  elseif self.timer < 90 then
    if self.timer == 45 then
      local player = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
      if not player or player.dead or player.state.isEmergencyWarping then
        return
      end

      GlobalObserver:none ( "SUPER_FLASH_END" )

      self.stateVars.firstFlash = true
      self.stateVars.flashTween = true
      self.spawnWarpRing.circleTween:reset ( )
      self:handleWhiteCircle               ( )
      ClearVisitedCells                    ( true )
      player:gotoProjectionWarp            ( )
      Audio:playSound                      ( SFX.gameplay_final2_hologram_spawn )
      Audio:playSound                      ( SFX.gameplay_cannon_open )

      -- for crash because he's a good boy
      Environment.conveyorBeltSurface ( false, false )

      --Audio:playSound    ( SFX.gameplay_scrap_golem_eye_shine )
      self.sprite:change ( 7, "crystal-spawn-pulse",  2, true )
      self.sprite:change ( 6, "crystal-eye-light-up", 4, true )

      self.sprite:change ( "spawn_ball", self.class.PROJECTIONS[self.stateVars.bossToProject].pa, 2, true )

      self.stateVars.ball   = true
      self.stateVars.btx    = self.class.PROJECTIONS[self.stateVars.bossToProject].px
      self.stateVars.bty    = self.class.PROJECTIONS[self.stateVars.bossToProject].py
      self.stateVars.part   = self.class.PROJECTIONS[self.stateVars.bossToProject].pp

      self.hitFlash.current = 16
      self.ACTIVE_PALETTE   = self.class.PROJECTIONS[self.stateVars.bossToProject].pal
    end
    if self.timer == 47 then
      Audio:playSound    ( SFX.gameplay_final2_hologram_projectile_2 )
    end
    self.sumTween:update(-1)
    if self.stateVars.shaken == 1 and self.sumTween:isAtStart ( ) then
      self.stateVars.shaken   = 2
      self.lidPosition.shaken = true
      self.lidPosition.shake  = 2
    end
  end

  if self.stateVars.flashTime > 0 then
    self.stateVars.flashTime = self.stateVars.flashTime + 1
  end

  if self.flashPlayerAway then
    self.flashPlayerAway      = false
    self.stateVars.ball       = false

    self.sprite:change ( "spawn_ball", nil )

    self.stateVars.flashTime    = 1

  elseif self.stateVars.flashTime == 2 then--10 then--30 then

    ----------------
    -- §§summon   --
    ----------------
    local player = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
    if not player or player.dead or player.state.isEmergencyWarping then
      return
    end

    local cellX, cellY = self.class.PROJECTIONS[self.stateVars.bossToProject].cellX,
                         self.class.PROJECTIONS[self.stateVars.bossToProject].cellY

    if self.state.isBossRushSpawn then
      cellX, cellY = MapData.BossRush.getBossMapCell ( self.stateVars.bossToProject )
      cellX, cellY = cellX - 1, cellY - 1
    end

    local playerX, playerY = self.class.PROJECTIONS[self.stateVars.bossToProject].playerSpawnX,
                             self.class.PROJECTIONS[self.stateVars.bossToProject].playerSpawnY

    cellX = cellX * GAME_WIDTH
    cellY = cellY * GAME_HEIGHT

    ClearVisitedCells               ( true )
    player:setActualPos             ( cellX+playerX, cellY+playerY )
    --player:exitProjectionWarpStatus (  )
    self.stateVars.playerInLimbo = player

    local cx, cy = Camera:getPos()
    cx           = cx + GAME_WIDTH  / 2
    cy           = cy + GAME_HEIGHT / 2

    local px, py = player:getPos ( )
    px = px + 14
    py = py + 12

    px = px - cx
    py = py - cy

    self.spawnBallX = px
    self.spawnBallY = py - 10

    self.stateVars.flashTween = true
    self.spawnWarpRing.circleTween:reset ( )
    self:handleWhiteCircle               ( )

    self.sprite:change ( "cursor", nil )

    Camera:clear            ( )
    Camera:remove           ( )  
    Camera:setPos           ( cellX, cellY )
    Camera:initializeMethod ( )
    Camera:subscribe        ( player )
    Camera:insert           ( )
    for i = 1, 10 do
      Camera:tick ( )
    end
    SetTempFlag ( "circuit-crystal-subarea-active", true )

    local boss   = self.class.PROJECTIONS[self.stateVars.bossToProject]
    local bobj   = GameObject:spawn ( 
      boss.obj,
      cellX+self.class.PROJECTIONS[self.stateVars.bossToProject].bossSpawnX,
      cellY+self.class.PROJECTIONS[self.stateVars.bossToProject].bossSpawnY
    )

    GAMEDATA.boss.setNextSpawnToHalfHealth ( false )

    bobj.state.isBoss         = true
    bobj.state.isSpawnBoss    = true
    bobj:activate    ( )
    bobj:gotoState   ( "S_HOP", self )
    bobj.sprite:flip ( -1, 1 )
    --bobj.preventDesperation   = true
    bobj.desperationActivated = true
    bobj.manageForcedLaunch   = false
    bobj.WILL_BE_FAKE_OUT     = true

    GlobalObserver:none ( "BRING_UP_BOSS_HUD", self.class.PROJECTIONS[self.stateVars.bossToProject].hudName, bobj.health )
    GlobalObserver:none ( "SHOW_BOSS_HUD_SPECIFICALLY" )

    if BUILD_FLAGS.DEBUG_BUILD and UI.kb.isDown ("b") then
      bobj.health = 1
    end

    self.stateVars.flashTween   = true
    self.stateVars.ball         = false
    self.SPAWNED_BOSS           = bobj

    self.sprite:change ( "spawn_ball", nil )

    self.stateVars.shaderPhase2 = true
    self.stateVars.alpha        = 1.0
  elseif self.stateVars.flashTime == 40 then
    self.lidPosition.opening = false
    self.sprite:change ( 5, "crystal-eye-light-down", 1, true )
  end

  self:handleBall        ( )
  self:handleWhiteCircle ( )
end

function _CRYSTAL:blowUpCircuitBox ( boss )
  if not self.class.PROJECTIONS[boss] then return end
  local x, y = self:getPos ( )

  if self.state.isBossRushSpawn then
    x, y = self.baseX, self.baseY + 6
  end

  x      = x + self.class.PROJECTIONS[boss].cx + 25
  y      = y + self.class.PROJECTIONS[boss].cy + 30

  Camera:startShake ( 0, 3, 20, 0.25 )
  SetTempFlag ( self.class.PROJECTIONS[boss].flag .. "-explosion", 1 )

  local l = self.layers.death()
  Particles:addSpecial("small_explosions_in_a_circle", x, y, l-4, false, 1.0, 0.75 )
end

function _CRYSTAL:randomizeCursor ( )
  local x, y = self:getPos()
  local slot = 1--self.stateVars.bossToProject
  self.cursorBounce = self.cursorBounce - 1

  if self.cursorBounce <= 0 then
    slot = self.stateVars.bossToProject
  else
    if self._unusedProjections and #self._unusedProjections > 0 then
      slot = self._unusedProjections[RNG:range(1,#self._unusedProjections)]
    else
      slot = self.stateVars.bossToProject
    end
  end

  self.cursorX      = x + self.class.PROJECTIONS[slot].cx
  self.cursorY      = y + self.class.PROJECTIONS[slot].cy

  if self.state.isBossRushSpawn then
    self.cursorY = self.cursorY + 4
  end

  self.sprite:change ( "cursor", "circuit-cursor", 1, true )
end

function _PROJECTION:handleWhiteCircle ( )
  if self.stateVars.flashTween then
    if self.spawnWarpRing.circleTween:update(1) then
      self.stateVars.flashTween = false
      if self.stateVars.flashAwayAfter then
        self.stateVars.flashAwayAfter = false
        self.stateVars.flashed        = true
        self.flashPlayerAway          = true  
      end
    end
    local mx, my = 0,0
    local x,  y  = self:getPos ( )

    if self.stateVars.firstFlash then
      if not self.stateVars.firstFlashPX then
        local px, py = GlobalObserver:single ( "GET_PLAYER_RAW_POSITION" )
        if not px then return end
        self.stateVars.firstFlashPX = px + 39
        self.stateVars.firstFlashPY = py + 45
      end

      if self.stateVars.playerRawPosition then
        mx, my = self.stateVars.firstFlashPX-25,
                 self.stateVars.firstFlashPY-29
      else
        local px, py = self.stateVars.firstFlashPX, self.stateVars.firstFlashPY
        local cx, cy = Camera:getPos()
        cx           = cx + GAME_WIDTH  / 2
        cy           = cy + GAME_HEIGHT / 2

        px = px - cx
        py = py - cy

        mx, my =  x+px,
                  y+py

        if not self.stateVars.firstFlashBaseX then
          self.stateVars.firstFlashBaseX = px - 23
          self.stateVars.firstFlashBaseY = py - 31
        end
      end
    else
      mx, my =  x+self.spawnBallX+self.spawnBallOX+16,
                y+self.spawnBallY+self.spawnBallOY+6
    end
    local l      = self.layers.death()
    GFX:push ( l, love.graphics.setLineWidth, self.spawnWarpRing.t   )
    GFX:push ( l, love.graphics.circle, "line", mx, my, self.spawnWarpRing.r )
    GFX:push ( l, love.graphics.setLineWidth, 1   )

    if self.spawnWarpRing.circleTween:getTime() < 0.25 and GetTime()%3==0 then
      Particles:addSpecial ( "emit_green_beam", mx, my, l+1, true )
    end
  end
end

function _PROJECTION:handleBall ( )
  if self.stateVars.ball then
    self.spawnBallPos.tween:update ( self.stateVars.ballDir or 1 )
    if self.spawnBallPos.tween:isFinished() and not self.stateVars.flashAwayAfter then

      self.stateVars.ball           = false
      self.stateVars.firstFlash     = false
      self.stateVars.flashTween     = true
      self.stateVars.flashAwayAfter = true
      self.stateVars.shaderPhase1   = true
      
      GlobalObserver:none ( "HIDE_BOSS_HUD_SPECIFICALLY" )
      self.sprite:change  ( "spawn_ball", nil )

      Audio:playSound ( SFX.gameplay_portal_enter )
      self.spawnWarpRing.circleTween:reset ( )
      self:handleWhiteCircle               ( )

      Audio:playSound ( SFX.gameplay_boss_phase_change_special )
    end

    local px, py = GlobalObserver:single ( "GET_PLAYER_RAW_POSITION" )
    if not px then return end

    if self.stateVars.useCircuitPos then
      self.spawnBallX = self.spawnBallPos.pos * self.stateVars.btx
      self.spawnBallY = self.spawnBallPos.pos * self.stateVars.bty
    else
      local cx, cy = Camera:getPos()
      cx           = cx + GAME_WIDTH  / 2
      cy           = cy + GAME_HEIGHT / 2

      px = px + 14
      py = py + 12

      px = px - cx
      py = py - cy

      if self.state.isBossRushSpawn then
        self.spawnBallX = math.lerp ( self.stateVars.firstFlashBaseX, self.stateVars.btx, self.spawnBallPos.pos ) --self.spawnBallPos.pos * px
        self.spawnBallY = math.lerp ( self.stateVars.firstFlashBaseY, self.stateVars.bty+4, self.spawnBallPos.pos ) --self.spawnBallPos.pos * py
      else
        self.spawnBallX = math.lerp ( self.stateVars.firstFlashBaseX, self.stateVars.btx, self.spawnBallPos.pos ) --self.spawnBallPos.pos * px
        self.spawnBallY = math.lerp ( self.stateVars.firstFlashBaseY, self.stateVars.bty, self.spawnBallPos.pos ) --self.spawnBallPos.pos * py
      end
    end

    if self.sprite:getAnimation ( "spawn_ball" ) and GetTime()%2 == 0 then
      local x, y = self:getPos()

      x, y = x + self.spawnBallX+self.spawnBallOX+14 + love.math.random(0,4)*math.rsign(),
             y + self.spawnBallY+self.spawnBallOY-16 + love.math.random(1,2)

      local l = self.activeLayer() + 20
      Particles:addFromCategory ( self.stateVars.part, x, y+4,   1,  1, 0, -0.5, l, false, nil, true )
      Particles:addFromCategory ( self.stateVars.part, x, y+36,  1, -1, 0,  0.5, l, false, nil, true )
    end
  end
end

function _CRYSTAL:pulseScreen ( )
  GAMESTATE.subbossDefeated     = true
  self.stateVars.shaderPulse    = true
  self.stateVars.shaderTime     = 0.0
  self.stateVars.shaderStrength = 0.18
end

function _CRYSTAL:signal ( )
  local player = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
  if not player or player.dead or player.state.isEmergencyWarping then
    self.stateVars.tryLater = true
    return
  end

  Audio:playSound ( SFX.gameplay_boss_phase_change_special )

  self.fakeOverkilledTimer      = 16
  self.state.isBossInvulnerable = false

  self.stateVars.tryLater = false

  self.stateVars.firstFlash         = true
  self.stateVars.firstFlashPX       = nil
  self.stateVars.playerRawPosition  = true

  self.stateVars.spawnDeadStart     = true
  self.stateVars.flashTween         = true

  self.stateVars.returnTrip         = true
  self.stateVars.shaderTime         = 0
  self.stateVars.shaderStrength     = 0.0
  self.stateVars.alphaTicks         = 11
  self.stateVars.alpha              = 0.0

  self.spawnWarpRing.circleTween:reset ( )
  self:handleWhiteCircle               ( )
  self.stateVars.shaderHandlesCircle = true
  self.stateVars.shaderPhase1 = true


  ClearVisitedCells         ( true )
  player:gotoProjectionWarp ( )
  --Audio:playSound           ( SFX.gameplay_final2_hologram_spawn )
  Audio:playSound           ( SFX.gameplay_portal_enter )

  GlobalObserver:none       ( "HIDE_BOSS_HUD_SPECIFICALLY" )
end

function _CRYSTAL:midSignal ( )
  local player = GlobalObserver:single ( "GET_PLAYER_OBJECT" )
  if not player or player.dead or player.state.isEmergencyWarping then
    return
  end

  ClearVisitedCells   ( true )

  local cx, cy = 40, 22
  if self.state.isBossRushSpawn then
    cx, cy = MapData.BossRush.getBossMapCell ( 11 )
    cx, cy = cx - 1, cy - 1
  end

  local spawnX = cx * GAME_WIDTH  + GAME_WIDTH /2 + self.stateVars.btx - 15
  local spawnY = cy * GAME_HEIGHT + GAME_HEIGHT/2 + self.stateVars.bty - 8

  player:setActualPos             ( spawnX, spawnY )
  player.sprite:flip              ( self.class.PROJECTIONS[self.stateVars.bossToProject].playerSpawnD or 1, 1 )

  Camera:clear            ( )
  Camera:remove           ( )  
  Camera:setPos           ( cx, cy )
  Camera:initializeMethod ( )
  Camera:subscribe        ( player )
  Camera:insert           ( )
  for i = 1, 10 do
    Camera:tick ( )
  end

  SetTempFlag ( "circuit-crystal-subarea-active", false )

  GlobalObserver:none ( "BRING_UP_BOSS_HUD", "crystal", self.health, 32 )
  GlobalObserver:none ( "SHOW_BOSS_HUD_SPECIFICALLY" )

  self.stateVars.shaderPhase2   = true
  self.stateVars.playerInLimbo2 = player
end

function _CRYSTAL:finishSignal ( )

  GAMESTATE.subbossDefeated   = false
  GAMESTATE.disableBouncePads = false
  SetTempFlag ( self.class.PROJECTIONS[self.stateVars.bossToProject].flag, 1 )
  self.stateVars.playerInLimbo2:exitProjectionWarpStatus ( )
  self.stateVars.playerInLimbo2 = nil

  self.SPAWNED_BOSS:delete ( )
  self.SPAWNED_BOSS = nil

  self.stateVars.firstFlash    = false
  self.stateVars.useCircuitPos = true 

  self.spawnBallX = self.spawnBallPos.pos * self.stateVars.btx
  self.spawnBallY = self.spawnBallPos.pos * self.stateVars.bty

  self.stateVars.ball       = true
  self.stateVars.ballDir    = -1.0
  self.stateVars.spawnDead  = true

  self.stateVars.flashTween = true
  self.spawnWarpRing.circleTween:reset ( )
  self:handleWhiteCircle               ( )

  Audio:playSound ( SFX.gameplay_portal_enter )

  self.sprite:change ( "spawn_ball", self.class.PROJECTIONS[self.stateVars.bossToProject].pa, 2, true )
end

function _CRYSTAL:shaderShenanigans ( )

  if self.stateVars.shaderHandlesCircle then
    self:handleWhiteCircle ( )
    if not self.stateVars.flashTween then
      self.stateVars.shaderHandlesCircle = nil
    end
  end

  if self.stateVars.spawnDeadStart then
    self.stateVars.shaderPulse = false
  end

  if self.stateVars.shaderPulse then
    GAMESTATE.applyShaderOnGameScreen = self.screenShader
    self.stateVars.shaderTime         = self.stateVars.shaderTime     + 0.05
    self.stateVars.shaderStrength     = math.max ( self.stateVars.shaderStrength - 0.015, 0.045 )

    self.screenShader:send ( "strength",    self.stateVars.shaderStrength );
    self.screenShader:send ( "time",        self.stateVars.shaderTime     );

    if self.stateVars.shaderStrength <= 0 then
      self.stateVars.shaderPulse        = false
      GAMESTATE.applyShaderOnGameScreen = nil
    end
    return true
  end
    
  if self.stateVars.shaderPhase1 then
    GAMESTATE.applyShaderOnGameScreen = self.screenShader

    if not self.stateVars.shaderTime then
      self.stateVars.shaderTime       = 0
      self.stateVars.shaderStrength   = 0.0
      self.stateVars.alphaTicks       = 11
    end
    self.stateVars.shaderTime     = self.stateVars.shaderTime     + 0.05
    if self.stateVars.shaderStrength < 0.25 then
      self.stateVars.shaderStrength = self.stateVars.shaderStrength + 0.040
    elseif self.stateVars.shaderStrength < 0.50 then
      self.stateVars.shaderStrength = self.stateVars.shaderStrength + 0.1
    else
      self.stateVars.shaderStrength = self.stateVars.shaderStrength + 0.15
    end

    self.screenShader:send ( "strength",    self.stateVars.shaderStrength );
    self.screenShader:send ( "time",        self.stateVars.shaderTime     );
    --self.screenShader:send ( "resolution",  _res            );

    if self.stateVars.shaderStrength > 0.15 then
      if self.stateVars.alphaTicks > 0 then
        self.stateVars.alphaTicks = self.stateVars.alphaTicks - 1
      else
        self.stateVars.alpha      = self.stateVars.alpha + 0.225
        self.stateVars.alphaTicks = 11
      end
    end

    if self.stateVars.alpha > 1.01 then
      self.stateVars.alpha          = 1.05
      self.stateVars.shaderStrength = 2.25
      self.stateVars.shaderPhase1   = false
      self.stateVars.alphaTicks     = 0
      self.stateVars.strengthBounce = 0
      self.stateVars.smallBounce    = false
    else
      if not self.stateVars.flashAwayAfter then
        return true
      end
    end
    --if true then return end
  elseif self.stateVars.shaderPhase2 then
    GAMESTATE.applyShaderOnGameScreen = self.screenShader

    self.stateVars.shaderTime     = self.stateVars.shaderTime     + 0.05
    --if self.stateVars.strengthBounce <= 0 or self.stateVars.strengthBounce >= 8 then
    if self.stateVars.strengthBounce <= 0 then
      self.stateVars.shaderStrength = math.max ( self.stateVars.shaderStrength - 0.055, 0.0 )
    else
      self.stateVars.shaderStrength = math.max ( self.stateVars.shaderStrength - 0.030, 0.0 )
    end
    --end

    self.screenShader:send ( "strength",    self.stateVars.shaderStrength );
    self.screenShader:send ( "time",        self.stateVars.shaderTime     );

    if (self.stateVars.shaderStrength <= 0 or self.stateVars.strengthBounce > 0) and self.stateVars.strengthBounce <= 6 then
      self.stateVars.shaderStrength = self.stateVars.shaderStrength + (self.stateVars.smallBounce and 0.035 or 0.050 )
      self.stateVars.strengthBounce = self.stateVars.strengthBounce + 1
      if not self.stateVars.smallBounce and self.stateVars.strengthBounce >= 6 then
        self.stateVars.smallBounce    = true
        self.stateVars.strengthBounce = 0
      end
    end

    --if self.stateVars.alphaTicks <= 0 then
      self.stateVars.alpha      = self.stateVars.alpha - 0.035
    --  self.stateVars.alphaTicks = 4
    --else
     -- self.stateVars.alphaTicks = self.stateVars.alphaTicks - 1
    --end
    if self.stateVars.shaderStrength <= 0.0 and self.stateVars.alpha <= 0 then
      self.stateVars.shaderPhase2       = false
      GAMESTATE.applyShaderOnGameScreen = nil

      if self.stateVars.playerInLimbo then
        self.stateVars.playerInLimbo:exitProjectionWarpStatus ( 1 )
        self.stateVars.playerInLimbo = nil
        self.lidPosition.opening     = false

        self.sprite:change ( 5, nil )
      elseif self.stateVars.playerInLimbo2 then
        self:finishSignal()
      end
    else
      return true
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DEFAULT             ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DEFAULT = _CRYSTAL:addState ( "DEFAULT" )

function _DEFAULT:enteredState ( )
  self.timer = 5
  self.stateVars.shots = 0

  self.stateVars.x     = self:getX ( )
  self.stateVars.y     = self:getY ( )

  self.stateVars.pos = {
    pos = 0,
  }
  self.stateVars.tween    = Tween.new ( 20, self.stateVars.pos, { pos = 1 }, "inOutQuad" )
end

function _DEFAULT:exitedState ( )
  self.sprite:change  ( 6, nil )
  self.sumTween:reset ( )
  self:endAction      ( false )
end

function _DEFAULT:tick ( )
  if not self.stateVars.warned then
    if not self.stateVars.warnSfx then
      self.stateVars.warnSfx = true
      Audio:playSound ( SFX.gameplay_cannon_close )
      self.sprite:change ( 6, "crystal-eye-light-up", 4, true )
    end

    self.stateVars.tween:update(1)

    local x = math.lerp         ( self.stateVars.x, self.stateVars.x,    self.stateVars.pos.pos )
    local y = math.lerp         ( self.stateVars.y, self.stateVars.y-16, self.stateVars.pos.pos )
    self:setActualPos           ( x, y )

    if self.sumTween:update ( 1 ) and self.stateVars.tween:isFinished ( ) then
      self.timer = self.timer - 1
      if self.timer <= 0 then
        self.stateVars.finishedShooting = false
        self.stateVars.warned    = true
        self.stateVars.shotTimer = 0
        self.stateVars.shots     = 0
        Audio:playSound ( SFX.gameplay_cannon_open )
      end
    end
  elseif not self.stateVars.finishedShooting then
    self.sumTween:update ( -1.5 )
    if self.sumTween:isAtStart () and not self.stateVars.shaken then
      self.stateVars.shaken   = true
      self.lidPosition.shaken = true
    end
    self.stateVars.shotTimer = self.stateVars.shotTimer - 1
    if self.stateVars.shotTimer <= 0 then
      self.stateVars.shotTimer = 1
      self:shoot()
      self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
      self.stateVars.shots = self.stateVars.shots + 1
      if self.stateVars.shots >= 120 then
        self.stateVars.finishedShooting = true
        self.timer                      = 1
      end
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.timer              = 10
      self.stateVars.warned   = false
      self.stateVars.warnSfx  = false
      self:endAction ( true )
    end
  end
end

function _CRYSTAL:shoot ()
  local x, y        = self:getMiddlePoint()
  x                 = x - 7
  y                 = y - 5 + math.sin(self.floatY)
  Audio:playSound  ( SFX.gameplay_plasma_shot, 0.8 )

  GameObject
    :spawn      ( "plasma_ball", x, y, 0, self, 1, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DEFAULT_2           ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DEFAULT_2 = _CRYSTAL:addState ( "DEFAULT_2" )

_CRYSTAL.static.DEFAULT_2_POSITIONS = {
  [1] = -120,
  [2] = -80,
  [3] = -40,
  [4] = 0,
  [5] = 40,
  [6] = 80,
  [7] = 120,
}

function _DEFAULT_2:enteredState ( px, py, mx, my )
  self.timer           = 25
  self.stateVars.shots = 0
  self.stateVars.ang   = -math.halfPi
  self.stateVars.dir   = px < mx and -1 or 1

  self.stateVars.x     = self:getX ( )
  self.stateVars.y     = self:getY ( )

  self.stateVars.pos = {
    pos = 0,
  }
  self.stateVars.tween    = Tween.new ( 35, self.stateVars.pos, { pos = 1 }, "inOutQuad" )

  if not self.lastDefault2Position then
    self.stateVars.firstTime  = true
    self.lastDefault2Position = 4
  end

  self.lastDefault2Position = self.lastDefault2Position + ((px < mx) and -1 or 1)
  if self.lastDefault2Position < 1 then
    self.lastDefault2Position = 2
  elseif self.lastDefault2Position > 7 then
    self.lastDefault2Position = 6
  end

  self.stateVars.position = self.lastDefault2Position
end

function _DEFAULT_2:exitedState ( )
  self.sprite:change  ( 6, nil )
  self.sumTween:reset ( )
  self.lidTween:reset ( )
  self:endAction      ( false )

  self.lidPosition.opening = true
end

function _DEFAULT_2:tick ( )
  if not self.stateVars.warned then
    if not self.stateVars.warnSfx then
      self.stateVars.warnSfx = true
      Audio:playSound ( SFX.gameplay_virus_cannoneer_charge )
      Audio:playSound ( SFX.gameplay_cannon_close )
      self.sprite:change ( 5, "crystal-eye-light-down", 4, true )
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )
    end
    self.lidPosition.opening = false
    self.lidPosition.shaken  = false

    self.stateVars.tween:update(1)

    local x = math.lerp         ( self.stateVars.x, self.baseX+self.class.DEFAULT_2_POSITIONS[self.stateVars.position], self.stateVars.pos.pos )
    local y = math.lerp         ( self.stateVars.y, self.baseY+((self.stateVars.position%2 == 1) and 8 or (self.stateVars.firstTime and 2 or 0)), self.stateVars.pos.pos )
    self:setActualPos           ( x, y )

    if self.lidTween:isFinished() and self.stateVars.tween:isFinished() then
      self.timer = self.timer - 1
      if self.timer <= 0 then
        self.stateVars.finishedShooting = false
        self.stateVars.warned    = true
        self.stateVars.shotTimer = 0
        self.stateVars.shots     = 0
        Audio:playSound ( SFX.gameplay_cannon_open )
        self.lidTween:update ( -2 )
      end
    end
  elseif not self.stateVars.finishedShooting then
    self.lidPosition.opening = true
    if self.lidTween:isAtStart () and not self.stateVars.shaken then
      self.stateVars.shaken   = true
    end
    self.stateVars.shotTimer = self.stateVars.shotTimer - 1
    if self.stateVars.shotTimer <= 0 then
      self.stateVars.shotTimer = 3
      self:shoot_plasma  ( self.stateVars.ang  )
      self.stateVars.ang = self.stateVars.ang + 0.180 * self.stateVars.dir
      self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
      self.stateVars.shots = self.stateVars.shots + 1
      if self.stateVars.shots >= 70 then
        self.stateVars.finishedShooting = true
        self.timer                      = 1
      end
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.timer              = 10
      self.stateVars.warned   = false
      self.stateVars.warnSfx  = false
      self:endAction ( true )
    end
  end
end

function _CRYSTAL:shoot_plasma ( ang )
  local x, y        = self:getMiddlePoint()
  x                 = x - 7
  y                 = y - 5 + math.sin(self.floatY)
  local sx          = self.sprite:getScaleX()
  local dirX, dirY  = 0, 1

  if ang then
    dirX, dirY = math.cos(ang), math.sin(ang)
  end

  dirX, dirY = math.normalize(dirX, dirY)
  Audio:playSound  ( SFX.gameplay_plasma_shot, 0.8 )
  GameObject
    :spawn      ( "plasma_ball", x, y, 0, self, 1, true )
    :setHeading ( dirX, dirY, 2.5, 2.5, true )
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §RAY                 ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _RAY = _CRYSTAL:addState ( "RAY" )

_CRYSTAL.static.RAY_POSITIONS = {
  [1] = -110,
  [2] = -55,
  [3] = 0,
  [4] = 55,
  [5] = 110,
}

_CRYSTAL.static.RAY_LASERS = {
  [1] = {
    dir = 1,
    x   = 7,
    y   = 47,
  },
  [2] = {
    dir = 2,
    x   = 24,
    y   = 52+1,
  },
  [3] = {
    dir = 3,
    x   = 24+17,
    y   = 47,
  },
  [4] = {
    dir = 4,
    x   = 0,
    y   = 30,
  },
  [6] = {
    dir = 6,
    x   = 48,
    y   = 30,
  },
  [7] = {
    dir = 7,
    x   = 7,
    y   = 13,
  },
  [8] = {
    dir = 8,
    x   = 24,
    y   = 8-1,
  },
  [9] = {
    dir = 9,
    x   = 24+17,
    y   = 13,
  },
  [10] = {
    dir = 1,
    x   = 7,
    y   = 57,
  },
  [11] = {
    dir = 2,
    x   = 24,
    y   = 62+1,
  },
  [12] = {
    dir = 3,
    x   = 24+17,
    y   = 57,
  },
  [13] = {
    dir = 4,
    x   = 0,
    y   = 40,
  },
  [14] = {
    dir = 6,
    x   = 48,
    y   = 40,
  },
  [15] = {
    dir = 7,
    x   = 7,
    y   = 23,
  },
  [16] = {
    dir = 8,
    x   = 24,
    y   = 18-1,
  },
  [17] = {
    dir = 9,
    x   = 24+17,
    y   = 23,
  },
  [18] = {
    dir = 1,
    x   = 17,
    y   = 47,
  },
  [19] = {
    dir = 2,
    x   = 34,
    y   = 52+1,
  },
  [20] = {
    dir = 3,
    x   = 34+17,
    y   = 47,
  },
  [21] = {
    dir = 4,
    x   = 10,
    y   = 30,
  },
  [22] = {
    dir = 6,
    x   = 58,
    y   = 30,
  },
  [23] = {
    dir = 7,
    x   = 17,
    y   = 13,
  },
  [24] = {
    dir = 8,
    x   = 34,
    y   = 8-1,
  },
  [25] = {
    dir = 9,
    x   = 34+17,
    y   = 13,
  },
  [26] = {
    dir = 1,
    x   = -7,
    y   = 47,
  },
  [27] = {
    dir = 2,
    x   = 14,
    y   = 52+1,
  },
  [28] = {
    dir = 3,
    x   = 14+17,
    y   = 47,
  },
  [29] = {
    dir = 4,
    x   = -10,
    y   = 30,
  },
  [30] = {
    dir = 6,
    x   = 38,
    y   = 30,
  },
  [31] = {
    dir = 7,
    x   = -7,
    y   = 13,
  },
  [32] = {
    dir = 8,
    x   = 14,
    y   = 8-1,
  },
  [33] = {
    dir = 9,
    x   = 14+17,
    y   = 13,
  },
}

function _RAY:enteredState ( )
  self.stateVars.lasers   = { }
  self.timer              = 0
  self.stateVars.yDir     = 1
  self.stateVars.position = 3

  self.stateVars.pos = {
    pos = 0,
  }
  self.stateVars.tween = Tween.new ( 37, self.stateVars.pos, { pos = 1 }, "inOutQuad" )
end

function _RAY:exitedState ( )
  if self.stateVars.lasers and self.stateVars.lasers[1] then
    for i = 1, 9 do
      if self.stateVars.lasers[i] then
        self.stateVars.lasers[i]:disconnect ( )
        self.stateVars.lasers[i] = nil
      end
    end
  end
end

function _RAY:tick ( )
  if not self.stateVars.shot then

    self.sprite:change   ( 5, "crystal-eye-light-down",1, true )
    self.stateVars.disconnected = false
    self.stateVars.shot         = true
    self.stateVars.lidTimer     = 1
    self.stateVars.shaken       = false
    self.stateVars.yDir         = -self.stateVars.yDir

    self.stateVars.x            = self:getX()
    self.stateVars.y            = self:getY()

    if not self.stateVars.first then
      self.stateVars.first    = true
      self.stateVars.yAmount  = 20
    else
      self.stateVars.yAmount = 32
    end

    local px, py, mx, my = self:getLocations()
    if self.stateVars.position == 1 then
      self.stateVars.position = 2
    elseif self.stateVars.position == 5 then
      self.stateVars.position = 4
    elseif px < mx then
      self.stateVars.position = self.stateVars.position - 1
    elseif px > mx then
      self.stateVars.position = self.stateVars.position + 1
    end

    self.stateVars.position  = math.max ( self.stateVars.position, 1 )
    self.stateVars.poisiton  = math.min ( self.stateVars.position, 3 )
    self.lidPosition.opening = false

    self.stateVars.tween:reset ( )

    Audio:playSound ( SFX.gameplay_cannon_close )

    self.timer    = 1
    local x,y     = self:getPos()
    y             = y + 2
    local lasers  = self.class.RAY_LASERS
    for i = 1, 33 do
      if lasers[i] then
        self.stateVars.lasers[i] = 
          GameObject:spawn ( 
            "laser_beam", 
            x+lasers[i].x, 
            y+lasers[i].y, 
            lasers[i].dir,
            70
          )
      end
    end
  else
    if self.stateVars.lidTimer > 0 then
      self.stateVars.lidTimer  = self.stateVars.lidTimer - 1
      if self.stateVars.lidTimer <= 0 then
        Audio:playSound ( SFX.gameplay_cannon_open )
        self.sprite:change   ( 5, "crystal-eye-quick-blink",1, true )
      end
    else

      self.lidPosition.opening = true
      self.lidTween:update ( -1 )
      if self.lidTween:isAtStart() and not self.stateVars.shaken then
        self.stateVars.shaken   = true
        self.lidPosition.shaken = false
      end
    end

    if not self.stateVars.disconnected and self.stateVars.lasers and self.stateVars.lasers[1] and self.stateVars.lasers[1].disconnected then
      self.stateVars.disconnected = true
      for i = 1, 9 do
        self.stateVars.lasers[i] = nil
      end
    elseif self.stateVars.disconnected then
      self.timer = self.timer - 1
      if self.timer <= 0 then
        
        if self.stateVars.tween:update(1) then
          self.stateVars.shot = false
        end

        local x = math.lerp         ( self.stateVars.x, self.baseX+self.class.RAY_POSITIONS[self.stateVars.position], self.stateVars.pos.pos )
        local y = math.lerp         ( self.stateVars.y, self.stateVars.y+self.stateVars.yDir*self.stateVars.yAmount, self.stateVars.pos.pos )
        self:setActualPos           ( x, y )
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §TRACE               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _TRACE = _CRYSTAL:addState ( "TRACE" )

function _TRACE:enteredState ( )
  self.timer = -5
  self.stateVars.y = self:getY()
end

function _TRACE:exitedState ( )
  self.sumTween:reset()
  self.floatingDisabled = false
end

_CRYSTAL.static.SYRINGE_SPAWNS = {
  HOP = {
    [1] = {
      2, 14, 3, 13, 6
    },
    [-1] = {
      2, 11, 1, 12, 4
    },
    delay  = 1,
    aerial = true,
  }
}

function _TRACE:tick ( )
  if not self.stateVars.hopped then

    Audio:playSound ( SFX.gameplay_powered_walker_jump )
    local px, py, mx, my = self:getLocations ( )
    local dir = -1
    if px > mx then
      dir = 1
    end

    local cx, cy = Camera:getPos ( )
    if (cx + 116) > mx then
      dir = 1
    elseif (cx + GAME_WIDTH - 116 ) < mx then
      dir = -1
    end

    self.stateVars.dope                = false
    self.floatingDisabled              = true
    self.velocity.horizontal.direction = dir
    self.velocity.horizontal.current   = 0.5 + RNG:range ( 1, 2 )

    self.velocity.vertical.direction  = 1
    self.velocity.vertical.current    = -4.75
    self.velocity.vertical.update     = true
    self.stateVars.hopped             = true    
    self.updatePhysics                = true
  end

  self:applyPhysics ( )


  if _TRACE.hasQuitState ( self ) then return end

  if self.velocity.vertical.current > 0 and self.stateVars.y - 12 < self:getY() and not self.stateVars.dope then
    self.stateVars.dope = true


    Audio:playSound    ( SFX.gameplay_final2_hologram_spawn )
    self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )

    local px, py, mx, my = self:getLocations ( )
    local syrDir = px < mx and -1 or 1
    local x,y    = self:getPos()
    local spawns = self.class.SYRINGE_SPAWNS.HOP[1]
    local method = self.class.SYRINGE_SPAWNS.HOP

    x = x + 16
    y = y + 20
    local cx, cy = Camera:getPos ( )

    if (cx + GAME_WIDTH - 80 ) > mx then
      for i = 2, #spawns do
        GameObject:spawn ( 
          "freezing_projectile", 
          x + 26,
          y+4,
          spawns[i],
          nil,
          (i-1)*(method.delay or 2),
          4
        )
      end
    end

    if (cx + 80) < mx then
      local spawns = self.class.SYRINGE_SPAWNS.HOP[-1]
      for i = 2, #spawns do
        GameObject:spawn ( 
          "freezing_projectile", 
          x - 26,
          y+4,
          spawns[i],
          nil,
          (i-1)*(method.delay or 2),
          4
        )
      end
    end

    self.floatY = 0
    self.velocity.horizontal.current = 0
    self.velocity.vertical.current = -0.5
    self.velocity.vertical.update  = false
    self:applyVerticalShake ( 3, 0.25, 1 )
    self.timer = 12
  end

  self.sumTween:update ( self.stateVars.dope and -1 or 1 )

  if self.timer > 0 then
    self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.25, 0 )
    if self.velocity.vertical.current == 0 then

      self.floatingDisabled = false
    end
    self.timer = self.timer - 1
    if self.timer <= 0 then

      self.stateVars.hopped = false
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §BLADE               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _BLADE = _CRYSTAL:addState ( "BLADE" )

function _BLADE:enteredState ( )

end

function _BLADE:exitedState ( )
  self.extraFloat               = 0
  self.updatePhysics            = false
  self.velocity.vertical.update = false
  self.sumTween:reset ( )
end

function _BLADE:tick ( )

  if not self.stateVars.started then
    Audio:playSound ( SFX.gameplay_cannon_close )
    self.stateVars.started              = true
    self.updatePhysics                  = true
    self.velocity.horizontal.direction  = 1
    self.velocity.vertical.current      = -0.35
    self.velocity.vertical.direction    = 1
    self.velocity.vertical.update       = false
    self.stateVars.shotTimer            = 19
  end

  if self.stateVars.started and not self.stateVars.drop then
    local px, py, mx, my = self:getLocations()

    if px < mx then
      local inc = self.velocity.horizontal.current > 0 and 0.125 or 0.25
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - inc, -3 )
    elseif px > mx then
      local inc = self.velocity.horizontal.current < 0 and 0.125 or 0.25
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + inc, 3 )
    end 
    self.stateVars.shotTimer = self.stateVars.shotTimer - 1
    if self.stateVars.shotTimer <= 0 then
      local mx, my = self:getMiddlePoint ( )
      self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
      self.stateVars.shotTimer = 19
      Audio:playSound ( SFX.gameplay_mortar_shot )
      local mx, my = self:getMiddlePoint()
      GameObject:spawn ( 
        "shift_downcut_projectile", 
        mx, 
        my, 
        self.sprite:getScaleX(), 
        self,
        0,
        -2.75
      )
      GameObject:spawn ( 
        "ice_ball", 
        mx, 
        my, 
        self.sprite:getScaleX(), 
        self,
        0,
        -2.75
      )
    end

    if self:checkIsPlayerFrozen ( ) and not self.stateVars.punishTime then
      self.stateVars.punishTime = -2
    end

    self.sumTween:update(1)
    local cy = Camera:getY ( )
    if self:getY() < cy + 44 then
      Audio:playSound ( SFX.gameplay_cannon_open )
      self.stateVars.drop           = true
      self.velocity.vertical.update = true
    end
  elseif not self.stateVars.drop2 then
    if self.velocity.horizontal.current < 0 then
      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current + 0.25, 0 )
    elseif self.velocity.horizontal.current > 0 then
      self.velocity.horizontal.current = math.max ( self.velocity.horizontal.current - 0.25, 0 )
    end

    if self:checkIsPlayerFrozen ( ) and not self.stateVars.punishTime then
      self.stateVars.punishTime = -2
    end

    self.sumTween:update(-1)
    if self:getY() > self.baseY + 8 then
      self.stateVars.drop2           = true
      self.velocity.vertical.update  = false
      self.velocity.vertical.current = -2
      self.timer                     = 60
    end
  elseif self.stateVars.drop2  then
    self.sumTween:update(-1)
    self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.25, 0 )
    self.timer                     = self.timer - 1
    if self.timer <= 0 then
      self.stateVars.started = false
      self.stateVars.drop    = false
      self.stateVars.drop2   = false
    end
  end

  if self.stateVars.punishTime then
    self.stateVars.punishTime = self.stateVars.punishTime + 1
    if self.stateVars.punishTime > 7 then
      self.velocity.horizontal.current = 0
      self.stateVars.punish            = true
      self:gotoState     ( "FREEZE_PUNISH" )
      return 
    end
  end

  self:applyPhysics ( )
end

function _CRYSTAL:checkIsPlayerFrozen ( )
  if self.playerIsKnownToBeAlive then
    local f = GlobalObserver:single ( "IS_PLAYER_FROZEN" )
    if f then
      local px = self:getLocations ( )
      local cx = Camera:getX       ( )
      if px > (cx + 44) and px < (cx + GAME_WIDTH - 44) then
        return true
      end
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §freeze punish ------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PUNISH = _CRYSTAL:addState ( "FREEZE_PUNISH" )

function _PUNISH:enteredState ( )
  self.landingGeneratesDustNow  = true

  local px, py, mx, my = self:getLocations ( )

  self.stateVars.curX     = self:getX ( )
  self.stateVars.curY     = self:getY ( )
  self.stateVars.targetX  = px - 12

  self.stateVars.pos = {
    pos = 0,
  }
  self.stateVars.tween = Tween.new ( 35, self.stateVars.pos, { pos = 1 }, "inOutQuad" )

  self.timer = 16
  self.state.isGrounded = false
end

function _PUNISH:exitedState ( )

  self.lidPosition.opening = true
  self.lidTween:reset ( )
  self.landingGeneratesDustNow  = false
end

function _PUNISH:tick ( )
  if not self.stateVars.movedToPosition then
    if self.stateVars.tween:update ( 1 ) then
      self.stateVars.movedToPosition = true
    end

    local cy = Camera:getY()
    local x = math.lerp         ( self.stateVars.curX, self.stateVars.targetX, self.stateVars.pos.pos )
    local y = math.lerp         ( self.stateVars.curY, cy+34,                  self.stateVars.pos.pos ) -- pos pos!
    self:setActualPos           ( x, y )
  elseif not self.stateVars.started then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.stateVars.started              = true
      self.lidPosition.opening            = false
      self.updatePhysics                  = true
      self.velocity.horizontal.direction  = 1
      self.velocity.vertical.direction    = 1
      self.velocity.vertical.update       = false
      self.sprite:change ( 5, "crystal-eye-light-down", 1, true )
    end
  end
  
  if self.stateVars.started and not self.stateVars.landed then
    self.velocity.vertical.current = self.velocity.vertical.current + 0.5
    self:applyPhysics ( )

    if _PUNISH.hasQuitState ( self ) then return end

    self.timer = 60

    if self.state.isGrounded then
      self.floatingDisabled = true
      self.floatY           = 0
      self.stateVars.tween:reset ()
      self:applyVerticalShake ( 3, 0.25, 1 )
      Camera:startShake       ( 0, 3, 20, 0.25 )
      self.lidTween:update    ( 999 )
      self.lidPosition.opening = false
      self.stateVars.landed    = true

      self.stateVars.curY = self:getY()

      Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
      Audio:playSound         ( SFX.gameplay_crash_impact )
    end
  end

  if self.stateVars.landed then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      if self.timer == 0 then
        self.sprite:change ( 5, "crystal-eye-light-up-simple", 1, true )
        self.floatingDisabled = false
        Audio:playSound ( SFX.gameplay_cannon_open )
      end
      self.lidPosition.opening = true
      local finish = false
      if self.stateVars.tween:update ( 1 ) then
        finish = true
      end

      local x = self:getX ( )
      local y = math.lerp ( self.stateVars.curY, self.baseY, self.stateVars.pos.pos ) -- pos pos!
      self:setActualPos   ( x, y )

      if finish then
        self:gotoState ( "BLADE" )
      end
    end
  end
end


--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §CABLE               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _CABLE = _CRYSTAL:addState ( "CABLE" )

function _CABLE:enteredState ( )
  self.floatingDisabled             = true
  self.velocity.horizontal.current  = 0
  self.velocity.vertical.direction  = 1
  self.stateVars.firstJump          = true
  self.stateVars.projectileTimer    = -1


  self.state.isGrounded         = false

  self.timer                    = 5
  self.stateVars.landed         = false
end

function _CABLE:exitedState ( )
  self.updatePhysics            = false
  self.landingGeneratesDustNow  = false
end

function _CABLE:tick ( )

  self.timer = self.timer - 1
  if self.timer == 0 then
    self.state.isGrounded         = false
    self.velocity.vertical.update = true
    self.updatePhysics            = true
    self.landingGeneratesDustNow  = true

    Audio:playSound ( SFX.gameplay_powered_walker_jump )

    self.stateVars.landed = false
    local px, py, mx, my  = self:getLocations ( )

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
    self.velocity.vertical.current     = self.stateVars.firstJump and -3.5 or -6.5
    self.state.isGrounded              = false
    self.stateVars.jumped              = true
  end

  if self.stateVars.jumped and not self.stateVars.doubleJumped and self.velocity.vertical.current > -1 and self.velocity.vertical.current < 2 then
    local px, py, mx, my = self:getLocations()
    if math.abs ( px - mx ) < 24 then
      self.velocity.vertical.current = -3.25
      self.stateVars.doubleJumped    = true
      self.stateVars.projectileTimer = 20

      self.velocity.horizontal.current = math.min ( self.velocity.horizontal.current, 1.5 )
      self.sprite:change ( 7, "crystal-spawn-pulse", 4, true )
    end
  end

  self.stateVars.projectileTimer = self.stateVars.projectileTimer - 1
  if self.stateVars.projectileTimer > 0 and self.stateVars.projectileTimer%6 == 0 then
    local px, py, mx, my = self:getLocations()
    self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
    GameObject:spawn ( 
      "plasma_ball", 
      mx-8, 
      my, 
      0, 
      1
    )
  end

  self:applyPhysics ( )

  if _CABLE.hasQuitState ( self ) then return end

  if self.state.isGrounded and not self.stateVars.landed then
    self.stateVars.jumped              = false
    self.stateVars.firstJump           = false
    self.stateVars.doubleJumped        = false
    self.sprite:change ( 5, nil )
    self.floatY                      = 0
    self.velocity.horizontal.current = 0
    self.stateVars.landed            = true

    self:applyVerticalShake ( 3, 0.25, 1 )
    Camera:startShake       ( 0, 3, 20, 0.25 )
    Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
    Audio:playSound         ( SFX.gameplay_crash_impact )
    local px, py, mx, my = self:getLocations()
    GameObject:spawn ( 
      "sticky_goop_vial", 
      mx-8, 
      my, 
      0, 
      1
    )
    self.timer = 1
  end

  if self.state.isGrounded then
    self.lidPosition.opening = false
    self.lidTween:update(999)
  else
    if not self.stateVars.firstJump and not self.stateVars.doubleJumped then
      self.sprite:change ( 5, "crystal-eye-light-up-simple" )
    end
    self.lidPosition.opening = true
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §BIT                 ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _BIT = _CRYSTAL:addState ( "BIT" )

_CRYSTAL.static.BIT_POSITIONS = {
  [1] = -57,
  [2] = 0,
  [3] = 57,
}

function _BIT:enteredState ( )
  local x, y = self:getPos()
  self.stateVars.pos = {
    x   = x,
    y   = y,
    pos = 0, 
  }
  self.stateVars.position    = 2
  self.stateVars.tween       = Tween.new ( 25, self.stateVars.pos, { pos = 1 }, "inOutQuad" )
  self.stateVars.tweenTarget = -1
  self.timer = 24
  --GameObject:spawn ( "shift_uppercut_projectile", mx,my-43, self.sprite:getScaleX() )
end

function _BIT:exitedState ( )

end

function _BIT:tick ( )
  if self.stateVars.tween:isAtStart() or self.stateVars.tween:isFinished() then
    self.timer = self.timer - 1
    if self.timer == 0 then

      local px, py, mx, my = self:getLocations ( )
      if py < my then
        if self.stateVars.position <= 1 then
          self.stateVars.position = 2
        else
          self.stateVars.position = self.stateVars.position - 1
        end
      else
        if self.stateVars.position >= 3 then
          self.stateVars.position = 2
        else
          self.stateVars.position = self.stateVars.position + 1
        end
      end

      self.stateVars.xDir = px < mx and -1 or 1
      local cx = Camera:getX()
      if (cx + 96) > mx then
        self.stateVars.xDir = 1
      elseif (cx + GAME_WIDTH - 96) < mx then
        self.stateVars.xDir = -1
      end

      self:applyVerticalShake ( 3, 0.25, 1 )
      self.floatY = 0

      self.stateVars.currentY = self:getY()
      self.stateVars.currentX = self:getX()

      local x,y = self:getPos()
      Audio:playSound ( SFX.gameplay_cannon_close )
      Audio:playSound ( SFX.gameplay_bit_uppercut )

      self.sprite:change   ( 5, "crystal-eye-quick-blink",1, true )
      self.sprite:change   ( 7, "crystal-spawn-pulse", 4, true )
      GameObject:spawn     ( "shift_uppercut_projectile", x,   y+1, -1 )
      local px, py, mx, my = self:getLocations()
      self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
      GameObject:spawn ( 
      "plasma_ball", 
      mx-8, 
      my, 
      0, 
      1
      )
      GameObject:spawn     ( "shift_uppercut_projectile", x+32,y+1,  1 )
      self.sumTween:update ( 999 )
      self.timer = 24
      self.stateVars.tweenTarget = -self.stateVars.tweenTarget 
      self.floatingDisabled      = true
      self.stateVars.tween:reset ( )
    end
  end

  self.sumTween:update        ( -1 )
  if self.timer < 20 and self.floatingDisabled then
    self.stateVars.tween:update ( 1 )
    local x = math.lerp         ( self.stateVars.currentX, self.stateVars.currentX+self.stateVars.xDir*24, self.stateVars.pos.pos )
    local y = math.lerp         ( self.stateVars.currentY, self.baseY+self.class.BIT_POSITIONS[self.stateVars.position], self.stateVars.pos.pos ) -- pos pos!
    self:setActualPos           ( x, y )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §MEDLEY              ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _MEDLEY = _CRYSTAL:addState ( "MEDLEY" )

_CRYSTAL.static.MEDLEY_POSITIONS = {
  [1] = -120,
  [2] = -80,
  [3] = -40,
  [4] = 0,
  [5] = 40,
  [6] = 80,
  [7] = 120,
}

function _MEDLEY:enteredState ( )
  self.timer = 1
  self.stateVars.shots = 0
  self.stateVars.y = self:getY()
  self.state.isgrounded = false

end

function _MEDLEY:exitedState ( )
  self.sumTween:reset ( )
  self.lidTween:reset ( )
  self.updatePhysics                = false

end

function _MEDLEY:tick ( )
  if not self.stateVars.firstShot then
    if not self.lidTween:isAtStart () then
      self.lidTween:update ( -1 )
      return
    end
    self.timer = self.timer - 1 
    if self.timer == 0 then
      self.stateVars.shots = self.stateVars.shots + 1
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )

      local mx, my = self:getMiddlePoint()
      local sin    = math.sin ( self.floatY )
      GameObject:spawn ( 
        "virus_engineer_grenade",
        mx-8-4, 
        my-10+sin,
        1,
        -2,
        -2.0
      )
      GameObject:spawn ( 
        "virus_engineer_grenade",
        mx-8+4, 
        my-10+sin,
        -1,
        -2,
        -2.0
      )

      Audio:playSound ( SFX.gameplay_cannon_open )
      self.sumTween:finish ( )

      if self.stateVars.shots < 12 then
        self.timer = 1
      end
    end

    self.sumTween:update(-1)

    if self.timer <= -50 then
      self.stateVars.firstShot = true
    end

    self.floatingDisabled          = true
    self.updatePhysics             = true
    self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.125, -0.25 )
    self:applyPhysics ( )
    return
  end

  if not self.stateVars.hopped then
    Audio:playSound ( SFX.gameplay_cannon_close )
    Audio:playSound ( SFX.gameplay_powered_walker_jump )
    local px, py, mx, my = self:getLocations ( )
    local dir = -1
    if px > mx then
      dir = 1
    end

    self.sprite:change ( 5, "crystal-eye-light-down" )

    local cx, cy = Camera:getPos ( )
    if (cx + 140) > mx then
      dir = 1
    elseif (cx + GAME_WIDTH - 140 ) < mx then
      dir = -1
    end

    self.stateVars.dope                = false
    self.floatingDisabled              = true
    self.velocity.horizontal.direction = dir
    self.velocity.horizontal.current   = 0.5 + RNG:range ( 1, 2 )

    self.velocity.vertical.direction  = 1
    if not self.stateVars.firstHop then
      self.stateVars.firstHop = true
      self.velocity.vertical.current    = -3.5
    else
      self.velocity.vertical.current    = -4.5
    end
    self.velocity.vertical.update     = true
    self.stateVars.hopped             = true    
    self.updatePhysics                = true

    self.lidPosition.opening = false
  end

  self:applyPhysics ( )
  if _MEDLEY.hasQuitState ( self ) then return end

  if self.state.isGrounded--[[self.velocity.vertical.current > 0 and self.stateVars.y + 15 < self:getY()]] and not self.stateVars.dope then
    self.stateVars.dope              = true
    self.timer                       = 40
    self.floatY                      = 0
    self.velocity.horizontal.current = 0
    self.velocity.vertical.current   = 2
    self.velocity.vertical.update    = false
    self.stateVars.vertDec           = true

    Audio:playSound ( SFX.gameplay_medley_wave_impact_2     )
    Audio:playSound ( SFX.gameplay_medley_wave_impact_2_pt2 )
    local px, py, mx, my = self:getLocations()
    self.sprite:change ( 5, "crystal-eye-quick-blink", 1, true )
    GameObject:spawn ( 
      "plasma_ball", 
      mx-8, 
      my, 
      0, 
      1
    )

    self:spawnWaveProjectile (  1 )
    self:spawnWaveProjectile ( -1 )

    Camera:startShake       ( 0, 3, 20, 0.25 )
    Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
    Audio:playSound         ( SFX.gameplay_crash_impact )
  end

  if self.timer > 0 then
    if self.stateVars.vertDec then
      self.velocity.vertical.current = math.max ( self.velocity.vertical.current - 0.25, -1 )
      if self.velocity.vertical.current <= -2 then
        self.stateVars.vertDec = false
      end
    else
      self.velocity.vertical.current = math.min ( self.velocity.vertical.current + 0.25, -0.25 )
    end
    --[[
    if self.velocity.vertical.current == 0 then
      self.floatingDisabled = false
    end]]
    self.timer = self.timer - 1
    if self.timer <= 0 then

      self.sprite:change ( 5, "crystal-eye-light-up-simple" )
      Audio:playSound ( SFX.gameplay_cannon_open )
      self.timer               = 15
      self.stateVars.hopped    = false
      self.stateVars.firstShot = false
      self.stateVars.shots     = 0
      self.lidPosition.opening = true
      self.lidPosition.shaken  = false
    end
  end
end

function _CRYSTAL:spawnWaveProjectile ( dir, amount, yOffset )
  yOffset              = yOffset or 0
  local i              = 1
  local spawnX, spawnY = self:getPos()
  local inc            = dir or 1
  local cx,cy          = Camera:getPos()
  spawnY               = cy + 210
  local layer          = Layers:get ( "TILES-RAY-LASERS" )

  if inc > 0 then
    spawnX = spawnX + self.dimensions.x + self.dimensions.w + 4
  else
    spawnX = spawnX + self.dimensions.x - 20
  end

  local target = amount or 30
  while i < target do
    GameObject:spawn ( 
      "wave_ground_projectile",
      spawnX, 
      spawnY+yOffset,
      (i-1),
      layer
    )
    i      = i + 1
    spawnX = spawnX + 15 * inc

    if spawnX <= cx or spawnX >= cx + GAME_WIDTH then
      break
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §CRASH               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _CRASH = _CRYSTAL:addState ( "CRASH" )

function _CRASH:enteredState ( px, py, mx, my )
  self.floatingDisabled             = true
  self.velocity.horizontal.current  = 0
  self.velocity.vertical.direction  = 1

  self.timer                    = -11
  self.stateVars.landed         = false
  self.state.isGrounded         = false
  self.velocity.vertical.update = true
  self.updatePhysics            = true
  self.landingGeneratesDustNow  = true
end

function _CRASH:exitedState ( )
  self.updatePhysics            = false
  self.landingGeneratesDustNow  = false
end

function _CRASH:tick ( )

  self.timer = self.timer - 1
  if self.timer == -5 then
    Audio:playSound ( SFX.gameplay_powered_walker_jump )

    self.stateVars.landed = false
    local px, py, mx, my  = self:getLocations ( )

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
    self.velocity.vertical.current     = -4.5 - RNG:range ( 1, 3 )
    self.state.isGrounded              = false
  end

  self:applyPhysics ( )


  if _CRASH.hasQuitState ( self ) then return end

  if self.state.isGrounded and not self.stateVars.landed then
    self.stateVars.landedOnce = true
    self.sprite:change ( 5, nil )
    self.floatY                      = 0
    self.velocity.horizontal.current = 0
    self.stateVars.landed            = true

    self:applyVerticalShake ( 3, 0.25, 1 )
    Camera:startShake       ( 0, 3, 20, 0.25 )
    Audio:playSound         ( SFX.gameplay_crash_earthquake, 0.6 )
    Audio:playSound         ( SFX.gameplay_crash_impact )

    self:spawnFallingBlocks ( nil, nil, true )
      local x,y = self:getPos()
      GameObject:spawn     ( "shift_uppercut_projectile", x,   y+20, -1 )
      GameObject:spawn     ( "shift_uppercut_projectile", x+32,y+20,  1 )
    self.timer = 1
  end

  if self.stateVars.landedOnce then
    if self.state.isGrounded then
      self.lidPosition.opening = false
      self.lidTween:update(999)
    else
      self.sprite:change ( 5, "crystal-eye-light-up-simple" )
      self.lidPosition.opening = true
    end
  end

  if self.timer > 0 and self.timer % 5 == 0 then
    self:spawnFallingBlocks ( nil, nil, true )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §HASH                ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _HASH = _CRYSTAL:addState ( "HASH" )

_CRYSTAL.static.HASH_POSITIONS = {
  [1] = -105,
  [2] = -70,
  [3] = -35,
  [4] = 0,
  [5] = 35,
  [6] = 70,
  [7] = 105,
  [8] = -90,
  [9] = -55,
  [10] = -20,
  [11] = 15,
  [12] = 50,
  [13] = 85,
  [14] = 120,
  [15] = -120,
  [16] = -85,
  [17] = -50,
  [18] = -15,
  [19] = 20,
  [20] = 55,
  [21] = 90,
}

function _HASH:enteredState ( )
  self.stateVars.rand  = RNG:range ( 1, 3 )
  self.stateVars.init  = false
  self.timer           = 1
  self.stateVars.count = 0
  self.stateVars.dir   = RNG:rsign()
  self.stateVars.first = true

  self.stateVars.pos = {
    pos = 0,
  }
  self.stateVars.tween = Tween.new ( 36, self.stateVars.pos, { pos = 1 }, "inOutQuad" )
end

function _HASH:exitedState ( )
  self.lidPosition.opening = true
  self.lidTween:reset ( )

  if self.stateVars.count > 0 then
    for i = 1, self.stateVars.count do
      if not self.stateVars.shot and self.stateVars[i] then
        self.stateVars[i]:handleBulletBlock()
      end
      self.stateVars[i] = nil
    end
  end
end

function _HASH:tick ( )
  if not self.stateVars.init then
    if not self.stateVars.eyeReset then
      Audio:playSound    ( SFX.gameplay_cannon_close   )
      self.sprite:change ( 5, "crystal-eye-light-down" )
      self.stateVars.eyeReset = true
    
      if not self.stateVars.position then
        self.stateVars.position = 4
      else
        self.stateVars.position = self.stateVars.position + RNG:rsign()
        if self.stateVars.position < 1 then
          self.stateVars.position = 2
        elseif self.stateVars.position > 7 then
          self.stateVars.position = 6
        end
      end

      self.stateVars.curX = self:getX()
    end

    if not self.stateVars.first then
      self.stateVars.tween:update(1)

      local x = math.lerp         ( self.stateVars.curX, self.baseX+(self.class.HASH_POSITIONS[self.stateVars.position]),    self.stateVars.pos.pos )
      self:setActualPos           ( x, self:getY() )
    end

    self.timer               = self.timer - 1
    self.lidPosition.opening = false
    self.lidPosition.shaken  = false
    if self.timer <= 0 and (self.stateVars.first or self.stateVars.tween:isFinished()) then
      self.stateVars.first    = false
      self.stateVars.init     = true
      self.timer              = 1
      self.stateVars.dir      = -self.stateVars.dir
      self.stateVars.shot     = false
      self.stateVars.spawning = true
    end
  elseif self.stateVars.spawning then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      local mx, my          = self:getMiddlePoint()
      self.stateVars.count  = self.stateVars.count + 1

      self.stateVars[self.stateVars.count] = GameObject:spawn ( 
        "hacker_projectile",
        mx-2, 
        my-4,
        2.0,
        2.0,
        0,
        0,
        self.stateVars.rand,
        30,
        math.pi + (-(self.stateVars.count-1) * 0.54)* -self.stateVars.dir,
        0.075 * -self.stateVars.dir,
        0,
        true
      )
      self.stateVars.rand  = self.stateVars.rand  + 1
      if self.stateVars.rand > 3 then
        self.stateVars.rand = 1
      end
      self.timer = self.stateVars.count >= 21 and 20 or 5
      self.stateVars.spawning = not (self.stateVars.count >= 21)
    end
  elseif not self.stateVars.shot then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      for i = 1, self.stateVars.count do
        self.stateVars[i]:giveIncreasingVelocity ( 0.75, 0.25, 3.0 )
        self.stateVars[i]:setAngleSpeed          ( -self.stateVars.dir * 0.03 )
      end
      self.stateVars.count     = 0
      self.timer               = 1
      self.stateVars.shot      = true
      self.lidPosition.opening = true
      Audio:playSound    ( SFX.gameplay_cannon_open   )
      self.sprite:change ( 5, "crystal-eye-light-up-simple" )
      self.sprite:change ( 7, "crystal-spawn-pulse", 2, true )
    end
  else
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.stateVars.tween:reset ( )
      self.stateVars.init      = false
      self.stateVars.eyeReset  = false
      self.timer               = 1
    end
  end
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Death               ------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _DEATH = _CRYSTAL:addState ( "DEATH" )

_CRYSTAL.static.DEATH_EXPLOSION_LOCATIONS = {
  {  -1,  9  },
  {  42,  0  },
  {  20, 30  },
  {  11, 65  }, 
  {  30, 70  }, 
  {  10, 24  }, 
  {  35, 48  }, 
  {  20, -5  },
  {  17, 18  },  
  {   8, 55  },  
  {  32, 60  },
}

function _DEATH:enteredState ( )
  StageClearStats.addKill ( )

  if self.state.isBossRushSpawn then
    self.stateVars.bossRushTimer = 180
    MapData.BossRush.markCleared      ( self.state.isBossRushSpawn_id )
    GameObject:startFinalKillSlowdown ( )
    self:spawnBossRushRewards         ( true )
  else
    GlobalObserver:single   ( "DESTROYED_TARGET_OBJECT", self )
  end

  self.lidPosition.opening = true
  self.lidPosition.shaken  = false

  self.isDying                      = true
  self.state.isFinalKill            = true
  self.stateVars.finalKillTimer     = 20
  self.isStunned                    = true
  self.stunTimer                    = 0
  self.velocity.horizontal.current  = 0
  self.velocity.vertical.update     = true
  self.angle                        = 0
  self.ACTIVE_PALETTE               = Colors.Sprites.enemy_stunned
  self.timer                        = 0

  self.sprite:change ( 5, "crystal-eye-light-up-simple", 5, false )

  self:applyShake                      ( 3, 0.125, -self.sprite:getScaleX ( ) )
  --self:permanentlyDisableContactDamage ( true )

  self.stateVars.explosionIndex = RNG:range ( 1, #self.class.DEATH_EXPLOSION_LOCATIONS )
  self:addRandomExplosion ( ) 
  self:addRandomExplosion ( ) 
  self:addRandomExplosion ( ) 

  local sx     = self.sprite:getScaleX  ( )
  local mx, my = self:getMiddlePoint    ( )
  --[[
  if sx == 1 then
    mx = mx + 65 
    my = my - 19
  else
    mx = mx + 55
    my = my - 19
  end]]
  mx = mx - 4
  my = my + 6


  DataChip.nextSpawnIgnoresPassables ( true )
  DataChip.spawn ( self.class.name, mx, my, true, true )
  DataChip.nextSpawnIgnoresPassables ( false )
end

function _DEATH:exitedState ( )

end

function _DEATH:tick ( )
  self.stunTimer = self.stunTimer + 1

  if self.stateVars.bossRushTimer then
    self.stateVars.bossRushTimer = self.stateVars.bossRushTimer - 1
    if self.stateVars.bossRushTimer <= 0 then
      if not self._notifiedBossRushHandler then
        self._notifiedBossRushHandler = true
        GAMESTATE.bossRushMode.defeated = true
        GlobalObserver:none ( "CUTSCENE_START", "special/cutscene_bossRushHandler" )
      end
    end
  end

  if self.stateVars.bossRushTimer then
    if self.stunTimer < 240 then
      if self.stunTimer % 20 == 0 then
        self:addRandomExplosion ( ) 
      end
    end
    if self.stunTimer == 80 then
      Audio:playSound    ( SFX.gameplay_final2_death )
      self.sprite:change ( 5, "crystal-eye-light-down", 1, true )
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
        Audio:playSound    ( SFX.gameplay_final2_death )
        self.sprite:change ( 5, "crystal-eye-light-down", 1, true )
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
      self:applyShake ( 5, 0.25  )

      local sx     = self.sprite:getScaleX  ( )
      local mx, my = self:getMiddlePoint    ( )
      --[[
      if sx == 1 then
        mx = mx + 65 
        my = my - 19
      else
        mx = mx + 55
        my = my - 19
      end]]
      mx = mx - 1
      my = my - 2 + math.sign(self.floatY)

      Audio:playSound ( SFX.gameplay_player_death_trigger, 0.75 )

      local l = self.layers.sprite()+20
      
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:addSpecial ( "emit_green_beam", mx,my, l, false, true )
      Particles:add ( "death_trigger_flash", mx,  my, math.rsign(), 1, 0, 0, l )

      self.stateVars.mx = mx
      self.stateVars.my = my
    elseif self.stunTimer == 340 then
      self.timer = 160
    elseif self.stunTimer > 340 then
      self:whiteCircle()

      if self.timer > 360 then
        self:updateGarbage ( )
      end
    end
  end

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

function _CRYSTAL:addRandomExplosion ( )
  if not self.stateVars.explosionIndex then
    self.stateVars.explosionIndex = RNG:range ( 1, #self.class.DEATH_EXPLOSION_LOCATIONS )
  end 
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
    elseif self.stateVars.explosionIndex > #self.class.DEATH_EXPLOSION_LOCATIONS then
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
        Camera:startShake ( 0, 3, 3, 0.25 )
        Audio:playSound   ( SFX.gameplay_enemy_bounces_on_ground, 1.1 )
      end
    end
  end

  if not self.fallingGibs[1].active then
    self.fallingGibs = nil
    if self.class.SCRIPT then
      SetBossDefeatedFlag ( self.class.name )
      GlobalObserver:none ( "CUTSCENE_START", self.class.SCRIPT )
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
--[[------------------------------ §take damage  -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local bossRushClearFlags_simple = {
  "subboss-defeated-ray",
  "subboss-defeated-trace",
  "subboss-defeated-blade",
  "subboss-defeated-cable",
  "subboss-defeated-bit",
  "subboss-defeated-medley",
  "subboss-defeated-crash",
  "subboss-defeated-hash"
}

function _CRYSTAL:takeDamage ( damage, direction )
  if not self.activated or self.isDying then
    return false
  end

  damage = damage or 0
  if isFunction(damage) then
    damage = damage ( )
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

  if self.state.isBossInvulnerable then
    local mx,my = self:getMiddlePoint ( )
    direction   = direction or 0
    direction   = math.abs(direction) > 0 and direction or 1

    local ox, oy = ((direction > 0) and -31 or -5), -24
    Particles:addSpecial( 
      "guard_flash", 
      mx+(ox), 
      my+(oy)+math.sin ( self.floatY ) * 3, 
      direction, 
      1, 
      2, 
      self.layers.particles() 
    )
    return true, true, true
  end

  damage       = damage    or 1
  direction    = direction or RNG:rsign()

  self:applyShake ( 2, 0.25, direction )

  Audio:playSound ( SFX.gameplay_final2_take_damage, 0.65 )

  if isFunction(damage) then
    damage = damage()
  end

  if BUILD_FLAGS.DEBUG_BUILD and UI.kb.isDown ("b") then
    if self.health > 32 then
      damage = self.health-16
    else
      damage = 48
    end
  end

  local before          = self.health
  self.hitFlash.current = self.hitFlash.max
  self.health           = self.health - damage

  if self.state.nextBoxToBlowUp and self.health <= 1 then
    self:blowUpCircuitBox ( self.state.nextBoxToBlowUp )
    SetTempFlag ( bossRushClearFlags_simple[self.state.nextBoxToBlowUp], 1 )
  end

  if self.state.lastPickPerformed then
    if self.health < 1 then
      self:gotoState ( "DEATH" )
    end
  else
    if self.health <= 1 then 
      self.health = 1
      self:gotoState ( "GOING_TO_PROJECTION" )
    elseif (before > 32 and self.health <= 32) then
      self:gotoState ( "GOING_TO_PROJECTION" )
    end
  end

  self:notifyBossHUD ( damage, direction )
  return true
end

_PROJECTION.takeDamage = protectedTakeDamage

function _CRYSTAL:chain ( )
  if self.health > 0 then
    self:takeDamage ( 1, RNG:rsign() )
  end
  return false
end

function _CRYSTAL:isGrabbable ( )
  return false
end
function _CRYSTAL:pull        ( )
  return false
end
function _CRYSTAL:isSuplexable ( )
  return false
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §going to projection §RECOVERING ------------]]--
--[[----------------------------------------------------------------------------]]--
local _RECOVERING = _CRYSTAL:addState ( "GOING_TO_PROJECTION" )

function _RECOVERING:enteredState ( )
  self:applyShake         ( 5, 0.25 )
  Audio:playSound         ( SFX.gameplay_portal_enter )
  self:addRandomExplosion ( )
  self:addRandomExplosion ( )
  self:addRandomExplosion ( )
  self.sumTween:reset     ( )

  self.fakeOverkilledTimer      = 10000
  self.state.isBossInvulnerable = true

  self.velocity.vertical.update    = false
  self.velocity.vertical.current   = 0
  self.velocity.horizontal.current = 0
  
  if self.state.isSimpleVersion then
    self.cursorX = nil
  end

  local x,y = self:getPos()
  if (self.baseX ~= x or self.baseY ~= y) then
    self.stateVars.pos = {
      x = x,
      y = y,
    }

    self.stateVars.tween = Tween.new (
      30,
      self.stateVars.pos,
      { x = self.baseX, y = self.baseY },
      "inOutQuad"
    )

    self.stateVars.delay = 30
    self.timer           = 0
  else
    self.stateVars.delay = 0
    self.timer           = 30
  end

  self.sprite:change ( 5, "crystal-eye-light-up-simple", 5, false )
  self.sprite:change ( 6, nil )

  self:permanentlyDisableContactDamage ( true )

  self.lidPosition.opening = true
end

function _RECOVERING:exitedState ( )

end

function _RECOVERING:tick ( )
  if self.stateVars.delay > 0 then
    self.stateVars.delay = self.stateVars.delay - 1
  else
    self.floatingDisabled = false
    if self.stateVars.tween and not self.stateVars.tween:isFinished ( ) then
      self.stateVars.tween:update ( 1 )
      self:setActualPos           ( self.stateVars.pos.x, self.stateVars.pos.y )
    end
  end

  self.timer = self.timer + 1
  if self.timer > 60 then
    if self.pickedProjection then

      local px, py, mx, my = self:getLocations()
      if self.state.isSimpleVersion then
        self:gotoState ( "PICKING", px, py, mx, my, self.pickedProjection )
      else
        self:gotoState ( "PROJECTION", px, py, mx, my, self.pickedProjection )
      end
    else
      self.forceProjection = true
      self.forcePicking    = true
      self:pickAction ( )
    end
  end
end

_RECOVERING.takeDamage = protectedTakeDamage

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Prefight intro -----------------------------]]--
--[[----------------------------------------------------------------------------]]--
local _PREFIGHT = _CRYSTAL:addState ( "PREFIGHT_INTRO" )

function _PREFIGHT:enteredState ( )
  self:setActualPos ( self:getX()-2, self:getY())
  self.sprite:change ( 1, nil )
  self.timer = 20
  self.stateVars.beams = 0
end

function _PREFIGHT:exitedState ( )

end

function _PREFIGHT:tick ( )

end

function _CRYSTAL:_runAnimation ( )
  

  self:gotoState ( "CUTSCENE" )

  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §draw                ------------------------]]--
--[[----------------------------------------------------------------------------]]--

function _CRYSTAL:customEnemyDraw ( x, oy, scaleX )

  local y = oy + math.sin ( self.floatY ) * (3 + self.extraFloat)
  self.sprite:drawInstant ( 4, x, y )
  self.sprite:drawInstant ( 5, x, y )
  self.sprite:drawInstant ( 1, x, y+self.lidPosition.top    -self.lidPosition.shake + self.lidPosition.summonTop  )
  self.sprite:drawInstant ( 2, x, y+self.lidPosition.bottom +self.lidPosition.shake + self.lidPosition.summonBot  )
  self.sprite:drawInstant ( 3, x, y+self.lidPosition.top    -self.lidPosition.shake + self.lidPosition.summonTop  )
  self.sprite:drawInstant ( 3, x, y+self.lidPosition.bottom +self.lidPosition.shake + self.lidPosition.summonBot + 130, nil, -1 )
  self.sprite:drawInstant ( 7, x, y )
  self.sprite:drawInstant ( 6, x, y )

  --self.sprite:drawInstant ( "spawn_ball", x+self.spawnBallX+self.spawnBallOX, oy+self.spawnBallY+self.spawnBallOY )
end

function _CRYSTAL:drawSpecial ( )
  if self.cursorX then
    local l = self.activeLayer()-25
    self.sprite:draw ( 
      "cursor",
      self.cursorX-self.cursorBounce*3,
      self.cursorY-self.cursorBounce*3,
      l,
      false
    ) 
    self.sprite:draw ( 
      "cursor",
      self.cursorX+70+self.cursorBounce*3,
      self.cursorY-self.cursorBounce*3,
      l,
      false,
      -1
    ) 
    self.sprite:draw ( 
      "cursor",
      self.cursorX-self.cursorBounce*3,
      self.cursorY+58+self.cursorBounce*3,
      l,
      false,
      1,
      -1
    ) 
    self.sprite:draw ( 
      "cursor",
      self.cursorX+70+self.cursorBounce*3,
      self.cursorY+58+self.cursorBounce*3,
      l,
      false,
      -1,
      -1
    ) 
  end

  local x,y = self:getPos         ( )
  local l   = self.spawnBallLayer ( )

  if self.stateVars and self.stateVars.alpha and self.stateVars.alpha > 0 then
    local cx, cy = Camera:getPos()
    GFX:push ( self.screenEffectLayer ( ), _drawThing, cx-10, cy-10, GAME_WIDTH+20, GAME_HEIGHT+20, self.stateVars.alpha )
  end

  self.sprite:draw ( "spawn_ball", x+self.spawnBallX+self.spawnBallOX, y+self.spawnBallY+self.spawnBallOY, l, false )

  if not self.drawKernel then return end
  local l   = self.kernelLayer() + 10
  self.sprite:draw        ( "kernel", x+self.kernelX, y+self.kernelY, l )
end 

_CRYSTAL.isWithinView = function ( self )
  return true
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Return -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

return _CRYSTAL