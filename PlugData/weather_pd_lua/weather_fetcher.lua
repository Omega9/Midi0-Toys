-- weather_fetcher.lua

function pdlua_load()
    print("Lua модуль загружен: weather_fetcher")
end

function get_weather()
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local cjson = require("cjson")

    local api_key = "2c309a6071cc813d066a296d31858751"
    local city = "Ufa"
    local url = "http://api.openweathermap.org/data/2.5/weather?q=" .. city .. "&appid=" .. api_key

    local response = {}
    local code, headers, status = http.request{
        url = url,
        sink = ltn12.sink.table(response)
    }

    if code == 200 then
        local json_str = table.concat(response)
        local data = cjson.decode(json_str)
        local temp = math.floor(data.main.temp - 273.15 + 0.5) -- Кельвины → Цельсии
        local humidity = data.main.humidity

        outlet(0, temp)
        outlet(1, humidity)
    else
        error("Ошибка при запросе к API: " .. tostring(code))
    end
end
