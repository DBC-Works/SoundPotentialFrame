
class SoundDataProvider {
  final AudioPlayer player;
  final FFT rightFft;
  final FFT leftFft;

  private final Minim minim;

  SoundDataProvider(PApplet applet, String filePath) {
    minim = new Minim(applet);
    player = minim.loadFile(filePath, 1024);
    rightFft = new FFT(player.bufferSize(), player.sampleRate());
    leftFft = new FFT(player.bufferSize(), player.sampleRate());
    rightFft.window(FFT.HAMMING);
    leftFft.window(FFT.HAMMING);
  }
  final float getMixLevel() {
    return player.mix.level();
  }
  final float getRightLevel() {
    return player.right.level();
  }
  final float getLeftLevel() {
    return player.left.level();
  }
  final boolean atLast() {
    return player != null && (player.length() - player.position()) < 10;
  }
  final float getProgressPercentage() {
    return player.position() / (float)player.length();
  }
  final SoundDataProvider play() {
    if (player != null) {
      player.play();
    }
    return this;
  }
  final SoundDataProvider pause() {
    if (player != null) {
      player.pause();
    }
    return this;
  }
  final SoundDataProvider stop() {
    if (player != null) {
      player.close();
    }
    if (minim != null) {
      minim.stop();
    }
    return this;
  }
  final SoundDataProvider update() {
    rightFft.forward(player.right);
    leftFft.forward(player.left);
    doUpdate();
    return this;
  }

  protected void doUpdate() {
  }
}

final class OctavedLevels {
  final List< List< Float > > rightLevels;
  final List< List< Float > > leftLevels;
    
  OctavedLevels(List< List< Float > > right, List< List< Float > > left) {
    rightLevels = right;
    leftLevels = left;
  }
}

final class MusicDataProvider extends SoundDataProvider {
  private float beatPerMinute;
  private float beatPerBar;
  private final BeatDetect beatDetector;
  
  MusicDataProvider(PApplet applet, String filePath, float bpm, float bpb) {
    super(applet, filePath);
    
    beatPerMinute = bpm;
    beatPerBar = bpb;
    beatDetector = new BeatDetect();
    beatDetector.detectMode(BeatDetect.FREQ_ENERGY);
  }

  float getBeatPerMinute() {
    return beatPerMinute;
  }
  float getCrotchetQuantityMillis() {
    return 60000.0 / beatPerMinute;
  }
  float getBarLengthMillis() {
    return getCrotchetQuantityMillis() * beatPerBar;
  }
  float getElapsedTimeMillis() {
    return player.position();
  }
  float getElapsedTimeAsQuantityMillis() {
    return getElapsedTimeMillis() / getCrotchetQuantityMillis();
  }
  OctavedLevels getOctavedLevels() {
    List< List< Float > > rightLevels = new ArrayList< List< Float > >();
    List< List< Float > > leftLevels = new ArrayList< List< Float > >();
    
    float maxFreq = rightFft.indexToFreq(rightFft.specSize() - 1);
    float beginFreq = 0;
    float endFreq = 27.5;
    while (endFreq < maxFreq) {
      rightLevels.add(getLevelsInRange(beginFreq, endFreq, rightFft));
      leftLevels.add(getLevelsInRange(beginFreq, endFreq, leftFft));
      
      beginFreq = endFreq;
      endFreq = endFreq * 2;
    }
    return new OctavedLevels(rightLevels, leftLevels);
  }
  long calcLengthMillis(String literal) {
    long len = player.length();
    
    if (literal.endsWith("%")) {
      len = (long)((len * Float.parseFloat(literal.substring(0, literal.length() - 1))) / 100);
    }
    else if (literal.contains(":")) {
      len = LocalTime.parse(literal, DateTimeFormatter.ISO_LOCAL_TIME).toNanoOfDay() / 1000000;
    }
    else {
      Scanner scanner = null;
      MatchResult result = null;
      try {
        scanner = new Scanner(literal);
        scanner.findInLine("([\\d\\.]+)bar([\\d\\.]+)beat"); 
        result = scanner.match();
      }
      finally {
        if (scanner != null) {
          scanner.close();
        }
      }
      if (result.groupCount() == 2) {
        final float bars = Float.parseFloat(result.group(1));
        final float beats = Float.parseFloat(result.group(2));
        len = (long)(((bars - 1) * getBarLengthMillis()) + ((beats - 1) * getCrotchetQuantityMillis()));
      }
    }
    return len;
  }
  MusicDataProvider setBeatPerMinute(float bpm) {
    beatPerMinute = bpm;
    return this;
  }

  private List<Float> getLevelsInRange(float beginFreq, float endFreq, FFT fft) {
      List<Float> levels = new ArrayList<Float>();
      for (int index = fft.freqToIndex(beginFreq); index < fft.freqToIndex(endFreq); ++index) {
        levels.add(fft.getBand(index));
      }
      return levels;
  }

  protected void doUpdate() {
    beatDetector.detect(player.mix);
  }
}  
