-- particles generative algorithm for the disting NT, inspired by the fall script for norns
-- Romain Faure, 2025 - with inspiration & support from thorinside & the disting community

-- Set a fixed random seed for reproducibility & debugging, or leave as nil for default randomness
local seed = nil 
if seed then
    math.randomseed(seed) -- Initialize the random number generator only if a seed is provided
end

-- ============ OPTIMIZATION: OBJECT POOLS ============
local MAX_PARTICLES = 12
local MAX_DUST = 50
local particle_pool = {}
local dust_pool = {}
local active_particles = 0
local active_dust = 0

-- Pre-create all particles in the pool
for i = 1, MAX_PARTICLES do
    particle_pool[i] = {
        x = 0, y = 0, base_speed = 0, sway = 0,
        sway_speed = 0, wind_sensitivity = 0,
        radius = 0, pitch = 0, last_collision_time = 0,
        active = false, index = i
    }
end

-- Pre-create all dust in the pool
for i = 1, MAX_DUST do
    dust_pool[i] = {
        x = 0, y = 0, dx = 0, dy = 0,
        brightness = 0, life = 0,
        active = false, index = i
    }
end

local time = 0
local output_table = {0, 0, 0, 0} -- Pre-allocated output table
local particles = particle_pool -- Falling particles triggering musical events
local dust = dust_pool -- Background dust specks (visual eye-candy)
local ground_level = 64 -- Y‑coordinate threshold for particles touching the ground
local last_ground_pitch_voltage = 0  -- Voltage of last particle that hit ground
local collision_cooldown_time = 3 -- Minimum time between collision events (in seconds)
local trigger_timer = 0 -- Timer for resetting particle trigger output
local trigger_duration = 0.05 -- Trigger duration in seconds
local collision_trigger_timer = 0 -- Timer for resetting collision trigger output
local collision_cv = 0 -- Random CV value for collisions
local verbose_message = "" -- Message to display in verbose mode
local verbose_timer = 0 -- Timer for verbose message duration
local verbose_duration = 1.0 -- How long to show verbose messages (in seconds)

-- Parameters default values
local selected_scale = 1 -- Default scale (minor)
local root_note = 0 -- Root note within scale (0-11)
local octave = 2 -- Default octave (C2)
local gravity = 1 -- Speed factor for particle size, affecting the base speed of new particles
local global_fall_speed = 5 -- Global fall speed modifier
local max_particles = 6 -- Maximum number of particles
local max_dust = 50 -- Maximum number of dust specks
local wind = 1 -- Wind parameter (affects sway)
local verbose = false -- Verbose mode (off by default)

-- Scales
local scales = {
    minor = {0, 2, 3, 5, 7, 8, 10},
    major = {0, 2, 4, 5, 7, 9, 11},
    dorian = {0, 2, 3, 5, 7, 9, 10},
    phrygian = {0, 1, 3, 5, 7, 8, 10},
    lydian = {0, 2, 4, 6, 7, 9, 11},
    mixolydian = {0, 2, 4, 5, 7, 9, 10},
    locrian = {0, 1, 3, 5, 6, 8, 10},
    harmonic_minor = {0, 2, 3, 5, 7, 8, 11},
    melodic_minor = {0, 2, 3, 5, 7, 9, 11}
}
local scale_names = {"minor", "major", "dorian", "phrygian", "lydian", "mixolydian", 
                            "locrian", "harmonic_minor", "melodic_minor"}

-- Map MIDI note to voltage
local function note_to_voltage(note)
    return note / 12  -- Direct conversion from MIDI note to voltage (1V/oct)
end

