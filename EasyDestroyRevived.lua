local aname = ...
-- Global Vars
--[[
	<Frame name="EasyDestroy" hidden="false">
		<Scripts>
			<OnLoad>
				-- Disables the DeleteCursorItem() call for testing when true
				EasyDestroy_Debug = false;
				EasyDestroy_OnLoad(self);
			</OnLoad>
			<OnEvent function="EasyDestroy_OnEvent" />
		</Scripts>
	</Frame>
	
--]]
local f = CreateFrame("Frame", aname)
VERSION = GetAddOnMetadata(aname, "Version");
AddonNamePlain = "%s" .. aname .. "%s";
AddonName = string.format(AddonNamePlain, "|cffff00ff", "|r");

-- Binding Vars
BINDING_HEADER_ED						= string.format(AddonNamePlain, "", "", "", "");
BINDING_NAME_EDOPTIONS				= "Easy Destroy Revived Options Frame";
BINDING_NAME_EDTOGGLE				= "Enable or Disable " .. aname;
BINDING_NAME_EDNOTIFY				= "Enable or Disable Notifications";
BINDING_NAME_EDCURSOR				= "Destroy what you just picked up";
BINDING_NAME_EDCONVERT				= "Manually convert the old safe list";
BINDING_NAME_EDSAFELIST				= "Show the safe list in the chat window";
BINDING_NAME_EDSAFELISTADD			= "Add the cursor item to the safe list";
BINDING_NAME_EDSAFELISTREMOVE		= "Remove the cursor item from the safe list";

QUALITY_FLOOR = 2;

-- For items of quality >= QUALITY_FLOOR (Green, Blue, Purple) we want to confirm that they
-- want to delete the item.	They can repeat the procedure to delete it.
LAST_ITEM_BAG = nil;
LAST_ITEM_SLOT = nil;
LAST_ITEM_LINK = nil;
LAST_CONFIRM = 0;

EasyDestroy_Options = { 
	Notify = false;
	On = true;
	Converted = false;
	KeyBoardShortcuts = true;
};

EasyDestroy_Safe = {
	["Hearthstone"] = true;
};
local aName, aVer = AddonName, VERSION;

-- OnLoad functions, set up Print, logon spam (:p), hooking and register events
function EasyDestroy_OnLoad(self)
	-- Disables the DeleteCursorItem() call for testing when true
	EasyDestroy_Debug = false;

	-- Make sure we have non-nil options
	if EasyDestroy_Options.Notify == nil then
		EasyDestroy_Options.Notify = false;
	end
	
	if EasyDestroy_Options.On == nil then
		EasyDestroy_Options.On = true;
	end
	
	if EasyDestroy_Options.Converted == nil then
		EasyDestroy_Options.Converted = false;
	end
	
	if EasyDestroy_Options.KeyBoardShortcuts == nil then
		EasyDestroy_Options.KeyBoardShortcuts = true;
	end
	--
	
	UIErrorsFrame:AddMessage(aName.." version "..aVer.." loaded.");
	if (not Print) then
		Print = function (x, ...)
			local r,g,b = ...;
			if (not r) then
				r = 1.0;
			end
			if (not g) then
				g = 1.0;
			end
			if (not b) then
				b = 1.0;
			end
			DEFAULT_CHAT_FRAME:AddMessage(x, r, g, b);
		end
	end

	Print("|cffffffff["..AddonName.."] " .. VERSION .. " loaded.|r");
	
	UIPanelWindows[aname .. "Options"] = {area = "center", pushable = 0};

	-- Events
	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	
	-- Slash Command Handler (added by Whizzbang)
	SlashCmdList["EASYD"] = EasyDestroy_Cmd;
	SLASH_EASYD1 = "/ed";
	SLASH_EASYD2 = "/easydestroy";
end

local function IsKeyAlreadyBound_helper(key, command, ...)
	for i = 1, select("#", ...) do
		if select(i, ...) == key then
			return true
		end
	end
end

local function IsKeyAlreadyBound(key)
	for i = 1, GetNumBindings() do
		if IsKeyAlreadyBound_helper(key, GetBinding(i)) then
			return true
		end
	end
end

if not SaveBindings then
	function SaveBindings(p)
			AttemptToSaveBindings(p)
	end
end

