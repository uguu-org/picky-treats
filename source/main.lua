--[[ Picky Treats

For PlayJam 6.

--]]

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "data"

-- Print a message, and return true.  The returning true part allows this
-- function to be called inside assert(), which means this function will
-- be stripped in the release build by strip_lua.pl.
local function debug_log(msg)
	print(string.format("[%f]: %s", playdate.getElapsedTime(), msg))
	return true
end

-- Log an initial message on startup, and another one later when the
-- initialization is done.  This is for measuring startup time.
local random_seed = playdate.getSecondsSinceEpoch()
local title_version <const> = playdate.metadata.name .. " v" .. playdate.metadata.version
assert(debug_log(title_version .. " (debug build), random seed = " .. random_seed))
math.randomseed(random_seed)

-- Draw frame rate in debug builds.
local function debug_frame_rate()
	playdate.drawFPS(0, 0)
	return true
end

----------------------------------------------------------------------
-- {{{ Constants.

-- Cached function references.
local gfx <const> = playdate.graphics
local abs <const> = math.abs
local floor <const> = math.floor
local max <const> = math.max
local min <const> = math.min
local rand <const> = math.random

-- Sprite indices.
local ROTATION_STEPS <const> = 36
local REAL_BAR <const> = 1
local FAKE_BAR1 <const> = REAL_BAR + ROTATION_STEPS
local FAKE_BAR2 <const> = REAL_BAR + ROTATION_STEPS * 2
local FAKE_BAR3 <const> = REAL_BAR + ROTATION_STEPS * 3
local FAKE_BAR4 <const> = REAL_BAR + ROTATION_STEPS * 4
local REAL_CUP <const> = REAL_BAR + ROTATION_STEPS * 6
local FAKE_CUP1 <const> = REAL_CUP + ROTATION_STEPS
local FAKE_CUP2 <const> = REAL_CUP + ROTATION_STEPS * 2
local FAKE_CUP3 <const> = REAL_CUP + ROTATION_STEPS * 3
local FAKE_CUP4 <const> = REAL_CUP + ROTATION_STEPS * 4
local REAL_SQUARE <const> = REAL_CUP + ROTATION_STEPS * 6
local FAKE_SQUARE1 <const> = REAL_SQUARE + ROTATION_STEPS
local FAKE_SQUARE2 <const> = REAL_SQUARE + ROTATION_STEPS * 2
local GENUINE_TYPES <const> = {REAL_BAR, REAL_CUP, REAL_SQUARE}

local HAND <const> = REAL_SQUARE + ROTATION_STEPS * 4

-- Number of pixels from the edges of the screen where sprites will not
-- be placed.  Sprites will still draw a bit outside of the screen.
local SCREEN_MARGIN <const> = 32

-- Amount of velocity maintained after each frame.
local VELOCITY_DECAY <const> = 0.8

-- Number of frames to animate in game_next_round state.
local TRANSITION_FRAME_COUNT <const> = 20

-- Total number of objects in each round.
local OBJ_COUNT <const> = 24

-- Number of game rounds to play.
local GAME_ROUND_COUNT <const> = 16

-- Value of each object, indexed by "kind" values.
--
-- The values for the genuine items match the calorie value of the original
-- treats that I was parodying, except the squares which were 170 per serving
-- (3 squares), so it should have been ~60 calories per square, but I didn't
-- want the genuine squares to worth less than the bootlegs of other items,
-- so I used the per-serving calorie value.
--
-- The values for the bootleg items are arbitrary prime numbers that are
-- significantly less than the genuine items.
local OBJ_VALUE <const> =
{
	[REAL_BAR] = 487,
	[FAKE_BAR1] = 41,
	[FAKE_BAR2] = 37,
	[FAKE_BAR3] = 31,
	[FAKE_BAR4] = 29,

	[REAL_CUP] = 210,
	[FAKE_CUP1] = 19,
	[FAKE_CUP2] = 17,
	[FAKE_CUP3] = 13,
	[FAKE_CUP4] = 11,

	[REAL_SQUARE] = 170,
	[FAKE_SQUARE1] = 23,
	[FAKE_SQUARE2] = 7,
}

-- Mapping from obj.kind to unrotated cursor sprite index.
local CURSOR <const> =
{
	[REAL_BAR] = REAL_BAR + ROTATION_STEPS * 5,
	[FAKE_BAR1] = REAL_BAR + ROTATION_STEPS * 5,
	[FAKE_BAR2] = REAL_BAR + ROTATION_STEPS * 5,
	[FAKE_BAR3] = REAL_BAR + ROTATION_STEPS * 5,
	[FAKE_BAR4] = REAL_BAR + ROTATION_STEPS * 5,

	[REAL_CUP] = REAL_CUP + ROTATION_STEPS * 5,
	[FAKE_CUP1] = REAL_CUP + ROTATION_STEPS * 5,
	[FAKE_CUP2] = REAL_CUP + ROTATION_STEPS * 5,
	[FAKE_CUP3] = REAL_CUP + ROTATION_STEPS * 5,
	[FAKE_CUP4] = REAL_CUP + ROTATION_STEPS * 5,

	[REAL_SQUARE] = REAL_SQUARE + ROTATION_STEPS * 3,
	[FAKE_SQUARE1] = REAL_SQUARE + ROTATION_STEPS * 3,
	[FAKE_SQUARE2] = REAL_SQUARE + ROTATION_STEPS * 3,
}

-- Mapping from obj.kind to collision table.
local COLLISION_POLY <const> =
{
	[REAL_BAR] = bar_poly,
	[FAKE_BAR1] = bar_poly,
	[FAKE_BAR2] = bar_poly,
	[FAKE_BAR3] = bar_poly,
	[FAKE_BAR4] = bar_poly,

	[REAL_CUP] = cup_poly,
	[FAKE_CUP1] = cup_poly,
	[FAKE_CUP2] = cup_poly,
	[FAKE_CUP3] = cup_poly,
	[FAKE_CUP4] = cup_poly,

	[REAL_SQUARE] = square_poly,
	[FAKE_SQUARE1] = square_poly,
	[FAKE_SQUARE2] = square_poly,
}

-- }}}

