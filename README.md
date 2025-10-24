## Autores
Luis Fernando Cruz Flores

Aristides Nieto Guzman 

Proyecto desarrollado para el curso de Sistemas Multi-Agentes

---

## Reflexiones Individuales
**Luis Fernando:** 
Durante el desarrollo de este proyecto aprendí a integrar Agents.jl con un frontend en React, lo que me permitió comprender mejor cómo conectar un modelo de simulación con una interfaz visual en tiempo real. Este proceso me ayudó a reforzar mi conocimiento sobre sistemas multiagentes, aprendí a implementar la sincronización de semáforos, la detección de vecinos y lo más complicado, aprendí a modelar el comportamiento de agentes entre si mediante el diseño de un scheduler personalizado para coordinar las interacciones dentro del entorno.
También entendí la importancia de equilibrar la precisión del modelo con la eficiencia computacional, ya que fue necesario simplificar aspectos como la física del vehículo y la detección basada en umbrales para mantener un desempeño estable. Trabajar con un escenario limitado a una intersección bidireccional me permitió enfocarme en la lógica de control antes de escalar hacia casos más complejos.

Considero que hay aspectos que se podría mejorar para lograr intersecciones más realistas, por ejemplo, incorporar control adaptativo de semáforos (por ejemplo, con aprendizaje por refuerzo), diversificar el tipo de vehículos y aplicar optimizaciones de rendimiento.
En general, este proyecto me permitió consolidar habilidades tanto técnicas como de diseño de sistemas, y representa una base sólida para el desarrollo de proyectos futuros como el proyecto Integrador, donde fusionaremos las simulaciones de Julia con un ambiente grafico en OpenGL


**Aristides Nieto**
Este proyecto me permitio pulir la idea de como ciertas simulaciones pueden ir escalando poco a poco mientras agregamos mas situaciones de la vida real, este pensamiento se viene puliendo desde entregas anterioes, uno de los mayores desafios fue la sincronizacion y los estados de los semaforos, ya que el correcto manejo de estos dictaria el comportamiento de los carros.

Este proyecto creo podria ser todavia mas interesante si agregamos mas situaciones, quizas peatones, vueltas a la derecha o izquierda, en fin cualquier tipo de simulacion es facilmente escalable, pero creo es una buena forma de sentar las bases de lo que son las simulaciones con multiagentes.

# Simulación de Tráfico con Semáforos

Sistema de simulación multi-agente que modela el comportamiento del tráfico vehicular en una intersección controlada por semáforos, implementado con Julia (Agents.jl) en el backend y React en el frontend.


---

## Implementación de Agentes

### 1. Agente Semáforo (TrafficLight)

#### Definición del Tipo
```julia
@enum TrafficLightColor GREEN YELLOW RED

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    color::TrafficLightColor
    timer::Int
    orientation::Symbol
end
```

**Atributos:**
- `color`: Estado actual del semáforo (GREEN, YELLOW, RED)
- `timer`: Contador para sincronización de cambios de estado
- `orientation`: Define si controla tráfico `:horizontal` o `:vertical`

#### Constantes de Tiempo
```julia
const GREEN_TIME = 10      # Duración de luz verde (10 pasos)
const YELLOW_TIME = 4      # Duración de luz amarilla (4 pasos)
const RED_TIME = 14        # Duración de luz roja (14 pasos)
const CYCLE_TIME = 28      # Ciclo completo (28 pasos)
```

El ciclo completo de 28 pasos garantiza la sincronización entre semáforos:
- Semáforo horizontal: Verde (10) → Amarillo (4) → Rojo (14)
- Semáforo vertical: Rojo (14) → Verde (10) → Amarillo (4)

#### Lógica de Actualización
```julia
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
    else  # vertical
        if cycle_time < GREEN_TIME + YELLOW_TIME
            light.color = RED
        elseif cycle_time < GREEN_TIME + YELLOW_TIME + GREEN_TIME
            light.color = GREEN
        else
            light.color = YELLOW
        end
    end
end
```

**Funcionamiento:**
1. Se obtiene el paso actual de la simulación desde las propiedades del modelo
2. Se calcula la posición en el ciclo usando módulo: `mod(tiempo - 1, CYCLE_TIME)`
3. Según la orientación y posición en el ciclo, se asigna el color correspondiente
4. Los semáforos están desfasados para evitar colisiones en la intersección

---

### 2. Agente Carro (Car)

#### Definición del Tipo
```julia
@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool
end
```

**Atributos:**
- `accelerating`: Flag que indica si el carro está acelerando
- Hereda `pos` y `vel` de `ContinuousAgent{2,Float64}`

#### Funciones de Control de Velocidad
```julia
accelerate(agent) = min(agent.vel[1] + 0.05, 1.0)
decelerate(agent) = max(agent.vel[1] - 0.1, 0.0)
```

- **Aceleración**: Incrementa velocidad en 0.05 hasta máximo de 1.0
- **Frenado**: Reduce velocidad en 0.1 hasta mínimo de 0.0
- El frenado es más agresivo que la aceleración (realista)

#### Detección de Semáforo Adelante
```julia
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
```

**Criterios de detección:**
- Solo detecta semáforos horizontales (en su misma dirección)
- El semáforo debe estar adelante: `agent.pos[1] > car.pos[1]`
- Debe estar en el mismo carril: `abs(agent.pos[2] - car.pos[2]) < 2.0`

#### Lógica de Frenado ante Semáforo
```julia
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
```

