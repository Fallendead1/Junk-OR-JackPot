-- Shared "make it feel alive" helpers for GuiButtons: hover grow, click
-- squash/bounce, and a springy pop-in for panels/buttons that just appeared.
-- Every client script's buttons run through this instead of each script
-- rolling its own tween code.
local TweenService = game:GetService("TweenService")

local UIJuice = {}

local HOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function scaledSize(size, factor)
	return UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
end

-- Hover grows slightly, press squashes down, release springs back to hover
-- size (or base size if the mouse already left). Safe to call on any
-- GuiButton at setup time, before or after it's parented/sized.
function UIJuice.MakeButtonJuicy(button)
	local baseSize = button.Size
	local hoverSize = scaledSize(baseSize, 1.06)
	local pressSize = scaledSize(baseSize, 0.94)
	local hovering = false

	button.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(button, HOVER_INFO, { Size = hoverSize }):Play()
	end)

	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(button, HOVER_INFO, { Size = baseSize }):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, PRESS_INFO, { Size = pressSize }):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, PRESS_INFO, { Size = hovering and hoverSize or baseSize }):Play()
	end)
end

-- Scales a GuiObject in from 0 with a springy overshoot. Call right after
-- setting Visible = true (or right after parenting something new in).
function UIJuice.PopIn(guiObject)
	local targetSize = guiObject.Size
	guiObject.Size = scaledSize(targetSize, 0.01)
	TweenService:Create(guiObject, POP_INFO, { Size = targetSize }):Play()
end

return UIJuice
