/*
 WaveEvent.pde

 Purpose:
 - Lightweight struct representing a motion-triggered wave event. Stored in
   a fixed-size array by the main sketch; each event has position `x`, an
   `intensity` and `age` which decays over time.
*/

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
