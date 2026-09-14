-- Sigil Knight Commander Auto-Progression Module
-- Path: Warrior → Sigil Knight → Sigil Knight Commander
-- For Rogue Lineage Gaia (5208655184)
-- Add to your repo as skc_progression.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LP = Players.LocalPlayer

------------------------------------------------------------
-- PROGRESSION DATABASE
-- Exact requirements pulled from RL wiki
------------------------------------------------------------

local Progression = {
    -- STEP 1: Warrior Base Class
    {
        name = "Warrior",
        type = "base",
        description = "Sword base class. Trainer: Alfric at Emeraldstone Tavern, Sea of Dust.",
        requirements = {
            sword_xp = 280,              -- ~8 Zombie Scrooms with bronze sword (40 hits/kill)
            orderly = 0,
            silver = 140,                -- 35 per skill, 4 skills
        },
        trainer = {
            name = "Alfric",
            area = "Emeraldstone Tavern, Sea of Dust",
            location = CFrame.new(780, 50, 200),
        },
        skills = {
            {name = "Pommel Strike", cost = 35, desc = "Hilt bash that concusses opponent"},
            {name = "Action Surge", cost = 35, desc = "Swift burst damage attack, great for combos"},
            {name = "Mercenary Carry", cost = 35, desc = "Carry players, useful for transporting grips"},
            {name = "Lord's Training", cost = 35, desc = "Extra M1 hits in combo — GET THIS for SKC"},
        },
        xp_farming = {
            method = "Kill Zombie Scrooms",
            location = "Crypt of Kings",
            cframe = CFrame.new(-340, 60, -550),
            hits_per_kill = 40,          -- bronze sword
            kills_needed = 8,           -- ~280 hits total
            tip = "Hold F to block shrieker attacks, hit during their pause"
        },
    },

    -- STEP 2: Sigil Knight Super Class
    {
        name = "Sigil Knight",
        type = "super",
        description = "Orderly sword super. Trainer at top of Central Sanctuary (Royal Woods).",
        requirements = {
            sword_xp = 480,              -- ~12 more ZScrooms after Warrior (20 total from start)
            orderly = 25,                -- drink tespian elixirs, do orderly quests
            silver = 195,                -- 65 per skill, 3 skills
            warrior_skills = 3,          -- need at least 3/4 warrior skills
        },
        trainer = {
            name = "Draug",
            area = "Central Sanctuary (climb tree in Royal Woods)",
            location = CFrame.new(350, 250, -680),
        },
        skills = {
            {name = "Flame Charge", cost = 65, desc = "Imbues sword with fire, ignites enemies"},
            {name = "Ice Charge", cost = 65, desc = "Creates ice on hit, blocks areas"},
            {name = "Lightning Charge", cost = 65, desc = "Electrifies sword, stun on hit"},
        },
        orderly_methods = {
            {method = "Tespian Elixir", gain = 5, desc = "Drink tespian — craft or buy, +5 orderly each"},
            {method = "Rot NPCs", gain = 1, desc = "Rot knocked players at fire pits, ~1 orderly per rot"},
            {method = "Orderly Quests", gain = "varies", desc = "Various NPC quests around the map"},
        },
        xp_farming = {
            method = "Kill Zombie Scrooms",
            location = "Crypt of Kings",
            cframe = CFrame.new(-340, 60, -550),
            hits_per_kill = 40,
            kills_needed = 12,           -- additional after warrior
            tip = "2 waves for base class + 1 wave for first SK skill"
        },
    },

    -- STEP 3: Sigil Knight Commander Ultra Class
    {
        name = "Sigil Knight Commander",
        type = "ultra",
        description = "Orderly sword ultra. Trainer: Jagen at Castle Sanctuary.",
        requirements = {
            orderly = 50,                -- wiki says 50, some say 60
            max_sigil_knight = true,     -- all 3 SK skills required
            silver = 1400,               -- 350 per skill, 4 skills (1850 with armor)
        },
        trainer = {
            name = "Jagen",
            area = "Castle Sanctuary",
            location = CFrame.new(-468, 260, -254),
        },
        skills = {
            {name = "Fire Charged Blow", cost = 350, desc = "Fire wave that ignites enemies, medium damage"},
            {name = "Ice Charged Blow", cost = 350, desc = "Ice pillars that knockback, only dodged by I-frames"},
            {name = "Lightning Charged Blow", cost = 350, desc = "Dash slash with thunder, breaks mana shield"},
            {name = "Hyper Body", cost = 350, desc = "Massive HP boost passive"},
        },
        extras = {
            {name = "Sigil Armor", cost = 450, desc = "Heavy armor set from Jagen"},
        },
        orderly_methods = {
            {method = "Tespian Elixir", gain = 5, desc = "5 tespians = 25 orderly"},
            {method = "Rot NPCs", gain = 1, desc = "Keep rotting knocked players"},
            {method = "All orderly quests", gain = "~55", desc = "Complete every orderly quest on the map"},
        },
    },
}

