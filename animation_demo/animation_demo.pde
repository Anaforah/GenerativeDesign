import processing.data.*;
import java.util.ArrayList;
import processing.video.*;

int canvasWidth = 350;
int canvasHeight = 24;

PGraphics canvas; // https://processing.org/reference/PGraphics.html
Tx tx;
ArrayList<BlackSquare> blackSquares;
ArrayList<GreySquare> greySquares;

Capture cam;
PImage prevCamFrame;
PVector motionCentroid = new PVector();
float motionLevel01 = 0;
boolean motionDetected = false;
float motionX01 = 0;
float motionY01 = 0;

boolean mirrorCamera = true;

int camCropX0 = 0;
int camCropY0 = 0;
int camCropW = 0;
int camCropH = 0;
float lastFetch = 0;

boolean fetchInFlight = false;
float fetchIntervalBaseMs = 60000;
float fetchIntervalMs = fetchIntervalBaseMs;
float fetchIntervalMaxMs = 10 * 60 * 1000;
float lastFetchErrorLogMs = 0;

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
  greySquares = new ArrayList<GreySquare>();

  setupCamera();
  
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

  // Grey squares (motion-driven)
  int greyCount = max(4, (tileCountX * tileCountY) / 10);
  for (int i = 0; i < greyCount; i++) {
    float s = random(tileWidth * 0.2, tileWidth * 0.7);
    greySquares.add(new GreySquare(random(canvasWidth), random(canvasHeight), s));
  }
  
  requestFetchPlanes();
}

