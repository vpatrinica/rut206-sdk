local nixio = require "nixio"
local fs = require "nixio.fs"
local o_utils = require "vuci.opkg_utils"
local OpkgPkg = require "vuci.opkg_pkg"
local util = require "vuci.util"
local json = require "luci.jsonc"

local PKG_QUEUE_FILE = o_utils.PKG_QUEUE_FILE
local PKG_STATUS_FILE = "/tmp/pkgman/packages_status.json"
local MSG_CODES = o_utils.MSG_CODES
local ERR_CODES = o_utils.ERR_CODES
local PKG_TYPES = o_utils.PKG_TYPES
local MULTI_ACTIONS = o_utils.MULTI_ACTIONS
local ACTION_TO_PKG_TYPE = o_utils.ACTION_TO_PKG_TYPE

local opkg_multi = {
	MULTI_ACTIONS = MULTI_ACTIONS
}

--- Package class used for easier management of packages during multi install/remove/delete
---@class OpkgPkgMulti : OpkgPkg
---@field type OPKG_PKG_TYPES?
---@field tlt_name string? pretty name needed for package display in WebUI when removing packages
---@field messages {code:OPKG_MSG_CODES, message:string}[]?
---@field errors {code:OPKG_ERR_CODES, error:string, source:string?, value:any}[]?
---@overload fun(_type: OPKG_PKG_TYPES?, app_name: string, tlt_name: string?): OpkgPkgMulti
local OpkgPkgMulti = util.class(OpkgPkg)
function OpkgPkgMulti.__init__(self, _type, app_name, tlt_name)
	OpkgPkg.__init__(self, nil, app_name, app_name)
	self.type = _type
	self.messages = nil
	self.errors = nil
	self.tlt_name = tlt_name
end

---@param available boolean? available or installed pkg
---@return boolean
function OpkgPkgMulti:_load_pkg_text(available)
	local pkg
	if available then
		pkg = OpkgPkg.get_available_pkg(self.app_name, true) -- refresh pkg list because it constantly changes when multiple actions are running/waiting
	else
		pkg = OpkgPkg.get_installed_pkg(self.app_name, true)
	end
	if not pkg then return false end
	self.pkg_text = pkg.pkg_text
	self.app_name = pkg.app_name
	self.pkg_name = pkg.pkg_name
	self._opt_cache = {}
	return true
end

function OpkgPkgMulti:_load_available_pkg_text()
	return self:_load_pkg_text(true)
end

function OpkgPkgMulti:_load_installed_pkg_text()
	return self:_load_pkg_text(false)
end

---@param msgs {code:OPKG_MSG_CODES, message:string}[]
function OpkgPkgMulti:add_messages(msgs)
	self.messages = self.messages or {}
	util.append(self.messages, msgs)
end

---Adds error to the pkg and sets it's type as errored
---@param err {code:OPKG_ERR_CODES, error:string, source:string?, value:any}
function OpkgPkgMulti:add_error(err)
	self.errors = self.errors or {}
	table.insert(self.errors, err)
	self.type = PKG_TYPES.ERRORED
end


function OpkgPkgMulti:_validate_pkg_online_install()
	return self:_validate_pkg_online_install_size_and_arch()
end

function OpkgPkgMulti:_pkg_online_install()
	if not next(o_utils.get_pkg_list()) then return false, ERR_CODES.NO_CONNECTION end
	if not self:_load_available_pkg_text() then return false, ERR_CODES.INVALID_PACKAGE end

	local ok, err_code = self:_validate_pkg_online_install()
	if not ok then return ok, err_code end

	ok, err_code = self:_install_package_online()

	local msgs
	if ok then
		self:_remove_pkg_from_pkg_restore()
		msgs = self:get_pkg_msgs()
	end
	return ok, err_code, msgs
end

function OpkgPkgMulti:_pkg_remove()
	if self:is_pending() then
		self:_remove_pkg_from_pkg_restore()
		return true
	end

	local result, err = self:_remove_package()

	if result == 0 then
		return true
	end
	local ok, err_code, depends = self:_validate_pkg_remove_depends(err)
	if not ok then return ok, err_code, depends end

	return false, ERR_CODES.FAILED_PKG_DELETE