------------------------------------------------------------
-- KNOWN LOCATIONS
------------------------------------------------------------
local Locations = {
    -- Trainers
    ["Alfric"]             = CFrame.new(780, 50, 200),       -- Warrior trainer, Sea of Dust
    ["Central Sanctuary"]  = CFrame.new(350, 250, -680),     -- Sigil Knight trainer area
    ["Castle Sanctuary"]   = CFrame.new(-468, 260, -254),    -- SKC trainer Jagen

    -- XP Farming
    ["Crypt of Kings"]     = CFrame.new(-340, 60, -550),     -- Zombie Scrooms
    ["Sleeping Forest"]    = CFrame.new(-150, 100, -400),    -- Shriekers

    -- Orderly
    ["Sentinel"]           = CFrame.new(-468, 211, -254),    -- Town hub
    ["Oresfall"]           = CFrame.new(-890, 200, -350),    -- Silver farming
    ["Tavern"]             = CFrame.new(-232, 128, -90),     -- Tespian crafting area

    -- Silver Farming
    ["Deep Forest"]        = CFrame.new(-100, 90, -300),     -- Loot chests
    ["Sunken Passage"]     = CFrame.new(120, 40, -410),      -- Loot chests
}

------------------------------------------------------------
-- MODULE STATE
------------------------------------------------------------
local SKC = {
    active = false,
    current_phase = "idle",
    status = "Not started",
    log = {},
    config = {
        auto_train_sword = true,
        auto_farm_silver = true,
        auto_buy_skills = true,
        player_safety = true,
        safety_range = 60,
        train_delay = 0.3,
    },
}

------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------
local function getChar() return LP.Character end
local function getHRP()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end

function SKC:log_msg(msg)
    local entry = "[" .. os.date("%H:%M:%S") .. "] " .. msg
    table.insert(self.log, entry)
    if #self.log > 200 then table.remove(self.log, 1) end
    print("[SKC] " .. msg)
end

------------------------------------------------------------
-- DETECTION
------------------------------------------------------------

-- detect which skills the player owns
function SKC:getOwnedSkills()
    local char = getChar()
    if not char then return {} end

    local owned = {}
    for _, child in ipairs(char:GetChildren()) do
        owned[child.Name] = true
    end

    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            owned[tool.Name] = true
        end
    end

    return owned
end

-- detect current orderly/chaotic alignment
function SKC:getAlignment()
    local result = {orderly = 0, chaotic = 0, alignment = "Neutral"}

    local ls = LP:FindFirstChild("leaderstats") or LP:FindFirstChild("Stats")
    if ls then
        local ord = ls:FindFirstChild("Orderly") or ls:FindFirstChild("Order")
        local cha = ls:FindFirstChild("Chaotic") or ls:FindFirstChild("Chaos")
        if ord then result.orderly = ord.Value end
        if cha then result.chaotic = cha.Value end
    end

    local char = getChar()
    if char then
        local ord = char:FindFirstChild("Orderly") or char:FindFirstChild("Order")
        local cha = char:FindFirstChild("Chaotic") or char:FindFirstChild("Chaos")
        if ord and ord:IsA("NumberValue") then result.orderly = ord.Value end
        if cha and cha:IsA("NumberValue") then result.chaotic = cha.Value end
    end

    if result.orderly > result.chaotic then
        result.alignment = "Orderly"
    elseif result.chaotic > result.orderly then
        result.alignment = "Chaotic"
    end

    return result
