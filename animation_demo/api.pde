// -------------------------
// API.pde
// Fetches Open-Meteo weather (precipitation) and flood (river discharge)
// data for Coimbra, Portugal. Holds last known values between fetches.
// -------------------------

import java.net.URL;
import java.net.HttpURLConnection;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.File;

// --- Cache file path ---
final String API_CACHE_FILE = sketchPath("api_cache.txt");

// --- Raw API values ---
float apiPrecipitation = 0.0;
float apiDischarge     = 80.0;

// --- Previous raw values (to detect if fetch returned same value) ---
float prevPrecipitation = Float.NaN;
float prevDischarge     = Float.NaN;

// --- Display values (nudged once per fetch if value unchanged) ---
float apiPrecipitationDisplay = 0.0;
float apiDischargeDisplay     = 80.0;

// --- Fetch timing ---
int lastPrecipFetch    = -1;
int lastDischargeFetch = -1;

// 5 min * 60 sec * 30 fps = 9000 frames
final int PRECIP_INTERVAL    = 9000;
final int DISCHARGE_INTERVAL = 9000;

// Coimbra coordinates
final float LAT =  40.2111;
final float LON = -8.4291;

// -------------------------
// Load last saved values from disk (call once in setup())
// -------------------------
void apiLoadCache() {
  try {
    File f = new File(API_CACHE_FILE);
    if (!f.exists()) return;
    BufferedReader br = new BufferedReader(new java.io.FileReader(f));
    String l1 = br.readLine();
    String l2 = br.readLine();
    br.close();
    if (l1 != null) apiPrecipitation = Float.parseFloat(l1.trim());
    if (l2 != null) apiDischarge     = Float.parseFloat(l2.trim());
    apiPrecipitationDisplay = apiPrecipitation;
    apiDischargeDisplay     = apiDischarge;
    prevPrecipitation       = apiPrecipitation;
    prevDischarge           = apiDischarge;
    println("[API] Cache loaded — precip: " + apiPrecipitation + "  discharge: " + apiDischarge);
  } catch (Exception e) {
    println("[API] No cache or parse error: " + e.getMessage());
  }
}

// -------------------------
// Save current values to disk on a background thread (non-blocking)
// -------------------------
void apiSaveCache() {
  final float p = apiPrecipitation;
  final float d = apiDischarge;
  new Thread(new Runnable() {
    public void run() {
      try {
        BufferedWriter bw = new BufferedWriter(new FileWriter(API_CACHE_FILE));
        bw.write(str(p)); bw.newLine();
        bw.write(str(d)); bw.newLine();
        bw.close();
      } catch (Exception e) {
        println("[API] Cache save error: " + e.getMessage());
      }
    }
  }).start();
}

// -------------------------
// Call this once per draw() to trigger fetches when due
// -------------------------
void apiUpdate() {
  if (lastPrecipFetch < 0) {
    fetchPrecipitation();
    fetchDischarge();
    return;
  }
  if (frameCount - lastPrecipFetch >= PRECIP_INTERVAL) {
    fetchPrecipitation();
  }
  if (frameCount - lastDischargeFetch >= DISCHARGE_INTERVAL) {
    fetchDischarge();
  }
}

// -------------------------
// Update display value after each fetch
// If real value unchanged, apply a fresh one-time nudge
// -------------------------
void refreshPrecipDisplay() {
  if (apiPrecipitation == prevPrecipitation) {
    apiPrecipitationDisplay = max(0, apiPrecipitation + random(-0.08, 0.08));
  } else {
    apiPrecipitationDisplay = apiPrecipitation;
  }
  prevPrecipitation = apiPrecipitation;
}

void refreshDischargeDisplay() {
  if (apiDischarge == prevDischarge) {
    apiDischargeDisplay = max(0, apiDischarge + random(-3.0, 3.0));
  } else {
    apiDischargeDisplay = apiDischarge;
  }
  prevDischarge = apiDischarge;
}

// -------------------------
// Returns wave amplitude multiplier from river discharge (0.5 – 2.5)
// -------------------------
float getDischargeAmplitude() {
  return map(constrain(apiDischargeDisplay, 10, 600), 10, 600, 0.5, 2.5);
}

