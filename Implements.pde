import java.util.AbstractMap.SimpleEntry;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.LinkedList;
import java.util.List;
import java.util.Scanner;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.regex.MatchResult;
import java.time.format.DateTimeFormatter;
import java.time.LocalTime;
import ddf.minim.AudioPlayer;
import ddf.minim.Minim;
import ddf.minim.analysis.BeatDetect;
import ddf.minim.analysis.FFT;
import spout.Spout;

final VisualizerManager visualizerManager = new VisualizerManager();

JSONObject setting;
boolean standby;
String senderName;
Spout spout;
List<SceneInfo> scenes = new ArrayList<SceneInfo>();

float screenScale;
FrameRecorderType recorderType;
FrameRecorder recorder;

MusicDataProvider provider;
int currentSceneIndex = 0;
int frameDropCount = 0;

boolean repeatPlayback() {
  return setting.getBoolean("repeat");
}
float getFramePerSecond() {
  return setting.getFloat("framePerSecond");
}
float getSecondPerFrame() {
  return (float)1.0 / getFramePerSecond();
}
int getShortSideLen() {
  return min(width, height); 
}
float getScaledValue(float source) {
    return source * screenScale;
}
SceneInfo getCurrentScene() {
  return scenes.get(currentSceneIndex); 
}
MusicDataProvider getMusicDataProvider() {
  return provider;
}

private JSONObject loadSetting() {
  setting = loadJSONObject("setting.json");
  JSONObject connectionInfo = setting.getJSONObject("connectionInfo");
  if (connectionInfo != null) {
    JSONObject outInfo = connectionInfo.getJSONObject("out");
    if (outInfo != null) {
      senderName = outInfo.getString("name", null);
    }
  }
  
  JSONArray sceneObjects = setting.getJSONArray("scenes");
  for (int index = 0; index < sceneObjects.size(); ++index) {
    scenes.add(new SceneInfo(sceneObjects.getJSONObject(index)));
  }    
  return setting;
}

private void playNewSound() {
  SceneInfo scene = scenes.get(currentSceneIndex); 
  provider = new MusicDataProvider(this, scene.soundInfo.filePath, scene.soundInfo.beatPerMinute, scene.soundInfo.beatPerBar);
  visualizerManager.setUpVisualizers(scene);
  provider.play();
}

private void tearDown() {
  if (provider != null) {
    provider.stop();
  }
  if (recorder != null) {
    recorder.finish();
    recorder = null;
  }
}