-- OnEvent functions, mainly to add myAddOns support
f:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		LoadAddOn("Blizzard_BindingUI")
		-- import the old bindings
		local key = (GetBindingKey("EDCURSOR")) or (GetBindingKey("CURSOR")) or (not IsKeyAlreadyBound("DELETE") and "DELETE")
		if key then
			SetBinding(key, "EDCURSOR")
		end
		for binding in pairs{"TOGGLE", "NOTIFY"} do
			local key = (GetBindingKey("ED" .. binding)) or (GetBindingKey(binding))
			if key then
				SetBinding(key, "ED" .. binding)
			end
		end
		if not IsKeyAlreadyBound("CTRL-S") then
			SetBinding("CTRL-S", "EDSAFELISTADD")
		end
		if not IsKeyAlreadyBound("CTRL-R") then
			SetBinding("CTRL-R", "EDSAFELISTREMOVE")
		end
		CreateFrame("Frame"):SetScript("OnUpdate", function(self)
			local CurrentBindingSet = GetCurrentBindingSet()
			if CurrentBindingSet then
				SaveBindings(CurrentBindingSet)
				self:Hide()
			end
		end)
	elseif ( event == "VARIABLES_LOADED" ) then
		-- myAddOns support
		EasyDestroyOptions.name = EasyDestroyOptions:GetName()
		InterfaceOptions_AddCategory(EasyDestroyOptions)
		EasyDestroyOptions:SetScript("OnHide", function(self)
			self:SetParent(UIParent)
		end)
		if ( myAddOnsFrame ) then
			myAddOnsList.EasyDestroy = {
				name = aname .. "Safe",
				releaseDate = "October 20, 2005",
				author = "tsigo, Wilz, Whizzbang",
				description = "Quickly and easily destroy items.",
				version = VERSION,
				category = MYADDONS_CATEGORY_INVENTORY,
				optionsframe = aname .. "Options",
			};
		end
		if (not EasyDestroy_Options["Converted"]) then
			-- Normalize an old Database.
			local temp = {};
			for k,v in pairs(EasyDestroy_Safe) do
				local _, _, itemName = strfind(k, "h%[(.*)%]%|h");
				if (EasyDestroy_Debug) then
					Print("|cffffffff["..AddonName.."]" .. " Checking "..k..".|r");
				end
				if (itemName ~= nil) then
					EasyDestroy_Safe[k] = nil;
					temp[itemName] = true;
				else
					temp[k] = true;
				end
			end
			if (temp) then
				EasyDestroy_Safe = temp;
			end
			EasyDestroy_Options["Converted"] = true;
		end
	end
end)

function EasyDestroy_GetCmd(msg)
	if msg then
		local a,b,c=strfind(msg, "(%S+)"); --contiguous string of non-space characters
		if a then
			return c, strsub(msg, b+2);
		else	
			return "";
		end
	end
end

