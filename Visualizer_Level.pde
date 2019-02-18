final class ParticleFountainVisualizer extends Visualizer {
  private final List<Particle> rightParticles = new ArrayList<Particle>();
  private final List<Particle> leftParticles = new ArrayList<Particle>();
  
  private float noiseSeed = random(1);
  
  ParticleFountainVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #fffa88, 0);

    noiseSeed((long)random(Integer.MAX_VALUE));
  }

  private void moveParticles(List<Particle> particles) {
    final PVector wind = new PVector(0, (noise(noiseSeed) - 0.5) * getScaledValue(8));
    int index = 0;
    while (index < particles.size()) {
      Particle particle = particles.get(index);
      if (particle.getAliveCount() < 10) {
        final PVector pos = particle.getCurrentPosition();
        pos.mult(1.2);
        pos.add(wind);
        particle.moveTo(pos);
        ++index;
      }
      else {
        particles.remove(index);
      }
    }
  }
  private Particle createParticle(float angle, float band) {
    final float len = band * width / 2.0;
    return new Particle(new PVector(len * cos(angle), len * sin(angle)), 1);
  }
  private void visualizeParticles(List<Particle> particles, float radius) {
    for (Particle particle : particles) {
      final PVector pos = particle.getCurrentPosition();
      if (1 < abs(pos.x) && 1 < abs(pos.y)) { 
        ellipse(pos.x, pos.y, radius, radius);
      }
    }
  }
  
  void clear() {
    rightParticles.clear();
    leftParticles.clear();
  }
  boolean isDrawable() {
    return rightParticles.isEmpty() == false || leftParticles.isEmpty() == false; 
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      initBackground();
    }
    
    moveParticles(rightParticles);
    moveParticles(leftParticles);
    noiseSeed += 0.01;
    
    if (getState() != VisualizingState.Expired) {
      final int maxSpec = provider.rightFft.specSize() / 2;
      for (int index = 0; index < maxSpec; ++index) {
        rightParticles.add(createParticle(PI * ((float)index / maxSpec), provider.rightFft.getBand(index)));
      }
      for (int index = 0; index < maxSpec; ++index) {
        leftParticles.add(createParticle(-PI * ((float)index / maxSpec), provider.leftFft.getBand(index)));
      }
    }
  }

  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    rectMode(CENTER);
    
    translate(width / 2, height / 2);
    rotate(PI / 2);
    noStroke();
    strokeWeight(getScaledValue(1));
    fill(hue(fgColor), saturation(fgColor), brightness(fgColor), 5);
    
    final float r = getScaledValue(8);
    ellipseMode(CENTER);
    visualizeParticles(rightParticles, r);
    visualizeParticles(leftParticles, r);
  }
}

abstract class LevelVisualizer extends Visualizer {
  private final float topFreq;
  private final float decayRate;

  private List< ValueAttenuator > rightLevels;
  private List< ValueAttenuator > leftLevels;

