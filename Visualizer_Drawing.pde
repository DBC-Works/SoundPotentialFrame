final class NoiseSteeringLineVisualizer extends Visualizer {
  private final List<Particle> particles = new ArrayList<Particle>();

  private XorShift32 rand;
  
  NoiseSteeringLineVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, 0, #ffffff);
  }

  void clear() {
    initBackground();
    particles.clear();
  }
  boolean isDrawable() {
    return particles.isEmpty() == false;
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    final int halfWidth = width / 2;
    final int halfHeight = height / 2;
    if (rand == null) {
      rand = new XorShift32((int)provider.beatPerMinute);
      if (isPrimary) {
        initBackground();
      }
    }
    if (isPrimary) {
      final float rate =  provider.player.sampleRate() / 2;
      final PVector right = new PVector(map(provider.rightFft.calcAvg(0, rate), 0, 1, 0, halfWidth), map(provider.player.right.level() * 5, 0, 1, halfHeight, -halfHeight));
      final PVector left = new PVector(map(provider.leftFft.calcAvg(0, rate), 0, 1, 0, -halfWidth), map(provider.player.left.level() * 5, 0, 1, halfHeight, -halfHeight));
      particles.add(new Particle(right, 2));
      particles.add(new Particle(left, 2));
    }
    
    if (0 < particles.size() && (isPrimary == false || 4 < particles.size())) {
      particles.remove(0);
    }
    int index = 0;
    while (index < particles.size()) {
      Particle particle = particles.get(index);
      if (particle.isAlive()) {
        final float length = getScaledValue(rand.nextFloat() * (height / 100.0) + 1);
        final PVector pos = particle.getCurrentPosition();
        final float ns = noise(pos.x / 25.0, pos.y / 25.0);
        pos.x += (cos(ns * TWO_PI) * length);
        pos.y += (sin(ns * TWO_PI) * length);
        particle.moveTo(pos);
        if (particle.isAlive()) {
          if (pos.x < -halfWidth  || pos.y < -halfHeight || halfWidth < pos.x || halfHeight < pos.y) {
            particle.terminate();
          }
        }
        ++index;
      }
      else {
          particles.remove(index);
      }
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    
    translate(width / 2, height / 2);
    stroke(hue(fgColor), saturation(fgColor), brightness(fgColor), 10);
    setStrokeWeight(1);
    noFill();
    for (Particle particle : particles) {
      final List<PVector> positions = particle.getPositionHistory();
      if (1 < positions.size()) {
        drawVertex(positions);
      }
    }
  }
}

final class NoiseSteeringCurveLineVisualizer extends Visualizer {
  private final List<Particle> rightParticles = new ArrayList<Particle>();
  private final List<Particle> leftParticles = new ArrayList<Particle>();

  private XorShift32 rand;
  private float ns;
  
  NoiseSteeringCurveLineVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }
  
  private void updateParticles(List<Particle> particles, boolean rightSide) {
    Iterator iterator = particles.iterator();
    while (iterator.hasNext()) {
      Particle p = (Particle)iterator.next();
      if (p.isAlive() == false || 20 < p.getAliveCount()) {
        p.terminate();
        iterator.remove();
      }
      else {
        PVector pos = p.getCurrentPosition();
        float angle = map(noise(pos.x, pos.y, ns), 0, 1, 0, PI);
        if (rightSide) {
          angle += HALF_PI;
        }
        else {
          angle = HALF_PI - angle;
        }
        float len = abs(p.getLastDistance()) * 0.8;
        pos.add(len * cos(angle), len * sin(angle));
        p.moveTo(pos);
      }
    }    
  }
  private void visualizeParticle(Particle particle) {
    beginShape();
    for (PVector pos : particle.getPositionHistory()) {
      curveVertex(pos.x, pos.y);
    }
    endShape();
  }
  
  void clear() {
    initBackground();
    rightParticles.clear();
    leftParticles.clear();
  }
  boolean isDrawable() {
    return rightParticles.isEmpty() == false || leftParticles.isEmpty() == false;
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (rand == null) {
      initBackground();
      rand = new XorShift32((int)provider.beatPerMinute);
      ns = rand.nextFloat();
      if (isPrimary) {
        initBackground();
      }
    }

    final float rate =  provider.player.sampleRate() / 3;
    
    final Particle rightParticle = new Particle(new PVector(width / 2, 0), 5);
    rightParticle.moveTo(new PVector(width / 2, map(provider.rightFft.calcAvg(0, rate), 0, 2.4, height / 2, -height / 2)));
    rightParticles.add(rightParticle);
    updateParticles(rightParticles, true);
    
    final Particle leftParticle = new Particle(new PVector(-width / 2, 0), 5); 
    leftParticle.moveTo(new PVector(-width / 2, map(provider.leftFft.calcAvg(0, rate), 0, 2.4, height / 2, -height / 2)));
    leftParticles.add(leftParticle);
    updateParticles(leftParticles, false);

    ns += 0.01;
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    rectMode(CENTER);
    
    translate(width / 2, height / 2);
    stroke(hue(fgColor), saturation(fgColor), brightness(fgColor), 5);
    setStrokeWeight(1);
    noFill();

    for (Particle particle : rightParticles) {
      if (particle.isAlive()) {
        visualizeParticle(particle);
      }
    }
    
    for (Particle particle : leftParticles) {
      if (particle.isAlive()) {
        visualizeParticle(particle);
      }
    }
  }
}

