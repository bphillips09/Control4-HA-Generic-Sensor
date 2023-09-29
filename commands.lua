SENT_INITIAL_TEMPERATURE = false
SENT_INITIAL_HUMIDITY = false

function DRV.OnDriverInit(init)
    C4:AddVariable("SENSOR_STATE", "", "STRING")
end

function DRV.OnDriverLateInit(init)
    C4:SetTimer(30000, EC.REFRESH, true)
end

function DRV.OnDriverDestroyed(init)
    C4:DeleteVariable("SENSOR_STATE")
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
        C4:SetVariable("SENSOR_STATE", tostring(state))

        if sensorType == "Temperature" then
            local numericValue = tonumber(state)
            local measurement = attributes["unit_of_measurement"]

            local celsiusValue
            local fahrenheitValue

            if measurement == "°F" then
                fahrenheitValue = numericValue
                celsiusValue = ToCelsius(fahrenheitValue)
            elseif measurement == "°C" then
                celsiusValue = numericValue
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
                    fahrenheitValue = numericValue
                    celsiusValue = ToCelsius(fahrenheitValue)
                elseif measurement == "°C" then
                    celsiusValue = numericValue
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
            local numericValue = tonumber(state)

            if SENT_INITIAL_HUMIDITY then
                tParams = {
                    VALUE = numericValue,
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