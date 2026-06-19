local util = require "vuci.util"
local OpkgPkg = require "vuci.opkg_pkg"
local o_utils = require "vuci.opkg_utils"
local opkg_multi = require "vuci.opkg_multi"

local ERR_CODES = o_utils.ERR_CODES
local PKG_TYPES = o_utils.PKG_TYPES

local opkg = {
	-- expose public functions here
	OpkgPkg = OpkgPkg,
	get_pkg_url = o_utils.get_pkg_url,
	check_package_arch = o_utils.check_package_arch,
	check_pkg_hw_info = o_utils.check_pkg_hw_info,
	get_size_online = o_utils.get_size_online,
	get_pkg_list_text = o_utils.get_pkg_list_text,
	get_pkg_list = o_utils.get_pkg_list,
	pkg_type_str = o_utils.pkg_type_str,
	fetch_pkg_list = o_utils.fetch_pkg_list,
	pkg_installed = o_utils.pkg_installed,
	pkg_pending = o_utils.pkg_pending,
	delete_custom_pkg_files = o_utils.delete_custom_pkg_files,
	err_str = o_utils.err_str,
	acquire_lock = o_utils.acquire_lock,
	clean_feeds = o_utils.clean_feeds,
	opkg_cmd = o_utils.opkg_cmd,
	_trigger_pkg_event = o_utils._trigger_pkg_event,
	_restart_services = o_utils._restart_services,
	_trigger_backup = o_utils._trigger_backup,
	_remove_pkg_from_pkg_restore = o_utils._remove_pkg_from_pkg_restore,
	PKG_TYPES = o_utils.PKG_TYPES,
	MSG_STR = o_utils.MSG_STR,
	MSG_CODES = o_utils.MSG_CODES,
	ERR_CODES = o_utils.ERR_CODES,
	ERR_STR = o_utils.ERR_STR,
	PKG_CUSTOM_FOLDER_PATH = o_utils.PKG_CUSTOM_FOLDER_PATH,
	PKG_CACHE_FILE = o_utils.PKG_CACHE_FILE,
	PKG_RESTORE_PATH = o_utils.PKG_RESTORE_PATH,
	FAILED_PKG_PATH = o_utils.FAILED_PKG_PATH,
	PKG_TAR_PATH = o_utils.PKG_TAR_PATH,
	PKG_MULTI_LOCK_PATH = o_utils.PKG_MULTI_LOCK_PATH,
	OPKG_TLT_URL = o_utils.OPKG_TLT_URL,
	DEST_ROOT = o_utils.DEST_ROOT,
}

---Returns old_package_v < new_package_v
---@param old_package_v string?
---@param new_package_v string
---@return boolean
function opkg.check_pkg_version(old_package_v, new_package_v)
	if not old_package_v then return true end
	return not old_package_v or o_utils._compare_versions(new_package_v, old_package_v)
end

---**Warning**: may need to call fetch_pkg_list before
---@param app_name string
---@return boolean ok
---@return integer? err_code
---@return table? msgs
function opkg.handle_online_upgrade(app_name)
	local ok, f = o_utils.acquire_lock(false)
	if not ok then return false, ERR_CODES.OPKG_BUSY end

	local ok, err_code, msgs = (function()
		if not next(o_utils.get_pkg_list()) then return false, ERR_CODES.NO_CONNECTION end

		local pkg = OpkgPkg.get_available_pkg(app_name)
		if not pkg then return false, ERR_CODES.INVALID_PACKAGE end

		local ok, err_code = pkg:_validate_pkg_upgrade()
		if not ok then return ok, err_code end

		pkg:_remove_package()
		ok, err_code = pkg:_install_package_online()
		local msgs = pkg:get_pkg_msgs()

		o_utils._trigger_pkg_event()
		if ok then
			o_utils._restart_services()
			o_utils._trigger_backup()
			opkg_multi.update_pkg_status_file({ [pkg.app_name] = { type = PKG_TYPES.INSTALLED, messages = msgs } })
		end
		return ok, err_code, msgs
	end)()
	f:lock("ulock")
	f:close()
	return ok, err_code, msgs
end

