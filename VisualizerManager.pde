 
final class SoundInfo {
  final String filePath;
  final float beatPerMinute;
  final float beatPerBar;

  SoundInfo(String path, float bpm, float bpb) {
    filePath = path;
    beatPerMinute = bpm;
    beatPerBar = bpb;
  }
}

final class VisualizationInfo {
  final String fgColor;
  final String background;
  final int blendMode;
  final String start;
  final String end;
  final String len;
  final JSONObject options;

  VisualizationInfo(
    String fg,
    String bg,
    String blendModeName,
    String st,
    String e,
    String l,
    JSONObject opt
  ) {
    fgColor = fg;
    background = bg;
    switch (blendModeName.toUpperCase()) {
      case "NORMAL":
        blendMode = NORMAL;
        break;
      case "ADD":
        blendMode = ADD;
        break;
      case "SUBTRACT":
        blendMode = SUBTRACT;
        break;
      case "DARKEST": 
        blendMode = DARKEST;
        break;
      case "LIGHTEST": 
        blendMode = LIGHTEST;
        break;
      case "DIFFERENCE": 
        blendMode = DIFFERENCE;
        break;
      case "EXCLUSION":
        blendMode = EXCLUSION;
        break;
      case "MULTIPLY": 
        blendMode = MULTIPLY;
        break;
      case "SCREEN": 
        blendMode = SCREEN;
        break;
      case "REPLACE":
        blendMode = REPLACE;
        break;
      default:
        blendMode = NORMAL;
        break;
    }
    start = st;
    end = e;
    len = l;
    options = opt;
  }
}

final class SceneInfo {
  final SoundInfo soundInfo;
  final List<SimpleEntry<String, VisualizationInfo>> visualizations = new ArrayList<SimpleEntry<String, VisualizationInfo>>();

  SceneInfo(JSONObject scene) {
    JSONObject soundObject = scene.getJSONObject("sound");
    soundInfo = new SoundInfo(soundObject.getString("filePath"),
                              soundObject.getFloat("beatPerMinute", Float.MIN_VALUE),
                              soundObject.getFloat("beatPerBar", 4));

    String fgColor = null;
    String bg = null;
    String blend = null;
    JSONArray v = scene.getJSONArray("visualizations");
    for (int index = 0; index < v.size(); ++index) {
      JSONObject info = v.getJSONObject(index);
      fgColor = info.getString("foreground", fgColor);
      bg = info.getString("background", bg);
      blend = info.getString("blendMode", blend);
      String visualizerName = info.getString("visualizer");
      VisualizationInfo vi = new VisualizationInfo(
        fgColor,
        bg,
        blend,
        info.getString("start", null),
        info.getString("end", null),
        info.getString("length", null),
        info.getJSONObject("options")
      );
      visualizations.add(new SimpleEntry(visualizerName, vi));
    }    
  }
}

abstract class Visualizer {
  final long startTimeMillis;
  final long endTimeMillis;

  protected final VisualizationInfo visualizationInfo;
  protected final color fgColor;
  protected final color bgColor;
  private final PImage backgroundImage;

  protected Visualizer(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis, color defaultForegroundColor, color defaultBackgroundColor) {
    visualizationInfo = info;
    
    MusicDataProvider provider = getMusicDataProvider();
    long start;
    if (info.start != null && 0 < info.start.length()) {
      start = firstTimeMillis + provider.calcLengthMillis(info.start);
    }
    else {
      start = lastTimeMillis;
    }
    startTimeMillis = start - (long)(getSecondPerFrame() * 1000);
    if (info.len != null && 0 < info.len.length()) {
      endTimeMillis = startTimeMillis + provider.calcLengthMillis(info.len);
    }
    else if (info.end != null && 0 < info.end.length()) {
      endTimeMillis = firstTimeMillis + provider.calcLengthMillis(info.end);
    }
    else {
      endTimeMillis = startTimeMillis + provider.player.length();
    }
    
    fgColor = info.fgColor != null ? decodeColor(info.fgColor) : defaultForegroundColor;
    if (info.background != null && 0 < info.background.length()) {
      if (info.background.startsWith("#")) {
        bgColor = decodeColor(info.background);
        backgroundImage = null; 
      }
      else {
        bgColor = defaultBackgroundColor;
        backgroundImage = loadImage(info.background); 
      }
    }
    else {
      bgColor = defaultBackgroundColor;
      backgroundImage = null; 
    }
  }
  final boolean expired(long curMillis) {
    return endTimeMillis <= curMillis;
  }
  final Visualizer prepare(boolean isPrimary, boolean expired) {
    doPrepare(getMusicDataProvider(), isPrimary, expired);
    return this;
  }
  final Visualizer visualize() {
    if (isDrawable()) {
      pushMatrix();
      blendMode(visualizationInfo.blendMode);
      doVisualize();
      popMatrix();
    }
    return this;
  }

