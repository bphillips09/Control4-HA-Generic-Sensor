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
        print("NO DATA")
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

    if state ~= nil then
        if sensorType == "Temperature" then
            local numericValue = tonumber(state)
            local measurement = attributes["unit_of_measurement"]

            local celciusValue
            local fahrenheitValue

            if measurement == "°F" then
                fahrenheitValue = numericValue
                celciusValue = ToCelsius(fahrenheitValue)
            elseif measurement == "°C" then
                celciusValue = numericValue
                fahrenheitValue = ToFahrenheit(celciusValue)
            end

            tParams = {
                CELSIUS = celciusValue,
                FAHRENHEIT = fahrenheitValue
            }

            C4:SendToProxy(500, 'VALUE_CHANGED', tParams, "NOTIFY")
        elseif sensorType == "Humidity" then
            local numericValue = tonumber(state)
            
            tParams = {
                VALUE = numericValue
            }

            C4:SendToProxy(600, 'VALUE_CHANGED', tParams, "NOTIFY")
        else
            
        end
    end
end