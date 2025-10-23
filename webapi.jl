include("lights.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = Dict()

route("/simulations", method = POST) do
    payload = jsonpayload()

    model = initialize_model()
    id = string(uuid1())
    instances[id] = model

    lights = []
    for light in allagents(model)
        light_data = Dict(
            "id" => light.id,
            "pos" => light.pos,
            "color" => string(light.color),
            "orientation" => string(light.orientation)
        )
        println("Light data: ", light_data)
        push!(lights, light_data)
    end
    
    response = Dict("Location" => "/simulations/$id", "lights" => lights)
    println("Sending response: ", response)
    json(response)
end

route("/simulations/:id") do
    id = payload(:id)
    println("Received GET request for simulation: ", id)
    
    model = instances[id]
    run!(model, 1)
    
    lights = []
    for light in allagents(model)
        light_data = Dict(
            "id" => light.id,
            "pos" => light.pos,
            "color" => string(light.color),
            "orientation" => string(light.orientation)
        )
        println("Updated light data: ", light_data)
        push!(lights, light_data)
    end
    
    response = Dict("lights" => lights)
    println("Sending update response: ", response)
    json(response)
end


Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

up()