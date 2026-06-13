// Particle class moved here from animation_demo.pde

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
