pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

--------------------------------
-- pico system - shuzo iwasaki -
--------------------------------

g_dbg = false
g_win = {x = 128, y = 128}
g_fps = 30

s_dbg_log = {'','',''}

-- utilities ------------------------

function printl(s,x,y,c)
	print(s,x,y,c)
end
function printr(s,x,y,c)
	x -= (#s*4)-1
	print(s,x,y,c)
end
function printm(s,x,y,c)
	x -= ((#s*4)/2)-1
	print(s,x,y,c)
end

function rndr(l,u)
	return rnd(abs(u-l))+min(l,u)
end

function rndi(u)
	return flr(rnd(u+1))
end

function rndir(l,u)
	return rndi(abs(u-l))+min(l,u)
end

function isort(list,fnc)
	for i=1,#list do
		local j=i
		while j>1 and fnc(list[j-1], list[j]) do
			list[j-1],list[j] = list[j],list[j-1]
			j-=1
		end
	end
end

function dist(x1,y1,x2,y2)
	-- anti overflow
	local d = max(abs(x1-x2), abs(y1-y2))
	local n = min(abs(x1-x2), abs(y1-y2)) / d
	return sqrt(n*n + 1)*d
end

function is_collide(x1,y1,r1,x2,y2,r2)
	return dist(x1,y1,x2,y2) <= (r1 + r2)
end

function inherit(sub, super)
	sub._super = super
	return setmetatable(
		sub, {__index = super}
	)
end

function instance(cls)
	return setmetatable(
		{}, {__index = cls}
	)
end

-- pico system ------------------------
-- default: x0 > x128, y128 ^ y0
-- p-sys:   x0 > x128, y0 ^ y128

p = {
	object = {},
	scene = {},

	scns = {},
	current = nil,
	next = nil,

	objs = {
		update = {},
		draw = {}
	}
}

p._comp_obj_update = function(a,b)
	return a._p.u > b._p.u
end

p._comp_obj_draw = function(a,b)
	return a._p.d > b._p.d
end

-- main loop

p.init = function()
end

p.update = function(delta)
	p._pre_update(delta)
	p._update_objs(delta)
	p._post_update(delta)
end

p._pre_update = function(delta)
	if p.next then
		p.current = p.next
		p.current:_init()
		p.current:init()
		p.next = nil
	end

	if p.current then
		p.current:_update(delta)
		p.current:pre_update(delta)
	end
end

p._update_objs = function(delta)
	foreach(p.objs.update,
		function(obj) obj:update(delta) end
	)
end

p._post_update = function(delta)
	if p.current then
		p.current:post_update(delta)
	end

	if p.next then
		p.current:fin()
		-- destroy all objs
		foreach(p.objs.update,
			function(obj) obj:destroy() end
		)
		p.current.objs = nil
	end
end

p.draw = function()
	p._pre_draw()
	p._draw_objs()
	p._post_draw()
end

p._pre_draw = function()
	if not p.current then return end
	p.current:pre_draw()
end

p._draw_objs = function()
	foreach(p.objs.draw,
		function(obj) obj:draw() end
	)
end

p._post_draw = function()
	if not p.current then return end
	p.current:post_draw()
end

-- scene

p.scene = {
	const = function(self,name)
		self.name = name
		self.cnt = 0
	end,

	_init = function(self)
		self.cnt = 0
	end,
	init = function(self) end,
	fin = function(self) end,

	_update = function(self,delta)
		self.cnt += 1
	end,
	pre_update = function(self,delta) end,
	post_update = function(self,delta) end,
	pre_draw = function(self) end,
	post_draw = function(self) end
}

-- add scene
p.add = function(name)
	local scn = inherit({},p.scene)
	scn:const(name)
	-- register
	p.scns[name] = scn
	return scn
end

-- move scene
p.move = function(name)
	if not p.scns[name] then return end
	p.next = p.scns[name]
end

-- object

p.object = {
	const = function(self,px,py,vx,vy,ax,ay,pu,pd)
		self._p  = {u=pu or 0, d=pd or pu or 0}
		self.pos = {x=px or 0, y=py or 0}
		self.vel = {x=vx or 0, y=vy or 0}
		self.acc = {x=ax or 0, y=ay or 0}

		self.size = 1
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		self.vel.x += delta*self.acc.x
		self.vel.y += delta*self.acc.y
		self.pos.x += delta*self.vel.x
		self.pos.y += delta*self.vel.y
	end,
	draw = function(self)
		pset(self.pos.x,self.pos.y,7)
	end,

	set_priority = function(self,pu,pd)
		self._p.u = pu or 0
		self._p.d = pd or pu or 0
		isort(p.objs.update, p._comp_obj_update)
		isort(p.objs.draw, p._comp_obj_draw)
	end,
	is_collide = function(self,obj)
		if obj == nil then return false end
		return is_collide(self.pos.x,self.pos.y,self.size,obj.pos.x,obj.pos.y,obj.size)
	end
}

-- define object class
p.define = function(sub,super)
	super = super or p.object
	return inherit(sub, super)
end

-- create object
p.create = function(cls, ...)
	local obj = instance(cls)
	obj:const(...)
	-- register
	add(p.objs.update, obj)
	isort(p.objs.update, p._comp_obj_update)
	add(p.objs.draw, obj)
	isort(p.objs.draw, p._comp_obj_draw)
	return obj
end

-- destroy object
p.destroy = function(obj)
	if obj == nil then return end
	obj:dest()
	-- unregister
	del(p.objs.update, obj)
	del(p.objs.draw, obj)
end

-- debug
p.draw_grid = function(num)
	for i=1,num-1 do
		line((128/num)*i,0, (128/num)*i,127, 2)
		line(0,(128/num)*i, 127,(128/num)*i, 2)
	end
end

-- debug
p.draw_debug = function()
	local by = 8
	print("",0,by,11)
	print("scn: "..p.current.name.." "..p.current.cnt)
	print("obj: "..#p.objs.update)

	local str=""
	for i=1,#p.objs.update do
		str = str..p.objs.update[i]._p.u
		if i<#p.objs.update then str = str.."," end
	end
	print("ord: "..str)
end

-- fade ------------------------

s_fade_table={
	{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	{1,1,1,1,1,1,1,0,0,0,0,0,0,0,0},
	{2,2,2,2,2,2,1,1,1,0,0,0,0,0,0},
	{3,3,3,3,3,3,1,1,1,0,0,0,0,0,0},
	{4,4,4,2,2,2,2,2,1,1,0,0,0,0,0},
	{5,5,5,5,5,1,1,1,1,1,0,0,0,0,0},
	{6,6,13,13,13,13,5,5,5,5,1,1,1,0,0},
	{7,6,6,6,6,13,13,13,5,5,5,1,1,0,0},
	{8,8,8,8,2,2,2,2,2,2,0,0,0,0,0},
	{9,9,9,4,4,4,4,4,4,5,5,0,0,0,0},
	{10,10,9,9,9,4,4,4,5,5,5,5,0,0,0},
	{11,11,11,3,3,3,3,3,3,3,0,0,0,0,0},
	{12,12,12,12,12,3,3,1,1,1,1,1,1,0,0},
	{13,13,13,5,5,5,5,1,1,1,1,1,0,0,0},
	{14,14,14,13,4,4,2,2,2,2,2,1,1,0,0},
	{15,15,6,13,13,13,5,5,5,5,5,1,1,0,0}
}

-- rate: [0.0,1.0]
function fade_scr(rate)
	for c=0,15 do
		local i = mid(0,flr(rate * 15),15) + 1
		pal(c, s_fade_table[c+1][i])
	end
end

-- gpio ------------------------

-- name: 36*36*36 = 46656
-- num: -32768.0 to 32767.99
-- gpio: 255*255 = 65025

s_gpio_cnt_idx = 10
s_gpio_ope_idx = 11
s_gpio_post_idx = 12
s_gpio_pull_idx = 12

-- num: -32768.0 to 32767.99 (overflow in calc is ok.)
s_num_offset = 32767

function peek_gpio(idx)
	return peek(0x5f80 + idx)
end
function poke_gpio(idx, n)
	poke(0x5f80 + idx, n)
end

function to_gpio2(num16, is_offset)
	is_offset = is_offset or false
	if is_offset then
		return {(num16 + s_num_offset) % 256, flr((num16 + s_num_offset) / 256)}
	end
	return {num16 % 256, flr(num16 / 256)}
end
function from_gpio2(gpio2, is_offset)
	is_offset = is_offset or false
	if is_offset then
		return gpio2[1] + (gpio2[2] * 256) - s_num_offset
	end
	return gpio2[1] + (gpio2[2] * 256)
end

function to_name_offset16(arr)
	local num16o = -s_num_offset
	local n = 1
	for i=1, 3 do
		num16o += arr[i] * n
		n *= 40
	end
	return num16o
end
function from_name_offset16(num16o)
	local arr = {}
	local n = 1
	local mod = s_num_offset % 40
	local num = num16o + mod
	local off = s_num_offset - mod
	for i=1, 3 do
		-- over 32767/40 is not work
		mod = off % 40
		num += mod
		off -= mod
		if num < 0 then
			arr[i] = (num + off) % 40
		else
			arr[i] = ((num % 40) + (off % 40)) % 40
		end
		num = (num - arr[i])/40
		off = off/40
	end
	return arr
end

function increment_gpio_cnt()
	if (peek_gpio(s_gpio_cnt_idx) >= 256) then
		poke_gpio(s_gpio_cnt_idx, 0)
	else
		poke_gpio(s_gpio_cnt_idx, peek_gpio(s_gpio_cnt_idx) + 1)
	end
end
function set_gpio_ope(idx)
	-- 1:post, 2:pull, 3:post done, 4:pull ok
	poke_gpio(s_gpio_ope_idx, idx)
end

--------------------------------
-- common objects -
--------------------------------

-- web api ------------------------

function get_null_ranking(max)
	local ranking = {}
	for i=1, max do
		add(ranking, {n={1,1,1}, s=0})
	end
	return ranking
end

s_api = {
	init = function(self,max)
		self.cnt = 0
		self.elasped = -1.0
		self.max = max
		self.wait_max = 4.0
		self.callback_post = nil
		self.callback_pull = nil

		poke_gpio(s_gpio_cnt_idx, 0)
		poke_gpio(s_gpio_ope_idx, 0)
	end,
	update = function(self,delta)
		if self.elasped >= 0 then self.elasped += delta end
		if self.elasped >= self.wait_max then
			if self.callback_post ~= nil then self.callback_post() end
			if self.callback_pull ~= nil then self.callback_pull(get_null_ranking(self.max)) end
			self.elasped = -1.0
		end

		if self.cnt == peek_gpio(s_gpio_cnt_idx) then return end
		self.cnt = peek_gpio(s_gpio_cnt_idx)

		if peek_gpio(s_gpio_ope_idx) == 3 then
			if self.callback_post ~= nil then
				self.callback_post()
				self.callback_post = nil
			end
			self.elasped = -1.0
		elseif peek_gpio(s_gpio_ope_idx) == 4 then
			if self.callback_pull ~= nil then
				local ranking = get_null_ranking(self.max)
				for i=1, #ranking do
					local idx = s_gpio_pull_idx + (i-1) * 4
					if peek_gpio(idx) ~= 0 then
						ranking[i]["n"] = from_name_offset16(
							from_gpio2({peek_gpio(idx+0), peek_gpio(idx+1)}, true)
						)
						ranking[i]["s"] = from_gpio2({peek_gpio(idx+2), peek_gpio(idx+3)})
					end
				end
				self.callback_pull(ranking)
				self.callback_pull = nil
			end
			self.elasped = -1.0
		end
	end,

	post = function(self,name,score,callback)
		if self.elasped >= 0 then return end
		local name_gpio2 = to_gpio2(to_name_offset16(name), true)
		local score_gpio2 = to_gpio2(score)
		poke_gpio(s_gpio_post_idx + 0, name_gpio2[1])
		poke_gpio(s_gpio_post_idx + 1, name_gpio2[2])
		poke_gpio(s_gpio_post_idx + 2, score_gpio2[1])
		poke_gpio(s_gpio_post_idx + 3, score_gpio2[2])
		set_gpio_ope(1)
		increment_gpio_cnt()
		self.callback_post = callback
		self.elasped = 0
	end,
	pull = function(self,callback)
		if self.elasped >= 0 then return end
		set_gpio_ope(2)
		increment_gpio_cnt()
		self.callback_pull = callback
		self.elasped = 0
	end,
	exit = function(self)
		self.callback_post = nil
		self.callback_pull = nil
		self.elasped = -1
	end,
	draw_debug = function(self)
		local by = 8
		printr(
			""..self.elasped..","..self.cnt.." ["..peek_gpio(s_gpio_cnt_idx)..","..peek_gpio(s_gpio_ope_idx).."]",
			g_win.x,by+0,11
		)
		printr(
			"["..peek_gpio(s_gpio_post_idx+0)..","..peek_gpio(s_gpio_post_idx+1)..","..peek_gpio(s_gpio_post_idx+2)..","..peek_gpio(s_gpio_post_idx+3).."]",
			g_win.x,by+6,11
		)
		local n = from_gpio2({peek_gpio(s_gpio_post_idx+0), peek_gpio(s_gpio_post_idx+1)}, true)
		local s = from_gpio2({peek_gpio(s_gpio_post_idx+2), peek_gpio(s_gpio_post_idx+3)})
		printr(
			"("..n..","..s..")",
			g_win.x,by+12,11
		)
	end
}

-- name reel ------------------------

s_alphabet = {
	"_","*",
	"a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p",
	"q","r","s","t","u","v","w","x",
	"y","z",",",".","+","-","!","?",
}

char_reel = p.define({
	const = function(self, px, py, num, color)
		char_reel._super.const(self,px,py)
		self.chars = {}
		for i = 1, num do
			self.chars[i] = 1
		end

		self.index = 1
		self.color = color

		self.fixed = false
		self.decided = false
		self.duration = 0.4
		self.elasped = 0
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		char_reel._super.update(self,delta)
		self.elasped = (self.elasped < self.duration * 2) and (self.elasped + delta) or (0)
	end,
	draw = function(self)
		-- blink after decided
		if self.decided then
			if self.elasped > self.duration then return end
		end

		local x = 0
		local y = 0
		color(self.color)
		print("[", self.pos.x + (-0 * 4), self.pos.y)
		for i = 1, #self.chars do
			local char = s_alphabet[self.chars[i]]
			if self.fixed then
				print(char, self.pos.x + (i * 4), self.pos.y)
			elseif (i ~= self.index) or (self.elasped > self.duration) then
				-- blink
				print(char, self.pos.x + (i * 4), self.pos.y)
			end
		end
		print("]", self.pos.x + ((#self.chars+1) * 4), self.pos.y)
	end,
	is_fixed = function(self)
		return self.fixed
	end,
	is_decided = function(self)
		return self.decided
	end,
	is_first = function(self)
		return (self.index == 1)
	end,
	is_last = function(self)
		return (self.index == #self.chars)
	end,
	decide = function(self)
		self.duration = 0.1
		self.decided = true
	end,
	fix = function(self)
		self.fixed = true
	end,
	cancel = function(self)
		self.fixed = false
		self.elasped = 0
	end,
	set_index = function(self, idx)
		self.index = mid(1, idx, #self.chars)
		if self.chars[self.index] == 1 then
			self.chars[self.index] = 2
		end
	end,
	next = function(self)
		self:set_index((self.index < #self.chars) and (self.index + 1) or (1))
		self.elasped = 0
	end,
	back = function(self)
		self:set_index((self.index > 1) and (self.index - 1) or (#self.chars))
		self.elasped = 0
	end,
	roll_up = function(self)
		self.chars[self.index] = (self.chars[self.index] < #s_alphabet) and (self.chars[self.index] + 1) or (2)
		self.elasped = self.duration
	end,
	roll_down = function(self)
		self.chars[self.index] = (self.chars[self.index] > 2) and (self.chars[self.index] - 1) or (#s_alphabet)
		self.elasped = self.duration
	end,

	set_name = function(self, name)
		for i=1, #self.chars do
			self.chars[i] = (name[i] == nil or name[i] <= 0 or name[i] > #s_alphabet) and 1 or name[i]
		end
	end,
	get_name = function(self)
		return self.chars
	end
})

--------------------------------
-- sample -
--------------------------------

ball = p.define({
	const = function(self,px,py,vx,vy)
		ball._super.const(self,px,py,vx,vy,0,15)
		self.color = 7
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		ball._super.update(self,delta)

		if self.pos.x < 0 then
			self.pos.x = 0
			self.vel.x = abs(self.vel.x)
		end
		if self.pos.x > 127 then
			self.pos.x = 127
			self.vel.x = -abs(self.vel.x)
		end
		if self.pos.y > 127 then
			self.pos.y = 127
			self.vel.x =  0.8*self.vel.x
			self.vel.y = -0.8*abs(self.vel.y)
		end
	end,
	draw = function(self)
		circ(self.pos.x,self.pos.y,3,self.color)
	end
})

big_ball = p.define({
	const = function(self,px,py,vx,vy)
		big_ball._super.const(self,px,py,vx,vy)
	end,
	draw = function(self)
		circ(self.pos.x,self.pos.y,5,self.color)
	end
}, ball)

-- title ------------------------

scn_title = p.add("title")

function scn_title:init()
end

function scn_title:fin()
end

function scn_title:pre_update(delta)
	if btnp(🅾️) then
		p.move("ingame")
	end
end

function scn_title:post_update(delta)
end

function scn_title:pre_draw()
	printm("[title]",64,62,3)
end

function scn_title:post_draw()
end

-- ingame ------------------------

scn_ingame = p.add("ingame")

function scn_ingame:init()
	self.balls = {}
	self:add_ball()
end

function scn_ingame:fin()
	foreach(self.balls,
		function(ball) p.destroy(ball) end
	)
	self.balls = {}
end

function scn_ingame:pre_update(delta)
		if btnp(🅾️) then
		p.move("result")
	end
	if btnp(❎) then
		self:add_ball()
	end
end

function scn_ingame:post_update(delta)
	self:del_ball()
end

function scn_ingame:pre_draw()
end

function scn_ingame:add_ball()
	local cls = ball
	if rnd(100)>80 then cls = big_ball end
	local obj = p.create(
		cls,
		rndr(0,128),128,
		rndr(-30,30),rndr(-80,-20)
	)
	obj.color = rndir(1,15)
	obj:set_priority(rndir(0,10))
	add(self.balls, obj)
end

function scn_ingame:del_ball()
	if #self.balls > 10 then
		p.destroy(self.balls[1])
		del(self.balls, self.balls[1])
		self:del_ball()
	end
end

-- result ------------------------

scn_result = p.add("result")

function scn_result:init()
end

function scn_result:fin()
end

function scn_result:pre_update(delta)
	if btnp(🅾️) then
		p.move("title")
	end
	if btnp(❎) then
	end
end

function scn_result:pre_draw()
	printm("result",64,62,3)
end

-- init ------------------------

function _init()
	p.init()
	p.move("title")
end

-- update ----------------------

function _update()
	local delta = 1/30
	p.update(delta)
end

-- draw ------------------------

function _draw()
	cls()
	if g_dbg then p.draw_grid(8) end
	p.draw()
	if g_dbg then p.draw_debug() end
end

