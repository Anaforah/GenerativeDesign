class BlackSquare {
  // x,y represent the moving CENTER position in canvas coordinates
  float x, y, size;
  float targetX, targetY;
  float speed = 0.01;

  // Trail (stores previous center positions). Render shrinks with age.
  int maxTrail = 16;
  float[] trailX = new float[maxTrail];
  float[] trailY = new float[maxTrail];
  int trailWriteIndex = 0;
  int trailCount = 0;

  BlackSquare(float x, float y, float size) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.targetX = x;
    this.targetY = y;
  }

  void update(float newX, float newY) {
    this.targetX = newX;
    this.targetY = newY;
  }

  void update(float newX, float newY, float planeVelocity) {
    this.targetX = newX;
    this.targetY = newY;
    setSpeedFromPlaneVelocity(planeVelocity);
  }

  void setSpeedFromPlaneVelocity(float planeVelocity) {
    // OpenSky velocity is in m/s (often ~0..300+ for aircraft).
    // Map to a small easing factor so motion reads slower on screen.
    float mapped = map(planeVelocity, 0, 300, 0.003, 0.02);
    speed = constrain(mapped, 0.002, 0.03);
  }
  
  void move() {
    // Save current center position as a trail point
    pushTrailPoint(x, y);
    x += (targetX - x) * speed;
    y += (targetY - y) * speed;
  }

  void display(PGraphics canvas, float tileSize) {
    canvas.pushStyle();
    canvas.noStroke();

    // 1) Trail: black squares only, shrinking with age (no transparency)
    canvas.rectMode(CENTER);
    for (int i = 0; i < trailCount; i++) {
      int idx = (trailWriteIndex - trailCount + i);
      while (idx < 0) idx += maxTrail;
      idx = idx % maxTrail;

      // Age: 0 oldest -> 1 newest
      float age01 = (trailCount <= 1) ? 1 : (i / float(trailCount - 1));
      float s = tileSize * lerp(0.15, 0.85, age01);

      // Snap each trail point to the tile it belonged to
      float tx = floor(trailX[idx] / tileSize) * tileSize;
      float ty = floor(trailY[idx] / tileSize) * tileSize;
      float cx = tx + tileSize * 0.5;
      float cy = ty + tileSize * 0.5;

      canvas.fill(0);
      canvas.rect(cx, cy, s, s);
    }

    // 2) Current: cover the entire white tile involved
    float tileX = floor(x / tileSize) * tileSize;
    float tileY = floor(y / tileSize) * tileSize;
    canvas.rectMode(CORNER);
    canvas.fill(0);
    canvas.rect(tileX, tileY, tileSize, tileSize);

    canvas.popStyle();
  }

  void pushTrailPoint(float px, float py) {
    trailX[trailWriteIndex] = px;
    trailY[trailWriteIndex] = py;
    trailWriteIndex = (trailWriteIndex + 1) % maxTrail;
    if (trailCount < maxTrail) trailCount++;
  }
}
