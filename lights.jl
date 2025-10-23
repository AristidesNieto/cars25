using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform

@enum TrafficLightColor GREEN YELLOW RED

const GREEN_TIME = 10
const YELLOW_TIME = 4
const RED_TIME = 14
const CYCLE_TIME = 28

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    color::TrafficLightColor
    timer::Int
    orientation::Symbol
end

@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool
end

function get_traffic_light_ahead(car::Car, model)
    for agent in allagents(model)
        if agent isa TrafficLight && agent.orientation == :horizontal
            if agent.pos[1] > car.pos[1] && abs(agent.pos[2] - car.pos[2]) < 2.0
                return agent
            end
        end
    end
    return nothing
end

function should_stop_for_light(car::Car, model, stopping_distance = 3.0)
    light = get_traffic_light_ahead(car, model)
    
    if isnothing(light)
        return false
    end
    
    distance_to_light = light.pos[1] - car.pos[1]
    
    if distance_to_light > 0 && distance_to_light <= stopping_distance
        if light.color == RED || light.color == YELLOW
            return true
        end
    end
    
    return false
end

function car_ahead(car::Car, model, detection_distance = 2.0)
    for agent in allagents(model)
        if agent isa Car && agent.id != car.id
            if abs(agent.pos[2] - car.pos[2]) < 1.0
                if agent.pos[1] > car.pos[1] && (agent.pos[1] - car.pos[1]) <= detection_distance
                    return agent
                end
            end
        end
    end
    return nothing
end

accelerate(agent) = min(agent.vel[1] + 0.05, 1.0)
decelerate(agent) = max(agent.vel[1] - 0.1, 0.0)

function agent_step!(light::TrafficLight, model)
    props = abmproperties(model)
    tiempo = props[:step]
    
    cycle_time = mod(tiempo - 1, CYCLE_TIME)
    
    if light.orientation == :horizontal
        if cycle_time < GREEN_TIME
            light.color = GREEN
        elseif cycle_time < GREEN_TIME + YELLOW_TIME
            light.color = YELLOW
        else
            light.color = RED
        end
    else
        if cycle_time < GREEN_TIME + YELLOW_TIME
            light.color = RED
        elseif cycle_time < GREEN_TIME + YELLOW_TIME + GREEN_TIME
            light.color = GREEN
        else
            light.color = YELLOW
        end
    end
end

function agent_step!(car::Car, model)
    new_velocity = car.vel[1]
    
    if should_stop_for_light(car, model)
        new_velocity = decelerate(car)
    elseif !isnothing(car_ahead(car, model))
        new_velocity = decelerate(car)
    else
        new_velocity = accelerate(car)
    end
    
    car.vel = SVector(new_velocity, 0.0)
    move_agent!(car, model, 0.4)
end

function model_step!(model)
    props = abmproperties(model)
    props[:step] += 1
end

function initialize_model(extent = (25, 25), num_cars = 1)
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = (true, false))
    rng = Random.MersenneTwister()

    properties = Dict(:step => 0)

    function traffic_scheduler(model)
        lights = [a.id for a in allagents(model) if a isa TrafficLight]
        cars = [a.id for a in allagents(model) if a isa Car]
        return vcat(lights, cars)
    end

    model = StandardABM(
        Union{Car, TrafficLight}, 
        space2d;
        properties = properties,
        rng, 
        agent_step!,
        model_step!,
        scheduler = traffic_scheduler
    )

    # Add traffic lights
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
        SVector(extent[1]/2, extent[2]/2 + 2.5),
        TrafficLight,
        model;
        color = RED,
        timer = 0,
        orientation = :vertical,
        vel = SVector(0.0, 0.0)
    )

    # Add cars
    semaphore_x = extent[1]/2 - 2
    exclusion_start = semaphore_x - 2
    exclusion_end = semaphore_x + 5
    
    car_y = extent[2]/2
    
    for i in 1:num_cars
        valid_position = false
        px = 0.0
        
        while !valid_position
            px = rand(rng) * extent[1]
            if px < exclusion_start || px > exclusion_end
                valid_position = true
            end
        end
        
        add_agent!(
            SVector(px, car_y),
            Car,
            model;
            vel = SVector(rand(rng, Uniform(0.3, 0.7)), 0.0),
            accelerating = true
        )
    end
    
    model
end