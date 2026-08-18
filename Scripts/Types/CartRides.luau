-- Cart Ride Script

local Window, Esp = ... -- Get APIs via VarArgs

local Player = game:GetService("Players").LocalPlayer

local Tab = Window:TypeTab("Cart Rides") -- Spawn a Tab for the Game Type. This will get put under the "Game Type" title in the UI, and will get saved locally per-game

local CatTab = Tab:NoCategory() -- Some scripts may not need Categories, so, for this, we just do "NoCategory", which makes the main "Cart Rides" button just open up this tab

CatTab:AddTextBox("victim")

local offset = CatTab:AddVector2("Offset", Vector2.new(1,0)) -- You don't HAVE to do ":Get" by the way. It's only an example in victim
-- Vector2 has a nice "Joystick-like" input thing, while Vector3 just has numbers.
-- Vector2 also has numbers, but in most cases, the Joystick-like thing is better.


local flingToggle
flingToggle = CatTab:AddLoopingToggle("Start Fling", function() -- This will get run from a :Heartbeat loop, but ONLY if the value is true.
	local victim = Window.Helpers:GetPlayer( CatTab:Get("victim").Value ) -- GetPlayer checks if it's "me" (LocalPlayer), the start of a player's normal ".Name" (priority) or their ".DisplayName" (convenience)
	if victim == nil then
		Window:Notification(2, "Player not Found!") -- Post a notification that exists for 2 seconds
	end
	local myChar = Player.Character
	local victimChar = victim.Character
	if myChar == nil or victimChar == nil then return end

	local myHrp = myChar.HumanoidRootPart
	local victimHrp = victimChar.HumanoidRootPart
	if myHrp == nil or victimHrp == nil then return end

	myHrp.CFrame = CFrame.new(victimHrp.CFrame.Position + offset:ToXZ()) -- Helper function to convert to Vector2 with X and Z values. .Value returns the Vector2, :ToXY() with X and Y values, and :ToYZ() with Y and Z values.
	if victim.Humanoid.Sit then
		myHrp.CFrame.Position = CFrame.new(VoidTarget)
	end
end,
function(value) -- This function gets called whenever you toggle the switch. Not in the loop, just when the value changes
	if value then
		flingToggle:SetText("Stop Fling")
	else
		flingToggle:SetText("Start Fling")
	end
end)


-- Type Tabs can have a cleanup script because you CAN actually disable them again!
Tab:Cleanup(function()
	flingToggle:Stop()
end)
