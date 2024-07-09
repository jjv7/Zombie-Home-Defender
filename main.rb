require 'gosu'

WINDOW_WIDTH = 798
WINDOW_HEIGHT = 798
NUM_LANES = 7
LANE_WIDTH = 114          # WINDOW_WIDTH / NUM_LANES

module ZOrder
  BACKGROUND, ZOMBIE, PLAYER, UI = *0..3
end

module Game_state
  MAINMENU, GAME, DEAD, SHOP = *0..3
end

# Structs for the player, bullets, zombies, barricades and shop items. They act similar to classes with an initialize method.
Game = Struct.new(:gamestate, :score, :hiscore, :multiplier, :livesbought, :zombie_speed_increase, :zombie_health_increase, :break_speed_increase)
Player = Struct.new(:x, :y, :image, :lives, :coins, :barricades)
Bullet = Struct.new(:x, :y, :image)
Zombie = Struct.new(:x, :y, :speed, :health, :break_speed, :image, :coins_given, :score_given)
Barricade = Struct.new(:x, :y, :health)
ShopItem = Struct.new(:name, :cost)

class GameWindow < Gosu::Window
  def initialize
    super(WINDOW_WIDTH, WINDOW_HEIGHT)
    self.caption = 'Zombie Home Defender'

    @game = Game.new(Game_state::MAINMENU, 0, load_hiscore, 1, 0, 1, 1, 1)
    @player = Player.new(399, 650, Gosu::Image.new('sprites/pistol.png'), 5, 0, 3)

    # Creates arrays to store instances of the bullets, zombies and barricades during gameplay
    @bullets = []
    @zombies = []
    @barricades = []

    # Creates an array for shop items and fills the array with shop items
    @shop_items = []
    load_shop_items
  end

  def update
    if @game.gamestate == Game_state::GAME
      update_bullets
      spawn_zombies_random                                                              # Spawns in new zombies
      update_zombies                                                                    # Moves all zombies down, also checks for collision with a barricade
      check_collisions
      @game.hiscore = @game.score if @game.score > @game.hiscore
    end
  end

  def draw
    case @game.gamestate
    when Game_state::MAINMENU
      draw_mainmenu
    when Game_state::GAME
      draw_background
      draw_entities      
      draw_UI
    when Game_state::DEAD
      draw_game_over_screen
    when Game_state::SHOP
      # The player should still see the amount of things such as coins they have to purchase the items, so the game background and UI still needs to be drawn here
      draw_background
      draw_UI
      draw_shop_menu
    end
  end

  def button_down(id)
    close if id == Gosu::KbEscape                                                       # Closes the program if the escape key is pressed in any of the game's states
  
    case @game.gamestate
    when Game_state::MAINMENU
      @game.gamestate = Game_state::GAME if id == Gosu::KbEnter || id == Gosu::KbReturn # Pressing enter starts the game. On some keyboards, this is apparently the return key.
    when Game_state::GAME
      handle_game_input(id)
    when Game_state::SHOP
      handle_shop_input(id)
      @game.gamestate = Game_state::GAME if id == Gosu::KbX
    end
  end
end

private

# Loads in the hiscore from its file
def load_hiscore
  if File.exist?("hiscore.txt")
    return File.read("hiscore.txt").to_i
  end
  return 0
end

# Loads in the shop_items into the @shop_items array
def load_shop_items
  @shop_items << ShopItem.new("1. Barricade", 10)                                         # Relatively cheap as zombies can easily break through it after some time
  @shop_items << ShopItem.new("2. Extra life", 100)                                       # Slightly more expensive as it lets you play for much longer
  @shop_items << ShopItem.new("3. Score multiplier increase", 500)                        # Most expensive item as it increases the amount of score you get with no downsides
  @shop_items << ShopItem.new("4. Zombie speed increase (x2 score)", 50)                  # Increases zombie speed in exchange for x2 score
  @shop_items << ShopItem.new("5. Zombie health increase (x2 score)", 50)                 # Increases zombie health in exchange for x2 score
  @shop_items << ShopItem.new("6. Zombie barricade break speed increase (x2 score)", 50)  # Increases the speed at which zombies can break through barricades in exchange for x2 score
end

def handle_game_input(id)
  case id
  when Gosu::KbLeft
    @player.x -= LANE_WIDTH if @player.x > LANE_WIDTH
  when Gosu::KbRight
    @player.x += LANE_WIDTH if @player.x < WINDOW_WIDTH - LANE_WIDTH
  when Gosu::KbSpace
    @bullets << Bullet.new(@player.x, @player.y, Gosu::Image.new('sprites/bullet.png'))
  when Gosu::KbB
    # Checks if the player has a barricade and if the barricade placement limit of 5 has not been reached and there is no barricade in the current lane
    if @player.barricades > 0 && @barricades.size < 5 && @barricades.none? { |barricade| barricade.x == @player.x }
      @barricades << Barricade.new(@player.x, 399, 200)
      @player.barricades -= 1
    end
  when Gosu::KbZ                                                                          # Originally used KbS for this which caused the shop to sometimes open and close quickly since the same key was used to exit the shop
    @game.gamestate = Game_state::SHOP
  end
