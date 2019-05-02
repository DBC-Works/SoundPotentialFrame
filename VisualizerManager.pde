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
  final String weight;
  final String start;
  final String end;
  final String len;
  final JSONArray filters;
  final JSONObject options;

  VisualizationInfo(
    String fg,
    String bg,
    String blendModeName,
    String sw,
    String st,
    String e,
    String l,
    JSONArray flt,
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
    weight = sw;
    start = st;
    end = e;
    len = l;
    filters = flt;
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
        info.getString("weight", null),
        info.getString("start", null),
        info.getString("end", null),
        info.getString("length", null),
        info.getJSONArray("filters"),
        info.getJSONObject("options")
      );
      visualizations.add(new SimpleEntry(visualizerName, vi));
    }    
  }
}

enum VisualizingState {
  Idle,
  Processing,
  Expired
}

abstract class Visualizer {
  final long startTimeMillis;
  final long endTimeMillis;

  protected final VisualizationInfo visualizationInfo;
  protected final color fgColor;
  protected final color bgColor;
  protected final float weight;

  private final PImage backgroundImage;
  private final List< PShader > filterShaders = new ArrayList< PShader >();
  private VisualizingState state = VisualizingState.Idle;

  protected Visualizer(VisualizationInfo info, long lastTimeMillis, color defaultForegroundColor, color defaultBackgroundColor) {
    visualizationInfo = info;

    weight = info.weight != null && 0 < info.weight.length() ? Float.parseFloat(info.weight) : -1;

    MusicDataProvider provider = getMusicDataProvider();
    long start;
    if (info.start != null && 0 < info.start.length()) {
      start = provider.calcLengthMillis(info.start);
    }
    else {
      start = lastTimeMillis;
    }
    startTimeMillis = start - (long)(getSecondPerFrame() * 1000);
    if (info.len != null && 0 < info.len.length()) {
      endTimeMillis = start + provider.calcLengthMillis(info.len);
    }
    else if (info.end != null && 0 < info.end.length()) {
      endTimeMillis = provider.calcLengthMillis(info.end);
    }
    else {
      endTimeMillis = start + provider.player.length();
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

    if (info.filters != null) {
      for (int index = 0; index < info.filters.size(); ++index) {
        String name = info.filters.getString(0, null);
        if (name != null) {
          PShader shader = loadShader(name);
          shader.set("u_size", width, height);
          filterShaders.add(shader);
        }
      }
    }
  }
  final protected float getStrokeWeight(float defaultWeight) {
    return getScaledValue(0 <= weight ? weight : defaultWeight);
  }
  final protected VisualizingState getState() {
    return state;
  }
  final VisualizingState updateState(long curMillis) {
    if (curMillis < startTimeMillis) {
      state = VisualizingState.Idle;
    }
    else if (endTimeMillis <= curMillis) {
      state = VisualizingState.Expired;
    }
    else {
      state = VisualizingState.Processing;
    }
    return state;
  }
  final Visualizer prepare(boolean isPrimary) {
    doPrepare(getMusicDataProvider(), isPrimary);
    return this;
  }
  final Visualizer setStrokeWeight(float defaultWeight) {
    strokeWeight(getStrokeWeight(defaultWeight));
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
  final Visualizer applyFilter() {
    for (PShader shader : filterShaders) {
      filter(shader);
    }
    return this;
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
    String clr = nm;
    String alpha = "FF";
    if (clr.length() == 9) {
      clr = nm.substring(0, 7);
      alpha = nm.substring(7);
    }
    final int c = Integer.decode(clr); 
    final int a = Integer.parseInt(alpha, 16); 
    return clr.startsWith("#0000") && c < 256
          ? color(0, 0, c, a)
          : color(red(c), green(c), blue(c), a);
  }

  void clear() {
  }
  abstract boolean isDrawable();

  protected abstract void doPrepare(MusicDataProvider provider, boolean isPrimary);
  protected abstract void doVisualize();
}

final class TextVisualizer extends Visualizer {
  private final String fontFace;
  private final float size;
  private final float x;
  private final float y;
  private final String text;
  private final PFont font;

  TextVisualizer(VisualizationInfo info, long lastTimeMillis) {
    super(info, lastTimeMillis, #ffffff, 0);

    fontFace = info.options.getString("fontFace", null);
    size = info.options.getFloat("size", 0.5);
    x = info.options.getFloat("x", 0.5);
    y = info.options.getFloat("y", 0.5);
    text = info.options.getString("text", "");

    font = createFont(fontFace, getScaledValue(size));
  }

  final boolean isDrawable() {
    return getState() == VisualizingState.Processing;
  }

  final protected void doPrepare(MusicDataProvider provider, boolean isPrimary) {
    if (isPrimary) {
      initBackground();
    }
  }
  protected void doVisualize() {
    colorMode(HSB, 360, 100, 100, 100);

    final float h = hue(fgColor);
    final float s = saturation(fgColor);
    final float b = brightness(fgColor);
    final float a = alpha(fgColor);
    fill(color(h, s, b, 0 < a ? a : 99));

    translate(width / 2, height / 2);
    textFont(font);
    textAlign(CENTER, CENTER);
    text(text, (width / 2) * x, (height / 2) * y);
  }
}

interface VisualizerFactory {
  Visualizer create(VisualizationInfo info, long lastTimeMillis);
}

final class VisualizerManager {
  private final List<Visualizer> visualizers = new LinkedList<Visualizer>();
  private final Map<String, VisualizerFactory> factories;

  VisualizerManager() {
    factories = new HashMap<String, VisualizerFactory>() {
      {
        // Text
        put("Text", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new TextVisualizer(info, lastTimeMillis);
          }
        });

        // Shape
        put("Ellipse rotation", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new EllipseRotationVisualizer(info, lastTimeMillis);
          }
        });

        // Drawing
        put("Noise steering line", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new NoiseSteeringLineVisualizer(info, lastTimeMillis);
          }
        });
        put("Noise steering curve line", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new NoiseSteeringCurveLineVisualizer(info, lastTimeMillis);
          }
        });
        put("Level trace", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new LevelTraceVisualizer(info, lastTimeMillis);
          }
        });
        put("Blurring arc", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new BlurringArcVisualizer(info, lastTimeMillis);
          }
        });

        // Level
        put("Simple bar level meter", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new SimpleBarLevelMeterVisualizer(info, lastTimeMillis);
          }
        });
        put("Beat circle and frequency level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new BeatCircleAndFreqLevelVisualizer(info, lastTimeMillis);
          }
        });
        put("Beat circle and octaved frequency level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new BeatCircleAndOctavedFreqLevelVisualizer(info, lastTimeMillis);
          }
        });
        put("Popping level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new PoppingLevelVisualizer(info, lastTimeMillis);
          }
        });
        put("Spread octagon level", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new SpreadOctagonVisualizer(info, lastTimeMillis);
          }
        });
        put("Triple regular octahedron", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new TripleRegularOctahedronVisualizer(info, lastTimeMillis);
          }
        });

        put("Facing levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new FacingLevelsVisualizer(info, lastTimeMillis);
          }
        });
        put("Fake laser light style levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new FakeLaserLightStyleLevelsVisualizer(info, lastTimeMillis);
          }
        });
        put("Beat arc levels", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new BeatArcLevelsVisualizer(info, lastTimeMillis);
          }
        });

        put("Natural angle spiral", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new NaturalAngleSpiralVisualizer(info, lastTimeMillis);
          }
        });

        put("Particle fountain", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new ParticleFountainVisualizer(info, lastTimeMillis);
          }
        });

        put("Lissajous", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new LissajousVisualizer(info, lastTimeMillis);
          }
        });

        put("Bluring boxes", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new BluringBoxesVisualizer(info, lastTimeMillis);
          }
        });

        put("Twisted plate", new VisualizerFactory() {
          Visualizer create(VisualizationInfo info, long lastTimeMillis) {
            return new TwistedPlateVisualizer(info, lastTimeMillis);
          }
        });
      }
    };
  }

  void setUpVisualizers(SceneInfo info) {
    long endTimeMillis = 0;
    final List<Visualizer> setUpVisualizers = new ArrayList<Visualizer>();
    for (SimpleEntry<String, VisualizationInfo> visualization : info.visualizations) {
      final String visualizerName = visualization.getKey(); 
      if (factories.containsKey(visualizerName)) {
        Visualizer v = factories.get(visualizerName).create(visualization.getValue(), endTimeMillis);
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
    visualizers.clear();
    visualizers.addAll(0, setUpVisualizers);
  }
  void visualize() {
    final long curMillis = provider.player.position();

    boolean primary = true;
    final Iterator it = visualizers.iterator();
    while (it.hasNext()) {
      Visualizer visualizer = (Visualizer)it.next();
      boolean drawable = false;
      final VisualizingState state = visualizer.updateState(curMillis);
      if (state != VisualizingState.Idle) {
        visualizer.prepare(primary);
        drawable = visualizer.isDrawable();
        if (drawable) {
          visualizer.visualize();
        }
        if (primary || drawable) {
          visualizer.applyFilter();
        }
        primary = false;
      }
      if (state == VisualizingState.Expired && drawable == false) {
        it.remove();
      }
    }
  }
  void clear() {
    for (Visualizer visualizer : visualizers) {
      visualizer.clear();
    }
  }
}
