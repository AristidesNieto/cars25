import { useState, useRef } from 'react';
import Plot from 'react-plotly.js';

export default function App() {
  let [location, setLocation] = useState("");
  let [cars, setCars] = useState([]);
  let [simSpeed, setSimSpeed] = useState(10);
  const running = useRef(null);
  const simTime = useRef([]);
  const carSpeed = useRef([]);
  const vizdata = useRef({
    x: [],
    y: [],
    type: 'scatter',
    mode: 'lines+markers',
    marker: {color: 'blue'},
    name: 'Velocidad Carro 1'
  });

  let setup = () => {
    console.log("Hola");
    // Reiniciar los datos de la gráfica
    simTime.current = [];
    carSpeed.current = [];
    vizdata.current = {
      x: [],
      y: [],
      type: 'scatter',
      mode: 'lines+markers',
      marker: {color: 'blue'},
      name: 'Velocidad Carro 1'
    };

    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).then(resp => resp.json())
    .then(data => {
      console.log(data);
      setLocation(data["Location"]);
      setCars(data["cars"]);
    });
  }

  const handleStart = () => {
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
      .then(res => res.json())
      .then(data => {
        setCars(data["cars"]);
        const car1 = data.cars.find(car => car.id === 1);
        if (car1) {
          simTime.current = [...simTime.current, simTime.current.length + 1];
          carSpeed.current = [...carSpeed.current, car1.vel[0]];
          vizdata.current = {
            ...vizdata.current,
            x: simTime.current,
            y: carSpeed.current
          };
        }
      });
    }, 1000 / simSpeed);
  };

  const handleStop = () => {
    clearInterval(running.current);
  }

  return (
    <div>
      <div>
        <button onClick={setup}>Setup</button>
        <button onClick={handleStart}>Start</button>
        <button onClick={handleStop}>Stop</button>
      </div>
      <div style={{ display: 'flex' }}>
        <svg width="800" height="500" xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"white"}}>
          <rect x={0} y={200} width={800} height={80} style={{fill: "darkgray"}} key="carretera"/>
          {
            cars.map(car =>
              <image 
                id={car.id} 
                x={car.pos[0]*32} 
                y={240} 
                width={32} 
                href="./racing-car.png" 
                key={`carro${car.id}`}
              />
            )
          }
        </svg>
        <div style={{ marginLeft: '20px' }}>
          <Plot
            data={[vizdata.current]}
            layout={{
              width: 400,
              height: 300,
              title: 'Velocidad del Carro 1',
              xaxis: { title: 'Tiempo' },
              yaxis: { 
                title: 'Velocidad',
                range: [0, 1]
              }
            }}
          />
        </div>
      </div>
    </div>
  );
}