void draw() {
  updateMotion();

  // Fetch flight data (auto-backoff on rate limits)
  if (millis() - lastFetch > fetchIntervalMs) {
    lastFetch = millis();
    requestFetchPlanes();
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

  // Move and display grey squares (react to camera motion)
  if (motionDetected && greySquares.size() > 0) {
    float targetX = motionX01 * canvasWidth;
    float targetY = motionY01 * canvasHeight;
    float jitter = tileWidth * lerp(0.2, 1.2, motionLevel01);

    for (int i = 0; i < greySquares.size(); i++) {
      GreySquare gs = greySquares.get(i);
      float ox = random(-jitter, jitter);
      float oy = random(-jitter, jitter);
      gs.update(constrain(targetX + ox, 0, canvasWidth), constrain(targetY + oy, 0, canvasHeight));
      gs.setSpeedFromMotion(motionLevel01);
    }
  }
  for (GreySquare gs : greySquares) {
    gs.move();
    gs.display(canvas, tileWidth);
  }
  
  canvas.endDraw();
  
  // Draw canvas on window
  image(canvas, 0, 0, width, height);
  
  // Send canvas to server
  tx.send(canvas);
}

void requestFetchPlanes() {
  if (fetchInFlight) return;
  fetchInFlight = true;
  lastFetch = millis();
  thread("fetchPlanes");
}

void setupCamera() {
  try {
    String[] cams = Capture.list();
    if (cams == null || cams.length == 0) {
      println("No cameras found.");
      cam = null;
      return;
    }

    // Pick first available camera.
    cam = new Capture(this, cams[0]);
    cam.start();

    // prevCamFrame will be allocated lazily when we get the first frame.
  } catch (Exception e) {
    println("Failed to initialize camera: " + e.getMessage());
    cam = null;
  }
}

void updateMotion() {
  motionDetected = false;
  motionLevel01 = 0;
  motionCentroid.set(0, 0);
  motionX01 = 0;
  motionY01 = 0;

  if (cam == null) return;

  if (cam.available()) {
    cam.read();
  } else {
    // No new frame: keep last motion state as 'no motion'.
    return;
  }

  cam.loadPixels();
  if (cam.pixels == null || cam.pixels.length == 0) return;

  if (prevCamFrame == null || prevCamFrame.width != cam.width || prevCamFrame.height != cam.height) {
    prevCamFrame = createImage(cam.width, cam.height, RGB);
    prevCamFrame.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
    prevCamFrame.updatePixels();
    return;
  }

  prevCamFrame.loadPixels();

  int step = 6;              // sampling stride (bigger = faster)
  float diffThreshold = 18;  // per-pixel brightness threshold

  updateCameraCrop();
  if (camCropW <= 0 || camCropH <= 0) return;

  float sumDiff = 0;
  float sumX = 0;
  float sumY = 0;

  int samples = 0;
  int x1 = camCropX0 + camCropW;
  int y1 = camCropY0 + camCropH;

  for (int y = camCropY0; y < y1; y += step) {
    for (int x = camCropX0; x < x1; x += step) {
      int idx = y * cam.width + x;
      float bNow = brightness(cam.pixels[idx]);
      float bPrev = brightness(prevCamFrame.pixels[idx]);
      float d = abs(bNow - bPrev);
      samples++;

      if (d > diffThreshold) {
        sumDiff += d;
        sumX += x * d;
        sumY += y * d;
      }
    }
  }

  // Normalize a motion amount: average brightness delta over the sampled pixels.
  float avgDiff = (samples > 0) ? (sumDiff / samples) : 0;
  motionLevel01 = constrain(map(avgDiff, 0, 25, 0, 1), 0, 1);

  // Consider motion detected if above a small threshold.
  motionDetected = avgDiff > 3.0;

  if (sumDiff > 0) {
    motionCentroid.set(sumX / sumDiff, sumY / sumDiff);

    // Normalize within the crop region so mapping is panoramic/aspect-correct.
    motionX01 = constrain((motionCentroid.x - camCropX0) / float(camCropW), 0, 1);
    motionY01 = constrain((motionCentroid.y - camCropY0) / float(camCropH), 0, 1);

    // Mirror horizontally (selfie-style) so mapping matches the person.
    if (mirrorCamera) {
      motionX01 = 1.0 - motionX01;
    }
  }

  // Update prev frame (no allocations).
  prevCamFrame.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
  prevCamFrame.updatePixels();
}

void updateCameraCrop() {
  // Center-crop camera frame to match the canvas aspect ratio.
  // This makes x-mapping feel "panoramic" on a very wide canvas.
  if (cam == null) {
    camCropX0 = camCropY0 = camCropW = camCropH = 0;
    return;
  }

  float targetAspect = canvasWidth / float(canvasHeight);
  float camAspect = cam.width / float(cam.height);

  if (camAspect > targetAspect) {
    // Camera is wider than target: crop left/right.
    camCropH = cam.height;
    camCropW = int(cam.height * targetAspect);
    camCropX0 = (cam.width - camCropW) / 2;
    camCropY0 = 0;
  } else {
    // Camera is taller than target (common here): crop top/bottom (a horizontal band).
    camCropW = cam.width;
    camCropH = int(cam.width / targetAspect);
    camCropX0 = 0;
    camCropY0 = (cam.height - camCropH) / 2;
  }

  // Clamp just in case of rounding.
  camCropW = constrain(camCropW, 1, cam.width);
  camCropH = constrain(camCropH, 1, cam.height);
  camCropX0 = constrain(camCropX0, 0, cam.width - camCropW);
  camCropY0 = constrain(camCropY0, 0, cam.height - camCropH);
}

void fetchPlanes() {
  try {
    String url = "https://opensky-network.org/api/states/all";
    // In a real scenario, you might want to specify a bounding box for your area of interest
    // String url = "https://opensky-network.org/api/states/all?lamin=45.8389&lomin=5.9962&lamax=47.8229&lomax=10.5226";
    
    // The loadJSONObject should be sufficient, but let's ensure parsing is robust
    String[] lines = null;
    try {
      lines = loadStrings(url);
    } catch (Exception e) {
      // loadStrings can throw on HTTP errors (e.g., 429)
      throw e;
    }
    if (lines == null || lines.length == 0) {
      throw new RuntimeException("Empty response (rate-limited or offline)");
    }

    String jsonString = join(lines, "");
    JSONObject response = parseJSONObject(jsonString);
    if (response == null) {
      throw new RuntimeException("Invalid JSON response");
    }

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
    // Success: reset interval
    fetchIntervalMs = fetchIntervalBaseMs;
  } catch (Exception e) {
    String msg = (e.getMessage() == null) ? "" : e.getMessage();
    boolean rateLimited = msg.indexOf("429") >= 0;

    if (rateLimited) {
      float prev = fetchIntervalMs;
      fetchIntervalMs = min(fetchIntervalMaxMs, max(fetchIntervalBaseMs, fetchIntervalMs * 2));
      if (millis() - lastFetchErrorLogMs > 2000) {
        println("OpenSky rate-limited (HTTP 429). Backoff: " + (prev / 1000) + "s -> " + (fetchIntervalMs / 1000) + "s");
        lastFetchErrorLogMs = millis();
      }
    } else {
      if (millis() - lastFetchErrorLogMs > 2000) {
        println("Failed to fetch or parse flight data: " + msg);
        lastFetchErrorLogMs = millis();
      }
    }
  } finally {
    fetchInFlight = false;
  }
}