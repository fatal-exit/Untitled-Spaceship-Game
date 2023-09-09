def tick args
  
  #default values
  args.state.game_start_tick ||= 0
  args.state.second_count ||= 0
  args.state.fire_start_tick ||= 0
  args.state.enemy_spawn_tick ||= 0
  args.state.game_over ||= false
  args.state.score ||= 0
  args.state.previous_second_count ||= 0

  args.state.fade_out_queue ||=[]
  
  args.state.main_menu ||= true
  args.state.is_game_running ||= false
  defaults(args)
  calc_camera(args)
  
  
  #start music
  if args.state.tick_count == 1
    args.audio[:music] = { input: "sounds/BlippyBlastbeat.ogg", looping: true, gain: 0.5 }
  end
  #background color
  args.outputs.background_color = [0, 0, 0]
  
  #screen size
  screen_width = args.grid.w
  screen_height = args.grid.h
  
  #default values
  args.state.enemy_spawn_tick ||= 0
  args.state.enemy_spawn_interval ||= 150  # 2.5 seconds * 60 frames/second
  
  args.state.spike_spawn_tick ||= 0
  args.state.spike_spawn_interval ||= 300  # 5 seconds * 60 frames/second
  
  #moving sky functions
  args.state.sky_x ||= 0
  sky_x = args.state.sky_x
  sky_speed = 4
  sky_x -= sky_speed
  sky_x = reset_sky_pos(sky_x,screen_width)
  
  #4 tiles of sky
  args.state.sky = [
    { x: sky_x+args.state.camera.x_offset, y: -(screen_height/2)+args.state.camera.y_offset ||= 0, w: screen_width, h: screen_height, path: '/sprites/skybg.png' },
    { x: screen_width+sky_x+args.state.camera.x_offset, y: -(screen_height/2)+args.state.camera.y_offset ||= 0, w: screen_width, h: screen_height, path: '/sprites/skybg.png' },
    { x: sky_x+args.state.camera.x_offset, y: (screen_height/2)+args.state.camera.y_offset ||= 0, w: screen_width, h: screen_height, path: '/sprites/skybg.png' },
    { x: screen_width+sky_x+args.state.camera.x_offset, y: (screen_height/2)+args.state.camera.y_offset ||= 0, w: screen_width, h: screen_height, path: '/sprites/skybg.png' }
  ]
  
  #shortform
  sky_array = args.state.sky
  #output the sky
  args.outputs.sprites << [sky_array]
  
  # Update args.state.sky_x with the new value of sky_x
  args.state.sky_x = sky_x
  
  #input functions
  input = args.state.input = {
    x: args.inputs.left_right,
    y: args.inputs.up_down,
    fire: args.inputs.keyboard.key_held.space || args.inputs.keyboard.key_held.z || args.inputs.controller_one.key_held.r2 || args.inputs.controller_one.key_held.r1  || args.inputs.mouse.button_left || args.inputs.mouse.button_right,
    fire_pressed: args.inputs.keyboard.key_down.space || args.inputs.keyboard.key_down.z || args.inputs.controller_one.key_down.r2 || args.inputs.controller_one.key_down.r1 || args.inputs.mouse.click,
    enter: args.inputs.keyboard.key_down.enter || args.inputs.controller_one.key_down.a,
    escape: args.inputs.keyboard.key_down.escape || args.inputs.controller_one.key_down.start,
  }
  #light pink borders
  args.outputs.borders << [0, 0, screen_width, screen_height, 255, 200, 255]
  # Render the label every tick, using the stored altitude value
  args.state.fade_out_queue.each do |item|
    # default the alpha value if it isn't specified
    item.a ||= 255
    # decrement the alpha by 5 each frame
    item.a -= 5
  end
  
  # remove the item if it's completely faded out
  args.state.fade_out_queue.reject! { |item| item.a <= 0 }
  
  # render the  one off sprites in the facde out queue
  args.outputs.sprites << args.state.fade_out_queue
  
  
  if args.state.game_over == false
    #by default gameloop if game_over is false
    gameloop(args, input, screen_width, screen_height)
    #main menu if not running
    if args.state.is_game_running == false
      mainmenu(args,input,screen_width,screen_height)
    end
  end
  #when game_over is true, go to gameover
  if args.state.game_over == true
    gameover(args, input, screen_width, screen_height, args.state.second_count_fixed)
  end
