/*
 raindrop.pde

 Purpose:
 - Represents an individual raindrop drawn onto the canvas. Construct with
   a precipitation `intensity` (0..1) which affects speed, brightness and
   spawn frequency (handled externally by `animation_demo.pde`).
*/

class RainDrop {
  float x, y;
  float speed;
  int len;
  float bright;

  RainDrop(float intensity) {
    x = random(canvasWidth);
    // começa um pouco acima do topo, para entrar a "cair"
    y = -random(0, 4);
    len = int(random(1, min(4, canvasHeight)));
    // chuva mais forte -> gotas caem mais rápido
    speed = map(intensity, 0, 1, 1.0, 3.0) + len * 0.3;
    speed *= random(0.85, 1.15);
    bright = random(0.4, 1.0) * intensity;
  }

  void update() {
    y += speed;
  }

  boolean isDone() {
    return y - len > canvasHeight;
  }

  void display() {
    int alpha = int(constrain(bright * 255, 60, 255));
    canvas.stroke(255, 255, 255, alpha);
    canvas.strokeWeight(1);
    for (int dy = 0; dy < len; dy++) {
      float py = y + dy;
      if (py >= 0 && py < canvasHeight) {
        canvas.point(x, py);
      }
    }
  }
}
