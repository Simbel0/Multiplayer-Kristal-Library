local Logger, super = Class(Object)

function Logger:init()
	super.init(self, 0, 0)
	self.layer = 10000000 - 2
	self.history = {}

	self.font_size = 16
    self.font_name = "main_mono"

    self.font = Assets.getFont(self.font_name, self.font_size)

	self.width = 300
	self.height = 150

	self.alpha = 0

	self.timer = 0
	self.old_history_length = #self.history
end

function Logger:update()
	self.timer = self.timer - DTMULT
	if self.timer < 0 then
		self.alpha = Utils.approach(self.alpha, 0, 0.05*DTMULT)
	else
		self.alpha = 1
	end

	if self.old_history_length ~= #self.history then
		if #self.history > self.old_history_length then
			self.timer = 100
		end
		self.old_history_length = #self.history
	end
end

function Logger:draw()
	love.graphics.setColor(0, 0, 0, 0.5*self.alpha)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)

	Draw.setColor(1, 1, 1, self.alpha)
	love.graphics.setFont(self.font)
	local offset = 0
	local wrapped_history = self:getWrappedHistory()
	for i=#wrapped_history, 1, -1 do
		local text = wrapped_history[i]
		love.graphics.printf(text, 0, (self.height-self.font_size)-offset, self.width)
		
		offset = offset + self.font_size
	end
end

-- A smarter person could probably figure out how to do the wrapping without this function
-- But I am not smart
function Logger:getWrappedHistory()
	local whistory = {}
	for i,text in ipairs(self.history) do
		local _, lines = self.font:getWrap(text, self.width)
		for i,line in ipairs(lines) do
			table.insert(whistory, line)
		end
	end
	return whistory
end

function Logger.log(msg, origin)
	local prefix = "[Multiplayer]"
	if origin then
		prefix = "[Multiplayer "..StringUtils.titleCase(origin).."]"
	end
	local log = prefix.." "..msg

	print(log)
	Kristal.Console:push(log)
	table.insert(Game.logger.history, log)
end

return Logger