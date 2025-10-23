using Agents, Random
using StaticArrays: SVector

@enum TrafficLightColor GREEN YELLOW RED

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    color::TrafficLightColor
    timer::Int
    orientation::Symbol
end

const GREEN_TIME = 10
const YELLOW_TIME = 4
const RED_TIME = 14
const CYCLE_TIME = 28

function agent_step!(agent::TrafficLight, model)
    props = abmproperties(model)
    props[:step] += 1
    tiempo = props[:step]
    
    cycle_time = mod(tiempo - 1, CYCLE_TIME)
    
    if agent.orientation == :horizontal
        if cycle_time < GREEN_TIME
            agent.color = GREEN
            agent.timer = GREEN_TIME - cycle_time
        elseif cycle_time < GREEN_TIME + YELLOW_TIME
            agent.color = YELLOW
            agent.timer = (GREEN_TIME + YELLOW_TIME) - cycle_time
        else
            agent.color = RED
            agent.timer = CYCLE_TIME - cycle_time
        end
    else
        if cycle_time < GREEN_TIME + YELLOW_TIME
            agent.color = RED
            agent.timer = (GREEN_TIME + YELLOW_TIME) - cycle_time
        elseif cycle_time < GREEN_TIME + YELLOW_TIME + GREEN_TIME
            agent.color = GREEN
            agent.timer = (GREEN_TIME + YELLOW_TIME + GREEN_TIME) - cycle_time
        else
            agent.color = YELLOW
            agent.timer = CYCLE_TIME - cycle_time
        end
    end
end

function initialize_model(extent = (25, 25))
    space2d = ContinuousSpace(extent; spacing = 0.5)
    rng = Random.MersenneTwister()

    properties = Dict(
        :step => 0
    )

    model = StandardABM(
        TrafficLight, 
        space2d;
        properties = properties,
        rng, 
        agent_step!,
        scheduler = Schedulers.ByID()
    )

    add_agent!(
        SVector(extent[1]/2 - 2, extent[2]/2),
        TrafficLight,
        model;
        color = GREEN,
        timer = 0,
        orientation = :horizontal,
        vel = SVector(0.0, 0.0)
    )

    add_agent!(
        SVector{2, Float64}(12.0, 15.0),
        TrafficLight,
        model;
        color = RED,
        timer = 0,
        orientation = :vertical,
        vel = SVector(0.0, 0.0)
    )

    model
end