  protected LevelVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);

    topFreq = info.options.getFloat("topFrequency", -1);
    decayRate = info.options.getFloat("decayRate", 0.5);
  }

  final boolean isDrawable() {
    return (rightLevels != null && hasValidValue(rightLevels))
         || (leftLevels != null && hasValidValue(leftLevels));
  }

  final protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    List< Float> latestRightLevels = null;
    List< Float> latestLeftLevels = null;
    
    if (isPrimary || getState() != VisualizingState.Expired) {
      if (isPrimary) {
        initBackground();
      }
      if (getState() != VisualizingState.Expired) {
        latestRightLevels = getLevels(provider.rightFft);
        latestLeftLevels = getLevels(provider.leftFft);
      }
    }
    if (rightLevels == null) {
      if (latestRightLevels != null) {
        rightLevels = initializeLevelContainer(latestRightLevels);
      }
    }
    else {
      updateLevels(latestRightLevels, rightLevels);
    }
    if (leftLevels == null) {
      if (latestLeftLevels != null) {
        leftLevels = initializeLevelContainer(latestLeftLevels);
      }
    }
    else {
      updateLevels(latestLeftLevels, leftLevels);
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    
    noFill();
    
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    final float a = alpha(fgColor);
    stroke(color(h, s, b, 0 < a ? a : 99));

    if (rightLevels != null) {
      pushMatrix();
      visualizeLevels(rightLevels, false);
      popMatrix();
    }
    if (leftLevels != null) {
      pushMatrix();
      visualizeLevels(leftLevels, true);
      popMatrix();
    }
  }

  private boolean hasValidValue(List< ValueAttenuator > levels) {
    Iterator< ValueAttenuator > it = levels.iterator();
    while (it.hasNext()) {
      final ValueAttenuator v = it.next();
      if (0.01 < v.getValue()) {
        return true;
      }
    }
    return false;
  }
  private List<Float> getLevels(FFT fft) {
    final List<Float> levels = new ArrayList<Float>();
    final int maxIndex = topFreq < 0
                        ? fft.specSize()
                        : min(fft.freqToIndex(topFreq), fft.specSize());
    for (int index = 0; index < maxIndex; ++index) {
      levels.add(fft.getBand(index));
    }
    return levels;
  }
  private List< ValueAttenuator > initializeLevelContainer(List< Float > latestLevels) {
    final List< ValueAttenuator > levels = new ArrayList< ValueAttenuator >();
    for (float level : latestLevels) {
      levels.add(new ValueAttenuator(decayRate).update(level));
    }
    return levels;
  }
  private void updateLevels(List< Float > latestLevels, List< ValueAttenuator > levels) {
    if (latestLevels != null) {
      for (int index = 0; index < levels.size(); ++index) {
        levels.get(index).update(latestLevels.get(index));
      }
    }
    else {
      for (ValueAttenuator value : levels) {
        value.update();
      }
    }
  }

  abstract protected void visualizeLevels(List< ValueAttenuator > levels, boolean asLeft);
}

final class SimpleBarLevelMeterVisualizer extends LevelVisualizer {
  private final float meterLenRatio;
  private final float meterWidthRatio;

  SimpleBarLevelMeterVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis);

    meterLenRatio = info.options.getFloat("meterLengthRatio", 1.0);
    meterWidthRatio = info.options.getFloat("meterWidthRatio", 1.0);
  }

  protected void visualizeLevels(List< ValueAttenuator > levels, boolean asLeft) {
    translate(0, height / 2);

    final float weight = (width / (float)levels.size());
    strokeWeight(weight * meterWidthRatio);
    float x = 0;
    for (ValueAttenuator value : levels) {
      final float levelRatio = value.getValue() / 150.0;
      line(x, 0, x, (levelRatio * (asLeft ? -1 : 1)) * ((height / 2) * meterLenRatio));
      x += weight;
    }
  }
}

abstract class BeatCircleVisualizer extends Visualizer {
  protected final float radius;
  protected final float weightUnit;

  private final float alphaLevel;
  private final List<Float> kickDiameters = new ArrayList<Float>();
  private final List<Float> hatDiameters = new ArrayList<Float>();

  private float detectionIntervalFrame = 1;
  private int kickCount = -1;
  private int hatCount = -1;
  
  protected BeatCircleVisualizer(VisualizationInfo info, long lastTimeMillis, float fgAlphaLevel) {
    super(info, lastTimeMillis, 0, #ffffff);
    alphaLevel = fgAlphaLevel;

    final int shortSideLen = getShortSideLen(); 
    radius = (shortSideLen / 2) * 4.0 / 5;
    weightUnit = shortSideLen / 100.0;
  }

  protected final void clearDiameters() {
    kickDiameters.clear();
    hatDiameters.clear();
  }

  final boolean isDrawable() {
    return getState() == VisualizingState.Processing;
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    final float dr = 24.0 / getFramePerSecond();

    if (isPrimary) {
      initBackground();
    }

    updateDiameters(kickDiameters, 0.67 * dr, (radius / 20.0));
    if (kickCount < 0) {
      if (provider.beatDetector.isKick()) {
        if (getState() != VisualizingState.Expired) {
          kickDiameters.add(radius * 2);
        }
        kickCount = 0;
      }
    }
    else {
      if (detectionIntervalFrame <= ++kickCount) {
        kickCount = -1;
      }
    }

    updateDiameters(hatDiameters, 1.2 * dr, max(width, height));
    if (hatCount < 0) {
      if (provider.beatDetector.isHat()) {
        if (getState() != VisualizingState.Expired) {
          hatDiameters.add(radius * 2);
        }
        hatCount = 0;
      }
    }
    else {
      if (detectionIntervalFrame <= ++hatCount) {
        hatCount = -1;
      }
    }

    prepareAdditionalElements(provider, getState() == VisualizingState.Expired);
  }
  protected final void doVisualize() {
    colorMode(RGB, 255, 255, 255, 100);
    noFill();
 
    translate(width / 2, height / 2);

    ellipseMode(CENTER);
    strokeWeight(weightUnit * 2);
    stroke(red(fgColor), green(fgColor), blue(fgColor), alphaLevel);
    for (float diameter : kickDiameters) {
      ellipse(0, 0, diameter, diameter);
    }
    
    strokeWeight(weightUnit * 1.5);
    for (float diameter : hatDiameters) {
      ellipse(0, 0, diameter, diameter);
    }
    
    visualizeAdditionalElements();
  }

  protected final void setDetectionIntervalFrame(float frame) {
    detectionIntervalFrame = frame; 
  }

  private void updateDiameters(List<Float> diameters, float ratio, float limit) {
    int index = 0;
    while (index < diameters.size()) {
      float diameter = diameters.get(index) * ratio;
      if ((ratio < 1.0 && diameter < limit) || (1.0 <= ratio && limit < diameter)) {
        diameters.remove(index);
      }
      else {
        diameters.set(index, diameter);
        ++index;
      }
    }
  }
  
  abstract protected boolean isAdditionalElementsDrawable();
  abstract protected void prepareAdditionalElements(MusicDataProvider provider, boolean expired);
  abstract protected void visualizeAdditionalElements();
}

final class BeatCircleAndFreqLevelVisualizer extends BeatCircleVisualizer {
  private final List<Particle> rightParticles = new ArrayList<Particle>();
  private final List<Particle> leftParticles = new ArrayList<Particle>();

  BeatCircleAndFreqLevelVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, 40);
  }

  private void updateParticles(List<Particle> particles, FFT fft, boolean expired, boolean asLeft) {
    final float bandRatio = 100;
    final int maxSpec = fft.freqToIndex(440 * 16);
    particles.clear();
    for (int index = 0; index < maxSpec; ++index) {
      final float rad = map(index, 0, maxSpec, -PI / 2, PI / 2);
      final PVector pos = new PVector(radius * cos(rad) * (asLeft ? -1 : 1), -radius * sin(rad));
      final Particle p = new Particle(pos, 2);
      final PVector a = PVector.mult(pos, sin(map(fft.getBand(index) / bandRatio, 0, 1, 0, PI / 2)) * map(index, 0, maxSpec, 1, 3));
      p.moveTo(new PVector(pos.x - a.x, pos.y - a.y));
      particles.add(p);
    }
  }
  private void visualizeParticles(List<Particle> particles) {
    for (Particle particle : particles) {
      drawVertex(particle.getPositionHistory());
    }
  }

  void clear() {
    rightParticles.clear();
    leftParticles.clear();
    clearDiameters();
  }

  protected final boolean isAdditionalElementsDrawable() {
    return rightParticles.isEmpty() == false || leftParticles.isEmpty() == false;
  }
  protected final void prepareAdditionalElements(MusicDataProvider provider, boolean expired) {
    updateParticles(rightParticles, provider.rightFft, expired, false);
    updateParticles(leftParticles, provider.leftFft, expired, true);
  }
  protected final void visualizeAdditionalElements() {
    strokeWeight(weightUnit);
    stroke(red(fgColor), green(fgColor), blue(fgColor), 80);
    visualizeParticles(rightParticles);
    visualizeParticles(leftParticles);
  }
}

final class BeatCircleAndOctavedFreqLevelVisualizer extends BeatCircleVisualizer {
  private OctavedLevels octavedLevels;

  BeatCircleAndOctavedFreqLevelVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, 67);
    setDetectionIntervalFrame(((provider.getCrotchetQuantityMillis() / 1000) * getFramePerSecond()) / 4);
  }
  
  private void drawLevels(List< List< Float > > levels, boolean asLeft) {
    for (List<Float> levelPerScale : levels) {
      final float angleStep = PI / levelPerScale.size();
      final float unit = getShortSideLen() / 2;
      float x = 0, y = 0, prevX = 0, prevY = unit; 
      for (int index = 0; index < levelPerScale.size(); ++index) {
        final float level = levelPerScale.get(index);
        x = (unit * (level / 20.0) * cos((PI / 2) + (angleStep * index))) * (asLeft ? -1 : 1);
        y = (unit * (level / 20.0) * sin((PI / 2) + (angleStep * index)));
        strokeWeight(getScaledValue(level * 1.5));
        line(prevX, prevY, x, y);
        prevX = x;
        prevY = y;
      }
      line(prevX, prevY, 0, -unit);
    }
  }

  void clear() {
    clearDiameters();
  }
  
  protected final boolean isAdditionalElementsDrawable() {
    return true;
  }
  protected final void prepareAdditionalElements(MusicDataProvider provider, boolean expired) {
    octavedLevels = provider.getOctavedLevels();
  }
  protected final void visualizeAdditionalElements() {
    stroke(red(fgColor), green(fgColor), blue(fgColor), 80);
    drawLevels(octavedLevels.rightLevels, false);
    drawLevels(octavedLevels.leftLevels, true);
  }
}