final class LevelTraceVisualizer extends Visualizer {
  private final List<Particle> rightParticles = new ArrayList<Particle>();
  private final List<Particle> leftParticles = new ArrayList<Particle>();
  private XorShift32 rand;
  private float ns;
  
  LevelTraceVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }

  void clear() {
    initBackground();
    rightParticles.clear();
    leftParticles.clear();
  }
  boolean isDrawable() {
    return rightParticles.isEmpty() == false || leftParticles.isEmpty() == false;
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (rand == null) {
      rand = new XorShift32((int)getCurrentScene().soundInfo.beatPerMinute);
      ns = rand.nextFloat();
      if (isPrimary) {
        initBackground();
      }
    }

    final int maxSpec = provider.rightFft.freqToIndex(440 * 4);
    rightParticles.clear();
    leftParticles.clear();
    if (getState() != VisualizingState.Expired) {
      for (int index = 0; index < maxSpec; ++index) {
        rightParticles.add(new Particle(new PVector(index, provider.rightFft.getBand(index)), 1));
      }
      for (int index = 0; index < maxSpec; ++index) {
        leftParticles.add(new Particle(new PVector(index, provider.leftFft.getBand(index)), 1));
      }
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    rectMode(CENTER);
    
    translate(width / 2, height);
    float h = hue(fgColor) + 60 * (noise(ns) - 0.5);
    if (h < 0) {
      h += 360;
    }
    else if (360 < h){
      h -= 360;
    }
    ns += 0.01;
    stroke(h, saturation(fgColor), brightness(fgColor), 5);
    setStrokeWeight(1);
    noFill();

    final float amp = height / 12;
    for (Particle particle : rightParticles) {
      visualizeParticle(particle, rightParticles.size(), amp, true);
    }
    
    for (Particle particle : leftParticles) {
      visualizeParticle(particle, leftParticles.size(), amp, false);
    }
  }

  private void visualizeParticle(Particle particle, int particleCount, float amp, boolean rightSide) {
    final PVector pos = particle.getCurrentPosition();
    final float x = map(pos.x, 0, particleCount, 0, (width / 2) *  (rightSide ? 1 : -1)) + (rand.nextGaussian() * amp); 
    final float y = map(pos.y, 0, 72, 0, -height) + (rand.nextGaussian() * amp); 
    final float n = noise(x / 100.0, y  / 100.0);
    final float yStep = -(y / 4);

    beginShape();
    curveVertex(x, y);
    curveVertex(x, y);
    curveVertex(x + (amp * n), y + yStep);
    curveVertex(x, y + yStep * 2);
    curveVertex(x - (amp * n), y + yStep * 3);
    curveVertex(x, 0);
    curveVertex(x, 0);
    endShape();
  }
}

final class BlurringArcVisualizer extends Visualizer {
  private final List<Particle> rightParticles = new ArrayList<Particle>();
  private final List<Particle> leftParticles = new ArrayList<Particle>();

  private float posNoiseSeed = Float.MIN_VALUE;
  private float hueNoiseSeed;
  private float hue;
  
  BlurringArcVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }

  private void moveParticles(List<Particle> particles, float angle, float level) {
    Iterator it = particles.iterator();
    while (it.hasNext()) {
      final Particle particle = (Particle)it.next();
      if (particle.getAliveCount() < 8) {
        final float newX =  getScaledValue(20) * noise(posNoiseSeed + level);
        posNoiseSeed += 0.01;
        final float newY =  getScaledValue(20) * noise(posNoiseSeed + level);
        posNoiseSeed += 0.01;
        final PVector pos = new PVector(newX, newY);
        pos.rotate(angle + TWO_PI * noise(pos.x, pos.y));
        particle.moveTo(particle.getCurrentPosition().add(pos));
      }
      else {
        it.remove();
      }
    }
  }
  private Particle createParticle(float unit, float level, float angle) {
    final float x = (unit + unit * level) * cos(angle);
    final float y = (unit + unit * level) * sin(angle);
    return new Particle(new PVector(x, y), 3);
  }
  private void visualizeParticles(List<Particle> particles) {
    for (Particle particle : particles) {
      drawVertex(particle.getPositionHistory());
    }
  }

  void clear() {
    initBackground();
    rightParticles.clear();
    leftParticles.clear();
  }
  boolean isDrawable() {
    return rightParticles.isEmpty() == false || leftParticles.isEmpty() == false;
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (posNoiseSeed == Float.MIN_VALUE) {
      posNoiseSeed = getCurrentScene().soundInfo.beatPerMinute;
      hueNoiseSeed = noise(posNoiseSeed);
      if (isPrimary) {
        initBackground();
      }
    }

    final float angle = -(PI * provider.getProgressPercentage());

    moveParticles(rightParticles, angle, provider.player.right.level());
    moveParticles(leftParticles, PI + angle, provider.player.left.level());

    final float unit = (getShortSideLen() / 2.0) * (provider.getProgressPercentage());
    if (getState() != VisualizingState.Expired) {
      rightParticles.add(createParticle(unit, provider.player.right.level(), angle));
      leftParticles.add(createParticle(unit, provider.player.left.level(), PI + angle));
    }
    
    hue = (hue(fgColor) + ((noise(provider.player.mix.level() + hueNoiseSeed) * 80) - 40)) % 360;
    hueNoiseSeed += 0.01;
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    stroke(hue, saturation(fgColor), brightness(fgColor), 5);
    setStrokeWeight(2);
    strokeCap(ROUND);
    ellipseMode(CENTER);
    noFill();
    translate(width / 2, height / 2);

    visualizeParticles(rightParticles);
    visualizeParticles(leftParticles);
  }
}
