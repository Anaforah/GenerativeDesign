
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

    // keep white stroke color but use same weight behavior as Particle
    canvas.stroke(255, a);

    float s = 2 + 4*n;
    canvas.strokeWeight(s);
    canvas.point(x, y);
    canvas.strokeWeight(1);

    if (random(1) < 0.05) {
      canvas.stroke(255, min(220, a));
      canvas.strokeWeight(2);
      canvas.point(x + random(-1,1), y + random(-1,1));
      canvas.strokeWeight(1);
    }
  }
}
