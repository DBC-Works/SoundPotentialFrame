void setup() {
  //size(640, 360, P3D);
  //size(960, 540, P3D);
  size(1280, 720, P3D);

  screenScale = width / 1280.0;

  loadSetting();
  println("ms per frame: " + (getSecondPerFrame() * 1000) + "ms");
  frameRate(getFramePerSecond());
  smooth();

  if(senderName != null && 0 < senderName.length()) { 
    println("initialize spout...");
    spout = new Spout(this);
    if (spout.createSender(senderName, width, height) == false) {
      println("warning: fail to create spout");
      spout = null;
    }
  }

  // recorderType: frame recorder type
  recorderType = null;
  String recordImageType = setting.getString("recordImageType");
  if (recordImageType != null) {
    recordImageType = recordImageType.toLowerCase();
    if (recordImageType.equals("jpeg") || recordImageType.equals("jpg")) {
      recorderType = FrameRecorderType.AsyncRecorder;
    }
    else if (recordImageType.equals("tga")) {
      recorderType = FrameRecorderType.SyncTgaRecorder;
    }
    else if (recordImageType.equals("png")) {
      recorderType = FrameRecorderType.SyncPngRecorder;
    }
  }

  if (recorderType != null) {
    recorder = createFrameRecorderInstanceOf(recorderType);
  }

  standby = setting.getBoolean("waitForStart");
  if (standby == false) {
    playNewSound();
  }
}

void draw() {
  if (standby) {
    colorMode(HSB, 360, 0, 0, 0);
    background(360 * sin(map(frameCount % (frameRate * 8), 0, frameRate * 8, -PI, PI)));
    return;
  }

  final long startTime = System.currentTimeMillis();
  if (provider.player.isPlaying() == false && provider.atLast()) {
    ++currentSceneIndex;
    if (scenes.size() <= currentSceneIndex) {
      if (repeatPlayback() == false) {
        if (provider != null) {
          provider.stop();
        }
        if (recorder != null) {
          recorder.finish();
          recorder = null;
        }
        if (0 < frameDropCount) {
          println("Frame drop count: " + frameDropCount + " / " + frameCount + "(" + (frameDropCount * 100.0 / frameCount) + ")");
        }
        tearDown();
        exit();
        return;
      }
      currentSceneIndex = 0;
    }
    playNewSound();
  }
  
  provider.update();
  visualizerManager.visualize();
  
  if (recorder != null) {
    recorder.recordFrame();
  }

  long timeTaken = System.currentTimeMillis() - startTime;
  if (((1.0 / frameRate) * 1000) < timeTaken) {
    println("Overtime: " + timeTaken + "ms(" + frameCount + ")");
    ++frameDropCount;
  }

  if (spout != null) {
    spout.sendTexture();
  }
}

void keyReleased( ){
  if (key == CODED) {
    switch (keyCode) {
      case 5:  // PrtSc
        saveFrame("scene-########.png");
        break;
      case ' ':
        if (standby) {
          standby = false;
          playNewSound();
        }
        else {
          if (provider.player.isPlaying()) {
            provider.pause();
          }
          else if (provider.atLast() == false) {
            provider.play();
          }
        }
        break;
      case ALT:
        break;
    }
  }
  else {
    switch (key) {
      case DELETE:
        visualizerManager.clear();
        break;
    }
  }
}
