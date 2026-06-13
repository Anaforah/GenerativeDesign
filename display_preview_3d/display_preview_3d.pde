int LED_COLS_FACADE1 = 275;
int LED_COLS_FACADE2 = 75;
int LED_ROWS = 24;
float LEDS_GROUND_DIST = 1700 / 2; // meters
float LEDS_SPACE = 10; // meters
float LEDS_SIZE = 5; // meters
float DISPLAY_FACADE1_W = LED_COLS_FACADE1 * LEDS_SPACE;
float DISPLAY_FACADE2_W = LED_COLS_FACADE2 * LEDS_SPACE;
float DISPLAY_H = LED_ROWS * LEDS_SPACE;
float BUILDING_FACADE1_W = DISPLAY_FACADE1_W * 1.2;
float BUILDING_FACADE2_W = DISPLAY_FACADE2_W * 1.2;
float BUILDING_H = LEDS_GROUND_DIST + DISPLAY_H * 1.5;

float camYaw = radians(30);
float minYaw = radians(-40);
float maxYaw = radians(150);
float camPitch = radians(-5);
float minPitch = radians(-10);
float maxPitch = radians(78);
float camDistance = 2750;

Rx rx;
PImage img;

void settings() {
  size(int(displayWidth * 0.8), int(displayHeight * 0.8), P3D);
  smooth(8);
}

void setup() {
  sphereDetail(8);
  rx = new Rx(this);
  rx.start();
}

void draw() {
  background(220);
  
  updateCamera();
  //drawWorldCentre();
  translate(DISPLAY_FACADE1_W / 2f, BUILDING_H * 0.75, DISPLAY_FACADE2_W / 2f);
  drawBuilding();
  drawDisplay();

  /*hint(DISABLE_DEPTH_TEST);
   camera();
   fill(20);
   text("Hi LEDs!", 20, 30);
   hint(ENABLE_DEPTH_TEST);*/

   PImage img = rx.getImage();

if (img != null)
  image(img,0,0);
}

void updateCamera() {
  float targetX = 0;
  float targetY = 0;
  float targetZ = 0;
  float eyeX = targetX + cos(camPitch) * cos(camYaw) * camDistance;
  float eyeY = targetY - sin(camPitch) * camDistance;
  float eyeZ = targetZ + cos(camPitch) * sin(camYaw) * camDistance;
  camera(eyeX, eyeY, eyeZ, targetX, targetY, targetZ, 0, 1, 0);
  perspective(PI / 3.0, width / float(height), 1, 20000);
}

void drawWorldCentre() {
  push();
  float axisLength = 200;
  strokeWeight(1);
  stroke(0, 0, 0);
  line(-axisLength, 0, 0, axisLength, 0, 0);
  line(0, 0, -axisLength, 0, 0, axisLength);
  line(0, -axisLength, 0, 0, axisLength, 0);
  pop();
}

void drawBuilding() {
  push();
  stroke((g.backgroundColor & 0xFF) < 128 ? 75 : 175);
  strokeWeight(1);
  line(0, 0, 0, -BUILDING_FACADE1_W, 0, 0); // Bottom left
  line(0, 0, 0, 0, 0, -BUILDING_FACADE2_W); // Bottom right
  line(0, 0, 0, 0, -BUILDING_H, 0); // Vertical corner line
  line(0, -BUILDING_H, 0, -BUILDING_FACADE1_W, -BUILDING_H, 0); // Top left
  line(0, -BUILDING_H, 0, 0, -BUILDING_H, -BUILDING_FACADE2_W); // Top right
  pop();
}

void drawDisplay() {
  float first_col_x = -(LED_COLS_FACADE1 * LEDS_SPACE);
  float top_row_y = -(LEDS_GROUND_DIST + LED_ROWS * LEDS_SPACE);
  float led_radius = LEDS_SIZE / 2f;
  
  img = rx.getImage();
  
  push();
  fill(0);
  noStroke();
  for (int row = 0; row < LED_ROWS; row++) {
    for (int col = 0; col < LED_COLS_FACADE1; col++) {
      float x = first_col_x + col * LEDS_SPACE;
      float y = top_row_y + row * LEDS_SPACE;
      //color c = color(map(col, 0, LED_COLS_FACADE1, 0, 255), map(row, 0, LED_ROWS, 0, 255), 0);
      pushMatrix();
      translate(x, y, 0);
      if (img != null) {
        fill(img.get(col, row));
      }
      sphere(led_radius);
      popMatrix();
    }
    for (int col = 0; col < LED_COLS_FACADE2; col++) {
      float y = top_row_y + row * LEDS_SPACE;
      float z = -col * LEDS_SPACE;
      //color c = color(map(col, 0, LED_COLS_FACADE2, 0, 255), map(row, 0, LED_ROWS, 0, 255), 0);
      pushMatrix();
      translate(0, y, z);
      if (img != null) {
        fill(img.get(LED_COLS_FACADE1 + col, row));
      }
      sphere(led_radius);
      popMatrix();
    }
  }
  pop();
}

void mouseDragged() {
  camYaw += (mouseX - pmouseX) * 0.01;
  camPitch += (mouseY - pmouseY) * 0.01;
  camYaw = constrain(camYaw, minYaw, maxYaw);
  camPitch = constrain(camPitch, minPitch, maxPitch);
}

void mouseWheel(MouseEvent event) {
  camDistance += event.getCount() * 10;
  camDistance = constrain(camDistance, 1000, 5000);
}