-- Slash Command Handler (added by Whizzbang)
function EasyDestroy_Cmd(msg)
		if (msg) then
		local cmd, sub = EasyDestroy_GetCmd(msg);

		if (cmd ~= nil) then
			cmd = cmd:lower();
		end

		if( cmd == "notify" ) then
			if(EasyDestroy_Options.Notify) then
				EasyDestroy_Options.Notify = false;
				Print("|cffffffff["..AddonName.."]" .. " Destroy notifcation |cffff0000disabled|r.|r");
			else
				EasyDestroy_Options.Notify = true;
				Print("|cffffffff["..AddonName.."]" .. " Destroy notifcation |cff00ff00enabled|r.|r");
			end
 		elseif ( cmd == 'debug' ) then
			EasyDestroy_Debug = (not EasyDestroy_Debug);
			local temporarily, mode;
			if (EasyDestroy_Debug) then
				temporarily, mode = " (temporarily)", "On\nDebug mode will turn off on reload or relog.";
			else
				temporarily, mode = "", "Off";
			end
			Print("|cffffffff["..AddonName.."] Debug mode"..temporarily..": "..mode.."|r");
		elseif( cmd == "showoptions" ) then
			EasyDestroyOptions:Show();
		elseif( cmd == "toggle" ) then
			if(EasyDestroy_Options.On) then
				EasyDestroy_Options.On = false;
				Print("|cffffffff["..AddonName.."] |cffff0000disabled|r.|r");
			else
				EasyDestroy_Options.On = true;
				Print("|cffffffff["..AddonName.."] |cff00ff00enabled|r.|r");
			end
		elseif ( cmd == "showsafe" ) then
			EasyDestroy_SafeList_Show();
		elseif ( cmd == 'keyboard' ) then
			EasyDestroy_Options.KeyBoardShortcuts = (not EasyDestroy_Options.KeyBoardShortcuts);
			Print("|cffffffff["..AddonName.."] |cff00ff00Keyboard Shortcuts: "..tostring(EasyDestroy_Options.KeyBoardShortcuts).."|r.|r");
		elseif cmd == "options" then
			EasyDestroyOptions_Toggle()
		elseif ( sub ) then
			EasyDestroy_AddRemove(sub, cmd);
		else
			Print("|cffffffff["..AddonName.."]" .. " Usage:|r");
			Print("|cffffffff"..SLASH_EASYD1..": Shortcut slash.|r");
			Print("|cffffffff"..SLASH_EASYD2.." notify: |cff00ff00Enabled|r or |cffff0000Disabled|r notifications.|r");
			Print("|cffffffff"..SLASH_EASYD2.." showoptions: Open the options menu.|r");
			Print("|cffffffff"..SLASH_EASYD2.." toggle: |cff00ff00Enabled|r or |cffff0000Disabled|r "..AddonName..".|r");
			Print("|cffffffff"..SLASH_EASYD2.." showsafe: Print safe list.|r");
			Print("|cffffffff"..SLASH_EASYD2.." add [item link]: Add an item to the safe list (use Shift-Click or type the item's name).|r");
			Print("|cffffffff"..SLASH_EASYD2.." remove [item link]: Remove an item from the safe list (use Shift-Click or type the item's name).|r");
			Print("|cffffffff"..SLASH_EASYD2.." keyboard: Toggle Keyboard Shortcuts on/off.|r");
			Print("|cffffffff"..SLASH_EASYD2.." options: Show the options frame.|r");
			Print("|cffffffffKeyboard Shortcuts (pick up an item and the do the shortcut)|r");
			local deleteKey = GetBindingKey("EDCURSOR")
			local saveKey = GetBindingKey("EDSAFELISTADD")
			local removeKey = GetBindingKey("EDSAFELISTREMOVE")
			if deleteKey then
				Print("|cffffffff[" .. deleteKey .. "] " .. BINDING_NAME_EDCURSOR .. ".|r");
			end
			if saveKey then
				Print("|cffffffff[" .. saveKey .. "] " .. BINDING_NAME_EDSAFELISTADD .. ".|r");
			end
			if removeKey then
				Print("|cffffffff[" .. removeKey .. "] " .. BINDING_NAME_EDSAFELISTREMOVE .. ".|r");
			end
		end
	end
end

function EasyDestroy_SafeList_Show()
	local output = "";
	local count = 0;
	for k,v in pairs(EasyDestroy_Safe) do
		if (output == "") then
			output = k;
		else
			output = output.."\n"..k;
		end
		count = count + 1;
	end
	Print("|cffffffff["..AddonName.."] Safe List ("..count.."):|r");
	if (count == 0) then
		Print('There are no items in safe list.');
	else
		Print(output);
	end
end

function EasyDestroy_AddRemove(sub, cmd)
	if sub == 'add' or sub == 'remove' then
		local _, _, itemLink = GetCursorInfo();
		cmd = sub
		sub = itemLink
	end

	if (sub == nil) then
		return false;
	end
	
	local itemName, tempsub = GetItemInfo(sub);
	if ( not itemName ) then
		Print("|cffffffff["..AddonName.."] Could not find "..sub.."|r");
	else
		if ( cmd == 'add' ) then
			if (EasyDestroy_Safe[itemName]) then
				Print("|cffffffff["..AddonName.."] "..tempsub.." is already on your safe list.|r");
			else
				EasyDestroy_Safe[itemName] = true;
				Print("|cffffffff["..AddonName.."] "..tempsub.." added to safe list.|r");
			end
		elseif ( cmd == 'remove' ) then
			if (EasyDestroy_Safe[itemName]) then
				EasyDestroy_Safe[itemName] = nil;

				Print("|cffffffff["..AddonName.."] "..tempsub.." removed safe list.|r");
			else
				Print("|cffffffff["..AddonName.."] "..tempsub.." is not in safe list.|r");
			end
		end
	end
end

local Old_ContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick;
function ContainerFrameItemButton_OnModifiedClick(self, button)
	if ( button == "RightButton" and EasyDestroy_Options.On and IsAltKeyDown() and IsShiftKeyDown() and not IsControlKeyDown() ) then
		EasyDestroy_DestroyItem(self:GetParent():GetID(), self:GetID());
	else
		Old_ContainerFrameItemButton_OnModifiedClick(self, button);
	end