end

-- detect current silver
function SKC:getSilver()
    local ls = LP:FindFirstChild("leaderstats") or LP:FindFirstChild("Stats")
    if ls then
        local s = ls:FindFirstChild("Silver") or ls:FindFirstChild("Gold")
        if s then return s.Value end
    end
    return 0
end

-- figure out where player is in the progression
function SKC:detectPhase()
    local skills = self:getOwnedSkills()
    local alignment = self:getAlignment()

    -- check SKC skills (ultra)
    local skc_skills = {"Fire Charged Blow", "Ice Charged Blow", "Lightning Charged Blow", "Hyper Body",
                        "ChargedBlow", "HyperBody", "FireChargedBlow", "IceChargedBlow", "LightningChargedBlow"}
    local has_skc = false
    for _, s in ipairs(skc_skills) do
        if skills[s] then has_skc = true; break end
    end
    if has_skc then
        return "complete", "You already have Sigil Knight Commander skills!"
    end

    -- check SK skills (super)
    local sk_names = {"Flame Charge", "Ice Charge", "Lightning Charge",
                      "FlameCharge", "IceCharge", "LightningCharge"}
    local sk_count = 0
    for _, s in ipairs(sk_names) do
        if skills[s] then sk_count += 1 end
    end

    local has_max_sk = sk_count >= 3

    if has_max_sk then
        -- need orderly + silver for SKC
        if alignment.orderly >= 50 then
            return "ready_for_skc", "Max Sigil Knight + enough orderly. Need 1400 silver for SKC trainer."
        else
            return "need_orderly_for_skc", "Max Sigil Knight but need " .. (50 - alignment.orderly) .. " more orderly for SKC."
        end
    end

    if sk_count > 0 then
        return "training_sk", "Have " .. sk_count .. "/3 Sigil Knight skills. Keep training."
    end

    -- check warrior skills (base)
    local warrior_names = {"Pommel Strike", "Action Surge", "Mercenary Carry", "Lord's Training",
                           "PommelStrike", "ActionSurge", "MercenaryCarry", "LordsTraining",
                           "LordTraining", "Pommel"}
    local warrior_count = 0
    for _, s in ipairs(warrior_names) do
        if skills[s] then warrior_count += 1 end
    end

    if warrior_count >= 3 then
        if alignment.orderly >= 25 then
            return "ready_for_sk", "Have enough Warrior skills + orderly. Need sword XP + 195 silver for SK trainer."
        else
            return "need_orderly_for_sk", "Have Warrior skills but need " .. (25 - alignment.orderly) .. " more orderly for Sigil Knight."
        end
    end

    if warrior_count > 0 then
        return "training_warrior", "Have " .. warrior_count .. "/4 Warrior skills. Keep farming XP + silver."
    end

    return "freshspawn", "No Warrior skills yet. Need sword XP + 140 silver. Farm Zombie Scrooms first."
end

------------------------------------------------------------
-- SAFETY CHECK — pause if players nearby
------------------------------------------------------------
function SKC:isPlayerNearby(range)
    if not self.config.player_safety then return false end
    range = range or self.config.safety_range

    local hrp = getHRP()
    if not hrp then return false end

    for _, plr in Players:GetPlayers() do
        if plr ~= LP then
            local c = plr.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - hrp.Position).Magnitude < range then
                return true, plr.DisplayName
            end
        end
    end
    return false
end

