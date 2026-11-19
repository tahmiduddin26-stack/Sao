--!strict
-- Router: opens and closes Ledger tabs and overlays, keeps one open at a time,
-- and handles Back on every input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Router = {}

Router.Changed = Signal.new() -- (openName: string?, tab: string?)

export type Surface = {
	open: (tab: string?) -> (),
	close: () -> (),
	setTab: ((tab: string) -> ())?,
}

local surfaces: { [string]: Surface } = {}
local current: string? = nil
local currentTab: string? = nil

function Router.register(name: string, surface: Surface)
	surfaces[name] = surface
end

function Router.current(): (string?, string?)
	return current, currentTab
end

function Router.isOpen(): boolean
	return current ~= nil
end

function Router.open(name: string, tab: string?)
	local surface = surfaces[name]
	if not surface then
		return
	end
	if current == name then
		-- Same shell: swap the content, not the shell.
		if tab and surface.setTab and tab ~= currentTab then
			currentTab = tab
			surface.setTab(tab)
			Router.Changed:Fire(current, currentTab)
		end
		return
	end
	if current then
		local prev = surfaces[current]
		if prev then
			prev.close()
		end
	end
	current = name
	currentTab = tab
	surface.open(tab)
	Router.Changed:Fire(current, currentTab)
end

-- Called by a surface when its own tab changes from inside (rail click).
function Router.noteTab(tab: string)
	currentTab = tab
	Router.Changed:Fire(current, currentTab)
end

function Router.close()
	if not current then
		return
	end
	local surface = surfaces[current]
	current = nil
	currentTab = nil
	if surface then
		surface.close()
	end
	Router.Changed:Fire(nil, nil)
end

-- Back: closes the top surface. Returns true if something closed.
function Router.back(): boolean
	if current then
		Router.close()
		return true
	end
	return false
end

function Router.toggle(name: string, tab: string?)
	if current == name and (tab == nil or tab == currentTab) then
		Router.close()
	else
		Router.open(name, tab)
	end
end

return Router
