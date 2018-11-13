// if you want to use <a href="https://www.funprogramming.org/VideoExport-for-Processing/">Video Export</a>,
// delete comment after this comment.
//import com.hamoid.*;

interface FrameRecorder {
  abstract void recordFrame();
  abstract void finish();
}

final class SyncFrameRecorder implements FrameRecorder {
  private final String frameFormat;
  SyncFrameRecorder(String ext) {
    frameFormat = "img/########." + ext;
  }

  void recordFrame() {
    saveFrame(frameFormat);
  }
  
  void finish() {
  } 
}

final class AsyncFrameRecorder implements FrameRecorder {
  private final ExecutorService executor = Executors.newCachedThreadPool();
  private final List<Future> futures = new ArrayList<Future>();
  
  AsyncFrameRecorder() {
  }

  void recordFrame() {
    if (executor.isShutdown()) {
      return;
    }

    loadPixels();

    final int[] savePixels = Arrays.copyOf(pixels, pixels.length);
    final long saveFrameCount = frameCount;
    Runnable saveTask = new Runnable() {
      public void run() {
        final PImage frameImage = createImage(width, height, HSB);
        frameImage.pixels = savePixels;
        frameImage.save(String.format("img/%08d.jpg", saveFrameCount));
      }
    };
    
    Iterator<Future> it = futures.iterator();
    while (it.hasNext()) {
      final Future f = it.next();
      if (f.isDone()) {
        it.remove();
      }
    }
    futures.add(executor.submit(saveTask));
  }
  
  void finish() {
    try {
      Thread.sleep(1000);
    }
    catch (InterruptedException e) {
    }
    
    for (Future f : futures) {
      if (f.isDone() == false && f.isCancelled() == false) {
        try {
          f.get();
        }
        catch (InterruptedException e) {
        }
        catch (ExecutionException e) {
        }
      }
    }
    if (executor.isShutdown() == false) {
      executor.shutdown();
      try {
        if (executor.awaitTermination(5, TimeUnit.SECONDS) == false) {
          executor.shutdownNow();
          executor.awaitTermination(5, TimeUnit.SECONDS);
        }
      }
      catch (InterruptedException e) {
        executor.shutdownNow();
      }
    }
  }
}

/*
final class VideoExportRecorder extends FrameRecorder {
  private final VideoExport videoExport;
  
  VideoExportRecorder(PApplet applet) {
    videoExport = new VideoExport(applet, "movie.mp4");
    videoExport.startMovie();
  }

  void recordFrame() {
    videoExport.saveFrame();
  }
  
  void finish() {
    videoExport.endMovie();
  }
}
 */

enum FrameRecorderType {
  //VideoExportRecorder,
  SyncTgaRecorder,
  SyncPngRecorder,
  AsyncRecorder
}

FrameRecorder createFrameRecorderInstanceOf(FrameRecorderType type) {
  switch (type) {
    /*
    case VideoExportRecorder:
      return new VideoExportRecorder(this);
     */
    case SyncTgaRecorder:
      return new SyncFrameRecorder("tga");
    case SyncPngRecorder:
      return new SyncFrameRecorder("png");
    case AsyncRecorder:
      return new AsyncFrameRecorder();
    default:
      throw new RuntimeException();
  }
}