// -------------------------
// Returns precipitation intensity 0.0 – 1.0
// -------------------------
float getPrecipIntensity() {
  return constrain(map(apiPrecipitationDisplay, 0, 10, 0, 1), 0, 1);
}

// -------------------------
// Fetch current-hour precipitation from Open-Meteo weather API
// -------------------------
void fetchPrecipitation() {
  lastPrecipFetch = frameCount;
  new Thread(new Runnable() {
    public void run() {
      try {
        String url =
          "https://api.open-meteo.com/v1/forecast" +
          "?latitude=" + LAT +
          "&longitude=" + LON +
          "&current=precipitation" +
          "&timezone=Europe%2FLisbon";
        String json = httpGet(url);
        if (json == null) return;
        float val = parseJsonFloat(json, "precipitation");
        if (!Float.isNaN(val)) {
          apiPrecipitation = val;
          refreshPrecipDisplay();
          apiSaveCache();
          println("[API] Precipitation: " + apiPrecipitation + " mm/h  display: " + apiPrecipitationDisplay);
        }
      } catch (Exception e) {
        println("[API] Precipitation fetch error: " + e.getMessage());
      }
    }
  }).start();
}

// -------------------------
// Fetch today's river discharge from Open-Meteo flood API
// -------------------------
void fetchDischarge() {
  lastDischargeFetch = frameCount;
  new Thread(new Runnable() {
    public void run() {
      try {
        String url =
          "https://flood.open-meteo.com/v1/flood" +
          "?latitude=" + LAT +
          "&longitude=" + LON +
          "&daily=river_discharge" +
          "&forecast_days=1";
        String json = httpGet(url);
        if (json == null) return;
        float val = parseJsonArrayFirstFloat(json, "river_discharge");
        if (!Float.isNaN(val)) {
          apiDischarge = val;
          refreshDischargeDisplay();
          apiSaveCache();
          println("[API] River discharge: " + apiDischarge + " m³/s  display: " + apiDischargeDisplay);
        }
      } catch (Exception e) {
        println("[API] Discharge fetch error: " + e.getMessage());
      }
    }
  }).start();
}

// -------------------------
// Minimal HTTP GET
// -------------------------
String httpGet(String urlStr) {
  try {
    URL url = new URL(urlStr);
    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
    conn.setRequestMethod("GET");
    conn.setConnectTimeout(8000);
    conn.setReadTimeout(8000);
    int code = conn.getResponseCode();
    if (code != 200) {
      println("[API] HTTP " + code + " for " + urlStr);
      return null;
    }
    BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()));
    StringBuilder sb = new StringBuilder();
    String line;
    while ((line = br.readLine()) != null) sb.append(line);
    br.close();
    return sb.toString();
  } catch (Exception e) {
    println("[API] httpGet error: " + e.getMessage());
    return null;
  }
}

// -------------------------
// Parse  "key":VALUE  from flat JSON string
// -------------------------
float parseJsonFloat(String json, String key) {
  String search = "\"" + key + "\":";
  int idx = json.indexOf(search);
  if (idx < 0) return Float.NaN;
  int start = idx + search.length();
  int end = start;
  while (end < json.length()) {
    char c = json.charAt(end);
    if (c == ',' || c == '}' || c == ']') break;
    end++;
  }
  try {
    return Float.parseFloat(json.substring(start, end).trim());
  } catch (Exception e) {
    return Float.NaN;
  }
}

// -------------------------
// Parse first value from  "key":[VALUE, ...]  in JSON string
// -------------------------
float parseJsonArrayFirstFloat(String json, String key) {
  String search = "\"" + key + "\":[";
  int idx = json.indexOf(search);
  if (idx < 0) return Float.NaN;
  int start = idx + search.length();
  int end = start;
  while (end < json.length()) {
    char c = json.charAt(end);
    if (c == ',' || c == ']') break;
    end++;
  }
  try {
    return Float.parseFloat(json.substring(start, end).trim());
  } catch (Exception e) {
    return Float.NaN;
  }
}