----------------------------------------------------------------------
--- {{{ Data.

-- Table of all sprites.
local sprites = gfx.imagetable.new("images/sprites")
assert(sprites)

-- Table of all object states.
local obj_table = table.create(OBJ_COUNT, 0)
for i = 1, OBJ_COUNT do
	obj_table[i] =
	{
		-- Sprite index of unrotated object.
		kind = 0,

		-- Center of sprite in screen coordinates.
		x = 0,
		y = 0,

		-- Rotation angle for each sprite, in the range of
		-- [0 .. ROTATION_STEPS - 1].
		a = 0,

		-- Sprite velocity in pixels per frame.
		vx = 0,
		vy = 0,
	}
end

-- Player cursor position.
local cursor_x = 200
local cursor_y = 120

-- Cursor movement speed in pixels per frame, in the range of [1..8].
local cursor_velocity = 1

-- Index of currently selected object, or nil if it needs to be refreshed.
local selected_object

-- Previous accelerometer readings, used to detect shakes.
local last_ax
local last_ay
local last_az

-- List of obj_table.kind values to record objects collected in each round.
local object_collection = table.create(GAME_ROUND_COUNT, 0)

-- Maximum possible score.
local max_score = 0

-- Current game round, starting from 1.
local game_round = 1

-- Total amount of game_loop time in number of frames.
local game_loop_frames = 0

-- Number of frames spent inside game_show_selected and game_next_round.
local game_transition_frames = 0

-- Pointer to game state function.
local game_state

-- }}}

