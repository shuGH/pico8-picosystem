pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

--------------------------------
-- pico system - shuzo iwasaki -
--------------------------------

g_dbg = false
g_fps = 30
g_win = {x = 128, y = 128}
s_letter = {h = 0, v = 20}

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

function vec(x,y)
	return {x = x or 0, y = y or 0}
end

function unit(x,y)
	local d = dist(x,y)
	return (d~=0) and vec(x / d, y / d) or 0
end

function dist(x1,y1,x2,y2)
	x2 = x2 or 0.0
	y2 = y2 or 0.0
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
		self.pos = vec(px,py)
		self.vel = vec(vx,vy)
		self.acc = vec(ax,ay)

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

-- info
p.draw_info = function()
	local by = 1
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

--------------------------------
-- gpio --
--------------------------------

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
-- web api -
--------------------------------

function get_null_ranking(max)
	local ranking = {}
	for i=1, max do
		add(ranking, {n={1,1,1}, s=0})
	end
	return ranking
end

api = {
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
	draw_info = function(self)
		local by = 1
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

--------------------------------
-- data -
--------------------------------

function save_name(name)
	dset(0, name[1])
	dset(1, name[2])
	dset(2, name[3])
end

function load_name()
	return {dget(0),dget(1),dget(2)}
end

function save_score(score)
	dset(3, score)
end
function load_score()
	return dget(3)
end

function init_data()
	dset(0, 0)
	dset(1, 0)
	dset(2, 0)
	dset(3, 0)
end

--------------------------------
-- common -
--------------------------------

-- debug ------------------------

s_dbg_log = {'','',''}

function set_log(i,val)
	s_dbg_log[i] = val
end

function set_logs(vals)
	vals = vals or {}
	s_dbg_log[1] = vals[1] or ''
	s_dbg_log[2] = vals[2] or ''
	s_dbg_log[3] = vals[3] or ''
end

function draw_logs()
	for i=1, #s_dbg_log do
		print(s_dbg_log[i], 0, (g_win.y-18)+6*(i-1),11)
	end
end

function draw_grid(num)
	for i=1,num-1 do
		line((128/num)*i,0, (128/num)*i,127, 2)
		line(0,(128/num)*i, 127,(128/num)*i, 2)
	end
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

-- letter box ------------------------

function draw_letter_box()
	if (s_letter.h > 0) then
		rectfill(0,0,s_letter.h-1,g_win.y,1)
		rectfill(g_win.x-s_letter.h,0,g_win.x,g_win.y,1)
	end
	if (s_letter.v > 0) then
		rectfill(0,0,g_win.x,s_letter.v-1,1)
		rectfill(0,g_win.y-s_letter.v,g_win.x,g_win.y,1)
	end
end

-- alphabet ------------------------

s_alphabet = {
	"_","*",
	"a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p",
	"q","r","s","t","u","v","w","x",
	"y","z",",",".","+","-","!","?",
}

function to_name_str(name)
	local str = ""
	for i=1, 3 do
		if name[i] and s_alphabet[name[i]] then
			str = str..s_alphabet[name[i]]
		else
			str = str..s_alphabet[1]
		end
	end
	return str
end

-- name reel ------------------------

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

-- ranking ------------------------

ranking_manager = p.define({
	const = function(self,px,py,max)
		ranking_manager._super.const(self,px,py)
		self.max = max
		self.ranking = get_null_ranking(self.max)
		self.marks = {128,129,130}
		self.loading = false
		self.cnt = 0
		self.anim = 0
		self.anim_d = 4
	end,
	dest = function(self)
		self.ranking = {}
	end,

	update = function(self,delta)
		ranking_manager._super.update(self,delta)
	end,
	draw = function(self)
		for i=1, self.max do
			local x = self.pos.x
			local y = self.pos.y + (10*(i-1))
			local name = "---"
			local score = 0
			if self.ranking[i] then
				name = to_name_str(self.ranking[i]["n"])
				score = self.ranking[i]["s"]
			 end
			printl(""..i..". ", x, y, 11)
			printl(""..name,    x+10, y, 11)
			printr(""..score,   x+64, y, 11)
			if self.marks[i] then
				spr(self.marks[i],x-12,y-2)
			end
		end

		if self.loading then
			self.cnt += 1
			if self.cnt % self.anim_d == 0 then self.anim += 1 end
			if self.anim >= 4 then self.anim = 0 end
			spr(144 + self.anim, g_win.x/2-4, g_win.x/2-4)
		end
	end,
	activate_loading = function(self, is_active)
		self.loading = is_active
		self.cnt = 0
	end,
	set_ranking = function(self, ranking)
		self.ranking = ranking
	end
})

-- effect ------------------------

effect_manager = p.define({
	const = function(self)
		effect_manager._super.const(self)
		self:set_priority(8,8)

		-- ptcl list {px,py,vx,vy,ax,ay,size,line,clr,life}
		self.ptcls = {}
		-- ptcl setting
		self.dash = {
			vx=6,vy=0,ax=0,ay=0,
			size=4,life=0.4,rect=10,clrs={6,7,7},
			num=8,line=true,ang=0
		}
		self.smoke = {
			vx=12,vy=8,ax=0,ay=16,
			size=2.6,life=0.8,rect=8,clrs={15,15,15,9},
			num=4,line=false,ang=0
		}
		self.smoke_s = {
			vx=13,vy=7,ax=0,ay=16,
			size=1.6,life=0.6,rect=8,clrs={7,7,7,6},
			num=10,line=false,ang=0
		}

		-- fade
		self.fade_duration = 0.0
		self.fade_from = 0.0
		self.fade_to = 1.0
		self.fade_elasped = -1.0
	end,
	dest = function(self)
		for i=1, #self.ptcls do
			self.ptcls[i] = {}
		end
		self.ptcls = {}
		fade_scr(0.0)
	end,

	update = function(self,delta)
		effect_manager._super.update(self,delta)
		-- ptcl
		for i=#self.ptcls, 1, -1 do
			for j=#self.ptcls[i], 1, -1 do
				local ptcl = self.ptcls[i][j]
				ptcl.vx += ptcl.ax * delta
				ptcl.px += ptcl.vx * delta
				ptcl.vy += ptcl.ay * delta
				ptcl.py += ptcl.vy * delta
				ptcl.life -= delta
				if ptcl.life < 0.0 then
					del(self.ptcls[i], ptcl)
				end
			end
			if #self.ptcls[i] == 0 then
				del(self.ptcls, self.ptcls[i])
			end
		end
		-- fade
		if self.fade_elasped >= 0.0 then
			self.fade_elasped += delta
			if (self.fade_elasped > self.fade_duration) then
				fade_scr(self.fade_from)
				self.fade_elasped = -1.0
			else
				local r = self.fade_to + ((self.fade_from - self.fade_to) * (self.fade_elasped/self.fade_duration))
				fade_scr(r)
			end
		end
	end,
	draw = function(self)
		for i=1, #self.ptcls do
			for j=1, #self.ptcls[i] do
				local ptcl = self.ptcls[i][j]
				if ptcl.line then
					local ox = ptcl.size * cos(ptcl.ang)
					local oy = ptcl.size * sin(ptcl.ang)
					line(ptcl.px, ptcl.py, ptcl.px+ox, ptcl.py+oy, ptcl.clr)
				else
					circfill(ptcl.px, ptcl.py, ptcl.size, ptcl.clr)
				end
			end
		end
	end,

	spawn_ptcl = function(self, setting, px,py, vx,vy)
		vx = vx or 0
		vy = vy or 0
		local ptcls = {}
		for i=1, setting.num do
			add(ptcls, {
				px = px + rndr(-setting.rect/2.0, setting.rect/2.0),
				py = py + rndr(-setting.rect/2.0, setting.rect/2.0),
				vx = rndr(-setting.vx, setting.vx) + vx,
				vy = rndr(-setting.vy, setting.vy) + vy,
				ax = setting.ax,
				ay = setting.ay,
				size = rndr(1,setting.size),
				clr = setting.clrs[rndir(1,#setting.clrs)],
				life = setting.life,
				line = setting.line,
				ang = setting.ang
			})
		end
		add(self.ptcls, ptcls)
	end,
	fade_in = function(self,sec)
		self.fade_duration = sec
		self.fade_from = 0.0
		self.fade_to = 1.0
		self.fade_elasped = 0.0
	end,
	fade_out = function(self,sec)
		self.fade_duration = sec
		self.fade_from = 1.0
		self.fade_to = 0.0
		self.fade_elasped = 0.0
	end
})

-- message ------------------------

message_manager = p.define({
	const = function(self)
		message_manager._super.const(self)
		self.msgs = {}
	end,
	dest = function(self)
		for i=1, #self.msgs do
			self.msgs[i] = {}
		end
		self.msgs = {}
	end,

	update = function(self,delta)
		message_manager._super.update(self,delta)
		for i=#self.msgs, 1, -1 do
			local msg = self.msgs[i]
			msg.l -= delta
			if msg.l < 0.0 then
				del(self.msgs, msg)
			end
		end
	end,
	draw = function(self)
		for i=1, #self.msgs do
			local msg = self.msgs[i]
			local f = ((msg.l % (msg.d * 2.0)) > msg.d)
			if (not msg.b) or f then printm(msg.t,msg.px,msg.py,msg.c) end
		end
	end,

	spawn_msg = function(self,x,y,text,life,is_blink,color,duration)
		local msg = {
			px = x,
			py = y,
			t = text,
			l = life,
			b = is_blink or false,
			c = color or 11,
			d = duration or 0.16
		}
		add(self.msgs, msg)
	end
})

--------------------------------
-- sample project -
--------------------------------

s_score = 0
s_name = {1,1,1}
s_ranking_max = 5
s_cart_id = 'sample'

-- objects ------------------------

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
		if self.pos.y > 127 - s_letter.v then
			self.pos.y = 127 - s_letter.v
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

message = p.define({
	const = function(self, str, px, py)
		message._super.const(self,px,py,0,-12,0,2)
		self:set_priority(20,20)
		self.str = str
		self.remaining = 0.8
	end,
	update = function(self,delta)
		message._super.update(self,delta)
		self.remaining -= delta
		if (self.remaining < 0) then
			p.destroy(self)
		end
	end,
	draw = function(self)
		printm(self.str, self.pos.x, self.pos.y,11)
	end
})

score_manager = p.define({
	const = function(self,time,ball_list)
		score_manager._super.const(self)
		self:set_priority(1000,1000)
		self.score = 0.0
		self.remaining = time
		-- state (ready, playing, stop)
		self.state = 'ready'
		self.ball_list = ball_list
	end,
	update = function(self,delta)
		score_manager._super.update(self,delta)
		if self.state == 'playing' then
			if self.remaining < 0 then
				self.state = 'stop'
			else
				self.remaining -= delta
			end
		end
	end,
	draw = function(self)
		local px = 2
		local py = s_letter.v + 2
		print("time:",px,py,11)
		printr(""..ceil(self.remaining),px+31,py,11)
		print("score:",g_win.x-px-42,py,11)
		printr(""..self:get_score(),g_win.x-px,py,11)
	end,
	start = function(self)
		self.state = 'playing'
	end,
	stop = function(self)
		self.state = 'stop'
	end,
	get_score = function(self)
		return #self.ball_list * 10
	end,
})

-- title ------------------------

scn_title = p.add("title")

function scn_title:init()
	set_logs({})
	if g_dbg then
		local n = load_name()
		set_log(3,"["..n[1]..","..n[2]..","..n[3].."] "..load_score())
	end

	self.next = ""
	self.duration = 0.16
	self.elasped = -1.0

	self.effect = p.create(effect_manager)
end

function scn_title:fin()
	p.destroy(self.effect)
end

function scn_title:pre_update(delta)
	if self.elasped >= 0.0 then
		self.elasped += delta
		if self.elasped > 0.8 then
			p.move(self.next)
		end
		-- button disable
		return
	end

	if btnp(🅾️) then
		self.next = "ingame"
		self.elasped = 0.0
	end
	if btnp(❎) then
		if api.elasped < 0 then
			p.move("ranking")
		end
	end
end

function scn_title:post_update(delta)
end

function scn_title:pre_draw()
	printm("[title]",64,62,3)

	local px = 34
	local col = 7
	if self.elasped < 0 then
		print("press 🅾️ start",px,88,col)
		print("press ❎ ranking",px,98,col)
	else
		local d = self.duration * 2.0
		local f = (self.elasped % d > self.duration)
		if self.next ~= "ingame" or f then
			print("press 🅾️ start",px,88,col)
		end
		if self.next ~= "ranking" or f then
			print("press ❎ ranking",px,98,col)
		end
	end
end

function scn_title:post_draw()
end

-- ingame ------------------------

scn_ingame = p.add("ingame")

function scn_ingame:init()
	set_logs({})
	s_score = 0

	-- state (demo, playing, ended)
	self.state = 'demo'
	self.elasped = 0.0
	self.balls = {}

	self.effect = p.create(effect_manager)
	self.score = p.create(score_manager,60,self.balls)
	self.msg = p.create(message_manager)

	self.score:start()
	self.effect:fade_in(0.8)
end

function scn_ingame:fin()
	s_score = self.score:get_score()

	p.destroy(self.effect)
	p.destroy(self.score)
	p.destroy(self.msg)
	foreach(self.balls,
		function(ball) p.destroy(ball) end
	)
	self.balls = {}
end

function scn_ingame:pre_update(delta)
	set_log(1, self.state)
	set_log(2, self.cnt)
	set_log(3, #self.balls)

	-- update
	if self.state == 'demo' then
		if self.cnt/g_fps > 2.4 then
			self.state = 'playing'
			self.cnt = 0
			self.msg:spawn_msg(64,48,"[start]",2.0,true)
			self:add_ball()
		end
	elseif self.state == 'playing' then
		if self.score.state == 'stop' then
			self.state = 'ended'
			self.cnt = 0
			self.msg:spawn_msg(64,48,"[time over]",2.0,true)
		end
	elseif self.state == 'ended' then
		-- goto result
		if self.cnt/g_fps > 3.2 then
			p.move("result")
		end
		-- fade
		if self.cnt/g_fps > 2.0 and self.effect.fade_elasped < 0.0 then
			self.effect:fade_out(1.2)
		end
	end

	-- collision
	if self.state == 'playing' then
	end

	-- input
	if self.state == 'playing' then
		if btnp(🅾️) then
			self:add_ball()
		end
		if btnp(❎) then
			if self.cnt/g_fps > 2.0 then
				self.state = 'ended'
				self.cnt = 0
				self.msg:spawn_msg(64,48,"[game over]",2.0,true)
			end
		end
	end
end

function scn_ingame:post_update(delta)
	self:cull_ball()
end

function scn_ingame:pre_draw()
end

function scn_ingame:post_draw()
	-- state
	if self.state == 'demo' then
		printm("press 🅾️ ball, ❎ exit",60,98,12)
	end
end

function scn_ingame:add_ball()
	local cls = ball
	if rnd(100)>80 then cls = big_ball end
	local obj = p.create(
		cls,
		rndr(0,128),128 - s_letter.v,
		rndr(-30,30),rndr(-80,-20)
	)
	obj.color = rndir(1,15)
	obj:set_priority(rndir(0,10))
	add(self.balls, obj)
end

function scn_ingame:cull_ball()
	for i=#self.balls, 1, -1 do
		local b = self.balls[i]
		if dist(b.vel.x,b.vel.y) < 1.0 then
			del(self.balls, b)
			p.destroy(b)
		end
	end
end

-- result ------------------------

scn_result = p.add("result")

function scn_result:init()
	self.reel = p.create(
		char_reel, g_win.x/2 - 10, g_win.y/2 + 4, 3, 7
	)
	self.reel:set_name(load_name())
	self.reel:set_index(1)
	self.is_new = s_score > load_score()
	self.elasped = -1.0
	self.effect = p.create(effect_manager)

	fade_scr(0.0)
end

function scn_result:fin()
	p.destroy(self.reel)
	p.destroy(self.effect)
end

function scn_result:pre_update(delta)
	-- s_dbg_log[1] = ""

	if self.elasped >= 0 then
		self.elasped += delta
		-- goto title after decided
		if self.elasped >= 2.0 then
			p.move("title")
		end
		-- button disable
		return
	end

	if btnp(⬆️) or btnp(➡️) then
		if not self.reel:is_fixed() then
			self.reel:roll_up()
		end
	end
	if btnp(⬇️) or btnp(⬅️) then
		if not self.reel:is_fixed() then
			self.reel:roll_down()
		end
	end
	if btnp(🅾️) then
		if self.reel:is_fixed() then
			if api.elasped < 0 then
				self.reel:decide()
				self.elasped = 0.0

				-- update and post result
				s_name = self.reel:get_name()
				save_name(s_name)
				if self.is_new then save_score(s_score) end
				api:post(s_name, s_score, function()
				end)
			end
		else
			if not self.reel:is_last() then
				self.reel:next()
			else
				self.reel:fix()
			end
		end
	end
	if btnp(❎) then
		if self.reel:is_fixed() then
			self.reel:cancel()
		else
			if not self.reel:is_first() then
				self.reel:back()
			end
		end
	end
end

function scn_result:pre_draw()
	local px = 64
	printm("thank you for playing!",64,26,3)

	print("score: ",   34,   60,11)
	printr(""..s_score,34+56,60,11)

	if self.is_new then
		printl("new!!",34+56+4,60,9)
	end
	if (self.reel:is_fixed() and self.elasped < 0) then
		printl("ok?",82,68,6)
	end

	px = 24
	print("press ⬇️ down, ⬆️ up",px,99,12)
	print("press ❎ back, 🅾️ ok",px,109,12)
end

------------------------------------------------------------------------------------------------
-- ranking
------------------------------------------------------------------------------------------------

scn_ranking = p.add("ranking")

function scn_ranking:init()
	self.ranking = p.create(
		ranking_manager, 34, 42, s_ranking_max
	)
	-- get ranking
	api:pull(function(ranking)
		self.ranking:set_ranking(ranking)
		self.ranking:activate_loading(false)
	end)
	self.ranking:activate_loading(true)
end

function scn_ranking:fin()
	api:exit()
	p.destroy(self.ranking)
end

function scn_ranking:pre_update(delta)
	if btnp(🅾️) then
	end
	if btnp(❎) then
		p.move("title")
	end
end

function scn_ranking:pre_draw()
	printm("[ranking]",64,26,3)
	print("press ❎ title",37,98,12)
end

-- init ------------------------

function _init()
	p.init()
	p.move("title")
	cartdata(s_cart_id)
	api:init(s_ranking_max)
end

-- update ----------------------

function _update()
	local delta = 1/g_fps
	p.update(delta)
	api:update(delta)
end

-- draw ------------------------

function _draw()
	cls()
	if g_dbg then draw_grid(8) end
	p.draw()
	draw_letter_box()
	if p.current.name == "title" then
		printm("(c) shuzo.i 2000", g_win.x / 2, g_win.y-7, 13)
	end
	if g_dbg then
		draw_logs()
		p.draw_info()
		api:draw_info()
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a00a00006666000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0aaaa0a006666000004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa006666000044244000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa000550000004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a9999a0000550000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09999990006666000044444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000660000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000070070000600600005005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006700000056000000050000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006700000056000000050000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05000060000000500700000006000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055000000000000007700000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