end

function EasyDestroy_Do_Item_Check(itemLink, qualityText, ...)
	local bag, slot = ...;
	if (not bag) then
		bag = -1;
	end
	if (not slot) then
		slot = -1;
	end

	-- If the item's quality is >= 2 (Green or better), then we want to make sure they *really* want to delete this.
	-- This is accomplished through making them do the procedure a second time within 5 seconds.

	Print("|cffffffff["..AddonName.."] " .. itemLink .. " is " .. qualityText .. "!	Repeat the procedure to destroy it.|r");

	LAST_ITEM_LINK = itemLink;
	LAST_ITEM_BAG	= bag;
	LAST_ITEM_SLOT = slot;
	LAST_CONFIRM	 = GetTime();
end

-- Delete item in hand
function EasyDestroy_DeleteCursorItem()
	if (EasyDestroy_Debug) then
		if (CursorHasItem()) then
			local type, _, itemLink = GetCursorInfo();
			local itemName, _, quality = GetItemInfo(itemLink);
			Print("|cffffffff["..AddonName.."] EasyDestroy_DeleteCursorItem called with: type=\""..type.."\" itemLink="..itemLink.." quality=\""..quality.."\".|r");
		else
			Print("|cffffffff["..AddonName.."] EasyDestroy_DeleteCursorItem called with no item.|r");
		end
	end
	if ( CursorHasItem() ) then
		local type, _, itemLink = GetCursorInfo();
		local itemName, _, quality, _, _, itemType = GetItemInfo(itemLink);
		local qualityText = EasyDestroy_GetQualityText(quality);
		if (type ~= "item") then
			return false;
		else
			if (EasyDestroy_Safe[itemName]) then
				Print("|cffffffff["..AddonName.."] " .. itemLink .. " is on your safe list! If you really want to destroy it, use Blizzard's default method or remove it from your safe list first.|r");
			else
				if ( (itemType == "Quest" or quality >= QUALITY_FLOOR) and ((itemLink ~= LAST_ITEM_LINK) or (-1 ~= LAST_ITEM_BAG) or (-1 ~= LAST_ITEM_SLOT) or (GetTime() - LAST_CONFIRM > 5)) ) then
					if itemType == "Quest" then
						qualityText = "Quest Item";
					end
				EasyDestroy_Do_Item_Check(itemLink, qualityText);
				else
					-- Prevents me from deleting something important during testing.
					if ( not EasyDestroy_Debug ) then
						DeleteCursorItem();
					else
						Print("["..AddonName.."] DEBUG : ITEM WOULD'VE BEEN DELETED!!!");
					end

					-- It's really gone now. Really.	No getting it back.
					LAST_ITEM_LINK = nil;
					LAST_ITEM_BAG	= nil;
					LAST_ITEM_SLOT = nil;
					LAST_CONFIRM	 = 0;
	
					if(EasyDestroy_Options.Notify) then
						Print("|cffffffff["..AddonName.."] |cff0000ffDestroyed|r - " .. itemLink .. ".|r");
					end
				end
			end
		end
	end
end

-- Generic function to allow either hooked function to destroy an item at <bag>,<slot>. 
function EasyDestroy_DestroyItem(bag, slot)		
	if ( EasyDestroy_Options.On and IsAltKeyDown() and IsShiftKeyDown() ) then
		local _, itemCount, _, _ = C_Container.GetContainerItemInfo(bag, slot);
		local itemLink = C_Container.GetContainerItemLink(bag, slot);
	
		-- Normalize the itemName.
		if not itemLink then
			return
		end
		local itemName, _, quality = GetItemInfo(itemLink);
		local qualityText = EasyDestroy_GetQualityText(quality);
	
		if (EasyDestroy_Safe[itemName]) then
			Print("|cffffffff["..AddonName.."] " .. itemLink .. " is on your safe list! If you really want to destroy it, use the default method or remove it from your safe list first.|r");
		else
			if ( quality >= 2 and ((itemLink ~= LAST_ITEM_LINK) or (bag ~= LAST_ITEM_BAG) or (slot ~= LAST_ITEM_SLOT) or (GetTime() - LAST_CONFIRM > 5)) ) then
				EasyDestroy_Do_Item_Check(itemLink, qualityText, bag, slot);
			else
				-- Either they've confirmed the deletion by clicking twice and we're seeing the same item,
				-- or the item's White or less and we don't care if it gets destroyed.
				if (bag ~= -1 and slot ~= -1) then
					C_Container.PickupContainerItem(bag, slot);
				end
	
				if ( CursorHasItem() ) then
					-- Prevents me from deleting something important during testing.
					if ( not EasyDestroy_Debug ) then
						DeleteCursorItem();
					else
						Print("DEBUG : ITEM WOULD'VE BEEN DELETED!!!");
					end
				
					-- It's really gone now.	Really.	No getting it back.
					LAST_ITEM_LINK = nil;
					LAST_ITEM_BAG	= nil;
					LAST_ITEM_SLOT = nil;
					LAST_CONFIRM	 = 0;
	
					if(EasyDestroy_Options.Notify) then
						Print("|cffffffff["..AddonName.."] |cff0000ffDestroyed|r - " .. (( itemCount > 1 ) and itemCount .. "x " or "") .. itemLink .. ".|r");
					end
				end
			end
		end
	end