**Comportamiento:**
1. Busca el semáforo adelante
2. Si no hay semáforo, no frena
3. Calcula distancia al semáforo
4. Si está dentro de la distancia de frenado (3.0 unidades) y el semáforo está en ROJO o AMARILLO, debe frenar

#### Detección de Carro Adelante
```julia
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
```

**Detección:**
- Ignora a sí mismo: `agent.id != car.id`
- Verifica mismo carril: `abs(agent.pos[2] - car.pos[2]) < 1.0`
- Detecta carros adelante dentro de 2.0 unidades de distancia

#### Actualización del Carro
```julia
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
```

**Prioridad de decisión:**
1. **Primera prioridad**: Frenar si hay semáforo en rojo/amarillo
2. **Segunda prioridad**: Frenar si hay carro adelante
3. **Por defecto**: Acelerar si el camino está libre

---

## Inicialización del Modelo

```julia
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

    # Agregar semáforos
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

    # Agregar carros
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
```

**Configuración:**
- **Espacio**: Continuo 2D con periodicidad horizontal (los carros reaparecen del otro lado)
- **Scheduler personalizado**: Actualiza semáforos primero, luego carros
- **Semáforos**: Posicionados en la intersección central
  - Horizontal comienza en VERDE
  - Vertical comienza en ROJO
- **Carros**: Distribuidos aleatoriamente, evitando zona de intersección
  - Velocidad inicial aleatoria entre 0.3 y 0.7
  - Número configurable desde el frontend

---


## Frontend (App.jsx)

### Estados Principales
```javascript
let [location, setLocation] = useState("");           // URL de simulación
let [trafficLights, setTrafficLights] = useState([]); // Estado de semáforos
let [cars, setCars] = useState([]);                   // Estado de carros
let [simSpeed, setSimSpeed] = useState(1);            // Velocidad de simulación
let [numCars, setNumCars] = useState(1);              // Número de carros
const running = useRef(null);                         // Intervalo de actualización
const simTime = useRef([]);                           // Tiempo para gráfica
const avgSpeed = useRef([]);                          // Velocidad promedio histórica
```

### Funciones Principales

#### Setup de Simulación
```javascript
let setup = () => {
    // Limpiar simulación anterior
    if (running.current) {
        clearInterval(running.current);
        running.current = null;
    }

    // Reiniciar datos de gráfica
    simTime.current = [];
    avgSpeed.current = [];

    // Crear nueva simulación
    fetch("http://localhost:8000/simulations", {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ num_cars: numCars })
    }).then(resp => resp.json())
    .then(data => {
        setLocation(data["Location"]);
        setTrafficLights(data["lights"] || []);
        setCars(data["cars"] || []);
    });
}
```

#### Iniciar Simulación
```javascript
const handleStart = () => {
    if (running.current) {
        clearInterval(running.current);
    }
    running.current = setInterval(() => {
        fetch("http://localhost:8000" + location)
        .then(res => res.json())
        .then(data => {
            setTrafficLights(data["lights"] || []);
            setCars(data["cars"] || []);
            
            // Calcular velocidad promedio
            if (data.cars && data.cars.length > 0) {
                const avgVel = data.cars.reduce((sum, car) => sum + car.vel[0], 0) / data.cars.length;
                simTime.current = [...simTime.current, simTime.current.length + 1];
                avgSpeed.current = [...avgSpeed.current, avgVel];
                vizdata.current = {
                    ...vizdata.current,
                    x: simTime.current,
                    y: avgSpeed.current
                };
            }
        });
    }, 1000 / simSpeed);
};
```

### Visualización SVG

#### Renderizado de Calles
```javascript
{/* Calle horizontal */}
<rect x={385} y={0} width={30} height={800} style={{fill: "#404040"}} />
{/* Calle vertical */}
<rect x={0} y={385} width={800} height={30} style={{fill: "#404040"}} />
```

#### Renderizado de Semáforos
```javascript
{trafficLights.map((light, index) => {
    let color;
    switch(light.color) {
        case "GREEN": color = "#00FF00"; break;
        case "YELLOW": color = "#FFFF00"; break;
        case "RED": color = "#FF0000"; break;
        default: color = "#808080";
    }

    const x = light.pos[0] * 32;
    const y = light.pos[1] * 32;

    return (
        <g key={`light-${index}`}>
            <rect x={x - 5} y={y - 5} width={10} height={40} style={{fill: "#333"}} />
            <rect x={x-6} y={y + 15} width={20} height={20} 
                  style={{fill: color, stroke: "#000", strokeWidth: 2}} />
        </g>
    );
})}
```

#### Renderizado de Carros
```javascript
{cars.map((car, index) => {
    const x = car.pos[0] * 32;
    const y = car.pos[1] * 32;

    return (
        <image
            key={`car-${index}`}
            href="/racing-car.png"
            x={x - 15}
            y={y - 10}
            width={30}
            height={20}
        />
    );
})}
```

### Gráfica de Velocidad (Plotly)

```javascript
<Plot
    data={[vizdata.current]}
    layout={{
        width: 500,
        height: 400,
        title: 'Velocidad Promedio de los Carros',
        xaxis: { title: 'Tiempo (steps)' },
        yaxis: { 
            title: 'Velocidad',
            range: [0, 1.2]
        }
    }}
/>
```

**Características:**
- Actualización en tiempo real
- Muestra velocidad promedio de todos los carros
- Rango normalizado: 0 a 1.2 (velocidad máxima es 1.0)
- Permite analizar patrones de aceleración/frenado

---