end

function OpkgPkgMulti:_pkg_upgrade()
	if not next(o_utils.get_pkg_list()) then return false, ERR_CODES.NO_CONNECTION end
	if not self:_load_available_pkg_text() then
		return false, ERR_CODES.INVALID_PACKAGE
	end
	local ok, err_code = self:_validate_pkg_upgrade()
	if not ok then return ok, err_code end

	self:_remove_package()
	ok, err_code = self:_install_package_online()
	local msgs = self:get_pkg_msgs()

	return ok, err_code, msgs
end

function OpkgPkgMulti:_handle_pkg_install()
	if self:_load_installed_pkg_text() then
		-- pkg already installed, skip installation
		self.type = PKG_TYPES.INSTALLED
		return
	end
	local ok, err_code, msgs = self:_pkg_online_install()
	if ok then
		util.log_str("Package '%s' installed successfully" % self.app_name)
		self.type = PKG_TYPES.INSTALLED
		if msgs then self:add_messages(msgs) end
	else
		self:add_error({ code = err_code, error = o_utils.err_str(err_code) })
	end
end

function OpkgPkgMulti:_handle_pkg_remove()
	if not self:_load_installed_pkg_text() and not self:is_pending() then
		-- pkg already removed, skip removing
		return true
	end
	local ok, err_code, depends = self:_pkg_remove()
	if ok then
		util.log_str("Package '%s' removed successfully" % self.app_name)
		return true
	else
		self:add_error({ code = err_code, error = o_utils.err_str(err_code), source = depends and "depends" or nil, value = depends })
		return false
	end
end

function OpkgPkgMulti:_handle_pkg_upgrade()
	local ok, err_code, msgs = self:_pkg_upgrade()
	if ok then
		util.perror("Package '%s' updated successfully" % self.app_name)
		self.type = PKG_TYPES.INSTALLED
		if msgs then self:add_messages(msgs) end
	else
		self:add_error({ code = err_code, error = o_utils.err_str(err_code) })
	end
end

---@return {[string]:OpkgPkgMulti}
function opkg_multi.get_pkg_statuses()
	local pkgs = json.parse(fs.readfile(PKG_STATUS_FILE) or "{}") or {}
	return pkgs
end

function opkg_multi.clear_net_restart_messages()
	local pkgs = opkg_multi.get_pkg_statuses()
	for pkg_name, pkg in pairs(pkgs) do
		for i, msg in ipairs(pkg.messages or {}) do
			if msg.code == MSG_CODES.NET_RESTART_REQUIRED then
				table.remove(pkg.messages, i)
				break
			end
		end
		if not next(pkg.messages or {}) then
			pkg.messages = nil
		end
	end
	opkg_multi.update_pkg_status_file(pkgs)
end

