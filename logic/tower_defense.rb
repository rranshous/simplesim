require_relative 'lib/board'
require_relative 'lib/game'
require_relative 'lib/client'

class Base < Body
  def init_attrs
    self.width = 20
    self.height = 20
    self.static = true
    self.location = Location.new(x: 0, y: 0)
  end
end

class PlayerBase < Base
  def init_attrs
    super
    self.color = 'blue'
  end
end

class EnemyBase < Base
  def init_attrs
    super
    self.color = 'red'
  end
end

class Tower < Body
  def init_attrs
    self.color = 'green'
    self.width = 10
    self.height = 10
    self.static = true
  end
end

class TowerGun
  attr_accessor :board, :tower, :bullet_class

  def fire_at_nearest_enemy enemies: nil
    enemy = nearest_enemy enemies: enemies
    return false unless enemy
    bullet = bullet_class.new
    bullet.location = tower.absolute_up distance: tower.height
    bullet.velocity = tower.vector_to(enemy.location) * bullet_class.speed
    board.add_body body: bullet, type: :bullet
  end

  def nearest_enemy enemies: nil
    enemies.near tower
  end
end

class Bullet < Body
  include Mover

  attr_accessor :friction

  def init_attrs
    self.width = 2
    self.height = 2
    self.density = 0.8
    self.friction = 0.001
    self.color = 'orange'
  end

  def self.speed
    4
  end
end

class TowerGame < Game
end

class TowerBoard < Board
  attr_accessor :player_base, :enemy_base, :player_tower

  def init_player_tower
    location = self.player_base.absolute_up(distance: 60) +
               self.player_base.absolute_left(distance: 60)
    self.player_tower = Tower.new
    self.player_tower.location = location
    add_body body: self.player_tower, type: :player_tower
  end
end

class Attacker < Body
  include Mover

  def init_attrs
    self.color = 'yellow'
    self.width = 10
    self.height = 10
    self.max_speed = 10
    self.acceleration = 3
  end
end

class Enemy < Attacker
end

class AttackerSpawner
  attr_accessor :board, :spawn_from, :attacker_class, :collection

  def spawn_attacker
    attacker = attacker_class.new
    attacker.location = random_nearby
    board.add_body body: attacker, type: :enemy_attacker
  end

  private

  def random_nearby
    min_distance = [spawn_from.width, spawn_from.height].max
    nearby = spawn_from.location
    while nearby.distance_to(spawn_from) < min_distance
      nearby = Location.new(
        x: nearby.x + rand(-1..1),
        y: nearby.y + rand(-1..1)
      )
    end
    return nearby
  end
end

class AttackerMover
  attr_accessor :body_mover, :collection

  def move_toward_target target: nil
    collection.each do |attacker|
      #body_mover.turn_toward body: attacker, target: target
      body_mover.go_toward body: attacker, target: target
    end
  end
end


class BulletReaper
  attr_accessor :body_remover, :bullets, :collisions

  def reap_stopped
    stalled = Vector.new(x: 0.01, y: 0.01)
    bullets.each do |bullet|
      if bullet.velocity < stalled
        body_remover.remove_body body: bullet
      end
    end
  end

  def reap_collided
    collisions.each do |bullet|
      body_remover.remove_body body: bullet
    end
  end
end

class AttackerShotHandler

  attr_accessor :body_remover, :collisions

  def reap_hit
    collisions.each do |attacker|
      body_remover.remove_body body: attacker
    end
  end
end

class CollisionGroup
  attr_accessor :board, :primary, :secondary

  def each
    board.collisions.each do |body1, body2|
      if primary.include?(body1) && secondary.include?(body2)
        yield body1
      elsif primary.include?(body2) && secondary.include?(body1)
        yield body2
      end
    end
  end
end

class BodyRemover
  attr_accessor :board, :to_remove

  def initialize
    self.to_remove = {}
  end

  def remove_body body: nil
    to_remove[body.uuid] = body
  end

  def do_removals
    to_remove.each do |_, body|
      board.remove_body body: body
    end
    to_remove.clear
  end

end

body_collections = BodyCollectionLookup.new

game = TowerGame.new
game.bodies = body_collections

board = TowerBoard.new
board.game = game
board.bodies = body_collections

board.player_base = PlayerBase.new
board.add_body body: board.player_base, type: :player_base

board.enemy_base = EnemyBase.new
board.enemy_base.location = Location.new(x: 400, y: 250)
board.add_body body: board.enemy_base, type: :enemy_base

location = board.player_base.absolute_up(distance: 60) +
board.player_base.absolute_left(distance: 60)
board.player_tower = Tower.new
board.player_tower.location = location
board.add_body body: board.player_tower, type: :player_tower

wall = HorizontalWall.new
wall.location = Location.new(x: 1000, y: 200)
board.add_body body: wall, type: :wall

body_remover = BodyRemover.new
body_remover.board = board

body_mover = BodyMover.new
body_mover.board = board

enemy_attackers = body_collections.collection type: :enemy_attacker
bullets = body_collections.collection type: :bullet

enemy_spawner = AttackerSpawner.new
enemy_spawner.board = board
enemy_spawner.spawn_from = board.enemy_base
enemy_spawner.attacker_class = Enemy
enemy_spawner.collection = enemy_attackers

enemy_mover = AttackerMover.new
enemy_mover.body_mover = body_mover
enemy_mover.collection = enemy_attackers

tower_gun = TowerGun.new
tower_gun.board = board
tower_gun.tower = board.player_tower
tower_gun.bullet_class = Bullet

bullet_collisions = CollisionGroup.new
bullet_collisions.board = board
bullet_collisions.primary = bullets
bullet_collisions.secondary = enemy_attackers

attacker_collisions = CollisionGroup.new
attacker_collisions.board = board
attacker_collisions.primary = enemy_attackers
attacker_collisions.secondary = bullets

bullet_reaper = BulletReaper.new
bullet_reaper.bullets = bullets
bullet_reaper.body_remover = body_remover
bullet_reaper.collisions = bullet_collisions

attacker_shot_handler = AttackerShotHandler.new
attacker_shot_handler.body_remover = body_remover
attacker_shot_handler.collisions = attacker_collisions

game.run do |tick|
  if tick % 1 == 0
    enemy_spawner.spawn_attacker
  end
  if tick % 20 == 0
    tower_gun.fire_at_nearest_enemy enemies: enemy_attackers
  end
  if tick % 100 == 0 
    enemy_mover.move_toward_target target: board.player_base
  end
  attacker_shot_handler.reap_hit
  bullet_reaper.reap_stopped
  bullet_reaper.reap_collided
  body_remover.do_removals
end
