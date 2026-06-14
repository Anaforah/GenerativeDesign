//test TOGGLES PARA PAINEL INFO NA LINHA 22


import processing.video.*;
import java.util.ArrayList;

int canvasWidth = 350;
int canvasHeight = 24;

PGraphics canvas;
Tx tx;

Capture cam;
PImage prevFrame;

int N = 250;
Particle[] p;

float zoff = 0;

// -------------------------
// DEBUG TOGGLES — ligar/desligar aqui
// -------------------------
boolean SHOW_CAMERA_PREVIEW = true;  // câmera no canto superior esquerdo
boolean SHOW_INFO_PANEL     = true;  // painel de API/hora no canto inferior esquerdo

// debug: último x mapeado e frame da deteção
float lastMappedX = -1;
int lastDetectedFrame = -1;

ArrayList<MotionParticle> motionParticles = new ArrayList<MotionParticle>();
// override de hora para debug (-1 = automático)
int debugHourOverride = -1;

// -------------------------
// ONDAS DE MOVIMENTO
// -------------------------

int MAX_WAVES = 20;

class WaveEvent {
  float x;
  float intensity;
  float age;

  WaveEvent(float x, float intensity) {
    this.x = x;
    this.intensity = intensity;
    this.age = 0;
  }
}

void mousePressed() {
  float bx = width - 110;
  float by = 10;
  float bw = 100;
  float bh = 28;
  if (mouseX >= bx && mouseX <= bx + bw && mouseY >= by && mouseY <= by + bh) {
    if (debugHourOverride < 0) debugHourOverride = 6;
    else {
      debugHourOverride++;
      if (debugHourOverride >= 24) debugHourOverride = -1;
    }
    println("debugHourOverride = " + debugHourOverride);
  }
}

// -------------------------
// Motion particles para arrasto
// -------------------------

class MotionParticle {
  float x, y;
  float speed;
  float life; // 1..0
  float seed;

  MotionParticle(float x_, float y_, float speed_, float life_) {
    x = x_;
    y = y_;
    speed = speed_;
    life = life_;
    seed = random(1000);
  }

  void update() {
    float angle = noise(x*0.01, y*0.05, zoff + seed) * TWO_PI * 4;

    x += cos(angle) * speed;
    y += sin(angle) * speed;

    if (x < 0) x += canvasWidth;
    if (x > canvasWidth) x -= canvasWidth;
    if (y < 0) y += canvasHeight;
    if (y > canvasHeight) y -= canvasHeight;

    // arrasto na velocidade
    speed *= 0.96;

    // diminuir life
    life -= 0.02;
  }

  void display() {
    float n = noise(x*0.02, y*0.02, zoff + seed);
    float bright = 180 + 75 * n;
    float a = constrain(life * 220, 0, 220);
    float size = constrain(2.0 + life * 6.0, 1.5, 8.0);

    canvas.stroke(bright, bright, bright, a);
    canvas.strokeWeight(1.5);
    canvas.point(x, y);

    if (random(1) < 0.05) {
      canvas.stroke(255, 200);
      canvas.point(x + random(-1,1), y + random(-1,1));
    }
    canvas.strokeWeight(1);
  }
}

WaveEvent[] waves = new WaveEvent[MAX_WAVES];

// -------------------------

void settings() {

  float scaling = 10;

  while (canvasWidth * scaling > displayWidth)
    scaling--;

  size(
    int(canvasWidth * scaling),
    int(canvasHeight * scaling)
  );

  pixelDensity(1);
  noSmooth();
}

void setup() {

  frameRate(30);

  // load last known API values from disk
  apiLoadCache();

  canvas = createGraphics(canvasWidth, canvasHeight);
  tx = new Tx(canvasWidth, canvasHeight);

  p = new Particle[N];

  for (int i=0; i<N; i++) {
    p[i] = new Particle();
  }

  // -------------------------
  // CAMERA (IMPORTANTE: resolução maior para detecção)
  // -------------------------

  cam = new Capture(this, 160, 90, 30);
  cam.start();

  prevFrame = createImage(160, 90, RGB);
}

// -------------------------