end
#screenshake
def screen_shake(args)
  args.state.camera.trauma += 0.5
end
#reset the sky if it goes so far off screen to make it seamlessly loop
def reset_sky_pos(x,width)
  if x < (-1 * width)
    x = 0
  end
  return x
end

def animate_explosions(args)
  if args.state.fade_out_queue.any?
    # Update the frame and path of each explosion every 4 frames
    args.state.fade_out_queue.each do |explosion|
      # Calculate the current frame based on the start_frame
      current_frame = Integer((args.state.tick_count - explosion[:start_frame]) / explosion[:hold_for])
      if current_frame != explosion[:frame]
        explosion[:frame] = current_frame
        base_name = explosion[:base_name]
        explosion[:path] = "/sprites/#{base_name}_00#{explosion[:frame]}.png"
        puts(explosion[:path])
      end
      # Remove the explosion once it has finished animating
      if explosion[:frame] >= 6
        explosion[:remove] = true
      end
    end
  end
  # Remove finished explosions
  args.state.fade_out_queue.reject! { |explosion| explosion[:remove] }
end


def gameloop (args,input,screen_width,screen_height)
  #disable main menu
  if args.state.is_game_running == true
    args.state.main_menu = false
    #count seconds
    if args.state.tick_count > args.state.game_start_tick + args.state.second_count * 60
      args.state.second_count += 1
    end
    
    #add score every time the second is one above the previous value
    args.state.previous_second_count ||= args.state.second_count_fixed
    if args.state.second_count_fixed > args.state.previous_second_count
      args.state.score += 250
      args.state.previous_second_count = args.state.second_count_fixed
    end
    
    #set player
    player = args.state.player
    
    
    
    
    
    #init arrays once
    args.state.lasers ||= []
    args.state.enemies ||= [] 
    args.state.spikes ||= [] 
    

    animate_explosions(args)
    
    #set some values including the fixed second count (so it doesn't immmediately start at one second)
    player.start_time ||= 0
    args.state.altitude ||= ((player.y+150).round).to_s
    args.state.second_count_fixed = args.state.second_count-1
    #set shorform names
    lasers = args.state.lasers
    enemies = args.state.enemies
    spikes = args.state.spikes
    
    #in game labels
    args.outputs.labels << {
      x: 55,
      y: 50,
      text: "Y=" + args.state.altitude + "m.",
      size_enum: 4,
      alignment_enum: 0,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
      
    }
    
    args.outputs.labels << {
      x: 55,
      y: 720-25,
      text: "Survived " + (args.state.second_count_fixed).to_s + " seconds.",
      size_enum: 4,
      alignment_enum: 0,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
      
    }
    
    args.outputs.labels << {
      x: 55,
      y: 720-50,
      text: "Score: #{args.state.score}",
      size_enum: 4,
      alignment_enum: 0,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
      
    }
    
    args.outputs.sprites << [player, lasers,enemies, spikes]
    #if fire is pressed once make sure the laser is instantly fired, if it is held, fire on interval
    if input.fire_pressed
      args.state.fire_start_tick = args.state.tick_count
      fire_laser(args, player)
    elsif input.fire && args.state.tick_count >= args.state.fire_start_tick + 10 # 6 times a second
      args.state.fire_start_tick = args.state.tick_count
      fire_laser(args, player)
    end
    
    #set laser speed to be 5 faster than player
    lasers.each do |laser|
      laser.x += laser.flip_horizontally ? -player.speed - 5 : player.speed + 5
    end
    
    #if the lasers go offscreen, destroy
    lasers.reject! do |laser|
      if laser.x < -100 || laser.x > screen_width + 100
        puts"(laser destroyed)"
        true
      else
        false
      end
    end
    
    enemies.each do |enemy|
      # Move the enemy at its speed
      enemy[:x] += enemy[:speed]+ args.state.camera.x_offset
      # Sine based motion for up and down movement
      enemy[:y] += 5 * Math.sin((args.state.tick_count - enemy[:start_time]) * 0.1) + args.state.camera.y_offset
      
      # Rotate the enemy
      enemy[:angle] = 15 * Math.sin((args.state.tick_count - enemy[:start_time]) * 0.1)
    end
    
    enemies.reject! do |enemy|
      # If the enemy is off-screen, remove it
      enemy[:x] < -250 || enemy[:x] > screen_width + 250
    end
    
    args.state.spikes.each do |spike|
      # Move the spike at its speed
      spike[:x] += spike[:speed] + args.state.camera.x_offset
    end
    
    args.state.spikes.reject! do |spike|
      # If the spike is off-screen, remove it
      spike[:x] < -250 || spike[:x] > screen_width + 250
    end
    
    # Sine based motion for up and down movement
    player.y = player.y + 2 * Math.sin((args.state.tick_count - player.start_time) * 0.1)
    
    # Tilt the ship forwards and backwards
    player.rotation_angle = 10 * Math.sin((args.state.tick_count - player.start_time) * 0.1)
    
    #XY inputs
    dx = input.x
    dy = input.y
    
    
    # Normalize the direction vector
    magnitude = Math.sqrt(dx * dx + dy * dy)
    if magnitude > 0
      dx /= magnitude
      dy /= magnitude
    end
    
    # Apply the speed
    dx *= player.speed
    dy *= player.speed
    
    #player speed calc+ screenshake
    player.x += dx
    player.y += dy
    player.x += args.state.camera.x_offset
    player.y += args.state.camera.y_offset
    
    
    #flip the player if they move left, flip back if they move right
    if input.x < 0 
      player.flip_horizontally = true 
    elsif input.x > 0
      player.flip_horizontally = false
    end
    
    # Adjust hold_for value based on player's movement
    player.hold_for = (dx != 0 || dy != 0) ? 4 : 8
    
    # Use the adjusted hold_for value when calculating the frame index
    player_sprite_index = 0.frame_index(count: 6, hold_for: player[:hold_for], repeat: true)
    player.path = "/sprites/Shippy#{player_sprite_index+1}.png" 
    
    
    
    # Limit the player's x position to a region around the center of the screen
    player[:x] = player[:x].clamp(300-player[:w], 640 + 340)
    
    # Wrap the player around if they go off the top and bottom of the screen
    if player.y > screen_height
      player.y  = 0 - 80
    elsif player.y < 0 - 80
      player.y  = screen_height
    end
    
    #spawn enemies on interval
    if args.state.tick_count >= args.state.enemy_spawn_tick + args.state.enemy_spawn_interval
      spawn_enemies(args, screen_width, screen_height)
      args.state.enemy_spawn_tick = args.state.tick_count
      
      # Decrease the spawn interval by 0.1 seconds every 3 seconds, down to a minimum of 0.25 seconds
      if args.state.second_count % 3 == 0 && args.state.enemy_spawn_interval > 15  # 0.25 seconds * 60 frames/second
        args.state.enemy_spawn_interval -= 6  # 0.1 seconds * 60 frames/second
      end
    end
    
    #spawn spikes on interval
    if args.state.tick_count >= args.state.spike_spawn_tick + args.state.spike_spawn_interval
      spawn_spikes(args, screen_width, screen_height)
      args.state.spike_spawn_tick = args.state.tick_count
      
      # Decrease the spawn interval by 0.1 seconds every 5 seconds, down to a minimum of 0.25 seconds
      if args.state.second_count % 5 == 0 && args.state.spike_spawn_interval > 15  # 0.25 seconds * 60 frames/second
        args.state.spike_spawn_interval -= 6  # 0.1 seconds * 60 frames/second
      end
    end
    
    
    #collision code
    handle_collisions(args, enemies, lasers, player, spikes)
    
    
    #update altimiter
    if args.state.tick_count % 15 == 0
      args.state.altitude = ((player.y+150).round).to_s
    end

    #return to main menu
    if input.escape
      args.outputs.sounds << "sounds/exitgame.wav"
      args.state.exit_scheduled_at = args.state.tick_count + 10
    end
    if args.state.exit_scheduled_at && args.state.tick_count >= args.state.exit_scheduled_at
      args.state.is_game_running = false
      return_to_main_menu(args, player, screen_width, screen_height)
      args.state.exit_scheduled_at = nil
    end
  end
  
  #fire lasers
  def fire_laser(args, player)
    args.outputs.sounds << "sounds/laser.wav"
    args.state.lasers << {
      x: player.flip_horizontally ? player.x - (player.w/2) + 48 : player.x + player.w - 32,
      y: player.y + 24,
      w: 24,
      h: 8,
      path: '/sprites/LaserBullet.png',
      flip_horizontally: player.flip_horizontally
    }
  end
  
  #spawn enemies function
  def spawn_enemies(args, screen_width,screen_height)
    x = [screen_width + 100, -100].sample
    speed = 2 + rand * 4
    args.state.enemies << {
      x: x,
      y: 200 + (rand * (screen_height-400)),
      w: 74*2,
      h: 50*2,
      path: '/sprites/FinEnemy.png',
      flip_horizontally: (x > 0),
      speed: (x < 0) ? speed : -speed,
      angle: 0,
      hp: 3,
      start_time: args.state.tick_count,
    }
    
  end
  #spawn spikes function
  def spawn_spikes(args, screen_width,screen_height)
    x = [screen_width + 100, -100].sample
    y = [-64, screen_height-64].sample
    
    speed = 4
    args.state.spikes << {
      x: x,
      y: y,
      w: 128,
      h: 128,
      path: '/sprites/SpikeBox.png',
      flip_horizontally: (x > 0),
      speed: (x < 0) ? speed : -speed,
      angle: 0,
      hp: 999,
      start_time: args.state.tick_count,
    }
    
  end
  
  #collision code
  def handle_collisions(args, enemies, lasers, player,spikes)
    enemies.each do |enemy|
      lasers.each do |laser|
        if laser[:x] < enemy[:x] + enemy[:w] &&
          laser[:x] + laser[:w] > enemy[:x] &&
          laser[:y] < enemy[:y] + enemy[:h] &&
          laser[:y] + laser[:h] > enemy[:y]
          # Collision detected, decrease enemy hp and destroy the laser
          enemy[:hp] -= 1
          args.outputs.sounds << "sounds/enemyhurt.wav"
          laser[:destroy] = true
        end
      end
      if player[:x] < enemy[:x] + enemy[:w] &&
        player[:x] + player[:w] > enemy[:x] &&
        player[:y] < enemy[:y] + enemy[:h] &&
        player[:y] + player[:h] > enemy[:y]
        # Collision detected, end the game
        args.outputs.sounds << "sounds/lose.wav"
        screen_shake(args)
        args.state.game_over = true
      end
    end
    # Collision detection for spikes
    spikes.each do |spike|
      if player[:x] < spike[:x] + spike[:w] &&
        player[:x] + player[:w] > spike[:x] &&
        player[:y] < spike[:y] + spike[:h] &&
        player[:y] + player[:h] > spike[:y]
        # Collision detected, end the game
        args.outputs.sounds << "sounds/lose.wav"
        screen_shake(args)
        args.state.game_over = true
      end
    end
    
    # Remove destroyed lasers
    lasers.reject! { |laser| laser[:destroy] }
    
    # Enemies die when out of health
    enemies.each do |enemy|
      if enemy[:hp] <= 0 && !enemy[:destroyed]
        
        args.outputs.sounds << "sounds/enemyexplode.wav"
        screen_shake(args)
        # Add an EnemyShatter explosion to fade_out_queue
        args.state.fade_out_queue << {
          hold_for: 4,
          frame: 0,
          start_frame: args.state.tick_count,
          x: enemy[:x],
          y: enemy[:y],
          w: enemy[:w],
          h: enemy[:h],
          base_name: "EnemyShatter",
          flip_horizontally: enemy[:flip_horizontally],
          path: "/sprites/EnemyShatter_000.png"  # Set the initial path
        }
        args.state.score += 1000
        enemy[:destroyed] = true
      end
    end

    # Remove destroyed enemies after the explosion animation has completed
    enemies.reject! { |enemy| enemy[:destroyed] && args.state.fade_out_queue.none? { |explosion| explosion[:x] == enemy[:x] && explosion[:y] == enemy[:y] } }
  end
