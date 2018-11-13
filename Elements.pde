final class ValueAttenuator {
  private final float ratio;
  private float value;
  
  ValueAttenuator(float r) {
    ratio = r;
  }
  
  float getValue() {
    return value;
  }
  ValueAttenuator update(float newValue) {
    if (value < newValue) {
      value = newValue;
    }
    else {
      value *= ratio;
    }
    return this;
  }
  ValueAttenuator update() {
    value *= ratio;
    return this;
  }
}

final class Particle {
  private final List<PVector> positions = new ArrayList<PVector>();
  private final int historyCount;
  private int aliveCount;
  private boolean terminated;
  
  Particle(PVector pos, int count) {
    positions.add(pos.get());
    historyCount = count;
  }

  PVector getCurrentPosition() {
    return positions.get(positions.size() - 1).get();
  }
  float getLastDistance() {
    return getCurrentPosition().dist(positions.get(positions.size() - 2));
  }
  List<PVector> getPositionHistory() {
    return Collections.unmodifiableList(positions);
  }
  int getAliveCount() {
    return aliveCount;
  }
  boolean isAlive() {
    return terminated == false || positions.isEmpty() == false;
  }
  
  void terminate() {
    terminated = true;
  }
  void moveTo(PVector pos) {
    ++aliveCount;
    if (terminated == false) {
      positions.add(pos);
    }
    if (historyCount < positions.size() || (terminated && positions.isEmpty() == false)) {
      positions.remove(0);
    }
  }
}

final class ShapeSource {
  final PVector position;
  final float radius;
  
  ShapeSource(PVector pos, float r) {
    position = pos;
    radius = r;
  }
}

abstract class Shape {
  protected ShapeSource source;
  
  protected Shape(ShapeSource src) {
    source = src;
  }
  
  final Shape setSource(ShapeSource src) {
    source = src;
    updateSource();
    return this;
  }
  final void visualize() {
    pushMatrix();
    translate(source.position.x, source.position.y, source.position.z);
    doVisualize();
    popMatrix();
  }
  
  protected void updateSource() {
  }
  
  abstract protected void doVisualize();
}

final class RegularPolygon extends Shape {
  private final int number;
  
  RegularPolygon(ShapeSource src, int num) {
    super(src);
    number = num;
  }
  
  protected final void doVisualize() {
    beginShape();
    for (float angle = 0; angle < TWO_PI; angle += (TWO_PI / number)) {
      vertex(source.position.x + (source.radius * cos(angle)), source.position.y + (source.radius * sin(angle)), source.position.z);
    }
    endShape(CLOSE);
  }
}

final class PliantSpot extends Shape {
  PliantSpot(ShapeSource src) {
    super(src);
  }
  
  protected final void doVisualize() {
    XorShift32 radomizer = new XorShift32((int)(source.position.x + source.position.y));
    float ns = radomizer.nextFloat() * (source.position.x * source.position.y);
    List<PVector> points = new ArrayList<PVector>();
    float baseAngle = radomizer.nextFloat() * TWO_PI;
    float angle = 0;
    int corners = 4 + ((int)(radomizer.nextFloat() * 4) * 2);
    while (angle < TWO_PI) {
      float baseX = source.radius * cos(baseAngle + angle);
      float baseY = source.radius * sin(baseAngle + angle);
      float r = source.radius * (0.5 + noise(baseX, baseY, ns));
      points.add(new PVector(r * cos(baseAngle + angle), r * sin(baseAngle + angle)));
      angle += (TWO_PI / corners) * (0.5 + noise(ns));
      ns += 0.01;
    }
    
    beginShape();
    PVector lastPoint = points.get(points.size() - 2); 
    curveVertex(lastPoint.x, lastPoint.y);
    for (PVector point : points) {
      curveVertex(point.x, point.y);
    }
    PVector firstPoint = points.get(1); 
    curveVertex(firstPoint.x, firstPoint.y);
    endShape(CLOSE);
  }
}

final class RegularTetrahedron extends Shape {
  private PVector front;
  private PVector back;
  private PVector right;
  private PVector left;
  
  RegularTetrahedron(ShapeSource src) {
    super(src);
    if (source != null) {
      updatePoints();
    }
  }
  
  private void updatePoints() {
    front = new PVector(source.radius, source.radius, source.radius);
    right = new PVector(source.radius, -source.radius, -source.radius);
    back = new PVector(-source.radius, source.radius, -source.radius);
    left = new PVector(-source.radius, -source.radius, source.radius);
  }
  
  protected final void doVisualize() {
    PVector[][] faces = new PVector[][] {
      { front, left, right }, 
      { back, left, right }, 
      { front, back, left }, 
      { front, back, right }, 
    };
    for (PVector[] face : faces) {
      beginShape();
      for (PVector point : face) {
        vertex(point.x, point.y, point.z);
      }
      endShape(CLOSE);
    }
  }
  
  protected void updateSource()
  {
    if (source != null) {
      updatePoints();
    }
  }
}

abstract class AbstractRegularOctahedron extends Shape {
  protected PVector top;
  protected PVector right;
  protected PVector bottom;
  protected PVector left;
  protected PVector front;
  protected PVector back;
  
  protected AbstractRegularOctahedron(ShapeSource src) {
    super(src);
    if (source != null) {
      updatePoints();
      doUpdateSource();
    }
  }
  
  private void updatePoints() {
    top = new PVector(0, -source.radius, 0);
    right = new PVector(source.radius, 0, 0);
    bottom = new PVector(0, source.radius, 0);
    left = new PVector(-source.radius, 0, 0);
    front = new PVector(0, 0, -source.radius);
    back = new PVector(0, 0, source.radius);
  }
  
  protected final void drawFace(PVector[][] faces) {
    for (PVector[] face : faces) {
      beginShape();
      for (PVector point : face) {
        vertex(point.x, point.y, point.z);
      }
      endShape(CLOSE);
    }
  }
  
  protected void updateSource() {
    if (source != null) {
      updatePoints();
      doUpdateSource();
    }
  }
  
  protected void doUpdateSource() {
  }
}

final class RegularOctahedron extends AbstractRegularOctahedron {
  private PVector[][] faces;

  RegularOctahedron(ShapeSource src) {
    super(src);
  }
  
  protected final void doVisualize() {
    drawFace(faces);
  }
  
  protected void doUpdateSource() {
    faces = new PVector[][] {
      { top, left, back }, 
      { top, right, back }, 
      { bottom, left, back }, 
      { bottom, right, back }, 
      { top, left, front }, 
      { top, right, front }, 
      { bottom, left, front }, 
      { bottom, right, front }
    };
  }
}

final class CrossSquare extends AbstractRegularOctahedron {
  private PVector[][] faces;

  CrossSquare(ShapeSource src) {
    super(src);
  }
  
  protected final void doVisualize() {
    drawFace(faces);
  }
  
  protected void doUpdateSource() {
    faces = new PVector[][] {
      { top, front, bottom, back }, 
      { top, right, bottom, left }, 
      { back, right, front, left }, 
    };
  }
}

final class LissajousCalculator {
  public List<PVector> calcSimpleLissajousPoints(int w, float freqX, float freqY, float phi, int step) {
    List<PVector> points = new ArrayList<PVector>(w);
    for (int index = 0; index <= w; index += step) {
      final float angle = map(index, 0, w, 0, TWO_PI);
      points.add(new PVector(sin(angle * freqX + phi), sin(angle * freqY)));
    }
    return points;
  }
}
