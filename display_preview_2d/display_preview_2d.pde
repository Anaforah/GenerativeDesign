int ledsW = 350;
int ledsH = 24;

Rx rx;

void settings() {
  // Find the larger scaling that fits your screen
  float scaling = 10;
  while (ledsW * scaling > displayWidth) scaling--;
  size(int(ledsW * scaling), int(ledsH * scaling));
}

void setup() {
  rx = new Rx(this);
  rx.start();
}

void draw() {
  background(0);
  PImage img = rx.getImage();
  if (img != null) {
    //image(img, 0, 0, width, height);
    noStroke();
    float cellDim = 0.9 * (width / (float) img.width);
    for (int y = 0; y < img.height; y++) {
      float cY = map(y + 0.5, 0, img.height, 0, height);
      for (int x = 0; x < img.width; x++) {
        float cX = map(x + 0.5, 0, img.width, 0, width);
        fill(img.get(x, y));
        circle(cX, cY, cellDim);
      }
    }
  }
}