---@param new_pkgs {[string]:OpkgPkgMulti}
function opkg_multi.update_pkg_status_file(new_pkgs)
	local old_pkgs = opkg_multi.get_pkg_statuses()

	-- update old pkgs with new pkgs, overwrite if needed
	for pkg_name, new_pkg in pairs(new_pkgs) do
		local p = {
			type = new_pkg.type,
			messages = new_pkg.messages,
			errors = new_pkg.errors
		}
		if (p.type == PKG_TYPES.INSTALLED and #util.keys(p) == 1) or not next(p) then
			-- if pkg successfully installed and it doesn't have any other info OR new_pkg is empty object, remove it from the file
			old_pkgs[pkg_name] = nil
		else
			local old_tlt_name = (old_pkgs[pkg_name] or {}).tlt_name
			old_pkgs[pkg_name] = p
			old_pkgs[pkg_name].tlt_name = new_pkg.tlt_name or old_tlt_name -- tlt_name can never change - reuse it from old pkg status
		end
	end

	fs.writefile(PKG_STATUS_FILE, json.stringify(old_pkgs))
	fs.chmod(PKG_STATUS_FILE, "rw-rw-r--")
end

---@param packages string[]
---@return boolean success
---@return integer? err_code
---@return string? failed_pkg_name
function opkg_multi.start_multi_install(packages)
	return opkg_multi._start_multi_action(packages, MULTI_ACTIONS.INSTALL)
end

---@param packages string[]
---@return boolean success
---@return integer? err_code
---@return string? failed_pkg_name
function opkg_multi.start_multi_remove(packages)
	return opkg_multi._start_multi_action(packages, MULTI_ACTIONS.REMOVE)
end

---@param packages string[]
---@return boolean success
---@return integer? err_code
---@return string? failed_pkg_name
function opkg_multi.start_multi_upgrade(packages)
	return opkg_multi._start_multi_action(packages, MULTI_ACTIONS.UPGRADE)
end

---Opens, locks, reads and seeks(0) queue file. File needs to be closed.
---@return string? file_text
---@return table f nixio file fd
function opkg_multi._read_queue_file()
	local ok, f =  o_utils._lock(PKG_QUEUE_FILE, "lock")
	if not ok then error("queue file lock error") end
	local file_text = f:readall()
	f:seek(0)
	return file_text, f
end

---@param packages string[]
---@param action 1|2|3
---@return boolean success
---@return integer? err_code
---@return string? failed_pkg_name
function opkg_multi._start_multi_action(packages, action)
	assert(packages and #packages > 0, "invalid function argument")
	assert(action == 1 or action == 2 or action == 3, "invalid function argument")

	-- reverse array because package_queue file uses reverse order
	for i = 1, math.floor(#packages / 2) do
		local tmp1 = packages[i]
		local tmp2 = packages[#packages - i + 1]
		packages[#packages - i + 1] = tmp1
		packages[i] = tmp2
	end

	o_utils.fetch_pkg_list()

	local pkg_type = ACTION_TO_PKG_TYPE[action]

	if (action == MULTI_ACTIONS.INSTALL or action == MULTI_ACTIONS.UPGRADE) and not next(o_utils.get_pkg_list()) then
		return false, ERR_CODES.NO_CONNECTION
	end

	for _, app_name_or_pkg_name in ipairs(packages) do
		if not o_utils.get_pkg_list_by_app_name()[app_name_or_pkg_name] and
		not o_utils.get_installed_pkg_list_by_app_name()[app_name_or_pkg_name] and
		not o_utils.get_pkg_list()[app_name_or_pkg_name] and
		not o_utils.pkg_installed(app_name_or_pkg_name) and
		not o_utils.pkg_pending(app_name_or_pkg_name) then
			return false, ERR_CODES.INVALID_PACKAGE, app_name_or_pkg_name
		end
	end

	local current_pkg_statuses = opkg_multi.get_pkg_statuses()

	---@type {[string]:OpkgPkgMulti}
	local new_pkg_statuses = {}
	for _, app_name in ipairs(packages) do
		local current_p_type = (current_pkg_statuses[app_name] or {}).type
		-- don't overwrite pkg type if it is already being installed/removed/updated
		if current_p_type ~= PKG_TYPES.INSTALLING and current_p_type ~= PKG_TYPES.REMOVING and current_p_type ~= PKG_TYPES.UPDATING then
			local available_pkg = OpkgPkg.get_available_pkg(app_name)
			local tlt_name = available_pkg and available_pkg:get("tlt_name") or nil
			if not tlt_name then
				local installed_pkg = OpkgPkg.get_installed_pkg(app_name)
				tlt_name = installed_pkg and installed_pkg:get("tlt_name") or nil
			end
			new_pkg_statuses[app_name] = OpkgPkgMulti(pkg_type, app_name, tlt_name)
		end
	end
	opkg_multi.update_pkg_status_file(new_pkg_statuses)

	local action_running = false
	local file_text, queue_file = opkg_multi._read_queue_file()

	local unlocked, f = o_utils.test_lock()
	if file_text and #util.trim(file_text) > 0 and not unlocked then
		action_running = true
	end
	f:close()

	-- add packages to queue file
	local new_text = ""
	for _, app_name_or_pkg_name in ipairs(packages) do
		new_text = new_text .. action .. " " .. app_name_or_pkg_name .. "\n"
	end
	new_text = new_text .. (file_text or "")
	queue_file:writeall(new_text)
	queue_file:lock("ulock")
	queue_file:close()
	if action_running then return true end -- pkg action is running, only append queue file and return

	local pid = nixio.fork()
	if pid == 0 then
		local lock_file -- <- need to keep file reference, otherwise it gets gc'd by nixio and unlocked
		-- child
		local ok, err = pcall(function()
			local ok
			ok, lock_file = o_utils.acquire_lock() -- wait for lock
			if not ok then
				-- should never get here
				for _, pkg in pairs(new_pkg_statuses) do
					pkg.type = PKG_TYPES.ERRORED
					pkg:add_error({ code = ERR_CODES.UNEXPECTED_ERROR, error = o_utils.err_str(ERR_CODES.UNEXPECTED_ERROR) })
				end
				opkg_multi.update_pkg_status_file(new_pkg_statuses)
				return
			end

			local file_text, queue_file = opkg_multi._read_queue_file()
			if not file_text or #file_text == 0 then error("unexpected empty queue file") end
			local file_lines = util.split(util.trim(file_text))
			queue_file:lock("ulock")
			queue_file:close()
			while #file_lines > 0 do
				-- file_lines are read again at the end of loop
				-- repeated until all pkg actions are done and file is empty
				local last_line = file_lines[#file_lines]
				local pkg_action, app_name = last_line:match("^(%d)%s+(.*)$")
				pkg_action = tonumber(pkg_action)

				local pkg = OpkgPkgMulti(ACTION_TO_PKG_TYPE[pkg_action], app_name)
				opkg_multi.update_pkg_status_file({ [app_name] = pkg })

				local available_pkg = OpkgPkg.get_available_pkg(app_name)
				local pkg_event_info = { package = app_name, name = available_pkg and available_pkg:get("tlt_name") or nil }
				if pkg_action == MULTI_ACTIONS.INSTALL then
					pkg:_handle_pkg_install()
				elseif pkg_action == MULTI_ACTIONS.REMOVE then
					local ok = pkg:_handle_pkg_remove()
					if ok then
						pkg_event_info.type = available_pkg and PKG_TYPES.AVAILABLE or PKG_TYPES.REMOVED
						pkg = {}
					end
				elseif pkg_action == MULTI_ACTIONS.UPGRADE then
					pkg:_handle_pkg_upgrade()
				end

				pkg_event_info.type = pkg_event_info.type or pkg.type
				pkg_event_info.errors = pkg.errors
				pkg_event_info.messages = pkg.messages
				pkg_event_info.pkg_name = pkg.pkg_name
				pkg_event_info.app_name = pkg.app_name

				o_utils._trigger_pkg_event(pkg_event_info)
				if not pkg.errors then
					o_utils._restart_services()
				end

				-- remove pkg from queue
				file_text, queue_file = opkg_multi._read_queue_file()
				if not file_text or #file_text == 0 then error("unexpected empty file") end
				file_lines = util.split(util.trim(file_text))
				file_lines[#file_lines] = nil -- remove last line

				-- check if another action for current package is queued and update its type accordingly (installing/removing/updating)
				for i = #file_lines, 1, -1 do
					local other_pkg_action, other_app_name = file_lines[i]:match("^(%d)%s+(.*)$")
					if other_app_name == app_name then
						pkg.type = ACTION_TO_PKG_TYPE[tonumber(other_pkg_action)]
						break
					end
				end
				opkg_multi.update_pkg_status_file({ [app_name] = pkg })

				last_line = file_lines[#file_lines]
				if not last_line then
					-- no more pkgs, clear file
					fs.writefile(PKG_QUEUE_FILE, "")
				else
					fs.writefile(PKG_QUEUE_FILE, table.concat(file_lines, "\n"))
				end
				fs.chmod(PKG_QUEUE_FILE, "rw-rw-r--")
				queue_file:lock("ulock")
				queue_file:close()
			end
		end)

		if not ok then util.perror(err) end
		lock_file:lock("ulock")
		lock_file:close()
		os.exit()
	elseif pid > 0 then
		return true
	else
		error("fork error")
	end
end

return opkg_multi
