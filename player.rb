require 'entity'
require 'gosu'
require 'zorder'

# The base Player class representing what all Players have in common
# Moves can be enqueued by calling add_move
# Calling update() causes a move to be dequeued and executed, applying forces
# to the game object
#
# The server instantiates this class to represent each connected player
# The connection (conn) is the received one for that player
class Player < Entity
  include Comparable
  attr_reader :conn, :player_name
  attr_accessor :score

  def initialize(space, conn, player_name)
    super(space, 0, 0)
    @conn = conn
    @player_name = player_name
    @score = 0
    @moves = []
    @current_move = nil
    @falling = false
  end

  def sleep_now?; false; end

  def update
    underfoot = next_to(self.a + 180)
    if @falling = underfoot.empty?
      self.a = 0
      accelerate(0, 1)
    else
      if current_move = @moves.shift
        if current_move.is_a? Hash # Currently for 'ping' only
          @conn.send_record :pong => current_move
        elsif [:slide_left, :slide_right, :flip].include? current_move
          send current_move
        else
          puts "Invalid move for #{self}: #{current_move}"
        end
      end
    end

    # Only go around corner if sitting on exactly one object
    if underfoot.size == 1
      other = underfoot.first
      # Figure out where corner is and whether we're about to reach or pass it
      corner, distance, overshoot, turn = going_past_entity(other.x, other.y)
      if corner
        original_speed = @x_vel.abs + @y_vel.abs
        original_dir = vector_to_angle
        new_dir = original_dir + turn

        # Make sure nothing occupies any space we're about to move through
        if (
          (@space.entities_overlapping(*corner) + next_to(new_dir, *corner))
          .delete self
        ).empty?
          # Move to the corner
          @x_vel, @y_vel = angle_to_vector(original_dir, distance)
          move

          # Turn and apply remaining velocity
          # Make sure we move at least one subpixel so we don't sit exactly at
          # the corner, and fall
          self.a += turn
          overshoot = 1 if overshoot.zero?
          @x_vel, @y_vel = angle_to_vector(new_dir, overshoot)
          move

          @x_vel, @y_vel = angle_to_vector(new_dir, original_speed)
        else
          # Something's in the way -- possibly in front of us, or possibly
          # around the corner
          move
        end
      else
        # Not yet reaching the corner -- or making a diagonal motion, for which
        # we can't support going around the corner
        move
      end
    else
      # Straddling two objects, or falling
      move
    end
  end

  def slide_left; slide(self.a - 90); end
  def slide_right; slide(self.a + 90); end

  def slide(dir)
    if next_to(dir).empty?
      accelerate(*angle_to_vector(dir))
    else
      self.a = dir + 180
    end
  end

  def flip
    self.a += 180
  end

  def add_move(new_move)
    @moves << new_move if new_move
  end

  def <=>(other)
    self.player_name <=> other.player_name
  end

  def to_s
    "#{player_name} (#{registry_id}) at #{x}x#{y}"
  end

  def as_json
    super().merge(
      :class => 'Player',
      :player_name => player_name,
      :score => score
    )
  end

  def update_from_json(json)
    @player_name = json['player_name']
    @score = json['score']
    super
  end

  def image_filename; "media/gize0-up.gif"; end

  def draw(window)
    super
    window.font.draw_rel(player_name,
      pixel_x + CELL_WIDTH_IN_PIXELS / 2, pixel_y, ZOrder::Text,
      0.5, 1.0, # Centered X; above Y
      1.0, 1.0, Gosu::Color::YELLOW)
  end

  def handle_input(window, pressed_buttons)
    return if @falling
    move = move_for_keypress(window, pressed_buttons)
    @conn.send_move move
    add_move move
  end

  # Check keyboard, return a motion symbol or nil
  def move_for_keypress(window, pressed_buttons)
    # Generated once for each keypress
    until pressed_buttons.empty?
      button = pressed_buttons.shift
      case button
        when Gosu::KbUp then return :flip
        when Gosu::KbP then @conn.send_ping; return nil
        when Gosu::KbLeft, Gosu::KbRight # nothing
        else puts "Ignoring key #{button}"
      end
    end

    # Continuously-generated when key held down
    case
      when window.button_down?(Gosu::KbLeft) then :slide_left
      when window.button_down?(Gosu::KbRight) then :slide_right
    end
  end
end
