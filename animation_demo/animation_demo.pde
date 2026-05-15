import processing.data.*;
import java.util.ArrayList;

int canvasWidth = 350;
int canvasHeight = 24;

PGraphics canvas; // https://processing.org/reference/PGraphics.html
Tx tx;
ArrayList<BlackSquare> blackSquares;
long lastFetch = 0;

void settings() {
  // Find the larger scaling that fits your screen
  float scaling = 10;
  while (canvasWidth * scaling > displayWidth) scaling--;
  size(int(canvasWidth * scaling), int(canvasHeight * scaling));
  pixelDensity(1); // Do not remove this line
  noSmooth(); // Do not remove this line
}

void setup() {
  frameRate(30);
  canvas = createGraphics(canvasWidth, canvasHeight);
  tx = new Tx(canvasWidth, canvasHeight);
  
  blackSquares = new ArrayList<BlackSquare>();
  
  // Initialize with some squares
  int tileCountY = 4;
  float tileHeight = canvasHeight / float(tileCountY);
  float tileWidth = tileHeight;
  int tileCountX = floor(canvasWidth / tileWidth);
  tileWidth = canvasWidth / float(tileCountX);
  
  for (int i = 0; i < tileCountX * tileCountY; i++) {
    float blackSquareSize = random(tileWidth * 0.2, tileWidth * 0.8);
    blackSquares.add(new BlackSquare(random(canvasWidth), random(canvasHeight), blackSquareSize));
  }
  
  thread("fetchPlanes");
}

void draw() {
  // Fetch data every 10 seconds
  if (millis() - lastFetch > 10000) {
    thread("fetchPlanes");
    lastFetch = millis();
  }

  // Draw animation on a (offscreen) canvas
  canvas.beginDraw();
  canvas.background(200); // Grey background

  int tileCountY = 4; // Adjusted to have multiple rows
  float tileHeight = canvasHeight / float(tileCountY);
  float tileWidth = tileHeight; // Make tiles square
  int tileCountX = floor(canvasWidth / tileWidth);
  
  // Recalculate tileWidth to fill the canvas width perfectly
  tileWidth = canvasWidth / float(tileCountX);
  tileHeight = tileWidth;

  // Draw the static grid of white squares
  for (int y = 0; y < tileCountY; y++) {
    for (int x = 0; x < tileCountX; x++) {
      float posX = x * tileWidth;
      float posY = y * tileHeight;
      canvas.fill(255); // White
      canvas.stroke(200); // Grid lines with background color
      canvas.rect(posX, posY, tileWidth, tileWidth); // Use tileWidth for height to keep it square
    }
  }

  // Move and display black squares
  for (BlackSquare bs : blackSquares) {
    bs.move();
    bs.display(canvas, tileWidth);
  }
  
  canvas.endDraw();
  
  // Draw canvas on window
  image(canvas, 0, 0, width, height);
  
  // Send canvas to server
  tx.send(canvas);
}

void fetchPlanes() {
  try {
    String url = "https://opensky-network.org/api/states/all";
    // In a real scenario, you might want to specify a bounding box for your area of interest
    // String url = "https://opensky-network.org/api/states/all?lamin=45.8389&lomin=5.9962&lamax=47.8229&lomax=10.5226";
    
    // The loadJSONObject should be sufficient, but let's ensure parsing is robust
    String[] lines = loadStrings(url);
    String jsonString = join(lines, "");
    JSONObject response = parseJSONObject(jsonString);

    JSONArray states = response.getJSONArray("states");

    if (states != null) {
      for (int i = 0; i < states.size() && i < blackSquares.size(); i++) {
        JSONArray flightInfo = states.getJSONArray(i);
        // longitude is at index 5, latitude is at index 6, velocity is at index 9 (m/s)
        if (!flightInfo.isNull(5) && !flightInfo.isNull(6)) {
          float lon = flightInfo.getFloat(5);
          float lat = flightInfo.getFloat(6);

          // Map lat/lon to canvas coordinates
          // This is a simple mapping and might need adjustment for your specific visualization.
          // Assuming a world map projection where lon is x and lat is y.
          // You'll need to define the bounds of the map you want to show.
          // For now, let's use a simple linear mapping.
          // Portugal bounding box: lat ~36.5 to 42.2, lon ~-9.5 to -6.2
          float minLon = -10.0;
          float maxLon = -6.0;
          float minLat = 36.0;
          float maxLat = 42.5;

          float targetX = map(lon, minLon, maxLon, 0, canvasWidth);
          float targetY = map(lat, maxLat, minLat, 0, canvasHeight); // Y is inverted in screen coordinates

          if (!flightInfo.isNull(9)) {
            float velocity = flightInfo.getFloat(9);
            blackSquares.get(i).update(targetX, targetY, velocity);
          } else {
            blackSquares.get(i).update(targetX, targetY);
          }
        }
      }
    }
  } catch (Exception e) {
    println("Failed to fetch or parse flight data: " + e.getMessage());
  }
}