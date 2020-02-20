require_relative 'lib/board'
require_relative 'lib/game'

class Base < Body
  def init_attrs
    self.width = 30
    self.height = 30
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
    self.width = 20
    self.height = 15
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

class Bullet < Body
  include Mover

  attr_accessor :friction

  def init_attrs
    self.width = 1
    self.height = 1
    self.density = 0.8
    self.friction = 0.001
    self.color = 'orange'
  end

  def self.speed
    3
  end
end

class TowerBoard < Board
  attr_accessor :player_base, :enemy_base, :player_tower

  def populate_initial
    init_player_base
    init_enemy_base
    init_player_tower
  end

  def init_player_base
    self.player_base = PlayerBase.new
    add_body body: self.player_base
  end

  def init_enemy_base
    self.enemy_base = EnemyBase.new
    self.enemy_base.location = Location.new(x: 150, y: 320)
    add_body body: self.enemy_base
  end

  def init_player_tower
    self.player_tower = Tower.new
    self.player_tower.location = self.enemy_base.below(distance: 100)
    add_body body: self.player_tower
  end
end

class Attacker < Body
  include Mover

  def init_attrs
    self.color = 'yellow'
    self.width = 5
    self.height = 4
    self.max_speed = 0.2
    self.acceleration = 0.03
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
      body_mover.turn_toward body: attacker, target: target
      body_mover.go_toward body: attacker, target: target
    end
  end
end

class TowerGun
  attr_accessor :board, :tower, :bullet_class

  def fire_at_nearest_enemy enemies: nil
    enemy = nearest_enemy enemies: enemies
    return false unless enemy
    bullet = bullet_class.new
    bullet.location = tower.above distance: tower.height
    bullet.velocity = tower.vector_to(enemy.location) * bullet_class.speed
    board.add_body body: bullet, type: :bullet
  end

  def nearest_enemy enemies: nil
    enemies.near tower
  end
end

body_collections = BodyCollectionLookup.new

game = Game.new
game.bodies = body_collections

board = TowerBoard.new
board.game = game
board.bodies = body_collections
board.populate_initial

body_mover = BodyMover.new
body_mover.board = board

enemy_attackers = body_collections.collection type: :enemy_attacker

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

game.run do |tick|
  if tick % 1000 == 0
    enemy_spawner.spawn_attacker
  end
  if tick % 100 == 0
    tower_gun.fire_at_nearest_enemy enemies: enemy_attackers
  end
  enemy_mover.move_toward_target target: board.player_base
end