end

function EasyDestroyOptions_Toggle()
	if (EasyDestroyOptions:IsVisible()) then
		EasyDestroyOptions:Hide();
	else
		EasyDestroyOptions:Show();
	end
end

function EasyDestroyOptions_Show()
	local str = EasyDestroyOptionsFrame_CheckButton1Text;
	str:SetText("Enable EasyDestroy");
	local button = EasyDestroyOptionsFrame_CheckButton1;
	if (EasyDestroy_Options.On) then
		checked = 1;
	else
		checked = 0;
	end
	button:SetChecked(checked);

	str = EasyDestroyOptionsFrame_CheckButton2Text;
	str:SetText("Announce Destroy");
	button = EasyDestroyOptionsFrame_CheckButton2;
	if (EasyDestroy_Options.Notify) then
		checked = 1;
	else
		checked = 0;
	end
	button:SetChecked(checked);

	str = EasyDestroyOptionsFrame_CheckButton3Text;
	str:SetText("Keyboard Shortcuts");
	button = EasyDestroyOptionsFrame_CheckButton3;
	if (EasyDestroy_Options.KeyBoardShortcuts) then
		checked = 1;
	else
		checked = 0;
	end
	button:SetChecked(checked);
end

function EasyDestroyOptions_Hide(self)
	if self:GetParent():GetParent() == UIParent then
		self:GetParent():Hide();
	end
end

function EasyDestroyOptions_Defaults()
	EasyDestroy_Options.On = true;
	EasyDestroy_Options.Notify = true;
end

local function clicky(self)
	if ( self:GetChecked() ) then
		PlaySound("igMainMenuOptionCheckBoxOff");
	else
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end

function EasyDestroyOptionsFrame_CheckButton1_OnClick(self)
	clicky(self)
	if(EasyDestroy_Options.On == true) then
		EasyDestroy_Options.On = false;
	else
		EasyDestroy_Options.On = true;
	end
end

function EasyDestroyOptionsFrame_CheckButton2_OnClick(self)
	clicky(self)
	if(EasyDestroy_Options.Notify == true) then
		EasyDestroy_Options.Notify = false;
	else
		EasyDestroy_Options.Notify = true;
	end
end

function EasyDestroyOptionsFrame_CheckButton3_OnClick(self)
	clicky(self)
	if(EasyDestroy_Options.KeyBoardShortcuts == true) then
		EasyDestroy_Options.KeyBoardShortcuts = false;
	else
		EasyDestroy_Options.KeyBoardShortcuts = true;
	end
end

function EasyDestroy_OptionsCheckButtonOnClick(self)
	_G[self:GetName().."_OnClick"](self)
end

-- Function to change quality integers into text for display in warning
function EasyDestroy_GetQualityText(quality)
	if ( quality == 0 ) then
		return "Junk";
	elseif ( quality == 1 ) then
		return "Common";
	elseif ( quality == 2 ) then
		return "Uncommon";
	elseif ( quality == 3 ) then
		return "Rare";
	elseif ( quality == 4 ) then
		return "Epic";
	elseif ( quality == 5 ) then
		return "Legendary";
	elseif ( quality == 6 ) then
		return "Artifact";
	else
		return "Unknown";
	end
end

GameTooltip:HookScript("OnTooltipSetItem", function(self, ...)
	local itemName, itemLink = self:GetItem()
	local line = aname
	for name in pairs(EasyDestroy_Safe) do
		if name == itemName then
			line = line .. ": this is in the safe list."
		end
	end
	if line ~= aname then
		self:AddLine(line)
		self:Show()
	end
end)

EasyDestroy_OnLoad(f)
