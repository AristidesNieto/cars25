import { useState, useRef } from 'react';

export default function App() {
  let [location, setLocation] = useState("");
  let [trafficLights, setTrafficLights] = useState([]);
  let [cars, setCars] = useState([]);
  let [simSpeed, setSimSpeed] = useState(1);
  let [numCars, setNumCars] = useState(1);
  const running = useRef(null);

  let setup = () => {
    if (running.current) {
      clearInterval(running.current);
      running.current = null;
    }

    console.log("Setting up simulation with", numCars, "cars");
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ num_cars: numCars })
    }).then(resp => resp.json())
    .then(data => {
      console.log("Setup data:", data);
      setLocation(data["Location"]);
      setTrafficLights(data["lights"] || []);
      setCars(data["cars"] || []);
    });
  }

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
      });
    }, 1000 / simSpeed);
  };

  const handleStop = () => {
    clearInterval(running.current);
  }

  return (
    <div style={{padding: "20px"}}>
      <div style={{marginBottom: "20px"}}>
        <button onClick={setup} style={{marginRight: "10px"}}>Setup</button>
        <button onClick={handleStart} style={{marginRight: "10px"}}>Start</button>
        <button onClick={handleStop} style={{marginRight: "10px"}}>Stop</button>
        
        
        <label style={{marginLeft: "20px"}}>
          Speed: 
          <input 
            type="range" 
            value={simSpeed} 
            onChange={(e) => setSimSpeed(parseInt(e.target.value))}
            min="1"
            max="30"
            style={{marginLeft: "10px"}}
          />
          {simSpeed}x
        </label>
      </div>

      <svg width="800" height="800" xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"#e0e0e0", border: "2px solid #333"}}>
        {/* Calles */}
        <rect x={385} y={0} width={30} height={800} style={{fill: "#404040"}} />
        <rect x={0} y={385} width={800} height={30} style={{fill: "#404040"}} />
        

        {/* Semáforos */}
        {trafficLights.map((light, index) => {
          const isHorizontal = light.orientation === "horizontal";
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
              {/* Poste del semáforo */}
              <rect 
                x={x - 5}
                y={y - 5}
                width={10}
                height={40}
                style={{fill: "#333"}}
              />
              {/* Luz del semáforo */}
              <rect 
                x={x-6}
                y={y + 15}
                width={20}
                height={20}
                style={{fill: color, stroke: "#000", strokeWidth: 2}}
              />
            </g>
          );
        })}
        
        {/* Carros */}
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
              style={{
                transform: `rotate(0deg)`,
                transformOrigin: `${x}px ${y}px`
              }}
            />
          );
        })}
      </svg>
      
    </div>
  );
}