final class PoppingLevelVisualizer extends Visualizer {
  private OctavedLevels octavedLevels;

  private XorShift32 rand;
  private float ns;
  
  PoppingLevelVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }
  
  boolean isDrawable() {
    return getState() == VisualizingState.Processing;
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (rand == null) {
      rand = new XorShift32((int)provider.beatPerMinute);
      ns = rand.nextFloat();
    }
    if (isPrimary) {
      initBackground();
    }
    octavedLevels = provider.getOctavedLevels();
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    ellipseMode(CENTER);
    
    translate(width / 2, 0);
    noStroke();
    
    visualizeLevels(octavedLevels.rightLevels, false);
    visualizeLevels(octavedLevels.leftLevels, true);
  }
  
  private void visualizeLevels(List<List<Float>> levelHistory, boolean asLeft) {
    final float unit = width / 4.0;
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    for (List<Float> levels : levelHistory) {
      int index = 0;
      final float alpha = 30 + (50 * ((float)levels.size() / (float)levelHistory.get(levelHistory.size() - 1).size()) - 0.1);
      fill(h, s, b, alpha);
      for (float level: levels) {
        final float u = (unit / levels.size()) * map(level, 0, 50, 0, 1);
        pushMatrix();
        final float x = map(index, 0, levels.size(), 0, (width / 2) * (asLeft ? -1 : 1));
        final float y = map(level, 0, 50, height, 0);
        translate(x, y);
        rotate(PI * (noise(x, y, ns) - 0.5));
        ellipse(0, 0, (width / 2.0) / levels.size(), u);
        popMatrix();

        ns += 0.01;
        ++index;
      }
    }
  }
}

final class SpreadOctagonVisualizer extends Visualizer {
  private final List<List<List<ShapeSource>>> rightSourcesHistory = new ArrayList<List<List<ShapeSource>>>();
  private final List<List<List<ShapeSource>>> leftSourcesHistory = new ArrayList<List<List<ShapeSource>>>();
  
  SpreadOctagonVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }
  
  boolean isDrawable() {
    return rightSourcesHistory.isEmpty() == false || leftSourcesHistory.isEmpty() == false;
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      initBackground();
      final OctavedLevels octavedLevels = provider.getOctavedLevels();
      rightSourcesHistory.add(translateLevelsToPoints(octavedLevels.rightLevels, false));
      leftSourcesHistory.add(translateLevelsToPoints(octavedLevels.leftLevels, true));
    }
    if ((isPrimary == false && rightSourcesHistory.isEmpty() == false) || 6 < rightSourcesHistory.size()) {
      rightSourcesHistory.remove(0);
    }
    if ((isPrimary == false && leftSourcesHistory.isEmpty() == false) || 6 < leftSourcesHistory.size()) {
      leftSourcesHistory.remove(0);
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    
    translate(width / 2, height / 2);
    noFill();

    strokeWeight(getScaledValue(3));
    pushMatrix();
    int index = rightSourcesHistory.size();
    for (List<List<ShapeSource>> rightSources : rightSourcesHistory) {
      visualizeSources(rightSources, (float)index / rightSourcesHistory.size());
      rotateY((PI / rightSourcesHistory.size()) / 2);
      --index;
    }
    popMatrix();
    pushMatrix();
    index = leftSourcesHistory.size();
    for (List<List<ShapeSource>> leftSources : leftSourcesHistory) {
      visualizeSources(leftSources, (float)index / leftSourcesHistory.size());
      rotateY(-((PI / rightSourcesHistory.size()) / 2));
      --index;
    }
    popMatrix();
  }

  private List<List<ShapeSource>> translateLevelsToPoints(List<List<Float>> levels, boolean asLeft) {
    final List<List<ShapeSource>> points = new ArrayList<List<ShapeSource>>(); 
    for (List<Float> levelsPerScale : levels) {
      final List<ShapeSource> pointsPerScale = new ArrayList<ShapeSource>(); 
      final float angleStep = PI / levelsPerScale.size();
      final float unit = getShortSideLen() / 2;
      for (int index = 0; index < levelsPerScale.size(); ++index) {
        final float level = levelsPerScale.get(index);
        final float x = (unit * (level / 20.0) * cos((PI / 2) + (angleStep * index))) * (asLeft ? 1 : -1);
        final float y = (unit * (level / 20.0) * sin((PI / 2) + (angleStep * index)));
        pointsPerScale.add(new ShapeSource(new PVector(x, y, 0), getScaledValue(level * 8)));
      }
      points.add(pointsPerScale);
    }
    return points;
  }
  private void visualizeSources(List<List<ShapeSource>> sources, float intensity) {
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    stroke(color(h, s * ((1 - intensity) * 2), b, 75));
    final Shape shape = new RegularPolygon(null, 8);
    for (List<ShapeSource> sourcesPerScale : sources) {
      for (ShapeSource source : sourcesPerScale) {
        shape.setSource(source).visualize();
      }
    }
  }
}
abstract class OctavedLevelsVisualizer extends Visualizer {
  protected final ValueAttenuator mixIntensity = new ValueAttenuator(0.5);
  protected final ValueAttenuator rightIntensity = new ValueAttenuator(0.5);
  protected final ValueAttenuator leftIntensity = new ValueAttenuator(0.5);
  