end

def mainmenu(args,input,screen_width,screen_height)
  if args.state.main_menu == true
    #read the highscore file, if it doesn't exist, create one
    high_score_file = args.gtk.read_file('HighScore.sav')
    if high_score_file
      args.state.high_score = high_score_file.to_i
    else
      args.state.high_score = 0
      args.gtk.write_file('HighScore.sav', args.state.high_score.to_s)
    end
    #main menu labels
    args.outputs.labels << {
      x: screen_width/2,
      y: screen_height/2+50,
      text: "Untitled Spaceship Game",
      size_enum: 12,
      alignment_enum: 1,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
    }
  
    args.outputs.labels << {
      x: screen_width/2,
      y: screen_height/2,
      text: "Press Enter or Gamepad A To Play",
      size_enum: 8,
      alignment_enum: 1,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
    }
    
    #to start the game
    if input.enter and args.state.is_game_running == false
      args.outputs.sounds << "sounds/gamestart.wav"
      reset_game(args,screen_width, screen_height)
      args.state.is_game_running = true
    end
    
    #to quit the game
    if input.escape
      args.outputs.sounds << "sounds/exitgame.wav"
      args.state.exit_scheduled_at = args.state.tick_count + 60
    end
    #continued
    if args.state.exit_scheduled_at && args.state.tick_count >= args.state.exit_scheduled_at
      exit
    end
  end
