using Agents, Random
using StaticArrays: SVector

@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool = true
end

accelerate(agent) = agent.vel[1] + 0.05
decelerate(agent) = agent.vel[1] - 0.1

function car_ahead(agent, model)
    for neighbor in nearby_agents(agent, model, 1.0)
        if neighbor.pos[1] > agent.pos[1]
            return neighbor
        end
    end
    return nothing
end

function  agent_step!(agent, model)
    new_velocity = agent.accelerating ? accelerate(agent) : decelerate(agent)

    if new_velocity >= 1.0
        new_velocity = 1.0
        agent.accelerating = false
    elseif new_velocity <= 0.0
        new_velocity = 0.0
        agent.accelerating = true
    end
    
    agent.vel = (new_velocity, 0.0)
    move_agent!(agent, model, 0.4)
end

function initialize_model(extent = (25, 10))
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    first = true
    py = 1.0
    for px in randperm(25)[1:5]
        if first
            add_agent!(SVector{2, Float64}(px, py), model; vel=SVector{2, Float64}(1.0, 0.0))
        else
            add_agent!(SVector{2, Float64}(px, py), model; vel=SVector{2, Float64}(rand(Uniform(0.2, 0.7)), 0.0))
        end
        py += 2.0
    end
    model
end