  private List< List< ValueAttenuator > > rightLevels;
  private List< List< ValueAttenuator > > leftLevels;

  protected OctavedLevelsVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }
  
  boolean isDrawable() {
    return getState() == VisualizingState.Processing && 
          (0 < mixIntensity.getValue()
          || 0 < leftIntensity.getValue()
          || 0 < rightIntensity.getValue());
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    List< List< Float >> latestRightLevels = null;
    List< List< Float >> latestLeftLevels = null;
    
    final boolean expired = getState() == VisualizingState.Expired;
    if (isPrimary || expired == false) {
      if (isPrimary) {
        initBackground();
      }
      if (expired == false) {
        OctavedLevels octavedLevels = provider.getOctavedLevels();
        latestRightLevels = octavedLevels.rightLevels; 
        latestLeftLevels = octavedLevels.leftLevels;
      }
    }
    if (latestRightLevels != null && rightLevels == null) {
      rightLevels = initializeLevelContainer(latestRightLevels);
    }
    else if (rightLevels != null) {
      updateLevels(latestRightLevels, rightLevels);
    }
    if (latestLeftLevels != null && leftLevels == null) {
      leftLevels = initializeLevelContainer(latestLeftLevels);
    }
    else if (leftLevels != null) {
      updateLevels(latestLeftLevels, leftLevels);
    }

    mixIntensity.update(isPrimary || expired == false ? provider.player.mix.level() : 0);
    rightIntensity.update(isPrimary || expired == false ? provider.player.right.level() : 0);
    leftIntensity.update(isPrimary || expired == false ? provider.player.left.level() : 0);
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    
    translate(width / 2, height / 2);
    noFill();
    
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    stroke(color(h, s, b, 25));

    if (rightLevels != null) {
      visualizeOctavedLevels(rightLevels, false);
    }
    if (leftLevels != null) {
      visualizeOctavedLevels(leftLevels, true);
    }

    visualizeAdditionalElements();
  }
  
  private List< List< ValueAttenuator > > initializeLevelContainer(List< List< Float > > latestOctavedLevels) {
    final List< List< ValueAttenuator > > octavedLevels = new ArrayList< List< ValueAttenuator > >();
    for (List< Float > latestLevels : latestOctavedLevels) {
      final List< ValueAttenuator > levels = new ArrayList< ValueAttenuator >();
      for (float level : latestLevels) {
        levels.add(new ValueAttenuator(0.5).update(level));
      }
      octavedLevels.add(levels);
    }
    return octavedLevels;
  }
  private void updateLevels(List< List< Float > > latestOctavedLevels, List< List< ValueAttenuator > > octavedLevels) {
    if (latestOctavedLevels != null) {
      for (int octave = 0; octave < latestOctavedLevels.size(); ++octave) {
        final List< Float > latestOctaves = latestOctavedLevels.get(octave);
        final List< ValueAttenuator > octaves = octavedLevels.get(octave); 
        for (int index = 0; index < latestOctaves.size(); ++index) {
          octaves.get(index).update(latestOctaves.get(index));
        }
      }
    }
    else {
      for (List< ValueAttenuator > levels : octavedLevels) {
        for (ValueAttenuator value : levels) {
          value.update();
        }
      }
    }
  }
  
  abstract protected void visualizeOctavedLevels(List< List< ValueAttenuator > > octavedLevels, boolean asLeft);
  protected void visualizeAdditionalElements() {
  }
}

