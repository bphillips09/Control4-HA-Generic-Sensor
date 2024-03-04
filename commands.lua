SENT_INITIAL_TEMPERATURE = false
SENT_INITIAL_HUMIDITY = false

function DRV.OnDriverInit(init)
    C4:AddVariable("SENSOR_STATE", "", "STRING")
    C4:AddVariable("SENSOR_STATE_INT", "", "INT")
    C4:AddVariable("SENSOR_STATE_FLOAT", "", "FLOAT")
end

function DRV.OnDriverDestroyed(init)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    local sensorType = Properties["Sensor Type"]

    local state = data["state"]
    local attributes = data["attributes"]

    local tParams = {}

    if not Connected then
        Connected = true
    end
    if state == "unavailable" then
        C4:SetVariable("SENSOR_STATE", tostring(state))

        if sensorType == "Temperature" then
            SENT_INITIAL_TEMPERATURE = false
            C4:SendToProxy(500, "VALUE_UNAVAILABLE", { STATUS = "offline" }, "NOTIFY")
        end
        if sensorType == "Humidity" then
            SENT_INITIAL_HUMIDITY = false
            C4:SendToProxy(600, "VALUE_UNAVAILABLE", { STATUS = "offline" }, "NOTIFY")
        end
        return
    end

    if state ~= nil and state ~= "unavailable" then
        local strState = tostring(state)
        local numericState

        if type(state) == "number" then
            numericState = tonumber(state)
        else
            numericState = 0
        end

        C4:UpdateProperty("Value", strState)

        C4:SetVariable("SENSOR_STATE", strState)
        C4:SetVariable("SENSOR_STATE_INT", numericState)
        C4:SetVariable("SENSOR_STATE_FLOAT", numericState)

        if sensorType == "Temperature" then
            local measurement = attributes["unit_of_measurement"]

            local celsiusValue
            local fahrenheitValue

            if measurement == "°F" then
                fahrenheitValue = numericState
                celsiusValue = ToCelsius(fahrenheitValue)
            elseif measurement == "°C" then
                celsiusValue = numericState
                fahrenheitValue = ToFahrenheit(celsiusValue)
            end

            if SENT_INITIAL_TEMPERATURE then
                tParams = {
                    CELSIUS = celsiusValue,
                    FAHRENHEIT = fahrenheitValue,
                    TIMESTAMP = tostring(os.time())
                }
                C4:SendToProxy(500, 'VALUE_CHANGED', tParams, "NOTIFY")
            else
                SENT_INITIAL_TEMPERATURE = true

                tParams = {
                    STATUS = "active",
                    TIMESTAMP = tostring(os.time())
                }
                C4:SendToProxy(500, 'VALUE_INITIALIZE', tParams, "NOTIFY")
                if measurement == "°F" then
                    fahrenheitValue = numericState
                    celsiusValue = ToCelsius(fahrenheitValue)
                elseif measurement == "°C" then
                    celsiusValue = numericState
                    fahrenheitValue = ToFahrenheit(celsiusValue)
                end
                tParams = {
                    CELSIUS = celsiusValue,
                    FAHRENHEIT = fahrenheitValue,
                    TIMESTAMP = tostring(os.time())
                }
                C4:SendToProxy(500, 'VALUE_CHANGED', tParams, "NOTIFY")
            end
        elseif sensorType == "Humidity" then
            if SENT_INITIAL_HUMIDITY then
                tParams = {
                    SCALE = "FAHRENHEIT",
                    VALUE = numericState,
                    TIMESTAMP = tostring(os.time())
                }

                C4:SendToProxy(600, 'VALUE_CHANGED', tParams, "NOTIFY")
            else
                SENT_INITIAL_HUMIDITY = true

                tParams = {
                    STATUS = "active",
                    TIMESTAMP = tostring(os.time())
                }

                C4:SendToProxy(600, 'VALUE_INITIALIZE', tParams, "NOTIFY")
            end
        end
    end
end