﻿#==============================================================================
# 
# ▼ dodger451 rpgmaker - Threat System v0.1
# 
#==============================================================================

$imported = {} if $imported.nil?
$imported["dodger451-ThreatSystem"] = false

#==============================================================================
# ▼ Introduction
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# This is a script to improve the AI of Enemies for RPG Maker VX Ace. During a 
# battle, the script lets enemies choose targets based on the accumulated 
# "threat" they feel for each opponent (multiplied by his tgr). This script 
# will maintain a threat table for each enemy, threat rises when an party member
# hurts an enemy or when he heals another member.
# 
#==============================================================================
# ▼ Instructions
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# To install this script, open up your script editor and copy/paste this script
# to an open slot below ▼ Materials/素材 but above ▼ Main. Remember to save.
# 
# Adjust the module's settings to adjust the behaviour.
# 
#==============================================================================
# ▼ Compatibility
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# This script is made strictly for RPG Maker VX Ace. It is highly unlikely that
# it will run with RPG Maker VX without adjusting.
# 
#==============================================================================

module DODGER451
  module THREAT
    
    #=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    # - General Threat Settings -
    #=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    # In this section, you can adjust the threat settings for your game
    # such as the modifiers and constants for threat manipulation
    #=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    DEBUG_ON     = true   

  end # THREAT
end # DODGER451


class Game_Threat

  def dbg(str)
    if(DODGER451::THREAT::DEBUG_ON)
      p str
    end
  end

  #global list
  def threat_tables_initialized?;
    return $threat_tables != nil;
  end

  def init_threat_tables;
    $threat_tables = {};
    return self;
  end

  #battler threat list
  def threat_table_initialized?(battler_name);
    return threat_tables_initialized? && $threat_tables[battler_name] != nil;
  end

  def init_threat_table(battler_name);
    init_threat_tables unless threat_tables_initialized?;
    $threat_tables[battler_name] = {};
    return self;
  end

  # threat on battler
  # string, string -> bool
  def threat_initialized?(name, opponentname);
    return threat_table_initialized?(name) && $threat_tables[name][opponentname] != nil;
  end

  # string, string -> self
  def init_threat(name, opponentname);
    init_threat_table(name) unless threat_table_initialized?(name);
    $threat_tables[name][opponentname] = 0;
    return self;
  end

  # get enemy's threat on actor
  # string, string -> int
  def get_threat(name, opponentname);
    init_threat(name, opponentname) unless threat_initialized?(name, opponentname);
    return $threat_tables[name][opponentname];
  end;

  #helper

  

  #modify threat
  
  def add_threat(enemy_defender, actor_attacker, additional_threat)
    init_threat(enemy_defender.name, actor_attacker.name) unless threat_initialized?(enemy_defender.name, actor_attacker.name);      
    $threat_tables[enemy_defender.name][actor_attacker.name] +=  additional_threat;
  end

  # updates the threat an enemy (and his teammates) feel from a actor 
  # after the actor caused hp- or mp-damage.
  # Called after an actor attacked an enemy (execute_damage in Game_Battler)
  # result, battler, battler -> self
  def update_threat_on_damage(result, actor_attacker, enemy_defender)
    # todo emit also to teammates
    # todo smarter scaling, e.g. relative to hp, lg scaled,...
    additional_threat = 1 + result.hp_damage
    p actor_attacker.name + " causes " + result.hp_damage.to_s + " damage on " + enemy_defender.name+", " +enemy_defender.name+" feels more threatened (+"+additional_threat.to_s+")"
    add_threat(enemy_defender, actor_attacker, additional_threat)
    #$threat_tables[enemy_defender.name][actor_attacker.name] +=  additional_threat;
    
    return self
  end

  # result, battler, battler -> self
  def update_threat_on_heal(result, actor_healer, actor_healed)
    # todo smsrter scaling, e.g. relative to hp, lg scaled,...
    # actor_healed

    #to test
    alive_count = actor_healed.opponents_unit.alive_members.size;
    return self unless alive_count>0
 
    additional_threat = ((1 + (-result.hp_damage)).to_f/alive_count.to_f).to_i     
    dbg actor_healer.name + " heals " + result.hp_damage.to_s + " hp on " + actor_healed.name+", all his enemies feel more threatened (+"+additional_threat.to_s+" each)"
    actor_healed.opponents_unit.alive_members.each do |enemy|
      dbg " -> " + enemy.name + " feels " + additional_threat.to_s + " more threatended by  " + actor_healer.name
      add_threat(enemy, actor_healer, additional_threat)
    end

    return self
  end
  
  #--------------------------------------------------------------------------
  # * sum of threat-weighted opponent's tgr
  #--------------------------------------------------------------------------  
  def tgr_threat_sum(name, opponents_unit)
    opponents_unit.alive_members.inject(0) {|r, member| r + tgr_threat(name, member) }
  end
  
  
  #--------------------------------------------------------------------------
  # * threat weighted by actor_opponent's tgr
  #--------------------------------------------------------------------------
  def tgr_threat(name, actor_opponent)
    actor_opponent.tgr * [1, get_threat(name, actor_opponent.name)].max.to_f
  end
  
  #--------------------------------------------------------------------------
  # * Find weighted random opponent for attacker based on threat and tgr
  #--------------------------------------------------------------------------
  def random_target(attacker)
    dbg attacker.name + " finds thread-based target"
    attacker.opponents_unit.alive_members.each do |enemy|
      dbg attacker.name + " feels threaten by " + enemy.name + " (tgr="+enemy.tgr.to_s+", threat="+$game_threat.get_threat(attacker.name, enemy.name).to_s+"): " + $game_threat.tgr_threat(attacker.name, enemy).to_s
    end

    tgr_rand = rand * tgr_threat_sum(attacker.name, attacker.opponents_unit)
    attacker.opponents_unit.alive_members.each do |member|
      tgr_rand -= tgr_threat(attacker.name, member)
      #return member if tgr_rand < 0
      if tgr_rand < 0
        dbg " choose " + member.name + "(" + tgr_threat(attacker.name, member).to_s + ")"
        return member 
      end
    end
    dbg " choose as fallback " + member.name 
    attacker.opponents_unit.alive_members[0]
  end 
  #--------------------------------------------------------------------------
  # * Object Initialization creates global threat list $threat_tables if not empty
  #--------------------------------------------------------------------------
  def initialize
    init_threat_tables unless threat_tables_initialized?
  end

