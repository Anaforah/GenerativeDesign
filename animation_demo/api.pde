// -------------------------
// API.pde
// Fetches Open-Meteo weather (precipitation) and flood (river discharge)
// data for Coimbra, Portugal. Holds last known values between fetches.
// -------------------------

import java.net.URL;
import java.net.HttpURLConnection;
import java.io.BufferedReader;
import java.io.InputStreamReader;

// --- Last known values (used between fetches) ---
float apiPrecipitation  = 0.0;   // mm/h, current hour
float apiDischarge      = 80.0;  // m³/s, today (Mondego typical baseline)

// --- Jitter (small random nudge applied each frame when data hasn't changed) ---
float apiPrecipitationDisplay = 0.0;  // jittered value used by the sketch
float apiDischargeDisplay     = 80.0;

// -------------------------
// Call once per draw() to nudge display values slightly around real values
// -------------------------
void apiJitter() {
  apiPrecipitationDisplay = max(0, apiPrecipitation + random(-0.08, 0.08));
  apiDischargeDisplay     = max(0,  apiDischarge     + random(-3.0,  3.0));
}

// --- Fetch timing ---
int lastPrecipFetch    = -1;
int lastDischargeFetch = -1;

// 5 min * 60 sec * 30 fps = 9000 frames
final int PRECIP_INTERVAL   = 9000;
// 5 min * 60 sec * 30 fps = 9000 frames
final int DISCHARGE_INTERVAL = 9000;

// Coimbra coordinates
final float LAT =  40.2111;
final float LON =  -8.4291;

// -------------------------
// Call this once per draw() to trigger fetches when due
// -------------------------
void apiUpdate() {
  // First call: fetch immediately
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
// Returns wave amplitude multiplier from river discharge (0.5 – 2.5)
// Mondego typical range: ~10 m³/s (dry) to ~600 m³/s (flood)
// -------------------------
float getDischargeAmplitude() {
  return map(constrain(apiDischargeDisplay, 10, 600), 10, 600, 0.5, 2.5);
}

// -------------------------
// Returns precipitation intensity 0.0 – 1.0
// 0 = dry, 1 = heavy rain (>=10 mm/h)
// -------------------------
float getPrecipIntensity() {
  return constrain(map(apiPrecipitationDisplay, 0, 10, 0, 1), 0, 1);
}

// -------------------------
// Fetch current-hour precipitation from Open-Meteo weather API
// -------------------------
void fetchPrecipitation() {
  Thread t = new Thread(new Runnable() {
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

        // Parse: "precipitation":VALUE
        float val = parseJsonFloat(json, "precipitation");
        if (!Float.isNaN(val)) {
          apiPrecipitation = val;
          println("[API] Precipitation: " + apiPrecipitation + " mm/h");
        }
      } catch (Exception e) {
        println("[API] Precipitation fetch error: " + e.getMessage());
      }
    }
  });
  t.start();
  lastPrecipFetch = frameCount;
}

// -------------------------
// Fetch today's river discharge from Open-Meteo flood API
// -------------------------
void fetchDischarge() {
  Thread t = new Thread(new Runnable() {
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

        // Parse first value in the river_discharge array
        float val = parseJsonArrayFirstFloat(json, "river_discharge");
        if (!Float.isNaN(val)) {
          apiDischarge = val;
          println("[API] River discharge: " + apiDischarge + " m³/s");
        }
      } catch (Exception e) {
        println("[API] Discharge fetch error: " + e.getMessage());
      }
    }
  });
  t.start();
  lastDischargeFetch = frameCount;
}

// -------------------------
// Minimal HTTP GET — returns body string or null on failure
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

    BufferedReader br = new BufferedReader(
      new InputStreamReader(conn.getInputStream())
    );
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
