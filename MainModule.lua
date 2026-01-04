local module = {}

local http = game:GetService("HttpService")

local function getGroupRoleId(targetRole, groupId, apiKey)
	local pageToken = nil

	repeat
		local url = "https://apis.roblox.com/cloud/v2/groups/" .. groupId .. "/roles?maxPageSize=100"
		if pageToken then
			url = url .. "&pageToken=" .. pageToken
		end

		local response = http:RequestAsync{
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-key"] = apiKey
			}
		}

		if not response.Success then
			warn("获取角色列表失败:", response.StatusCode, response.Body)
			return nil
		end

		local data = http:JSONDecode(response.Body)

		-- 查找目标角色
		for _, role in ipairs(data.groupRoles) do
			if tonumber(role.rank) == tonumber(targetRole) then
				return tostring(role.id) -- 确保返回字符串类型
			end
		end

		pageToken = data.nextPageToken
	until not pageToken

	return nil -- 未找到目标角色
end

local function getUserMembershipId(targetUserIdNum, groupId, apiKey)
	print("开始获取membershipId，目标用户ID（数字）：", targetUserIdNum)

	local pageToken = nil
	local pageNum = 1
	local MAX_PAGES = 100

	repeat
		-- 构建请求URL
		local url = "https://apis.roblox.com/cloud/v2/groups/" .. groupId .. "/memberships?maxPageSize=50"
		if pageToken and pageToken ~= "" then
			url = url .. "&pageToken=" .. pageToken
		end
		print("请求URL（第" .. pageNum .. "页）：", url)

		-- 发送请求
		local response = http:RequestAsync{
			Url = url,
			Method = "GET",
			Headers = { ["x-api-key"] = apiKey }
		}

		-- 检查请求是否成功
		if not response.Success then
			print("请求失败，状态码：", response.StatusCode, "响应体：", response.Body)
			return nil
		end

		-- 解析JSON（修正pcall用法）
		local success, data = pcall(function()
			return http:JSONDecode(response.Body)
		end)

		-- 检查解析结果
		if not success or type(data) ~= "table" then
			print("JSON解析失败：", data or "未知错误")
			print("原始响应体：", response.Body)
			return nil
		end

		-- 验证数据结构
		if not data.groupMemberships then
			print("响应数据缺少groupMemberships字段")
			print("解析后的数据：", http:JSONEncode(data))
			return nil
		end

		print("第" .. pageNum .. "页成员数量：", #data.groupMemberships)

		-- 遍历成员
		for _, membership in ipairs(data.groupMemberships) do
			-- 提取用户ID并转换为数字
			local userIdStr = membership.user:match("users/(%d+)")
			local userId = userIdStr and tonumber(userIdStr) or nil
			print("当前成员ID（字符串）：", userIdStr)
			print("当前成员ID（数字）：", userId)

			-- 匹配目标用户
			if userId == tonumber(targetUserIdNum) then
				print("✅ 匹配成功！当前成员ID = 目标ID：", userId)

				-- 提取membershipId
				local membershipId = membership.path:match("memberships/([%w]+)")
				if membershipId then
					print("✅ 提取成功，membershipId：", membershipId)
					return membershipId
				else
					-- 保底方案
					local segments = {}
					for s in membership.path:gmatch("[^/]+") do
						table.insert(segments, s)
					end
					membershipId = segments[#segments]
					print("⚠️ 保底提取membershipId：", membershipId)
					return membershipId
				end
			end
		end

		-- 处理分页
		pageToken = data.nextPageToken or nil
		if pageToken == "" then pageToken = nil end
		pageNum += 1
	until not pageToken or pageNum > MAX_PAGES

	print("❌ 未找到目标用户")
	return nil
end

-- 更新用户角色
local function updateUserRole(targetRoleId, targetMembershipId, groupId, apiKey)
	local response = http:RequestAsync{
		Url = "https://apis.roblox.com/cloud/v2/groups/" .. groupId .. "/memberships/" .. targetMembershipId,
		Method = "PATCH",
		Headers = {
			["Content-Type"] = "application/json",
			["x-api-key"] = apiKey
		},
		Body = http:JSONEncode({ role = "groups/" .. groupId .. "/roles/" .. targetRoleId }),
	}

	if not response.Success then
		local data = http:JSONDecode(response.Body)
		return false, "调整失败,错误码: " .. response.StatusCode .. ", 信息: " .. (data.message or "未知错误")
	end

	return true, "调整成功"
end

function module.updateRoleProcess(userId, roleRank, groupId, apiKey)
	local roleId = getGroupRoleId(roleRank, groupId, apiKey)
	if not roleId then
		return false, "未找到指定角色"
	end
	print("获取角色ID:", roleId)

	local membershipId = getUserMembershipId(userId, groupId, apiKey)
	if not membershipId then
		return false, "未找到指定用户的成员信息"
	end
	print("获取成员ID:", membershipId)

	local success, message = updateUserRole(roleId, membershipId, groupId, apiKey)
	return success, message
	
end



return module