end # Game_Threat


class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # * Start Processing
  #--------------------------------------------------------------------------
  alias scene_battlestart_ga start
  def start
    $game_threat = Game_Threat.new()
    $game_threat.init_threat_tables
    scene_battlestart_ga
  end
end # Scene_Battle

class Game_Battler < Game_BattlerBase

  alias game_battlerexecute_damage_ga execute_damage
  def execute_damage(user)
    update_threat_on_execute_damage(user)
    game_battlerexecute_damage_ga(user)
  end

  def update_threat_on_execute_damage(user)
    # fix as suggested by gstv87 in http://forums.rpgmakerweb.com/index.php?/topic/48155-threat-based-targeting/#entry498845
    return if $game_threat.nil?
    
    if (self.is_a?(Game_Enemy) && user.is_a?(Game_Actor))
      $game_threat.update_threat_on_damage(@result, user, self)
    end
    if (self.is_a?(Game_Actor) && user.is_a?(Game_Actor) && @result.hp_damage < 0)
      $game_threat.update_threat_on_heal(@result, user, self)
    end
  end
end # Game_Battler

class Game_Action
  alias game_actiontargets_for_opponents_ga targets_for_opponents
  def targets_for_opponents
    original = game_actiontargets_for_opponents_ga
    if (!item.for_random? && item.for_one? && (@target_index < 0))
      num = 1 + (attack? ? subject.atk_times_add.to_i : 0)
      return [$game_threat.random_target(subject)] * num
    end
    return original
  end
end # Game_Action