------------------------------------------------------------
-- CORE ACTIONS
------------------------------------------------------------

-- teleport safely
function SKC:teleportTo(name, cframe)
    local hrp = getHRP()
    if not hrp then return false end

    self:log_msg("Teleporting to " .. name .. "...")
    self.status = "Traveling to " .. name
    task.wait(0.2)
    hrp.CFrame = cframe
    task.wait(0.8)
    return true
end

-- farm sword XP by attacking nearest NPCs
function SKC:farmSwordXP(duration)
    duration = duration or 120  -- seconds
    self.status = "Farming sword XP at Crypt of Kings"
    self:log_msg("Starting sword XP farm (" .. duration .. "s)...")

    self:teleportTo("Crypt of Kings", Locations["Crypt of Kings"])

    local startTime = os.clock()
    local swingCount = 0

    while self.active and (os.clock() - startTime) < duration do
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then task.wait(1); continue end

        -- safety check
        local danger, dangerName = self:isPlayerNearby()
        if danger then
            self:log_msg("Player detected: " .. dangerName .. " — pausing farm...")
            self.status = "DANGER — player nearby: " .. dangerName
            task.wait(5)
            continue
        end

        -- find nearest NPC/zombie to attack
        local nearest, bestDist = nil, 50
        local live = workspace:FindFirstChild("Live")
        if live then
            for _, mob in ipairs(live:GetChildren()) do
                if mob ~= getChar() then
                    local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                    local mobHum = mob:FindFirstChildOfClass("Humanoid")
                    local monsterInfo = mob:FindFirstChild("MonsterInfo")

                    if mobHRP and mobHum and mobHum.Health > 0 and monsterInfo then
                        local d = (mobHRP.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            nearest = mob
                            bestDist = d
                        end
                    end
                end
            end
        end

        if nearest then
            local mobHRP = nearest:FindFirstChild("HumanoidRootPart")
            if mobHRP then
                -- face the mob
                hrp.CFrame = CFrame.new(hrp.Position, mobHRP.Position)

                -- move close if needed
                if bestDist > 8 then
                    hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, 5)
                    task.wait(0.2)
                end

                -- swing sword (left click)
                local char = getChar()
                if char then
                    local handler = char:FindFirstChild("CharacterHandler")
                    if handler then
                        local remotes = handler:FindFirstChild("Remotes")
                        if remotes then
                            local leftClick = remotes:FindFirstChild("LeftClick")
                            if leftClick then
                                leftClick:FireServer({math.random(1, 10), math.random()})
                                swingCount += 1
                            end
                        end
                    end
                end
            end
        end

        task.wait(self.config.train_delay + math.random() * 0.15)
    end

    self:log_msg("Sword farm session done — " .. swingCount .. " swings")
    return swingCount
end