end

def gameover(args, input, screen_width, screen_height, seconds_survived)
  #turn off the game running state
  args.state.is_game_running = false
  #if a new highscore
  if args.state.score > args.state.high_score
    args.state.high_score = args.state.score
    args.gtk.write_file('HighScore.sav', args.state.high_score.to_s)
    args.state.new_high_score = true
  end
  
  args.state.main_menu = false
  #player explosion code
  player = args.state.player
  animate_explosions(args)
  if !args.state.explosion_created
    args.state.fade_out_queue << {
      hold_for: 4,
      frame: 0,
      start_frame: args.state.tick_count,
      x: player.x,
      y: player.y,
      w: player.w,
      h: player.h,
      base_name: "ShipShatter",
      flip_horizontally: player.flip_horizontally,
      path: "/sprites/ShipShatter_000.png"  # Set the initial path
    }
    args.state.explosion_created = true
  end
  #labels for gameover
  args.outputs.labels << {
    x: screen_width / 2,
    y: screen_height / 2 + 100,
    text: "Game Over",
    size_enum: 12,
    alignment_enum: 1,
    r: 255,
    g: 200,
    b: 255,
    a: 255,
    font: "/fonts/KenneyFutureNarrow.ttf",
    
  }
  
  args.outputs.labels << {
    x: screen_width / 2,
    y: screen_height / 2 + 50,
    text: "You Survived #{seconds_survived} Seconds",
    size_enum: 8,
    alignment_enum: 1,
    r: 255,
    g: 200,
    b: 255,
    a: 255,
    font: "/fonts/KenneyFutureNarrow.ttf",
    
  }
  
  args.outputs.labels << {
    x: screen_width / 2,
    y: screen_height / 2,
    text: "You Scored #{args.state.score} Points",
    size_enum: 8,
    alignment_enum: 1,
    r: 255,
    g: 200,
    b: 255,
    a: 255,
    font: "/fonts/KenneyFutureNarrow.ttf",
    
  }
  
  args.outputs.labels << {
    x: screen_width / 2,
    y: screen_height / 2 - 50,
    text: "Press Enter or Gamepad A To Restart",
    size_enum: 8,
    alignment_enum: 1,
    r: 255,
    g: 200,
    b: 255,
    a: 255,
    font: "/fonts/KenneyFutureNarrow.ttf",
    
  }
  #depending on new high score, choose a label
  if args.state.new_high_score
    args.outputs.labels << {
      x: screen_width / 2,
      y: screen_height / 2 - 100,
      text: "New Highscore",
      size_enum: 8,
      alignment_enum: 1,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
      
    }
  else
    args.outputs.labels << {
      x: screen_width / 2,
      y: screen_height / 2 - 100,
      text: "Your previous highscore was #{args.state.high_score}",
      size_enum: 8,
      alignment_enum: 1,
      r: 255,
      g: 200,
      b: 255,
      a: 255,
      font: "/fonts/KenneyFutureNarrow.ttf",
    }
  end
  #restart the game
  if input.enter
    reset_game(args, screen_width, screen_height)
    args.state.is_game_running = true
  end