end

# Handles the number keys pressed on the keyboard in exchange for shop items
def handle_shop_input(id)
  case id
  when Gosu::Kb1
    buy_item(0) if @player.coins >= @shop_items[0].cost
  when Gosu::Kb2
    buy_item(1) if @player.coins >= @shop_items[1].cost && @player.lives > 0 && @game.livesbought < 2
  when Gosu::Kb3
    buy_item(2) if @player.coins >= @shop_items[2].cost
  when Gosu::Kb4
    buy_item(3) if @player.coins >= @shop_items[3].cost && @game.zombie_speed_increase == 1
  when Gosu::Kb5
    buy_item(4) if @player.coins >= @shop_items[4].cost && @game.zombie_health_increase == 1
  when Gosu::Kb6
    buy_item(5) if @player.coins >= @shop_items[5].cost && @game.break_speed_increase == 1
  end
end

def buy_item(id)
  @player.coins -= @shop_items[id].cost
  case id
  when 0
    @player.barricades += 1
  when 1
    @player.lives += 1
    @game.livesbought += 1                                                                # increases progress towards threshold by 1. This separate counter is needed or else the program can't tell if the threshold has been reached
    @shop_items[1].name = "MAX BOUGHT" if @game.livesbought >= 2
  when 2
    @game.multiplier *= 2
  when 3
    @game.zombie_speed_increase += 0.5
    @game.multiplier *= 2
    @shop_items[3].name = "MAX BOUGHT"
  when 4
    @game.zombie_health_increase += 0.5
    @game.multiplier *= 2
    @shop_items[4].name = "MAX BOUGHT"
  when 5
    @game.break_speed_increase += 1
    @game.multiplier *= 2
    @shop_items[5].name = "MAX BOUGHT"
  end
end

def update_bullets
  @bullets.each do |bullet|
    bullet.y -= 30
    @bullets.delete(bullet) if bullet.y < 0
  end
end

def spawn_zombies_random
  # This sets the zombie spawn limits randomly based on the current score
  spawn_limit = case @game.score
                when 0...500 then 5
                when 500... 5000 then 10
                else 20
                end

  # Spawns a random zombie in a delayed time interval if the current zombies in the array is less than the limit
  if @zombies.size < spawn_limit && rand(50) < 2
    lane = rand(NUM_LANES)
    # Spawns either a normal, speedy or tanky zombie based on a random number from 0 to 99. Allows for percentage based spawning to occur.
    case rand(100)
    when 0..88                                                                            # 88% chance to spawn normal zombie
      spawn_zombie(lane, 2, 5, 1, 1, 10, 'normal.png')
    when 89..98                                                                           # 10% chance to spawn speedy zombie
      spawn_zombie(lane, 4, 2, 0, 5, 20, 'speedy.png')
    when 99                                                                               # 1% chance to spawn tanky zombie
      spawn_zombie(lane, 1, 15, 10, 10, 50, 'tanky.png')
    end
  end
end

def spawn_zombie(lane, speed, health, break_speed, coins_given, score_given, image_file)
  health *= @game.zombie_health_increase
  @zombies << Zombie.new((lane + 0.5) * LANE_WIDTH, 0, speed, health, break_speed, Gosu::Image.new("sprites/#{image_file}"), coins_given, score_given)
end

def update_zombies
  @zombies.each do |zombie|
    zombie.y += zombie.speed * @game.zombie_speed_increase
    handle_offscreen_zombies(zombie)
    check_zombie_barricade_collision(zombie)
  end
end

def handle_offscreen_zombies(zombie)
  if zombie.y > WINDOW_HEIGHT
    @zombies.delete(zombie)
    @player.lives -= 1

    # Changes the gamestate to DEAD if the player has no more lives
    if @player.lives <= 0
      File.write("hiscore.txt", @game.hiscore)
      @game.gamestate = Game_state::DEAD
    end
  end
end

def check_zombie_barricade_collision(zombie)
  @barricades.each do |barricade|
    next unless barricade.x == zombie.x && (barricade.y - zombie.y).abs < 20            # Checks if the x and y coordinates of the objects are within 20 pixels of each other
    
    if zombie.break_speed > 0 && barricade.health > 0                                   # The zombie break speed is checked here to see if the zombie is a speedy type, as speedy types just climb over the barricade
      barricade.health -= zombie.break_speed * @game.break_speed_increase
      if barricade.health > 0
        zombie.y -= zombie.speed * @game.zombie_speed_increase + 0.1                    # Stops the zombie at the barricade if it exists and provides a bit of visual feedback for the zombie breaking the barricade
      else
        @barricades.delete(barricade)
      end
    end
  end