----------------------------------------------------------------------
--- {{{ Functions.

-- Compute cross product of (ax,ay)*(bx,by) and returns true if the result
-- is non-negative.
local function cross_positive(ax, ay, bx, by)
	return ax * by >= bx * ay
end

-- Get index to first obj_table entry that intersects player cursor.
-- Returns 0 if there is none.
local function get_selected_object()
	-- Check the objects from top to bottom.
	for i = OBJ_COUNT, 1, -1 do
		-- Translate cursor coordinate to be relative to object center,
		-- and do a quick bounding box check first.
		local obj <const> = obj_table[i]
		local x <const> = cursor_x - obj.x
		local y <const> = cursor_y - obj.y
		if abs(x) < 64 and abs(y) < 64 then
			-- Having passed the bounding box check, now check if translated
			-- cursor is within bounding polygon.
			local poly <const> = COLLISION_POLY[obj.kind][obj.a + 1]
			local a <const> = poly[1]
			local b <const> = poly[2]
			local c <const> = poly[3]
			local d <const> = poly[4]
			if cross_positive(b[1] - a[1], b[2] - a[2], x - a[1], y - a[2]) and
			   cross_positive(c[1] - b[1], c[2] - b[2], x - b[1], y - b[2]) and
			   cross_positive(d[1] - c[1], d[2] - c[2], x - c[1], y - c[2]) and
			   cross_positive(a[1] - d[1], a[2] - d[2], x - d[1], y - d[2]) then
				return i
			end
		end
	end
	return 0
end

-- Change an genuine object into a bootleg one, preserving object kind.
local function make_fake(index)
	if index == REAL_SQUARE then
		return index + rand(2) * ROTATION_STEPS
	end
	return index + rand(4) * ROTATION_STEPS
end

-- Initialize objects to random positions and kinds.
local function init_objects()
	if game_round == 1 then
		-- First round has all real stuff, evenly distributed.
		for i = 1, OBJ_COUNT do
			obj_table[i].kind = GENUINE_TYPES[(i - 1) % 3 + 1]
		end

	elseif game_round <= 4 then
		-- Rounds 2-4 has mostly real stuff of the same kind, with the last
		-- few being bootlegs.
		for i = 1, OBJ_COUNT - 5 do
			obj_table[i].kind = GENUINE_TYPES[game_round - 1]
		end
		for i = OBJ_COUNT - 4, OBJ_COUNT do
			obj_table[i].kind = make_fake(GENUINE_TYPES[game_round - 1])
		end

	else
		-- All remaining rounds have object kinds being completely random,
		-- with decreasing ratio of genuine objects.
		local fake_start <const> = max(2, OBJ_COUNT - 4 - game_round)
		for i = 1, fake_start - 1 do
			-- For the last two rounds, make an effort not to use REAL_BAR at
			-- all.  This is because the presence of REAL_BAR makes it obvious
			-- what is the highest value item, and for the last two rounds we
			-- we want the player to try harder to look for the second highest
			-- value item (REAL_CUP or REAL_SQUARE).
			if game_round >= GAME_ROUND_COUNT - 1 then
				obj_table[i].kind = GENUINE_TYPES[rand(2, 3)]
			else
				obj_table[i].kind = GENUINE_TYPES[rand(3)]
			end
		end
		for i = fake_start, OBJ_COUNT do
			obj_table[i].kind = make_fake(GENUINE_TYPES[rand(3)])
		end
	end

	-- Set initial object positions and velocities such that they fall toward
	-- some random position on screen, and decelerates to zero just as they
	-- arrived at their designated locations.
	--
	-- Also keep track of highest value item in this round.
	local best_item_value = 0
	for i = 1, OBJ_COUNT do
		local obj = obj_table[i]
		obj.a = rand(0, ROTATION_STEPS - 1)
		obj.x = rand(SCREEN_MARGIN, 400 - SCREEN_MARGIN)
		obj.y = rand(SCREEN_MARGIN, 240 - SCREEN_MARGIN)
		obj.vx = 0
		obj.vy = rand(50, 100) / 100.0
		for j = 1, TRANSITION_FRAME_COUNT do
			obj.vx /= VELOCITY_DECAY
			obj.vy /= VELOCITY_DECAY
			obj.x -= obj.vx
			obj.y -= obj.vy
		end

		-- Update highest score that can be achieved in this round.
		local item_value <const> = OBJ_VALUE[obj.kind]
		if best_item_value < item_value then
			best_item_value = item_value
		end
	end
	assert(best_item_value > 0)
	max_score += best_item_value
end

-- Draw background rectangle to reflect round index.  Background gets
-- progressively darker as a way of saying the night is getting late.
local function draw_background()
	gfx.clear(gfx.kColorWhite)
	gfx.setColor(gfx.kColorBlack)
	gfx.setDitherPattern(max(0.5 - 0.6 * game_round / GAME_ROUND_COUNT, 0))
	gfx.fillRect(0, 0, 400, 240)
end

-- Draw all items on screen.
local function draw_objects()
	for i = 1, OBJ_COUNT do
		local obj <const> = obj_table[i]
		sprites:drawImage(obj.kind + obj.a, obj.x - 64, obj.y - 64)
	end
end

-- Update selected_object, and optionally draw selection cursor.
local function update_and_draw_selection()
	if not selected_object then
		selected_object = get_selected_object()
	end
	if selected_object == 0 then
		return
	end

	local obj <const> = obj_table[selected_object]
	sprites:drawImage(CURSOR[obj.kind] + obj.a, obj.x - 64, obj.y - 64)
end

-- Draw player cursor location.
local function draw_hand()
	sprites:drawImage(HAND, cursor_x - 32, cursor_y - 32)
end

-- Apply object movements.
local function update_objects(enforce_bounds)
	for i = 1, OBJ_COUNT do
		local obj = obj_table[i]
		if obj.vx ~= 0 or obj.vy ~= 0 then
			obj.x += obj.vx
			obj.y += obj.vy
			if enforce_bounds then
				obj.x = min(max(obj.x, 0), 400)
				obj.y = min(max(obj.y, 0), 240)
			end
			obj.vx *= VELOCITY_DECAY
			obj.vy *= VELOCITY_DECAY
			if abs(obj.vx) < 1 then obj.vx = 0 end
			if abs(obj.vy) < 1 then obj.vy = 0 end

			-- Invalidate selected object index, since something moved.
			selected_object = nil
		end
	end
end

-- Detect shake and update object velocities accordingly.
local function apply_shake()
	local x <const>, y <const>, z <const> = playdate.readAccelerometer()

	if abs(x - last_ax) > 0.25 or
	   abs(y - last_ay) > 0.25 or
	   abs(z - last_az) > 0.25 then
		-- Add a random velocity element to each object, with the magnitude
		-- proportional to how far the object is from player's cursor.
		for i = 1, OBJ_COUNT do
			local obj = obj_table[i]
			local dx <const> = floor(abs(obj.x - cursor_x))
			local dy <const> = floor(abs(obj.y - cursor_y))
			local jx <const> = max(32 - dx, 6)
			local jy <const> = max(32 - dy, 6)
			obj.vx += rand(-jx, jx)
			obj.vy += rand(-jy, jy)
			obj.a = (obj.a + rand(-2, 2) + ROTATION_STEPS) % ROTATION_STEPS
		end
	end

	last_ax = x
	last_ay = y
	last_az = z
end

-- Handle D-pad input.
local function handle_dpad()
	if playdate.buttonIsPressed(playdate.kButtonLeft) then
		cursor_x -= cursor_velocity
		if cursor_x < 0 then
			cursor_x = 0
		end
		selected_object = nil
	end
	if playdate.buttonIsPressed(playdate.kButtonRight) then
		cursor_x += cursor_velocity
		if cursor_x > 400 then
			cursor_x = 400
		end
		selected_object = nil
	end
	if playdate.buttonIsPressed(playdate.kButtonUp) then
		cursor_y -= cursor_velocity
		if cursor_y < 0 then
			cursor_y = 0
		end
		selected_object = nil
	end
	if playdate.buttonIsPressed(playdate.kButtonDown) then
		cursor_y += cursor_velocity
		if cursor_y > 240 then
			cursor_y = 240
		end
		selected_object = nil
	end

	-- Accelerate cursor_velocity if D-pad button was held, otherwise set
	-- cursor_velocity to lowest speed.
	if selected_object then
		-- selected_object was not invalidated, so all D-pad buttons
		-- were released.
		cursor_velocity = 1
	else
		cursor_velocity += 1
		if cursor_velocity > 8 then
			cursor_velocity = 8
		end
	end
end

-- Forward declaration of game transition state.
local game_next_round

-- Show instruction text.
local function game_title()
	-- Show title screen and instructions.
	gfx.clear()
	sprites:drawImage(580, 0, 0)
	sprites:drawImage(581, 128, 0)
	sprites:drawImage(582, 256, 0)
	sprites:drawImage(583, 384, 0)

	sprites:drawImage(REAL_BAR, 8, 32)
	sprites:drawImage(REAL_CUP, 136, 32)
	sprites:drawImage(REAL_SQUARE, 264, 32)

	gfx.drawTextAligned("*D-pad*=Move   *A*=Take   *Shake*=Shuffle", 200, 134,
	                    kTextAlignment.center)
	gfx.drawTextAligned("Collect candies with highest calories!", 200, 163,
	                    kTextAlignment.center)
	gfx.drawTextAligned("Watch out for fake products!", 200, 185,
	                    kTextAlignment.center)

	gfx.drawText("PlayJam 6 \"Trick or Treat\"", 2, 220)
	gfx.drawTextAligned("(c)2024 uguu.org", 398, 220, kTextAlignment.right)

	-- Start game on button press.
	if playdate.buttonJustPressed(playdate.kButtonA) or
	   playdate.buttonJustPressed(playdate.kButtonB) then
		game_loop_frames = 0
		game_transition_frames = 0
		game_round = 1
		max_score = 0
		init_objects()
		game_state = game_next_round
	end
end

-- Show score summary.
local function game_complete()
	-- Animate item table.
	local item_limit <const> = min(GAME_ROUND_COUNT, game_transition_frames // 15)

	local score = 0
	gfx.clear(gfx.kColorWhite)
	for x = 0, 3 do
		for y = 0, 3 do
			local i = x * 4 + y + 1
			if i <= item_limit then
				score += OBJ_VALUE[object_collection[i]]
				sprites:drawImage(object_collection[i], x * 100 - 14, y * 50)
			end
		end
	end

	-- Draw stats.
	gfx.drawText("Total calories = " .. score, 2, 2)
	if score == max_score then
		gfx.drawTextAligned("*PERFECT!!*", 200, 22, kTextAlignment.center)
	end

	local millis <const> = (game_loop_frames % 30) * 1000 // 30
	local seconds <const> = (game_loop_frames // 30) % 60
	local minutes <const> = game_loop_frames // (30 * 60)
	gfx.drawTextAligned(
		string.format("Game time = %d:%02d.%03d", minutes, seconds, millis),
		398, 2,
		kTextAlignment.right)

	-- Move back to title state on button press, once all items are visible.
	game_transition_frames += 1
	if item_limit >= GAME_ROUND_COUNT and
	   (playdate.buttonJustPressed(playdate.kButtonA) or
	    playdate.buttonJustPressed(playdate.kButtonB)) then
		game_state = game_title
	end
end

-- Show selected item.
local function game_show_selected()
	draw_background()

	-- Draw all objects except the last one.
	for i = 1, OBJ_COUNT - 1 do
		local obj <const> = obj_table[i]
		sprites:drawImage(obj.kind + obj.a, obj.x - 64, obj.y - 64)
	end

	-- Animate the last object.
	local f
	if game_transition_frames > TRANSITION_FRAME_COUNT // 2 then
		f = 1
	else
		f = game_transition_frames / (TRANSITION_FRAME_COUNT * 0.5)
	end
	local obj <const> = obj_table[OBJ_COUNT]
	local x <const> = obj.x + (200 - obj.x) * f
	local y <const> = obj.y + (120 - obj.y) * f
	local a
	if obj.a > ROTATION_STEPS // 2 then
		a = floor(obj.a + (ROTATION_STEPS - obj.a) * f) % ROTATION_STEPS
	else
		a = floor(obj.a - obj.a * f)
	end
	local scale <const> = 1 + f
	sprites:getImage(obj.kind + a):drawScaled(x - 64 * scale, y - 64 * scale, scale)

	-- Move on to next state.
	game_transition_frames += 1
	if game_transition_frames > TRANSITION_FRAME_COUNT then
		game_transition_frames = 0
		game_round += 1
		if game_round > GAME_ROUND_COUNT then
			game_state = game_complete
		else
			init_objects()
			game_state = game_next_round
		end
	end
end

-- Select item.
local function game_loop()
	-- Update and draw objects.
	update_objects(true)
	draw_background()
	draw_objects()
	update_and_draw_selection()
	draw_hand()

	-- Handle input.
	assert(selected_object)
	if selected_object > 0 and
	   (playdate.buttonJustPressed(playdate.kButtonA) or
	    playdate.buttonJustPressed(playdate.kButtonB)) then
		-- Make selected object the last object.
		if selected_object < OBJ_COUNT then
			local tmp <const> = obj_table[selected_object]
			for i = selected_object, OBJ_COUNT - 1 do
				obj_table[i] = obj_table[i + 1]
			end
			obj_table[OBJ_COUNT] = tmp
		end

		-- Record collected object.
		object_collection[game_round] = obj_table[OBJ_COUNT].kind

		-- Move on to next state.
		game_transition_frames = 0
		game_state = game_show_selected
	end
	handle_dpad()
	apply_shake()

	-- Update timer.
	game_loop_frames += 1
end

-- Transition to next round.
game_next_round = function()
	-- Draw objects falling into place.
	update_objects(false)
	draw_background()
	draw_objects()

	-- Refresh accelerometer readings.
	last_ax, last_ay, last_az = playdate.readAccelerometer()

	-- Transition to game_loop once enough frame has passed.
	game_transition_frames += 1
	if game_transition_frames >= TRANSITION_FRAME_COUNT then
		game_state = game_loop
	end
end

-- }}}

----------------------------------------------------------------------

game_state = game_title

playdate.startAccelerometer()

assert(debug_log("Initialized"))

-- Playdate callbacks.
function playdate.update()
	game_state()
	assert(debug_frame_rate())
end
