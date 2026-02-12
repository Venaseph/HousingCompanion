-- ============================================================================
-- Vamoose's Endeavors - EventBus
-- Simple pub/sub event system for decoupled module communication
-- ============================================================================

HC = HC or {}
HC.EventBus = {
    listeners = {}
}

-- Register a callback for an event
function HC.EventBus:Register(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], callback)
end

-- Trigger an event with optional payload
function HC.EventBus:Trigger(event, payload)
    if self.listeners[event] then
        for _, callback in ipairs(self.listeners[event]) do
            -- Safely call callback to prevent one error breaking the bus
            local status, err = pcall(callback, payload)
            if not status then
                print("|cffff0000[HC EventBus Error]|r", event, err)
            end
        end
    end
end

-- Unregister a specific callback (optional utility)
function HC.EventBus:Unregister(event, callback)
    if self.listeners[event] then
        for i, cb in ipairs(self.listeners[event]) do
            if cb == callback then
                table.remove(self.listeners[event], i)
                return true
            end
        end
    end
    return false
end