final class TripleRegularOctahedronVisualizer extends OctavedLevelsVisualizer {
  private final Shape shape = new RegularOctahedron(null);
  private final PVector sharedShapePoint = new PVector(0, 0, 0);

  TripleRegularOctahedronVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis);
  }

  protected void visualizeOctavedLevels(List< List< ValueAttenuator > > octavedLevels, boolean asLeft) {
    final float len = width / 2;
    for (List< ValueAttenuator > levels : octavedLevels) {
      if (0 < levels.size()) {
        final float step = ((float)height) / levels.size();
        float y =  height / 2;
        if (levels.size() % 2 != 0) {
          y -= (step / 2);
        }
        final float x = asLeft ? -len : len; 
        for (ValueAttenuator value : levels) {
          line(x, y + (step / 2), x + (len * value.getValue() * (asLeft ? 1 : -1)), y - (step / 2));
          y -= step;
        }
      }
    }
  }
  protected void visualizeAdditionalElements() {
    final float ratio = radians(TWO_PI * provider.getElapsedTimeAsQuantityMillis() / 1000);

    pushMatrix();
    rotateX(-ratio);
    visualizeShape(height / 3, mixIntensity.getValue());
    popMatrix();
    
    pushMatrix();
    translate(-width / 4, 0, 0);
    rotateY(-ratio);
    visualizeShape(height / 4, leftIntensity.getValue());
    popMatrix();
    
    pushMatrix();
    translate(width / 4, 0, 0);
    rotateY(ratio);
    visualizeShape(height / 4, rightIntensity.getValue());
    popMatrix();
  }
  
  private void visualizeShape(float radius, float intensity) {
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    stroke(color(h, s / 2, b, intensity * 100));
    
    shape.setSource(new ShapeSource(sharedShapePoint, radius)).visualize();
  }
}

final class FacingLevelsVisualizer extends OctavedLevelsVisualizer {
  private float ns = random(100);
  
  FacingLevelsVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis);
  }
  
  protected void visualizeOctavedLevels(List< List< ValueAttenuator > > octavedLevels, boolean asLeft) {
    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    stroke(color(h, s, b, 25 + (75 * (asLeft ? leftIntensity.getValue() : rightIntensity.getValue()))));

    final float len = width / 2;
    for (List< ValueAttenuator > levels : octavedLevels) {
      if (0 < levels.size()) {
        float step = ((float)height) / levels.size();
        float y =  height / 2;
        if (levels.size() % 2 != 0) {
          y -= (step / 2);
        }
        final float x = asLeft ? -len : len;
        
        final float weight = Math.max(step / 2, getScaledValue(3)); 
        for (ValueAttenuator value : levels) {
          float lineLen = (len * value.getValue() * (asLeft ? 1 : -1));
          
          strokeWeight(weight * (noise(x, y, ns) + 0.5));
          line(x, y, x + lineLen, y);
          ns += 0.05;
          
          strokeWeight(weight / 2 * (noise(x, y, ns) + 0.5));
          line(x, y, x + lineLen, y);
          ns += 0.05;

          y -= step;
        }
      }
    }
  }
}

final class FakeLaserLightStyleLevelsVisualizer extends OctavedLevelsVisualizer {
  FakeLaserLightStyleLevelsVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis);
  }
  
  protected void visualizeOctavedLevels(List< List< ValueAttenuator > > octavedLevels, boolean asLeft) {
    final int asLeftSign = (asLeft ? -1 : 1);
    pushMatrix();
    translate((width / 4) * asLeftSign, 0);
    rotate(radians(provider.getElapsedTimeMillis() / provider.getCrotchetQuantityMillis() * 16) * asLeftSign);
    for (List< ValueAttenuator > levels : octavedLevels) {
      for (ValueAttenuator value : levels) {
        strokeWeight(getScaledValue(3) * value.getValue());
        line(0, 0, 0, width);
        rotate((TWO_PI / (float)levels.size()) * asLeftSign);
      }
    }
    popMatrix();
  }
}

