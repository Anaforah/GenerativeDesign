//test


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

      float diff =
        abs(brightness(cam.pixels[i]) -
            brightness(prevFrame.pixels[i]));

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

    // normalizar (0–1)
    float nx = avgX / w;

    // mapear para canvas principal
    float mappedX = nx * canvasWidth;

    // intensidade REAL estável
    float intensity = constrain(total * 0.0008, 0, 1);

    // aumentar sensibilidade ligeiramente e guardar último mapeamento para debug
    intensity = constrain(intensity * 1.2, 0, 1);
    lastMappedX = mappedX;
    lastDetectedFrame = frameCount;

    println("Motion detected - frame:" + frameCount + " avgX:" + avgX + " avgY:" + avgY + " mappedX:" + mappedX + " intensity:" + intensity + " total:" + total);
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
  int hh = (debugHourOverride >= 0) ? debugHourOverride : hour();
  int brc, bgc, bbc;
  if (hh >= 6 && hh < 12) {
    // manhã - azul claro
    brc = 135; bgc = 206; bbc = 250;
  } else if (hh >= 12 && hh < 18) {
    // tarde - azul mais escuro
    brc = 70; bgc = 130; bbc = 180;
  } else {
    // noite - cinzento escuro
    brc = 30; bgc = 30; bbc = 40;
  }

  // overlay semi-transparente do tom de fundo para manter trailing
  canvas.noStroke();
  canvas.fill(brc, bgc, bbc, 12);
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
  // ONDAS
  // -------------------------

  for (int j=0; j<6; j++) {

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
          canvas.stroke(0, constrain(200 + c*0.3, 0, 255), constrain(c, 0, 255), 120);
          canvas.strokeWeight(1);
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

  // -------------------------
  // DEBUG: API INFO (canto inferior esquerdo)
  // -------------------------
  {
    int panelX = 0;
    int panelW = 230;
    int panelH = 44;
    int panelY = height - panelH;

    noStroke();
    fill(0, 150);
    rect(panelX, panelY, panelW, panelH, 4);

    fill(255);
    textAlign(LEFT, TOP);
    textSize(11);

    // Precipitation line
    String precipStr = nf(apiPrecipitation, 1, 2) + " mm/h";
    String precipFetch = (lastPrecipFetch < 0)
      ? "never"
      : nf((frameCount - lastPrecipFetch) / 30, 0) + "s ago";
    text("Rain: " + precipStr + "  |  fetched: " + precipFetch, panelX + 6, panelY + 5);

    // Discharge line
    String dischargeStr = nf(apiDischarge, 1, 1) + " m³/s";
    String dischargeFetch = (lastDischargeFetch < 0)
      ? "never"
      : nf((frameCount - lastDischargeFetch) / 30, 0) + "s ago";
    text("River: " + dischargeStr + "  |  fetched: " + dischargeFetch, panelX + 6, panelY + 22);
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
  println("addWave() - frame:" + frameCount + " x:" + x + " intensity:" + intensity);

  for (int i=0; i<MAX_WAVES; i++) {
    if (waves[i] == null) {
      waves[i] = new WaveEvent(x, intensity);
      println("  stored at slot " + i);
      return;
    }
  }

  int idx = int(random(MAX_WAVES));
  println("  no empty slot, replacing slot " + idx);
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

    canvas.point(x, y);

    if (random(1) < 0.05) {
      canvas.stroke(255, 150);
      canvas.point(x + random(-1,1), y + random(-1,1));
    }
  }
}