-- train at a click-detector NPC (like trainers)
function SKC:trainAtTrainer(trainerName, location, maxClicks)
    maxClicks = maxClicks or 30
    self.status = "Training at " .. trainerName
    self:teleportTo(trainerName, location)

    local clicks = 0
    while self.active and clicks < maxClicks do
        local hrp = getHRP()
        if not hrp then task.wait(1); continue end

        local danger, name = self:isPlayerNearby()
        if danger then
            self:log_msg("Player nearby: " .. name .. " — pausing...")
            self.status = "DANGER — " .. name .. " nearby"
            task.wait(5)
            continue
        end

        -- find click detectors near trainer location
        local nearest, bestDist = nil, 25
        for _, obj in workspace:GetDescendants() do
            if obj:IsA("ClickDetector") then
                local part = obj.Parent
                if part and part:IsA("BasePart") then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestDist then
                        nearest = obj; bestDist = d
                    end
                end
            end
        end

        -- also check for proximity prompts (Gaia uses these sometimes)
        if not nearest then
            for _, obj in workspace:GetDescendants() do
                if obj:IsA("ProximityPrompt") then
                    local part = obj.Parent
                    if part and part:IsA("BasePart") then
                        local d = (part.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            fireproximityprompt(obj)
                            clicks += 1
                            self:log_msg("Proximity prompt click #" .. clicks)
                        end
                    end
                end
            end
        end

        if nearest then
            fireclickdetector(nearest)
            clicks += 1
            if clicks % 5 == 0 then
                self:log_msg("Trainer click #" .. clicks .. "/" .. maxClicks)
            end
        end

        task.wait(0.4 + math.random() * 0.2)
    end

    self:log_msg("Training session done — " .. clicks .. " interactions")
    return clicks
end

-- farm silver by looting chests
function SKC:farmSilver(targetAmount, duration)
    duration = duration or 180
    self.status = "Farming silver (need " .. targetAmount .. ")"
    self:log_msg("Starting silver farm — target: " .. targetAmount)

    local lootSpots = {
        {name = "Deep Forest", cframe = Locations["Deep Forest"]},
        {name = "Sunken Passage", cframe = Locations["Sunken Passage"]},
        {name = "Crypt of Kings", cframe = Locations["Crypt of Kings"]},
    }

    local startTime = os.clock()
    local spotIndex = 1

    while self.active and (os.clock() - startTime) < duration do
        local currentSilver = self:getSilver()
        if currentSilver >= targetAmount then
            self:log_msg("Silver target reached! (" .. currentSilver .. "/" .. targetAmount .. ")")
            return true
        end

        local danger, name = self:isPlayerNearby()
        if danger then
            self:log_msg("Player nearby: " .. name .. " — pausing...")
            task.wait(5)
            continue
        end

        -- cycle through loot spots
        local spot = lootSpots[spotIndex]
        self:teleportTo(spot.name, spot.cframe)

        -- pick up nearby items
        local hrp = getHRP()
        if hrp then
            for _, obj in workspace:GetDescendants() do
                if obj:IsA("Tool") and obj.Parent == workspace then
                    local handle = obj:FindFirstChild("Handle")
                    if handle and (handle.Position - hrp.Position).Magnitude < 30 then
                        firetouchinterest(hrp, handle, 0)
                        task.wait()
                        firetouchinterest(hrp, handle, 1)
                    end
                end
            end
        end

        task.wait(3)
        spotIndex = (spotIndex % #lootSpots) + 1
    end

    self:log_msg("Silver farm session ended. Current: " .. self:getSilver())
    return false
end

------------------------------------------------------------
-- MAIN PROGRESSION LOOP
------------------------------------------------------------

function SKC:start()
    if self.active then
        self:log_msg("Already running — call SKC:stop() first")
        return
    end

    self.active = true
    self:log_msg("=== SIGIL KNIGHT COMMANDER PROGRESSION STARTED ===")

    task.spawn(function()
        while self.active do
            local phase, desc = self:detectPhase()
            self:log_msg("Phase: " .. phase .. " — " .. desc)
            self.current_phase = phase

            if phase == "complete" then
                self:log_msg("CONGRATULATIONS — you are Sigil Knight Commander!")
                self.status = "COMPLETE — Sigil Knight Commander achieved!"
                self.active = false
                break

            elseif phase == "freshspawn" then
                -- Step 1: Farm sword XP then buy Warrior skills
                self:log_msg("STEP 1: Get Warrior base class")
                self:log_msg("  → Need ~280 sword hits (8 Zombie Scrooms)")
                self:log_msg("  → Need 140 silver for skills")
                self:log_msg("  → Trainer: Alfric at Emeraldstone Tavern, Sea of Dust")

                if self.config.auto_farm_silver then
                    local silver = self:getSilver()
                    if silver < 140 then
                        self:farmSilver(140, 120)
                    end
                end

                if self.config.auto_train_sword then
                    self:farmSwordXP(180)
                end

                if self.config.auto_buy_skills then
                    self:trainAtTrainer("Alfric (Warrior)", Locations["Alfric"], 20)
                end

            elseif phase == "training_warrior" then
                self:log_msg("STEP 1 (cont): Still training Warrior")
                self:log_msg("  → Keep farming sword XP + buying skills")

                local silver = self:getSilver()
                if silver < 35 then
                    self:farmSilver(35, 60)
                end

                self:farmSwordXP(120)
                self:trainAtTrainer("Alfric (Warrior)", Locations["Alfric"], 10)

            elseif phase == "need_orderly_for_sk" then
                local alignment = self:getAlignment()
                local needed = 25 - alignment.orderly
                self:log_msg("STEP 2 (prep): Need " .. needed .. " more orderly for Sigil Knight")
                self:log_msg("  → Drink Tespian Elixirs (+5 each)")
                self:log_msg("  → Rot knocked players at fire pits (+1 each)")
                self:log_msg("  → Complete orderly quests around the map")
                self.status = "Need " .. needed .. " orderly — manual action required"
                -- can't auto-grind orderly easily, wait for player
                task.wait(15)

            elseif phase == "ready_for_sk" then
                self:log_msg("STEP 2: Get Sigil Knight super class")
                self:log_msg("  → Need more sword XP (~12 Zombie Scrooms)")
                self:log_msg("  → Need 195 silver for skills")
                self:log_msg("  → Trainer: Draug at Central Sanctuary (Royal Woods)")

                local silver = self:getSilver()
                if silver < 195 then
                    self:farmSilver(195, 120)
                end

                self:farmSwordXP(180)
                self:trainAtTrainer("Draug (Sigil Knight)", Locations["Central Sanctuary"], 20)

            elseif phase == "training_sk" then
                self:log_msg("STEP 2 (cont): Training Sigil Knight skills")

                local silver = self:getSilver()
                if silver < 65 then
                    self:farmSilver(65, 60)
                end

                self:farmSwordXP(120)
                self:trainAtTrainer("Draug (Sigil Knight)", Locations["Central Sanctuary"], 10)

            elseif phase == "need_orderly_for_skc" then
                local alignment = self:getAlignment()
                local needed = 50 - alignment.orderly
                self:log_msg("STEP 3 (prep): Need " .. needed .. " more orderly for SKC")
                self:log_msg("  → 5 Tespians = 25 orderly")
                self:log_msg("  → Complete ALL orderly quests (~55 orderly)")
                self:log_msg("  → Rot knocked players")
                self.status = "Need " .. needed .. " orderly for SKC — manual action required"
                task.wait(15)

            elseif phase == "ready_for_skc" then
                self:log_msg("STEP 3: Get Sigil Knight Commander ultra class!")
                self:log_msg("  → Need 1400 silver for all skills (1850 with armor)")
                self:log_msg("  → Trainer: Jagen at Castle Sanctuary")

                local silver = self:getSilver()
                if silver < 1400 then
                    self:farmSilver(1400, 300)
                end

                self:trainAtTrainer("Jagen (SKC)", Locations["Castle Sanctuary"], 20)
                self:log_msg("Check if you got your skills!")
            end

            task.wait(3)
        end
    end)
end

function SKC:stop()
    self.active = false
    self.status = "Stopped"
    self:log_msg("Progression stopped")
end

------------------------------------------------------------
-- STATUS / ANALYSIS
------------------------------------------------------------

function SKC:analyze()
    local phase, desc = self:detectPhase()
    local alignment = self:getAlignment()
    local silver = self:getSilver()
    local skills = self:getOwnedSkills()

    print("\n╔══════════════════════════════════════════╗")
    print("║   SIGIL KNIGHT COMMANDER PROGRESSION     ║")
    print("╠══════════════════════════════════════════╣")
    print("║ Current Phase: " .. phase)
    print("║ Status: " .. desc)
    print("║ Orderly: " .. alignment.orderly .. " / 50 needed for SKC")
    print("║ Silver: " .. silver)
    print("╠══════════════════════════════════════════╣")

    print("║ WARRIOR (Base) — need 3/4 skills:")
    local warriorSkills = {"Pommel Strike", "Action Surge", "Mercenary Carry", "Lord's Training",
                           "PommelStrike", "ActionSurge", "MercenaryCarry", "LordsTraining"}
    local wCount = 0
    for _, s in ipairs(warriorSkills) do
        if skills[s] then
            print("║   ✓ " .. s)
            wCount += 1
        end
    end
    if wCount == 0 then print("║   ✗ No warrior skills yet") end

    print("║")
    print("║ SIGIL KNIGHT (Super) — need all 3:")
    local skSkills = {"Flame Charge", "Ice Charge", "Lightning Charge",
                      "FlameCharge", "IceCharge", "LightningCharge"}
    local skCount = 0
    for _, s in ipairs(skSkills) do
        if skills[s] then
            print("║   ✓ " .. s)
            skCount += 1
        end
    end
    if skCount == 0 then print("║   ✗ No Sigil Knight skills yet") end

    print("║")
    print("║ SKC (Ultra) — need all 4:")
    local skcSkills = {"Fire Charged Blow", "Ice Charged Blow", "Lightning Charged Blow", "Hyper Body",
                       "FireChargedBlow", "IceChargedBlow", "LightningChargedBlow", "HyperBody"}
    local skcCount = 0
    for _, s in ipairs(skcSkills) do
        if skills[s] then
            print("║   ✓ " .. s)
            skcCount += 1
        end
    end
    if skcCount == 0 then print("║   ✗ No SKC skills yet") end

    print("╠══════════════════════════════════════════╣")
    print("║ TOTAL SILVER NEEDED FROM SCRATCH:")
    print("║   Warrior:  140  (35 × 4 skills)")
    print("║   Sigil:    195  (65 × 3 skills)")
    print("║   SKC:     1400  (350 × 4 skills)")
    print("║   Armor:    450  (optional)")
    print("║   TOTAL:   1735  (2185 with armor)")
    print("╠══════════════════════════════════════════╣")
    print("║ ORDERLY NEEDED:")
    print("║   Sigil Knight: 25")
    print("║   SKC:          50")
    print("║   Methods: Tespian Elixir (+5), Rots (+1)")
    print("╚══════════════════════════════════════════╝\n")
end

-- quick reference for manual steps
function SKC:guide()
    print("\n=== SKC QUICK GUIDE ===")
    print("")
    print("1. WARRIOR (Sword Base Class)")
    print("   • Farm 8 Zombie Scrooms at Crypt of Kings with bronze sword")
    print("   • Get 140 silver")
    print("   • Talk to Alfric at Emeraldstone Tavern, Sea of Dust")
    print("   • Buy all 4 skills (especially Lord's Training)")
    print("")
    print("2. SIGIL KNIGHT (Orderly Super Class)")
    print("   • Get 25 orderly (5 Tespian Elixirs = done)")
    print("   • Farm 12 more Zombie Scrooms for sword XP")
    print("   • Get 195 silver")
    print("   • Climb the big tree in Royal Woods → Central Sanctuary")
    print("   • Talk to Draug, buy all 3 charge skills")
    print("")
    print("3. SIGIL KNIGHT COMMANDER (Orderly Ultra Class)")
    print("   • Max all Sigil Knight skills")
    print("   • Get 50 orderly total (tespians + quests + rots)")
    print("   • Get 1400 silver (1850 with armor)")
    print("   • Go to Castle Sanctuary → talk to Jagen")
    print("   • Buy all 4 skills")
    print("")
    print("TIPS:")
    print("   • Get Lord's Training early — extra M1 combo hits = more damage as SKC")
    print("   • Flame Charge vs Necros/Vampires, Ice Charge for area denial")
    print("   • Lightning Charged Blow breaks mana shields — use vs mages")
    print("   • Hyper Body is massive HP boost — your main survivability tool")
    print("   • Get Solan's Sword later for White Fire Charge combo")
    print("========================\n")
end

return SKC
