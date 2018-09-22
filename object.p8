pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
g_scns = {}
g_dbg = true

-- util ------------------------

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

function isort(list, fnc)
	for i=1,#list do
		local j=i
		while j>1 and fnc(list[j-1], list[j]) do
			local t = list[j-1]
			list[j-1] = list[j]
			list[j] = t
			j-=1
		end
	end
end

function inherit(sub, super)
	super = super or {}
	sub._super = super
	return setmetatable(
		sub, {__index = super}
	)
end

function class(sub, super)
	local obj = inherit({}, inherit(sub, super))
	--local obj = inherit(inherit({}, sub), super)
	if obj._const then obj:_const() end
	return obj
end

-- scene ------------------------

g_scns = {
	scns = {},
	current = nil,
	next = nil,
	objs = {
 	update = {},
 	draw = {},
	}
}

function scene(nm)
	return class(
		{
			name = nm,
			cnt = 0,
			init = function(self)
				self.cnt = -1
			end,
			fin = function(self)
			end,
			pre_update = function(self,delta)
				self.cnt += 1
			end,
			post_update = function(self,delta) end,
			pre_draw = function(self) end,
			post_draw = function(self) end
		}
	)
end

function reg_scn(scn)
 g_scns.scns[scn.name] = scn
end

function move_scn(name)
	if not g_scns.scns[name] then return end
	g_scns.next = g_scns.scns[name]
end

function pre_update_scns(delata)
	if g_scns.next then
	 g_scns.current = g_scns.next
	 g_scns.current:init()
	 g_scns.next = nil
	end

	if g_scns.current then
		g_scns.current:pre_update(delta)
	end
end

function post_update_scns(delta)
	if g_scns.current then
		g_scns.current:post_update(delta)
	end

	if g_scns.next then
		g_scns.current:fin()
		foreach(g_scns.objs.update,
			function(obj) obj:destroy() end
		)
		g_scns.current.objs = nil
	end
end

function pre_draw_scns()
	if g_scns.current then
		g_scns.current:pre_draw()
	end
end

function post_draw_scns()
	if g_scns.current then
		g_scns.current:post_draw()
	end
end

-- object ------------------------

function reg_obj(obj)
	add(g_scns.objs.update, obj)
	isort(g_scns.objs.update, sort_obj_update)
	add(g_scns.objs.draw, obj)
	isort(g_scns.objs.draw, sort_obj_draw)
end

function unreg_obj(obj)
	del(g_scns.objs.update, obj)
	del(g_scns.objs.draw, obj)
end

function sort_obj_update(a,b)
	return a._p.update > b._p.update
end

function sort_obj_draw(a,b)
	return a._p.draw > b._p.draw
end

function object(px,py,vx,vy,ax,ay,pu,pd)
 return class(
		{
			_p  = {update=pu or 0, draw=pd or pv or 0},
			pos = {x=px or 0, y=py or 0},
			vel = {x=vx or 0, y=vy or 0},
			acc = {x=ax or 0, y=ay or 0},

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
				self._p.update = pu or 0
				self._p.draw   = pd or self._p.update
				isort(g_scns.objs.update, sort_obj_update)
				isort(g_scns.objs.draw, sort_obj_draw)	
			end,

			destroy = function(self)
				unreg_obj(self)
			end,
			_const = function(self)
				reg_obj(self)
			end
		}
	)
end

function update_objs(delta)
	foreach(g_scns.objs.update,
		function(obj) obj:update(delta) end
	)
end

function	draw_objs()
	foreach(g_scns.objs.draw,
		function(obj) obj:draw() end
	)
end

function ball(px,py,vx,vy)
	obj = class(
		{
			color = 7,
			update = function(self,delta)
				self.color += 1
			end,
			draw = function(self)
				circ(self.pos.x,self.pos.y,3,self.color)
			end
		}
		,object(px,py,vx,vy,0,15)
	)
	--obj._super.update = function(self,delta)
	--end
	--obj._super._super.draw = function(self)
	--end
	return obj
end

-- title ------------------------

scn_title = scene("title")

function scn_title:init()
	self._super:init()
end

function scn_title:fin()
	self._super:fin()
end

function scn_title:pre_update(delta)
	self._super:pre_update(delta)
	
	if btnp(🅾️) then
		move_scn("ingame")
	end
end

function scn_title:post_update(delta)
	self._super:post_update(delta)
end

function scn_title:pre_draw()
	self._super:pre_draw()

	printm("[title]",64,64,3)
end

function scn_title:post_draw()
	self._super:post_draw()
end

-- ingame ------------------------

scn_ingame = scene("ingame")

function scn_ingame:init()
	self._super:init()
	
	self.balls = {}
	self:add_ball()
end

function scn_ingame:add_ball()
	local obj = ball(
	 	rndr(0,128),128,
			rndr(-30,30),rndr(-80,-20)
	)
	obj.color = rndir(1,15)
	obj:set_priority(rndir(0,10))
	add(self.balls, obj)
end

function scn_ingame:del_ball()
	if #self.balls > 10 then
		self.balls[1]:destroy()
		del(self.balls, self.balls[1])	
		self:del_ball()
	end	
end

function scn_ingame:fin()
	self._super:fin()
end

function scn_ingame:pre_update(delta)
	self._super:pre_update(delta)
	
	if btnp(🅾️) then
		move_scn("result")
	end
	if btnp(❎) then
	 self:add_ball()
	end
end

function scn_ingame:post_update(delta)
	self._super:post_update(delta)

	self:del_ball()
end

function scn_ingame:pre_draw()
	self._super:pre_draw()
end

function scn_ingame:post_draw()
	self._super:post_draw()
end

-- result ------------------------

scn_result = scene("result")

function scn_result:init()
	self._super:init()
end

function scn_result:fin()
	self._super:fin()
end

function scn_result:pre_update(delta)
	self._super:pre_update(delta)

	if btnp(🅾️) then
		move_scn("title")
	end
	if btnp(❎) then
	end
end

function scn_result:post_update(delta)
	self._super:post_update(delta)
end

function scn_result:pre_draw()
	self._super:pre_draw()

	printm("result",64,64,3)
end

function scn_result:post_draw()
	self._super:post_draw()
end

-- init ------------------------

function _init()
	g_objs = {}
	
	reg_scn(scn_title)
	reg_scn(scn_ingame)
	reg_scn(scn_result)
	move_scn("title")
end

-- update ----------------------

function _update()
	local delta = 1/30
	pre_update_scns(delta)
	update_objs(delta)
 post_update_scns(delta)
end

-- draw ------------------------

function draw_grid(num)
	for i=1,num-1 do
		line(
			(128/num)*i,0,
			(128/num)*i,127,2)
		line(
			0,(128/num)*i,
			127,(128/num)*i,2)
	end
end

function draw_debug()
	print("",0,0,11)
	print("scn: "..g_scns.current.name.." "..g_scns.current.cnt)
	print("obj: "..#g_scns.objs.update)

	if #g_scns.objs.update > 0 then
 	local str=""
 	for i=1,#g_scns.objs.update do
 		str = str..g_scns.objs.update[i]._p.update
 		if i<#g_scns.objs.update then str = str.."," end
 	end
 	print("ord: "..str)
 end
end

function _draw()
	cls()
	if g_dbg then draw_grid(8) end
	pre_draw_scns()
	draw_objs()
	post_draw_scns()
	if g_dbg then draw_debug() end
end

