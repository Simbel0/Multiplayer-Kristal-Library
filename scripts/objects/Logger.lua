local Logger, super = Class(Object)

function Logger:init()
	super.init(self, 0, 0)
	self.layer = 10000000 - 2

	self.history = {}
	self.wrapped_history = {}

	self.font_size = 16
    self.font_name = "main_mono"

    self.font = Assets.getFont(self.font_name, self.font_size)

	self.width = 300
	self.height = 150

	self.alpha = 0

	self.timer = 0
	self.timer_max = 100 -- TODO: read lib config
end

function Logger:update()
	self.timer = self.timer - DTMULT
	if self.timer < 0 then
		self.alpha = Utils.approach(self.alpha, 0, 0.05*DTMULT)
	else
		self.alpha = 1
	end
end

function Logger:draw()
	love.graphics.setColor(0, 0, 0, 0.5*self.alpha)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)

	love.graphics.setFont(self.font)
	local offset = 0
	for i=#self.wrapped_history, 1, -1 do
		local color = {1, 1, 1}
		local text = self.wrapped_history[i]
		if type(text) == "table" then
			color, text = unpack(text)
		end

		local r, g, b = unpack(color)
		Draw.setColor(r, g, b, self.alpha)

		love.graphics.printf(text, 0, (self.height-self.font_size)-offset, self.width)
		
		offset = offset + self.font_size
	end
end

-- A smarter person could probably figure out how to do the wrapping without this function
-- But I am not smart
function Logger:getWrappedHistory()
	local whistory = {}
	for i,text in ipairs(self.history) do
		if type(text) == "table" then
			local color, text = unpack(text)
			local _, lines = self.font:getWrap(text, self.width)
			for i,line in ipairs(lines) do
				table.insert(whistory, {color, line})
			end
		else
			local _, lines = self.font:getWrap(text, self.width)
			for i,line in ipairs(lines) do
				table.insert(whistory, line)
			end
		end
	end
	return whistory
end

function Logger.log(msg, origin, color)
	local prefix = "[Multiplayer]"
	if origin then
		prefix = "[Multiplayer "..StringUtils.titleCase(origin).."]"
	end
	local log_msg = prefix.." "..msg

	print(log_msg)
	Kristal.Console:push(log_msg)
	if color then
		log_msg = {color, log_msg}
	end
	Game.logger:addToHistory(log_msg)
end

function Logger:addToHistory(msg)
	table.insert(self.history, msg)
	self.timer = self.timer_max
	if #self.history > math.floor(self.height/self.font_size) then
		table.remove(self.history, 1)
	end
	self.wrapped_history = self:getWrappedHistory()
end

return Logger