---Handles online pkg install. **Warning**: may need to call fetch_pkg_list before
---@param app_name string
---@param set_lang boolean? if true and the package is a language package (vuci-i18n-*) then the language is selected when installed
---@return boolean success
---@return integer? err_code
---@return table? msgs
function opkg.handle_online_install(app_name, set_lang)
	local ok, f = o_utils.acquire_lock(false)
	if not ok then return false, ERR_CODES.OPKG_BUSY end

	local ok, err_code, msgs = (function()
		if not next(o_utils.get_pkg_list()) then return false, ERR_CODES.NO_CONNECTION end

		local pkg = OpkgPkg.get_available_pkg(app_name)
		if not pkg then return false, ERR_CODES.INVALID_PACKAGE end

		local ok, err_code = pkg:_validate_pkg_online_install()
		if not ok then return ok, err_code end

		if set_lang then o_utils._set_language("1") end

		ok, err_code = pkg:_install_package_online()

		if set_lang then o_utils._set_language("") end

		local msgs
		local pkg_event_info = {
			package = app_name,
			name = pkg and pkg:get("tlt_name") or nil,
			type = ok and PKG_TYPES.INSTALLED or PKG_TYPES.ERRORED
		}
		if ok then
			msgs = pkg:get_pkg_msgs()
			util.log_str("Package '%s' installed successfully" % pkg.app_name)
			pkg:_remove_pkg_from_pkg_restore()
			opkg_multi.update_pkg_status_file({ [pkg.app_name] = { type = PKG_TYPES.INSTALLED, messages = msgs } })
			o_utils._restart_services()
			o_utils._trigger_backup()
		end
		pkg_event_info.messages = msgs
		o_utils._trigger_pkg_event(pkg_event_info)
		return ok, err_code, msgs
	end)()
	f:lock("ulock")
	f:close()
	return ok, err_code, msgs
end

---Handles offline pkg install
---@param package_dir string extracted package dir e.g. "/tmp/custom_package"
---@param set_lang boolean? if true and the package is a language package (vuci-i18n-*) then the language is selected when installed 
---@return boolean success
---@return integer? err_code
---@return table? msgs
---@return OpkgPkg? app_name
function opkg.handle_offline_install(package_dir, set_lang)
	local ok, f = o_utils.acquire_lock(false)
	if not ok then return false, ERR_CODES.OPKG_BUSY end

	local ok, err_code, msgs, installed_pkg = (function ()
		local pkg, err_code = OpkgPkg.get_pkg_from_dir(package_dir)
		if not pkg then return false, err_code end

		local msgs = pkg:get_pkg_msgs()

		if set_lang then o_utils._set_language("1") end

		local ok, err_code = pkg:_install_packages_offline()

		if set_lang then o_utils._set_language("") end

		local pkginfo, installed_pkg
		if ok then
			installed_pkg = opkg.OpkgPkg.get_installed_pkg(pkg.app_name, true)
			pkginfo = {
				package = installed_pkg.app_name,
				type = PKG_TYPES.INSTALLED,
				app_name = installed_pkg.app_name,
				pkg_name = installed_pkg.pkg_name,
			}
		end

		o_utils._trigger_pkg_event(pkginfo)
		if ok then
			util.perror("Package '%s' installed successfully" % pkg.app_name)
			pkg:_remove_pkg_from_pkg_restore()
			opkg_multi.update_pkg_status_file({ [pkg.app_name] = { type = PKG_TYPES.INSTALLED, messages = msgs } })
			o_utils._restart_services()
			o_utils._trigger_backup()
		end
		return ok, err_code, msgs, installed_pkg
	end)()

	o_utils.delete_custom_pkg_files()
	f:lock("ulock")
	f:close()
	return ok, err_code, msgs, installed_pkg
end

---@param app_name string app_name or pkg_name (AppName or Package)
---@return boolean success
---@return integer? err_code
---@return table? depends
function opkg.handle_package_remove(app_name)
	local ok, f = o_utils.acquire_lock(false)
	if not ok then return false, ERR_CODES.OPKG_BUSY end

	local ok, err_code, depends = (function ()
		local pkg = OpkgPkg.get_installed_pkg(app_name)
		if not pkg then
			pkg = OpkgPkg(nil, app_name, app_name)
		end

		local ok, err_code = pkg:_validate_pkg_remove()
		if not ok then return ok, err_code end

		if pkg.pending then
			pkg:_remove_pkg_from_pkg_restore()
			o_utils._trigger_pkg_event()
			o_utils._restart_services()
			return true
		end

		local result, err_code = pkg:_remove_package()

		o_utils._trigger_pkg_event()
		if result == 0 then
			o_utils._restart_services()
			opkg_multi.update_pkg_status_file({ [pkg.app_name] = {} })
			return true
		end
		local ok, err_code, depends = pkg:_validate_pkg_remove_depends(err_code)
		if not ok then return ok, err_code, depends end
		return false, ERR_CODES.FAILED_PKG_DELETE
	end)()

	f:lock("ulock")
	f:close()
	return ok, err_code, depends
end

return opkg