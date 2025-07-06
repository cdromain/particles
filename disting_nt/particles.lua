-- particles generative algorithm, inspired by the fall script for norns
-- Romain Faure, 2025 - with inspiration & support from thorinside & the disting community

-- Set a fixed random seed for reproducibility & debugging, or leave as nil for default randomness
local seed = nil 
if seed then
    math.randomseed(seed) -- Initialize the random number generator only if a seed is provided
end

local time = 0
local particles = {} -- Falling particles triggering musical events
local dust = {}      -- Background dust specks (visual eye-candy)
local ground_level = 64 -- Y‑coordinate threshold for particles touching the ground
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

-- Create a new particle
local function create_particle()
    local size = math.random(3, 10) -- particle size
    local speed_factor = (1.5 * size + 3) / 10 * gravity
    return {
        x = math.random(0, 255), -- X position within screen width
        y = 0, -- Start at the top of the screen
        base_speed = speed_factor,
        sway = math.random() * 2 * math.pi,
        sway_speed = math.random(1, 3) / 10,
        wind_sensitivity = 0.7 + 0.3 / size,
        radius = size,
        pitch = math.random(1, #scales[selected_scale]),
        last_collision_time = -collision_cooldown_time -- Initialize to allow immediate collision
    }
end

-- Create a new dust speck
local function create_dust()
    return {
        x = math.random(0, 255),
        y = math.random(0, 63),
        dx = (math.random() - 0.5) * wind,
        dy = (math.random() - 0.5) * 5,
        brightness = math.random(1, 5),
        life = math.random(3, 10)
    }
end

-- Update falling particles
local function update_particles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
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
            verbose_message = string.format("Particle CV: %.2fV, Trigger: 5V", pitch_voltage)
            verbose_timer = verbose_duration
            trigger_timer = trigger_duration -- Activate particle trigger
            table.remove(particles, i)
        end
    end

    if #particles < max_particles and math.random() > 0.8 then
        table.insert(particles, create_particle())
    end
end

-- Update dust specks
local function update_dust(dt)
    for i = #dust, 1, -1 do
        local d = dust[i]
        d.x = d.x + d.dx * dt
        d.y = d.y + d.dy * dt
        d.life = d.life - dt

        -- Remove expired dust specks
        if d.life <= 0 then
            table.remove(dust, i)
        end
    end

    while #dust < max_dust do
        table.insert(dust, create_dust())
    end
end

-- Check for collisions between particles
local function check_collisions(dt)
    for i = 1, #particles do
        for j = i + 1, #particles do
            local p1 = particles[i]
            local p2 = particles[j]

            -- Box-based collision detection
            local box1 = {
                left = p1.x,
                right = p1.x + p1.radius,
                top = p1.y,
                bottom = p1.y + p1.radius
            }
            local box2 = {
                left = p2.x,
                right = p2.x + p2.radius,
                top = p2.y,
                bottom = p2.y + p2.radius
            }

            -- Check if boxes overlap
            if box1.left < box2.right and
               box1.right > box2.left and
               box1.top < box2.bottom and
               box1.bottom > box2.top then
                
                -- Check if enough time has passed since the last collision for either particle
                local current_time = time
                if current_time - p1.last_collision_time >= collision_cooldown_time and 
                   current_time - p2.last_collision_time >= collision_cooldown_time then

                    -- Collision detected
                    collision_cv = math.random(-50, 50) / 10 -- Random CV between -5V and +5V
                    verbose_message = string.format("Collision CV: %.2fV, Trigger: 5V", collision_cv)
                    verbose_timer = verbose_duration
                    collision_trigger_timer = trigger_duration -- Activate collision trigger

                    -- Update collision times
                    p1.last_collision_time = current_time
                    p2.last_collision_time = current_time
                end
            end
        end
    end
end

-- Draw particles and dust on the screen
local function draw_elements()
    -- Draw particles as smooth boxes
    for _, p in ipairs(particles) do
        local brightness = math.floor(p.radius * 1.5) -- Brightness based on size
        drawSmoothBox(p.x, p.y, p.x + p.radius, p.y + p.radius, brightness)
    end

    -- Draw dust as small points using drawLine
    for _, d in ipairs(dust) do
        drawLine(math.floor(d.x), math.floor(d.y), math.floor(d.x),
        math.floor(d.y), d.brightness)
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
        local scale_names = {"minor", "major", "dorian", "phrygian", "lydian", "mixolydian", 
                            "locrian", "harmonic_minor", "melodic_minor"}
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

        if #particles > 0 then
            -- Calculate the actual MIDI note using the scale degree
            local midi_note = scale_to_midi(particles[1].pitch, selected_scale, root_note, octave)
            local pitch_voltage = note_to_voltage(midi_note)
            return {pitch_voltage, particle_trigger_value, collision_cv, collision_trigger_value}
        else
            return {0, particle_trigger_value, collision_cv, collision_trigger_value}
        end
    end,

    draw = function(self)
        draw_elements() -- Call the draw function for all visual elements
    end
}
