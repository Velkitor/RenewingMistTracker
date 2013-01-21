local RenewingMistTracker = _G.RenewingMistTracker

local slash_cmd = {}
RenewingMistTracker.slash_cmd = slash_cmd
-- Setup Slash Commands
SLASH_REMTRACKER1, SLASH_REMTRACKER2 = '/rem', '/remtracker'

function SlashCmdList.REMTRACKER(msg, editbox) -- 4.
	local command, rest = msg:match("^(%S*)%s*(.-)$");
	command = string.lower( command )
	if command == "" or command == "info" or command == "help" then
		slash_cmd:DisplayHelp()
	elseif command == "scale" then
		slash_cmd:ScaleUi( rest )
	elseif command == "position" or command == "pos" then
		slash_cmd:PositionUi( rest )
	end
	
end

function slash_cmd:DisplayHelp()
	DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker Slash Commands", 0.5, 1, 0.831 )
	DEFAULT_CHAT_FRAME:AddMessage( "====================================", 1,1,1 )
	DEFAULT_CHAT_FRAME:AddMessage( "/rem, /rem info, /rem help - This Menu", 1,1,1 )
	DEFAULT_CHAT_FRAME:AddMessage( "/rem scale # - Sets the scale of the RemTracker frame", 1,1,1 )
end

function slash_cmd:ScaleUi( rest )
	local value = tonumber( rest )
	if not value or value < 0.1 then
		DEFAULT_CHAT_FRAME:AddMessage( "Please specify a valid number for the ui scale", 1,1,1 )
		DEFAULT_CHAT_FRAME:AddMessage( "/rem scale # - Sets the scale of the RemTracker frame", 1,1,1 )
	end
	RenewingMistTracker.ui:Scale( value )
end

function slash_cmd:PositionUi( rest )
	local x_str, y_str = rest:match("^(%S*)%s*(.-)$");
	local x = tonumber( x_str ) or 1
	local y = tonumber( y_str ) or 1
	RenewingMistTracker.ui:SetPosition( x, y )
end