final class BeatArcLevelsVisualizer extends OctavedLevelsVisualizer {
  BeatArcLevelsVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis);
  }
  
  protected void visualizeOctavedLevels(List< List< ValueAttenuator > > octavedLevels, boolean asLeft) {
    final int asLeftSign = (asLeft ? 1 : -1);
    noFill();
    strokeCap(PROJECT);
    for (List< ValueAttenuator > levels : octavedLevels) {
      if (levels.isEmpty() == false) {
        final int valueCount = levels.size();
        final float step = radians(180 / valueCount) * asLeftSign;
        float angle = PI / 2;
        for (ValueAttenuator value : levels) {
          final float volume = value.getValue();
          strokeWeight(getScaledValue(10) * volume);
          final float unit = (getShortSideLen() * (volume / 50));
          if (asLeft) {
            arc(0, 0, unit, unit, angle, angle + step);
          }
          else {
            arc(0, 0, unit, unit, angle + step, angle);
          }
          angle += step;
        }
      }
    }
  }
}

final class LissajousVisualizer extends Visualizer {
  private final LissajousCalculator calculator = new LissajousCalculator();

  private long startMillis = 0;
  private float rightLevel;
  private float leftLevel;
  private List<PVector> rightPoints;
  private List<PVector> leftPoints;

  private float rotationY;

  LissajousVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, 0, #ffffff);
  }
 
  boolean isDrawable() {
    return getState() == VisualizingState.Processing;
  }
  
  private void drawPoints(List<PVector> points, float factorX, float factorY) {
    for (int index = 0; index < points.size() / 2; ++index) {
      final PVector start = points.get(index);
      final PVector end = points.get(points.size() - (index + 1));
      line(start.x * factorX, start.y * factorY, end.x * factorX, end.y * factorY);
    }
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      initBackground();
      if (startMillis == 0) {
        startMillis = System.currentTimeMillis();
      }
    }
    final float amp = provider.getBeatPerMinute() / 5;
    rightLevel = provider.getRightLevel();
    leftLevel = provider.getLeftLevel();

    final float phi = radians(provider.getMixLevel() * 100);
    rightPoints = calculator.calcSimpleLissajousPoints(width / 2, rightLevel * amp, leftLevel * amp, phi, 4);
    leftPoints = calculator.calcSimpleLissajousPoints(width / 2, leftLevel * amp, rightLevel * amp, phi, 4);
    
    final float elapsedTimeMillis = System.currentTimeMillis() - startMillis;
    rotationY = radians(TWO_PI * (elapsedTimeMillis % provider.getCrotchetQuantityMillis()));
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    stroke(hue(fgColor), saturation(fgColor), brightness(fgColor), 25);
    noFill();
    strokeWeight(getScaledValue(2));

    final float factor = height / 2; 
    final float distanceX = width / 4; 
    
    pushMatrix();
    translate(distanceX * 3, factor);
    rotateY(rotationY);
    drawPoints(rightPoints, factor, factor);
    popMatrix();
    
    pushMatrix();
    translate(distanceX, factor);
    rotateY(-rotationY);
    drawPoints(leftPoints, -factor, factor);
    popMatrix();
  }
}

final class NaturalAngleSpiralVisualizer extends Visualizer {
  private long startMillis = 0;
  private float rightLevel;
  private float leftLevel;
  private float elapsedTime;
  private float mixLevel;
  private List<PVector> rightPoints;
  private List<PVector> leftPoints;

  NaturalAngleSpiralVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, 0, #ffffff);
  }
 
  boolean isDrawable() {
    return getState() == VisualizingState.Processing;
  }
  
  private List<PVector> calcPoints(float level, float angleStep) {
    float len = (height / 2) / 20;
    float angle = angleStep < 0 ? PI : 0;
    List<PVector> points = new ArrayList<PVector>();
    for (int count = 0; count < 100; ++count) {
      points.add(new PVector(len * cos(angle), len * sin(angle)));
      len *= (1 + level);
      angle += angleStep;
    }
    return points;
  }
  private void drawPoints(List<PVector> points) {
    beginShape();
    for (PVector p: points) {
      curveVertex(p.x, p.y);
    }
    endShape();
  }
  
  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      initBackground();
      if (startMillis == 0) {
        startMillis = System.currentTimeMillis();
      }
    }
    rightLevel = provider.getRightLevel();
    leftLevel = provider.getLeftLevel();
    mixLevel = provider.getMixLevel();
    
    elapsedTime = provider.getElapsedTimeAsQuantityMillis();
    
    rightPoints = calcPoints(rightLevel,TWO_PI / 2.6181); 
    leftPoints = calcPoints(leftLevel,-(TWO_PI / 2.6181));
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);
    noFill();
    strokeWeight(getScaledValue(2));
    curveTightness(-1);

    pushMatrix();
    translate(width / 4 * 3, height / 2);
    rotate(-elapsedTime);
    stroke(hue(fgColor), 100 - (100 * rightLevel), brightness(fgColor), 5 + 95 * (rightLevel * 5));
    drawPoints(rightPoints);
    popMatrix();
    pushMatrix();
    translate(width / 4, height / 2);
    rotate(elapsedTime);
    stroke(hue(fgColor), 100 - (100 * leftLevel), brightness(fgColor), 5 + 95 * (leftLevel * 5));
    drawPoints(leftPoints);
    popMatrix();
  }
}

final class BluringBoxesVisualizer extends Visualizer {
  private final List<Float> rightLevels = new ArrayList<Float>();
  private final List<Float> leftLevels = new ArrayList<Float>();

  private float saturation = 0;
  private float boxScale = 0;
  private float ns = -1;

  BluringBoxesVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);
  }

  protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      if (ns < 0) {
        final int tempo = (int)provider.getBeatPerMinute();
        randomSeed(tempo);
        ns = random(tempo);
      }

      initBackground();
    }
    clear();
    if (getState() != VisualizingState.Expired) {
      if (provider.beatDetector.isKick()) {
        saturation = 99;
      } else {
        saturation = saturation * 0.8;
      }
      if (provider.beatDetector.isHat()) {
        boxScale = 1.0;
      } else {
        boxScale = boxScale * 0.8;
      }

      final int maxSpec = provider.rightFft.specSize() / 2;
      if (rightLevels.isEmpty()) {
        for (int index = 0; index < maxSpec; ++index) {
          rightLevels.add(provider.rightFft.getBand(index));
          leftLevels.add(provider.leftFft.getBand(index));
        }
      }
      else {
        for (int index = 0; index < maxSpec; ++index) {
          rightLevels.set(index, (provider.rightFft.getBand(index) - rightLevels.get(index)) * 0.1);
          leftLevels.set(index, (provider.leftFft.getBand(index) - leftLevels.get(index)) * 0.1);
        }
      }
    }
    else {
      saturation = saturation * 0.8;
      boxScale = boxScale * 0.8;
    }
  }

  void clear() {
    rightLevels.clear();
    leftLevels.clear();
  }
  boolean isDrawable() {
    return 0.1 <= saturation;
  }

  private void drawLevels(List<Float> levels, boolean asLeft) {
    final float r = TWO_PI * noise(ns);
    for (int index = 0; index < levels.size(); ++index) {
      final int level = (int)Math.ceil(levels.get(index) * (width / 50));
      final int y = (int)map(index, 0, levels.size(), 0, height / 2);

      float nsHue = random(asLeft ? provider.player.left.level() : provider.player.right.level());

      pushMatrix();
      rotate(r);
      final float boxSize = height / 5.0 * (exp(-(1.0 - boxScale)));
      float h = hue(fgColor) + ((noise(nsHue) * 180) - 90);
      if (h < 0) {
        h += 360;
      }
      else if (359 <= h) {
        h -= 359;
      }
      final int xUnit = width / 50;
      for (int x = 0; x < level && x < (width / 2) + (xUnit * 2); x += xUnit) {
        stroke(color(h, 99 - saturation, brightness(fgColor), 33));
        final int drawY = (int)Math.ceil(height / 2 * noise(x / 100.0, y / 100.0, ns));
        pushMatrix();
        translate(x * (asLeft ? -1 : 1), drawY % 2 == 0 ? drawY : -drawY);
        rotateX(r);
        rotateY(r);
        box(boxSize);
        popMatrix();

        nsHue += 0.1;
      }
      popMatrix();
    }
  }

  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);

    translate(width / 2, height / 2);

    strokeWeight(getScaledValue(2));
    noFill();

    drawLevels(rightLevels, false);
    drawLevels(leftLevels, true);
    ns += 0.01;
  }
}