  protected final float getProgressPercentage() {
    return (System.currentTimeMillis() - startTimeMillis) / (float)(endTimeMillis - startTimeMillis);
  }
  protected final void initBackground() { 
    if (backgroundImage != null) {
      background(0);
      image(backgroundImage, 0, 0, width, height);
    }
    else {
      background(bgColor);
    }
  }
  protected final void drawVertex(List<PVector> positions) { 
    beginShape(LINES);
    for (PVector pos: positions) {
      vertex(pos.x, pos.y);
    }
    endShape();
  }

  private color decodeColor(String nm) {
    final int c = Integer.decode(nm); 
    return nm.startsWith("#0000") && c < 256 ? color(0, 0, c) : color(c);
  }

  void clear() {
  }
  abstract boolean isDrawable();

  protected abstract void doPrepare(MusicDataProvider provider, boolean isPrimary, boolean expired);
  protected abstract void doVisualize();
}

interface VisualizerFactory {
  Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis);
}

final class VisualizerManager {
  private final List<Visualizer> visualizers = new LinkedList<Visualizer>();
  private final Map<String, VisualizerFactory> factories;

  VisualizerManager() {
    factories = new HashMap<String, VisualizerFactory>() {
      {
        // Shape
        put("Ellipse rotation", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new EllipseRotationVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        // Drawing
        put("Noise steering line", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new NoiseSteeringLineVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Noise steering curve line", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new NoiseSteeringCurveLineVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Level trace", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new LevelTraceVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Blurring arc", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new BlurringArcVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        // Level
        put("Beat circle and frequency level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new BeatCircleAndFreqLevelVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Beat circle and octaved frequency level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new BeatCircleAndOctavedFreqLevelVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Popping level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new PoppingLevelVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Spread octagon level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new SpreadOctagonVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Triple regular octahedron", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new TripleRegularOctahedronVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        put("Facing levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new FacingLevelsVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Fake laser light style levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new FakeLaserLightStyleLevelsVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
        put("Beat arc levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new BeatArcLevelsVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        put("Natural angle spiral", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new NaturalAngleSpiralVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        put("Particle fountain", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new ParticleFountainVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });

        put("Lissajous", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long firstTimeMillis, long lastTimeMillis) {
            return new LissajousVisualizer(info, firstTimeMillis, lastTimeMillis);
          }
        });
      }
    };
  }

  void setUpVisualizers(SceneInfo info) {
    final long startTimeMillis = System.currentTimeMillis();
    long endTimeMillis = startTimeMillis;
    final List<Visualizer> setUpVisualizers = new ArrayList<Visualizer>();
    for (SimpleEntry<String, VisualizationInfo> visualization : info.visualizations) {
      final String visualizerName = visualization.getKey(); 
      if (factories.containsKey(visualizerName)) {
        Visualizer v = factories.get(visualizerName).create(visualization.getValue(), startTimeMillis, endTimeMillis);
        setUpVisualizers.add(v);
        if (endTimeMillis < v.endTimeMillis) {
          endTimeMillis = v.endTimeMillis;
        }
      }
    }
    Collections.sort(setUpVisualizers, new Comparator<Visualizer>() {
      public int compare(Visualizer lhs, Visualizer rhs) {
        long timeDiff = lhs.startTimeMillis - rhs.startTimeMillis;
        if (timeDiff == 0) {
          timeDiff = lhs.endTimeMillis - rhs.endTimeMillis;
        }
        return (int)timeDiff;
      }
    });
    visualizers.addAll(0, setUpVisualizers);
  }
  void visualize() {
    final long curMillis = System.currentTimeMillis();

    boolean primary = true;
    final Iterator it = visualizers.iterator();
    while (it.hasNext()) {
      Visualizer visualizer = (Visualizer)it.next();
      final boolean expired = visualizer.expired(curMillis); 
      if (expired && visualizer.isDrawable() == false) {
        it.remove();
      }
      if (visualizer.startTimeMillis <= curMillis) {
        visualizer.prepare(primary, expired);
        primary = false;
        if (visualizer.isDrawable()) {
          visualizer.visualize();
        }
      }
    }
  }
  void clear() {
    for (Visualizer visualizer : visualizers) {
      visualizer.clear();
    }
  }
}
