include("simple.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = Dict()

route("/simulations", method = POST) do
    payload = jsonpayload()

    model = initialize_model()
    id = string(uuid1())
    instances[id] = model

    cars = []
    for car in allagents(model)
        if car.id == 1
            println("Carro Id 1 con posicion: $(car.pos)")
        end
        push!(cars, car)
    end
    
    json(Dict("Location" => "/simulations/$id", "cars" => cars))
end

route("/simulations/:id") do
    println(payload(:id))
    model = instances[payload(:id)]
    run!(model, 1)
    cars = []
    for car in allagents(model)
        push!(cars, Dict(
            "id" => car.id,
            "pos" => car.pos,
            "vel" => car.vel
        ))
    end
    
    json(Dict("cars" => cars))
end


Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

up()