-- Convert scale degree to actual MIDI note
local function scale_to_midi(scale_degree, scale_type, root, oct)
    local scale = scales[scale_type]
    -- Get the scale note and add root note offset
    local note_in_scale = scale[((scale_degree - 1) % #scale) + 1]
    -- Calculate final MIDI note: (octave * 12) + root + scale_note
    return (oct * 12) + root + note_in_scale
end

-- Get an inactive particle from the pool
local function get_particle()
    for i = 1, MAX_PARTICLES do
        if not particle_pool[i].active then
            return particle_pool[i]
        end
    end
    return nil
end

-- Activate a particle with new values
local function activate_particle(p)
    local size = math.random(3, 10) -- particle size
    local speed_factor = (1.5 * size + 3) / 10 * gravity
    
    p.x = math.random(0, 255) -- X position within screen width
    p.y = 0 -- Start at the top of the screen
    p.base_speed = speed_factor
    p.sway = math.random() * 2 * math.pi
    p.sway_speed = math.random(1, 3) / 10
    p.wind_sensitivity = 0.7 + 0.3 / size
    p.radius = size
    p.pitch = math.random(1, #scales[selected_scale])
    p.last_collision_time = time - collision_cooldown_time -- Initialize to allow immediate collision
    p.active = true
    active_particles = active_particles + 1
end

-- Deactivate a particle
local function deactivate_particle(p)
    p.active = false
    active_particles = active_particles - 1
end

-- Get an inactive dust from the pool
local function get_dust()
    for i = 1, MAX_DUST do
        if not dust_pool[i].active then
            return dust_pool[i]
        end
    end
    return nil
end

-- Activate a dust speck with new values
local function activate_dust(d)
    d.x = math.random(0, 255)
    d.y = math.random(0, 63)
    d.dx = (math.random() - 0.5) * wind
    d.dy = (math.random() - 0.5) * 5
    d.brightness = math.random(1, 5)
    d.life = math.random(3, 10)
    d.active = true
    active_dust = active_dust + 1
end

-- Deactivate a dust speck
local function deactivate_dust(d)
    d.active = false
    active_dust = active_dust - 1
end

-- Update falling particles
local function update_particles(dt)
    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        if p.active then
            p.y = p.y + p.base_speed * global_fall_speed * dt
            p.sway = p.sway + p.sway_speed * dt
            p.x = p.x + math.sin(p.sway) * wind * p.wind_sensitivity

            -- Handle borders
            if p.x < 0 then
                p.x = 0
                p.sway = p.sway + math.pi / 4
            elseif p.x > 255 then
                p.x = 255
                p.sway = p.sway - math.pi / 4
            end

            -- Handle ground collision
            if p.y >= ground_level then
                -- Calculate the actual MIDI note using the scale degree
                local midi_note = scale_to_midi(p.pitch, selected_scale, root_note, octave)
                local pitch_voltage = note_to_voltage(midi_note)
                last_ground_pitch_voltage = pitch_voltage 
                verbose_message = string.format("Particle CV: %.2fV, Trigger: 5V", pitch_voltage)
                verbose_timer = verbose_duration
                trigger_timer = trigger_duration -- Activate particle trigger
                deactivate_particle(p)
            end
        end
    end

    -- Spawn new particles if needed
    if active_particles < max_particles and math.random() > 0.8 then
        local p = get_particle()
        if p then
            activate_particle(p)
        end
    end
end

-- Update dust specks
local function update_dust(dt)
    for i = 1, MAX_DUST do
        local d = dust[i]
        if d.active then
            d.x = d.x + d.dx * dt
            d.y = d.y + d.dy * dt
            d.life = d.life - dt

            -- Deactivate expired dust
            if d.life <= 0 then
                deactivate_dust(d)
            end
        end
    end

    -- Spawn new dust if needed
    while active_dust < max_dust do
        local d = get_dust()
        if d then
            activate_dust(d)
        else
            break
        end
    end
end

-- Check for collisions between particles
local function check_collisions(dt)
    for i = 1, MAX_PARTICLES do
        local p1 = particles[i]
        if p1.active then
            for j = i + 1, MAX_PARTICLES do
                local p2 = particles[j]
                if p2.active then

                    -- Box-based collision detection (overlap)
                    if p1.x < p2.x + p2.radius and
                       p1.x + p1.radius > p2.x and
                       p1.y < p2.y + p2.radius and
                       p1.y + p1.radius > p2.y then
                        
                        -- Check if enough time has passed since the last collision for either particle (cooldown)
                        local current_time = time
                        if current_time - p1.last_collision_time >= collision_cooldown_time and 
                           current_time - p2.last_collision_time >= collision_cooldown_time then

                            -- Collision detected
                            collision_cv = math.random(-50, 50) / 10
                            verbose_message = string.format("Collision CV: %.2fV, Trigger: 5V", collision_cv)
                            verbose_timer = verbose_duration
                            collision_trigger_timer = trigger_duration

                            -- Update collision times
                            p1.last_collision_time = current_time
                            p2.last_collision_time = current_time
                        end
                    end
                end
            end
        end
    end
end

-- Draw particles and dust on the screen
local function draw_elements()
    -- Draw active particles as smooth boxes
    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        if p.active then
            local brightness = math.floor(p.radius * 1.5) -- Brightness based on size
            drawSmoothBox(p.x, p.y, p.x + p.radius, p.y + p.radius, brightness)
        end
    end

    -- Draw active dust as small points using drawLine
    for i = 1, MAX_DUST do
        local d = dust[i]
        if d.active then
            drawLine(math.floor(d.x), math.floor(d.y), math.floor(d.x),
                    math.floor(d.y), d.brightness)
        end
    end

    -- Display verbose message if timer is active and verbose mode is enabled
    if verbose and verbose_timer > 0 then
        drawText(0, 55, verbose_message)
    end
end

-- Main update loop
return {
    name = "particles",
    author = "Romain Faure",

    init = function(self)
        -- Reset all particles and dust to inactive on init
        for i = 1, MAX_PARTICLES do
            particle_pool[i].active = false
        end
        for i = 1, MAX_DUST do
            dust_pool[i].active = false
        end
        active_particles = 0
        active_dust = 0

        return {
            inputs = 1,
            outputs = 4,
            parameters = {
                {"Root Note", 0, 11, root_note, kInt}, -- Root note within one octave
                {"Octave", 0, 8, octave, kInt}, -- Octave selection
                {"Scale", 1, 9, selected_scale, kInt}, -- Scale selection
                {"Global Fall Speed", 1, 250, global_fall_speed * 10, kNone, kBy10},
                {"Gravity", 1, 50, gravity * 10, kNone, kBy10},
                {"Max Particles", 1, 12, max_particles, kInt},
                {"Wind", 0, 10, wind, kNone, kBy10},
                {"Verbose", 0, 1, verbose and 1 or 0, kInt}
            }
        }
    end,

    step = function(self, dt, inputs)
        root_note = self.parameters[1]
        octave = self.parameters[2]
        -- Convert numeric scale selection to scale name
        selected_scale = scale_names[self.parameters[3]] or "minor"
        global_fall_speed = self.parameters[4]
        gravity = self.parameters[5]
        max_particles = self.parameters[6]
        wind = self.parameters[7] / 10
        verbose = self.parameters[8] == 1

        time = time + dt -- Increment global time

        -- Update timers
        if verbose_timer > 0 then
            verbose_timer = verbose_timer - dt
        end
        
        if trigger_timer > 0 then
            trigger_timer = trigger_timer - dt
        end
        
        if collision_trigger_timer > 0 then
            collision_trigger_timer = collision_trigger_timer - dt
        end

        update_particles(dt)
        update_dust(dt)
        check_collisions(dt)

        local particle_trigger_value = trigger_timer > 0 and 5 or 0
        local collision_trigger_value = collision_trigger_timer > 0 and 5 or 0

        output_table[1] = last_ground_pitch_voltage
        output_table[2] = particle_trigger_value
        output_table[3] = collision_cv
        output_table[4] = collision_trigger_value
        return output_table
    end,

    draw = function(self)
        draw_elements() -- Call the draw function for all visual elements
    end
}