end

def reset_game(args, screen_width, screen_height)
  #reset the player position and values
  args.state.player = {
    x: screen_width/2-(132/2),
    y: screen_height/2,
    w: 132,
    h: 64,
    speed: 8,
    flip_horizontally: false,
    start_time: args.state.tick_count,
    rotation_angle:0
  }
  #reinit arrays
  args.state.lasers = []
  args.state.enemies = []
  args.state.spikes = []
  #reset values
  args.state.explosion_created = false
  
  args.state.new_high_score = false
  
  args.state.score = 0
  args.state.second_count = 0
  args.state.second_count_fixed = -1
  args.state.previous_second_count = 0
  args.state.enemy_spawn_tick =  0
  args.state.enemy_spawn_interval= 150  # 2.5 seconds * 60 frames/second
  
  args.state.spike_spawn_tick = 0
  args.state.spike_spawn_interval = 300  
  args.state.altitude = ((args.state.player[:y]+150).round).to_s  # Use args.state.player here
  args.state.game_start_tick = args.state.tick_count  # Reset the game start tick
  
  args.state.exit_scheduled_at = nil  # Reset the scheduled exit time
  args.state.game_over = false
end

#simple return to main menu function
def return_to_main_menu(args, player, screen_width, screen_height)
  reset_game(args, screen_width, screen_height)
  args.state.main_menu = true
  
end

def defaults(args)
  #for screenshake (defaults)
  args.state.camera.trauma ||= 0
  args.state.camera.angle ||= 0
  args.state.camera.x_offset ||= 0
  args.state.camera.y_offset ||= 0
end

def calc_camera(args)
  #calculations for screenshake
  next_camera_angle = 180.0 / 20.0 * args.state.camera.trauma**2
  next_offset       = 100.0 * args.state.camera.trauma**2
  
  # Ensure that the camera angle always switches from
  # positive to negative and vice versa
  # which gives the effect of shaking back and forth
  args.state.camera.angle = args.state.camera.angle > 0 ?
  next_camera_angle * -1 :
  next_camera_angle
  
  args.state.camera.x_offset = next_offset.randomize(:sign, :ratio)
  args.state.camera.y_offset = next_offset.randomize(:sign, :ratio)
  
  # Gracefully degrade trauma
  args.state.camera.trauma *= 0.95
end