end

def check_collisions
  check_zombie_player_collision
  check_bullet_zombie_collision
end

# Collision logic between zombies and the player, since it would look awkward for the player to just move through the zombie
def check_zombie_player_collision
  @zombies.each do |zombie|
    next unless @player.x == zombie.x && (@player.y - zombie.y).abs < 25                # Checks if the zombie's coordinates are within 25 pixels of the player's coordinates
      
    @zombies.delete(zombie)
    @player.lives -= 1

    if @player.lives <= 0
      File.write("hiscore.txt", @game.hiscore)
      @game.gamestate = Game_state::DEAD
    end
  end
end

# Collision logic between the bullets and zombies
def check_bullet_zombie_collision
  @bullets.each do |bullet|
    @zombies.each do |zombie|
      next unless bullet.x == zombie.x && (bullet.y - zombie.y).abs < 25               # Checks if the bullet's coordinates and within 20 pixels of the zombie's coordinates
      
      zombie.health -= 1
      if zombie.health <= 0
        @game.score += zombie.score_given * @game.multiplier
        @player.coins += zombie.coins_given * @game.multiplier
        @zombies.delete(zombie)
      end
      @bullets.delete(bullet)
    end
  end
end

def draw_background
  draw_rect(0, 0, 798, 700, Gosu::Color::GREEN, ZOrder::BACKGROUND)                   # Draws a green rectangle for the 7 lanes
  draw_rect(0, 700, 798, 100, Gosu::Color::RED, ZOrder::PLAYER)                       # Draws the roof as a red rectangle. Z value is set to player, so zombies go under it. Separate space to put in UI elements.
  draw_rect(0, 700, 798, 3, Gosu::Color::BLACK, ZOrder::UI)                           # Draws a line for the roof to act as a border for the roof
end

def draw_entities
  @player.image.draw(@player.x - 18, @player.y - 25.5, ZOrder::PLAYER)
  @bullets.each { |bullet| bullet.image.draw(bullet.x - 1.5, bullet.y - 12, ZOrder::ZOMBIE) }
  @zombies.each { |zombie| zombie.image.draw(zombie.x - 21, zombie.y - 19.5, ZOrder::ZOMBIE) }
  @barricades.each { |barricade| draw_rect(barricade.x - 57, barricade.y, LANE_WIDTH, 10, Gosu::Color::rgb(102, 51, 0), ZOrder::BACKGROUND) }
end

# Displays all the UI elements on the "roof" during gameplay
def draw_UI
  font = Gosu::Font.new(20)
  font.draw_text("Score (x#{@game.multiplier}): #{@game.score}", 10, 725, ZOrder::UI)
  font.draw_text("Lives: #{@player.lives}", 700, 725, ZOrder::UI)
  font.draw_text("Coins: #{@player.coins}", 700, 750, ZOrder::UI)
  font.draw_text("Hi-score: #{@game.hiscore}", 10, 750, ZOrder::UI)
  font.draw_text("Barricades: #{@player.barricades}", 500, 740, ZOrder::UI)
end

# Draws the main menu
def draw_mainmenu
  draw_rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, Gosu::Color::BLACK, ZOrder::UI)        # Makes a black background for a simple main menu

  Gosu::Font.new(50).draw_text("Zombie Home Defender", 162.5, 374, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  Gosu::Font.new(30).draw_text("Press ENTER to start", 271, 444, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
end

#Draws the death screen
def draw_game_over_screen
  draw_rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, Gosu::Color::BLACK, ZOrder::UI)        # Makes a black background for a simple death screen

  Gosu::Font.new(50).draw_text("YOU DIED!", 286.5, 374, ZOrder::UI, 1, 1, Gosu::Color::RED)  
  Gosu::Font.new(30).draw_text("Score: #{@game.score}", 341.25, 444, ZOrder::UI, 1, 1, Gosu::Color::RED)
  Gosu::Font.new(30).draw_text("Hi-score: #{@game.hiscore}", 326.25, 484, ZOrder::UI, 1, 1, Gosu::Color::RED)
end

# Draws the shop menu
def draw_shop_menu
  draw_rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT - 98, Gosu::Color::BLACK, ZOrder::UI)

  Gosu::Font.new(50).draw_text("Shop Menu", 286.25, 50, ZOrder::UI, 1, 1, Gosu::Color::WHITE)

  item_y = 150
  @shop_items.each do |item|
    Gosu::Font.new(25).draw_text("#{item.name} (#{item.cost} coins)", 82.5, item_y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    item_y += 50
  end

  Gosu::Font.new(20).draw_text("Press 'X' to exit the shop", 299.5, 673, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
end

window = GameWindow.new
window.show