local pbServiceHelper = require "serviceHelper.pb"
local tableControllerUtility = require "utility.tableController"

local conf = {
	loginCheck = true,
	protocalHandlers = tableControllerUtility.getProtocalHandlerHash({0x020000, 0x020001, 0x020002, 0x020008, 0x02000C, 0x02000F}),
}

pbServiceHelper.createService(conf)
