local ConfigService = require("api/ConfigService")
local util = require("vuci.util")
local fs = require("nixio.fs")

local Recipients = ConfigService:new({
	increment_name = true
})

Recipients.ERR_CODES = {
	SEND_EMAIL_FAIL = 1
}

local function add_shared_option(table, name, required)
	local opt
	if name == "secure_conn" then
		opt = table:option("secure_conn")
		function opt:validate(value)
			return self.dt:is_bool(value)
		end
	elseif name == "smtp_ip" then
		opt = table:option("smtp_ip")
		opt.maxlength = 64
		function opt:validate(value)
			return self.dt:host(value)
		end
	elseif name == "smtp_port" then
		opt = table:option("smtp_port")
		function opt:validate(value)
			return self.dt:port(value)
		end
	elseif name == "username" then
		opt = table:option("username")
		opt.maxlength = 64
		function opt:validate(value)
			local ok, err = self.dt:credentials_validate(value)
			if not ok then return ok, err end
			return self.dt:fieldvalidation(value, "^[^']*$")
		end
	elseif name == "password" then
		opt = table:option("password", { sensitive = true })
		opt.maxlength = 128
		function opt:validate(value)
			local ok, err = self.dt:credentials_validate(value)
			if not ok then return ok, err end
			return self.dt:fieldvalidation(value, "^[^']*$")
		end
	elseif name == "senderemail" then
		opt = table:option("senderemail")
		opt.maxlength = 128
		function opt:validate(value)
			return self.dt:email(value)
		end
	end
	if required and opt then
		opt.require = true
	end
end

function remove_and_recalculate_symlinks(ca_file)
	local symlink = util.trim(util.exec("ls -l /etc/ssl/certs | grep " .. ca_file .. " | awk -F ' ' '{print $9}'"))
	if not symlink or symlink == "" then
		return
	end

	os.remove("/etc/ssl/certs/" .. symlink)

	local output = util.file_exec("/usr/bin/openssl", { "x509", "-hash", "-noout", "-in", ca_file })
	local symlink_hash = util.trim(output and output.stdout or "")
	if not symlink_hash or symlink_hash == "" then
		return
	end

	local symlink_number = string.match(symlink, "[^.]*$") + 1
	symlink              = "/etc/ssl/certs/" .. symlink_hash .. "."
	local symlink_exists = fs.stat(symlink .. symlink_number)

	while symlink_exists do
		fs.move(symlink .. symlink_number, symlink .. symlink_number - 1)
		symlink_number = symlink_number + 1
		symlink_exists = fs.stat(symlink .. symlink_number)
	end
end

function Recipients:before_update()
	local old_data = self.uci:get_all("user_groups", self.sid)
	if old_data.ca_file then
		remove_and_recalculate_symlinks(old_data.ca_file)
	end
end

function Recipients:PUT_after_data_hook(_)
	self:before_update()
end

function Recipients:PUT_validate_section_hook()
	local old_ca_file = self:table_get(self.config, self.sid, "ca_file")
	local ca_file = self:get_abs_value(self.config, self.sid, "ca_file")

	if not ca_file or (old_ca_file and old_ca_file == ca_file) then
		return
	end

	local output = util.file_exec("/usr/bin/openssl", { "x509", "-hash", "-noout", "-in", ca_file })
	local hash   = util.trim(output and output.stdout or "")

	if not hash or hash == "" then
		return
	end

	local _, symlink_count = fs.glob("/etc/ssl/certs/" .. hash .. ".*")

	fs.symlink(ca_file, "/etc/ssl/certs/" .. hash .. "." .. symlink_count)
end

local EmailUsers = Recipients:section("user_groups", "email")

	local opt_name = EmailUsers:option("name")
		opt_name.cfg_require = true
		opt_name.maxlength = 16
		opt_name.unique = true
		function opt_name:validate(value)
			self:table_foreach(self.config, "email", function(s)
				if s.name == value and s[".name"] ~= self.sid then
					self:add_critical_error(STD_CODES.UCI_CREATE_ERROR, "name already exists")
				end
			end)
			return self.dt:default_validation(value)
		end

	local opt_credentials = EmailUsers:option("credentials")
		function opt_credentials:validate(value)
			return self.dt:is_bool(value)
		end

	local opt_do_not_verify = EmailUsers:option("do_not_verify")
		function opt_do_not_verify:validate(value)
			return self.dt:is_bool(value)
		end

	local opt_ca_file = EmailUsers:option("ca_file", {certificate = {
		upload_only = true,
		failsafe = true
	}})
	opt_ca_file.file_size = 16777216

	add_shared_option(EmailUsers, "secure_conn")
	add_shared_option(EmailUsers, "smtp_ip")
	add_shared_option(EmailUsers, "smtp_port")
	add_shared_option(EmailUsers, "username")
	add_shared_option(EmailUsers, "password")
	add_shared_option(EmailUsers, "senderemail")

function Recipients:DELETE_before_section_delete_hook()
	local group_name = self:table_get(self.config, self.sid, "name")
	self:table_foreach("event_juggler", "action", function(s)
		if s.action == "smtp" and s.smtp_email_group == group_name then
			self:table_delete("event_juggler", s[".name"], "smtp_email_group")
			if s.enabled and s.enabled == "1" then
				self:table_set("event_juggler", s[".name"], "enabled", "0")
			end
			self:table_foreach("event_juggler", "event", function(event)
				if event.action and util.contains(event.action, s[".name"]) then
					self:table_set("event_juggler", event[".name"], "enabled", "0")
				end
			end)
		end
	end)

	-- check modbus tcp/serial client alarms
	if self.t_func:_get_config_safe("modbus_client") then
		for _, s in pairs(self.t_func:get_uci_config("modbus_client")) do
			if s[".type"]:find("alarm_") then
				if s.email_group_id and s.email_group_id == self.sid then
					self:table_delete("modbus_client", s[".name"], "email_group_id")
					if s.enabled and s.enabled == "1" then
						self:table_set("modbus_client", s[".name"], "enabled", "0")
					end
				end
			end
		end
	end

	local group_ca_file = self:table_get(self.config, self.sid, "ca_file")
	if group_ca_file then
		remove_and_recalculate_symlinks(group_ca_file)
	end
end

function Recipients:UPLOAD_before_upload_hook()
	local ca_file = self:table_get(self.config, self.sid, "ca_file")
	if ca_file then
		remove_and_recalculate_symlinks(ca_file)
	end
end

local TestEmail = Recipients:action("send_email", function(self, data)
	local email = require("vuci.email")
	local EMAIL_TIMEOUT = 30

	local hostname = self:table_get("system", "system", "hostname") or "DEVICE"
	local message = "Test email from: " .. hostname
	local code = email:send_email(data, "Test email", message, data.senderemail, EMAIL_TIMEOUT)
	if code == 0 then
		self:ResponseOK()
	end
	self:add_critical_error(self.ERR_CODES.SEND_EMAIL_FAIL, "Failed to send an email.")
end)

add_shared_option(TestEmail, "smtp_ip", true)
add_shared_option(TestEmail, "smtp_port", true)
add_shared_option(TestEmail, "username")
add_shared_option(TestEmail, "password")
add_shared_option(TestEmail, "senderemail", true)
add_shared_option(TestEmail, "secure_conn", true)

return Recipients