void draw() {

  // -------------------------
  // API UPDATE (non-blocking, runs on background thread)
  // -------------------------
  apiUpdate();

  // -------------------------
  // LER CÂMARA
  // -------------------------
if (cam.available()) {
  cam.read();

  cam.loadPixels();
  prevFrame.loadPixels();

  float sumX = 0;
  float sumY = 0;
  float total = 0;

  int w = cam.width;
  int h = cam.height;

  for (int y = 0; y < h; y += 2) {
    for (int x = 0; x < w; x += 2) {

      int i = x + y * w;

      color ca = cam.pixels[i];
      color cb = prevFrame.pixels[i];
      float diff = abs(
        (0.299 * ((ca >> 16) & 0xFF) + 0.587 * ((ca >> 8) & 0xFF) + 0.114 * (ca & 0xFF)) -
        (0.299 * ((cb >> 16) & 0xFF) + 0.587 * ((cb >> 8) & 0xFF) + 0.114 * (cb & 0xFF))
      ) / 255.0 * 100.0;

      if (diff > 8) {
        sumX += x * diff;
        sumY += y * diff;
        total += diff;
      }
    }
  }

  // -------------------------
  // DETECÇÃO ROBUSTA
  // -------------------------

  if (total > 50) {

    float avgX = sumX / total;
    float avgY = sumY / total;

    // esticar mapeamento para cobrir strip inteiro
    float mappedX = map(avgX, w * 0.25, w * 0.75, 0, canvasWidth);
    mappedX = constrain(mappedX, 0, canvasWidth);

    // intensidade REAL estável
    float intensity = constrain(total * 0.0008, 0, 1);

    // aumentar sensibilidade ligeiramente e guardar último mapeamento para debug
    intensity = constrain(intensity * 1.2, 0, 1);
    lastMappedX = mappedX;
    lastDetectedFrame = frameCount;

    addWave(mappedX, intensity);

    // criar uma motion particle com velocidade baseada na intensidade (speed) e vida
    float speed = 1.2 + intensity * 2.5;
    float life = 0.8 + intensity * 1.2;
    MotionParticle mp = new MotionParticle(mappedX, canvasHeight/2, speed, life);
    motionParticles.add(mp);
  }

  // atualizar frame anterior corretamente
  prevFrame.copy(cam, 0, 0, w, h, 0, 0, w, h);
}

  // -------------------------
  // DESENHO PRINCIPAL
  // -------------------------

  canvas.beginDraw();

  // cor de fundo consoante a hora do dia (manhã / tarde / noite)
  float timeOfDay;
  if (debugHourOverride >= 0) {
    timeOfDay = debugHourOverride;
  } else {
    timeOfDay = hour() + minute() / 60.0 + second() / 3600.0;
  }
  float[] keyT  = {  0,   6,   9,  15,  19,  24 };
  float[] keyR  = { 10,  20, 135,  70,  15,  10 };
  float[] keyG  = { 20,  50, 206, 130,  30,  20 };
  float[] keyB  = { 80, 120, 250, 180, 100,  80 };
  float brc = keyR[0], bgc = keyG[0], bbc = keyB[0];
  for (int ki = 0; ki < keyT.length - 1; ki++) {
    if (timeOfDay >= keyT[ki] && timeOfDay < keyT[ki+1]) {
      float t = (timeOfDay - keyT[ki]) / (keyT[ki+1] - keyT[ki]);
      brc = lerp(keyR[ki], keyR[ki+1], t);
      bgc = lerp(keyG[ki], keyG[ki+1], t);
      bbc = lerp(keyB[ki], keyB[ki+1], t);
      break;
    }
  }

  // overlay semi-transparente do tom de fundo para manter trailing
  canvas.noStroke();
  canvas.fill((int)brc, (int)bgc, (int)bbc, 12);
  canvas.rect(0, 0, canvasWidth, canvasHeight);

  zoff += 0.003;

  // partículas
  for (int i=0; i<N; i++) {
    p[i].update();
    p[i].display();
  }

  // atualizar e desenhar motionParticles (arrasto + tamanho maior)
  for (int i = motionParticles.size()-1; i >= 0; i--) {
    MotionParticle m = motionParticles.get(i);
    m.update();
    m.display();
    if (m.life <= 0) {
      motionParticles.remove(i);
    }
  }

  // -------------------------
  // ONDAS  AS J SAO AS LIGHT BLUE
  // -------------------------

  canvas.strokeWeight(1);
  for (int j=0; j<8; j++) {

    for (int x=0; x<canvasWidth; x++) {

      float h =
        canvasHeight/2 +

        sin(x*0.02 + frameCount*0.02 + j)*4 +
        noise(x*0.015, zoff + j)*8;

      float waveAdd = 0;
      float sumInfluenceAbs = 0;
      boolean hasMotionWave = false;

      // ondas do movimento: acumular magnitudes de influência por coluna
      for (int i=0; i<MAX_WAVES; i++) {

        WaveEvent w = waves[i];

        if (w != null) {

          float dist = abs(x - w.x);

          float influence =
            w.intensity * 12 * getDischargeAmplitude() *
            exp(-dist * 0.03) *
            sin(dist * 0.2 - w.age * 0.5);

          waveAdd += influence;
          sumInfluenceAbs += abs(influence);
        }
      }

      // decidir presença de onda de movimento por soma das magnitudes
      if (sumInfluenceAbs > 0.3) {
        hasMotionWave = true;
      }

      h += waveAdd;

      for (int y=int(h); y<canvasHeight; y++) {

        float c = map(y, h, canvasHeight, 255, 20);

        // -------------------------
        // COR
        // -------------------------

        if (hasMotionWave) {
          // desenhar como partículas brancas (semelhantes às azuis), com jitter e brilho variável
          float n = noise(x*0.02, y*0.02, zoff);
          float bright = 180 + 75 * n;
          canvas.stroke(bright, bright, bright, 200);

          float jx = x + random(-0.8, 0.8);
          float jy = y + random(-0.8, 0.8);
          canvas.point(jx, jy);

          // pequenos 'sparkles' ocasionais como em Particle.display
          if (random(1) < 0.04) {
            canvas.stroke(255, 200);
            canvas.point(jx + random(-1,1), jy + random(-1,1));
          }

        } else {
          // ONDAS BASE
          canvas.stroke((int)(brc*0.1), constrain((int)(200 + c*0.3), 0, 255), constrain((int)c, 0, 255), 120);
          canvas.point(x, y);
        }
      }
    }
  }

  // envelhecer ondas uma vez por frame (antes de terminar o desenho)
  for (int i=0; i<MAX_WAVES; i++) {
    WaveEvent w = waves[i];
    if (w != null) {
      w.age += 0.05;
      if (w.age > 20) {
        waves[i] = null;
      }
    }
  }

  // -------------------------
  // RAIN LAYER (API-driven, drawn on top of everything)
  // -------------------------
  float rainIntensity = getPrecipIntensity();
  if (rainIntensity > 0) {
    // Number of flashing columns scales with rain intensity (1–35)
    int rainDrops = int(rainIntensity * 35);
    for (int r = 0; r < rainDrops; r++) {
      int rx = int(random(canvasWidth));
      // Brightness: heavier rain = more solid white, lighter rain = dimmer
      float bright = random(0.4, 1.0) * rainIntensity;
      int alpha = int(constrain(bright * 255, 60, 255));
      // Flash 1–3 pixels tall per column (strip is only 24px)
      int dropHeight = int(random(1, min(4, canvasHeight)));
      int ry = int(random(canvasHeight - dropHeight));
      canvas.stroke(255, 255, 255, alpha);
      canvas.strokeWeight(1);
      for (int dy = 0; dy < dropHeight; dy++) {
        canvas.point(rx, ry + dy);
      }
    }
  }

  canvas.endDraw();

  image(canvas, 0, 0, width, height);

  tx.send(canvas);

  // -------------------------
  // DEBUG: IMAGEM DA CÂMERA
  // -------------------------

  if (SHOW_CAMERA_PREVIEW) {
    image(cam, 0, 0, 120, 68);
    noFill();
    stroke(255);
    rect(0, 0, 120, 68);

    // debug: mostrar o mapeamento detectado no ecrã principal
    if (lastMappedX >= 0 && frameCount - lastDetectedFrame < 30) {
      float sx = map(lastMappedX, 0, canvasWidth, 0, width);
      noFill();
      stroke(255, 0, 0);
      strokeWeight(2);
      line(sx, 0, sx, height);
      strokeWeight(1);
    }
  }

  // -------------------------
  // DEBUG: API INFO (canto inferior esquerdo)
  // -------------------------
  if (SHOW_INFO_PANEL) {
    int panelX = 0;
    int panelW = 310;
    int panelH = 62;
    int panelY = height - panelH;

    noStroke();
    fill(0, 150);
    rect(panelX, panelY, panelW, panelH, 4);

    fill(255);
    textAlign(LEFT, TOP);
    textSize(11);

    // Time line
    int curHour = (debugHourOverride >= 0) ? debugHourOverride : hour();
    String timeStr = nf(curHour, 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
    String timeMode = (debugHourOverride >= 0) ? " (debug)" : " (auto)";
    text("Time: " + timeStr + timeMode, panelX + 6, panelY + 5);

    // Precipitation line
    String precipStr = nf(apiPrecipitation, 1, 2) + " mm/h";
    String precipFetch = (lastPrecipFetch < 0)
      ? "never"
      : nf((frameCount - lastPrecipFetch) / 30, 0) + "s ago";
    text("Rain: " + precipStr + " (~" + nf(apiPrecipitationDisplay, 1, 2) + ")  |  fetched: " + precipFetch, panelX + 6, panelY + 22);

    // Discharge line
    String dischargeStr = nf(apiDischarge, 1, 1) + " m³/s";
    String dischargeFetch = (lastDischargeFetch < 0)
      ? "never"
      : nf((frameCount - lastDischargeFetch) / 30, 0) + "s ago";
    text("River: " + dischargeStr + " (~" + nf(apiDischargeDisplay, 1, 1) + ")  |  fetched: " + dischargeFetch, panelX + 6, panelY + 39);
  }

  // botão debug para alterar hora (clicar para avançar, chega a 24 volta para auto)
  float bx = width - 110;
  float by = 10;
  float bw = 100;
  float bh = 28;
  noStroke();
  fill(0, 140);
  rect(bx, by, bw, bh, 6);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(12);
  String label = (debugHourOverride < 0) ? "Hour: auto" : "Hour: " + debugHourOverride;
  text(label, bx + bw/2, by + bh/2);
}

// -------------------------
// ADICIONAR ONDA
// -------------------------

void addWave(float x, float intensity) {

  for (int i=0; i<MAX_WAVES; i++) {
    if (waves[i] == null) {
      waves[i] = new WaveEvent(x, intensity);
      return;
    }
  }

  int idx = int(random(MAX_WAVES));
  waves[idx] = new WaveEvent(x, intensity);
}

// -------------------------
// PARTÍCULAS (inalteradas)
// -------------------------

class Particle {

  float x;
  float y;
  float speed;

  Particle() {
    x = random(canvasWidth);
    y = random(canvasHeight);
    speed = random(0.3, 1.2);
  }

  void update() {

    float angle =
      noise(x*0.01, y*0.05, zoff) *
      TWO_PI * 4;

    x += cos(angle) * speed;
    y += sin(angle) * speed;

    if (x < 0) x += canvasWidth;
    if (x > canvasWidth) x -= canvasWidth;

    if (y < 0) y += canvasHeight;
    if (y > canvasHeight) y -= canvasHeight;
  }

  void display() {
    float n = noise(x*0.02, y*0.02, zoff);
    canvas.stroke(
      50 + 150*n,
      100 + 100*n,
      180 + 75*n
    );
    float s = 1 + 2.5*n;
    canvas.strokeWeight(s);
    canvas.point(x, y);
    canvas.strokeWeight(1);
    if (random(1) < 0.05) {
      canvas.stroke(255, 150);
      canvas.strokeWeight(2);
      canvas.point(x + random(-1,1), y + random(-1,1));
      canvas.strokeWeight(1);
    }
  }
}
