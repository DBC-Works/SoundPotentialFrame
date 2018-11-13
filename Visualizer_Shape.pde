final class EllipseRotationVisualizer extends Visualizer {
  private final float fgHue;
  private final float fgBrightness;
  private final float fgSaturation;
  
  private float rotationInc;
  private float rotation = -1;
  private float rightIntensity;
  private float leftIntensity;
  private float mixIntensity;
  
  EllipseRotationVisualizer(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
    super(info, firstTimeMillis, lastTimeMillis, 0, #ffffff);

    fgHue = hue(fgColor);
    fgSaturation = saturation(fgColor);
    fgBrightness = brightness(fgColor);
  }
  private float calcNewIntensity(float oldIntensity, float newIntensity) {
    float value = newIntensity;
    if (oldIntensity < newIntensity) {
      if (oldIntensity < 0.1) {
        value = newIntensity;
      }
      else {
        value = oldIntensity * 1.1;
      }
    }
    else {
      value *= 0.95;
    }
    return value;
  }
  private void drawEllipse(PVector center, float rotation, float intensity, float colorHue) {
    strokeWeight(getScaledValue(2));
    pushMatrix();
    translate(center.x, center.y);
    
    float ratio = 0;
    float rotationX = rotation;
    boolean direction = true;
    for (int dist = 4; dist < width / 3; dist += getScaledValue(16)) {
      ratio += width / 3.0;
      rotationX += ratio * 0.00004 * (direction ? 1 : -1);
      if (TWO_PI < rotationX) {
        direction = false;
      }
      else if (rotationX < 0) {
        direction = true;
      }
      
      stroke(colorHue, fgSaturation * (1.0 - dist / (width / 2.5)), fgBrightness, intensity * 99);
      pushMatrix();
      rotateX(rotationX);
      rotateY(rotation);
      ellipse(0, 0, dist * intensity * 1.5, dist * intensity * 1.5);
      popMatrix();
    }
    popMatrix();
  }
 
  boolean isDrawable() {
    return expired(System.currentTimeMillis()) == false;
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary, boolean expired) {
    if (isPrimary) {
      if (rotation < 0) {
        rotationInc = 4.0 * (provider.getCrotchetQuantityMillis() / 1000) / getFramePerSecond();
        rotation = 0;
      }
      initBackground();
      rightIntensity = calcNewIntensity(rightIntensity, provider.player.right.level() * 4);
      leftIntensity = calcNewIntensity(leftIntensity, provider.player.left.level() * 4);
      mixIntensity = calcNewIntensity(mixIntensity, provider.player.mix.level() * 4);
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    
    noFill();
    ellipseMode(CENTER);

    translate(width / 2, height / 2);
    rotateZ(rotation);
    rotateY(PI / 4.0 - rotation);

    int step = 60;
    float h = fgHue + step;
    if (360 <= h) {
      h -= 360;
    }
    drawEllipse(new PVector(width / 4, 0), PI - rotation, rightIntensity, h);
    h = fgHue - step;
    if (h < 0) {
      h += 360;
    }
    drawEllipse(new PVector(-width / 4, 0), TWO_PI - rotation, leftIntensity, h);
    drawEllipse(new PVector(0, 0), rotation, mixIntensity, fgHue);

    rotation += rotationInc;
    if (TWO_PI < rotation) {
      rotation = 0;
    }
  }
}
