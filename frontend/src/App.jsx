import { useState, useRef, useEffect } from 'react';
import Plot from 'react-plotly.js';

export default function App() {
  let [location, setLocation] = useState("");
  let [trafficLights, setTrafficLights] = useState([]);
  let [simSpeed, setSimSpeed] = useState(1);
  const running = useRef(null);

  let setup = () => {
    console.log("Hola");
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({  })
    }).then(resp => resp.json())
    .then(data => {
      console.log("Setup data:", data);
      console.log("Traffic lights:", data["lights"]);
      setLocation(data["Location"]);
      setTrafficLights(data["lights"]);
    });
  }

  const handleStart = () => {
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
      .then(res => res.json())
      .then(data => {
        console.log("Update data:", data);
        console.log("Traffic lights:", data["lights"]);
        setTrafficLights(data["lights"]);
      });
    }, 1000 / simSpeed);
  };

  const handleStop = () => {
    clearInterval(running.current);
  }

  const handleSimSpeedSliderChange = (event, newValue) => {
    setSimSpeed(newValue);
  };


  return (
    <div>
      <div>
        <button onClick={setup}>
          Setup
        </button>
        <button onClick={handleStart}>
          Start
        </button>
        <button onClick={handleStop}>
          Stop
        </button>
      </div>

      <svg width="800" height="500" xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"white"}}>
          <rect x={0} y={200} width={800} height={80} style={{fill: "darkgray"}} key="carretera-h"/>
          <rect x={360} y={0} width={80} height={500} style={{fill: "darkgray"}} key="carretera-v"/>
        
        {trafficLights.map((light, index) => {
          console.log("Rendering light:", light);
          const isHorizontal = light.orientation === "horizontal";
          let color;
          console.log("Light color:", light.color);
          switch(light.color) {
            case "GREEN": color = "#00FF00"; break;
            case "YELLOW": color = "#FFFF00"; break;
            case "RED": color = "#FF0000"; break;
            default: 
              console.log("Unknown color:", light.color);
              color = "#808080";
          }

          // Calculate position based on the light's orientation
          const x = isHorizontal ? 440 : 360;  // Horizontal light goes after intersection, vertical before
          const y = isHorizontal ? 170 : 280;  // Horizontal light above road, vertical light before intersection

          return (
            <g key={index}>
              {/* Semaphore post */}
              <rect 
                x={x}
                y={y}
                width={8}
                height={30}
                style={{fill: "#333333"}}
              />
              {/* Light box */}
              <rect 
                x={x - 6}
                y={y - 15}
                width={20}
                height={20}
                style={{fill: color, stroke: "black", strokeWidth: 1}}
              />
            </g>
          );
        })}
      </svg>
    </div>
  );
}