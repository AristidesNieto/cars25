## Autores
Luis Fernando Cruz Flores
Aristides Nieto Guzman 

Proyecto desarrollado para el curso de Sistemas Multi-Agentes

---

# Simulación de Tráfico con Semáforos

Sistema de simulación multi-agente que modela el comportamiento del tráfico vehicular en una intersección controlada por semáforos, implementado con Julia (Agents.jl) en el backend y React en el frontend.

## Descripción del Proyecto

Este proyecto simula el flujo de tráfico en una intersección con dos semáforos sincronizados (horizontal y vertical). Los vehículos deben obedecer las señales de tráfico, detectar otros vehículos y ajustar su velocidad en consecuencia. El sistema incluye monitoreo en tiempo real de la velocidad promedio para análisis del comportamiento del tráfico.

## Arquitectura del Sistema

### Backend (Julia)
- **Framework**: Agents.jl para simulación basada en agentes
- **API**: Genie.jl para servidor HTTP RESTful
- **Espacio**: ContinuousSpace 2D (25x25 unidades)

### Frontend (React)
- **Visualización**: SVG para renderizado de simulación
- **Gráficas**: Plotly.js para monitoreo de velocidad
- **Comunicación**: Fetch API para conexión con backend

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

## API REST (webapi.jl)

### Endpoints

#### POST /simulations
Crea una nueva simulación

**Request:**
```json
{
  "num_cars": 5
}
```

**Response:**
```json
{
  "Location": "/simulations/{uuid}",
  "lights": [
    {
      "id": 1,
      "pos": [10.5, 12.5],
      "color": "GREEN",
      "orientation": "horizontal"
    }
  ],
  "cars": [
    {
      "id": 2,
      "pos": [5.2, 12.5],
      "vel": [0.5, 0.0]
    }
  ]
}
```

#### GET /simulations/:id
Avanza la simulación un paso y retorna el estado actualizado

**Response:**
```json
{
  "lights": [...],
  "cars": [...]
}
```

### Configuración CORS
```julia
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
```

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

## Monitoreo de Velocidad Promedio

### Objetivo
Reportar la velocidad promedio de los autos con diferentes configuraciones (3, 5 y 7 autos) para análisis del comportamiento del tráfico.

### Metodología

1. **Configuración**: Establecer número de carros (3, 5 o 7)
2. **Inicialización**: Click en "Setup" para crear simulación
3. **Ejecución**: Click en "Start" para iniciar
4. **Monitoreo**: Observar gráfica en tiempo real
5. **Registro**: Anotar velocidad promedio estabilizada
6. **Repetición**: Realizar múltiples pruebas por configuración

### Datos Recolectados

La gráfica muestra:
- **Eje X**: Pasos de simulación (tiempo discreto)
- **Eje Y**: Velocidad promedio (0.0 - 1.0)
- **Línea**: Evolución temporal de la velocidad

### Patrones Esperados

- **Pocos carros (3)**: Velocidad promedio alta, pocas interrupciones
- **Carros medios (5)**: Velocidad moderada, más interacciones
- **Muchos carros (7)**: Velocidad baja, congestión frecuente

---

## Instalación y Ejecución

### Backend (Julia)

#### Requisitos
```julia
julia> using Pkg
julia> Pkg.add("Agents")
julia> Pkg.add("Genie")
julia> Pkg.add("StaticArrays")
julia> Pkg.add("Distributions")
```

#### Ejecutar servidor
```bash
julia webapi.jl
```
El servidor estará disponible en `http://localhost:8000`

### Frontend (React)

#### Requisitos
```bash
npm install
npm install react-plotly.js plotly.js
```

#### Ejecutar aplicación
```bash
npm run dev
```
La aplicación estará disponible en `http://localhost:5173` (o puerto asignado por Vite)

---

## Características Principales

✅ **Simulación Multi-Agente**: Carros y semáforos interactúan en tiempo real  
✅ **Sincronización de Semáforos**: Ciclos coordinados para evitar colisiones  
✅ **Detección de Colisiones**: Los carros frenan ante otros vehículos  
✅ **Respeto a Señales**: Frenado ante luces rojas y amarillas  
✅ **Monitoreo en Tiempo Real**: Gráfica de velocidad promedio  
✅ **Configuración Dinámica**: Número variable de carros (1-10)  
✅ **Control de Velocidad**: Simulación ajustable (1x-30x)  
✅ **Visualización SVG**: Representación gráfica de la intersección  
