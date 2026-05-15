/*
 * Rx — TCP frame receiver
 *
 * Opens a TCP server on port 5005 and waits for a Tx transmitter to
 * connect. After the "RGB_STREAM_V1" handshake (which establishes the
 * stream dimensions), incoming frames of raw RGB bytes are read in a
 * background thread. The latest frame is exposed as a PImage in a
 * thread-safe way via getImage(). Only one transmitter is accepted at
 * a time; any additional connection attempts are rejected until the
 * active client disconnects.
 *
 * Author: Tiago Martins — CDV Lab (cdv.dei.uc.pt)
 * Year: 2025-2026
 */

import java.net.*;
import java.io.*;

class Rx {
  private final PApplet parent;
  private final int port;

  private ServerSocket serverSocket;
  private volatile boolean running = true;
  private volatile boolean clientActive = false;

  private PImage receivedImage;
  private byte[] latestFrameBytes = null;
  private boolean hasNewFrame = false;
  private int streamWidth = 0;
  private int streamHeight = 0;

  private final Object frameLock = new Object();
  private final Object clientLock = new Object();

  Rx(PApplet parent) {
    this(parent, 5005);
  }

  Rx(PApplet parent, int port) {
    this.parent = parent;
    this.port = port;
  }

  void start() {
    Thread serverThread = new Thread(new Runnable() {
      public void run() {
        runServer();
      }
    }
    );
    serverThread.start();
  }

  void stop() {
    running = false;
    try {
      if (serverSocket != null) {
        serverSocket.close();
      }
    }
    catch (Exception e) {
    }
  }

  PImage getImage() {
    updateLatestFrame();
    return receivedImage;
  }

  boolean isClientActive() {
    return clientActive;
  }

  private void updateLatestFrame() {
    byte[] frameToDraw = null;

    synchronized (frameLock) {
      if (hasNewFrame && latestFrameBytes != null) {
        frameToDraw = latestFrameBytes;
        hasNewFrame = false;
      }
    }

    if (frameToDraw == null || receivedImage == null) {
      return;
    }

    receivedImage.loadPixels();

    int bufferIndex = 0;

    for (int i = 0; i < receivedImage.pixels.length; i++) {
      int r = frameToDraw[bufferIndex++] & 0xFF;
      int g = frameToDraw[bufferIndex++] & 0xFF;
      int b = frameToDraw[bufferIndex++] & 0xFF;
      receivedImage.pixels[i] = parent.color(r, g, b);
    }

    receivedImage.updatePixels();
  }

  private void runServer() {
    try {
      serverSocket = new ServerSocket(port);
      //println("RX listening on port " + port);

      while (running) {
        Socket clientSocket = serverSocket.accept();
        clientSocket.setTcpNoDelay(true);

        synchronized (clientLock) {
          if (clientActive) {
            rejectClient(clientSocket);
            continue;
          }
          clientActive = true;
        }

        Thread clientThread = new Thread(new Runnable() {
          public void run() {
            handleClient(clientSocket);
          }
        }
        );

        clientThread.start();
      }
    }
    catch (Exception e) {
      if (running) {
        //println("Server error.");
      }
    }
  }

  private void rejectClient(Socket clientSocket) {
    try {
      //println("Rejected TX because another TX is already connected.");
      DataOutputStream rejectOut = new DataOutputStream(
        new BufferedOutputStream(clientSocket.getOutputStream())
        );
      rejectOut.writeByte(0);
      rejectOut.flush();
      rejectOut.close();
      clientSocket.close();
    }
    catch (Exception e) {
      try {
        clientSocket.close();
      }
      catch (Exception ignored) {
      }
    }
  }

  private void handleClient(Socket clientSocket) {
    DataInputStream in = null;
    DataOutputStream out = null;

    try {
      //println("TX attempting handshake...");
      in = new DataInputStream(new BufferedInputStream(clientSocket.getInputStream()));
      out = new DataOutputStream(new BufferedOutputStream(clientSocket.getOutputStream()));

      String magic = in.readUTF();
      if (!magic.equals("RGB_STREAM_V1")) {
        //println("Invalid TX protocol.");
        out.writeByte(0);
        out.flush();
        return;
      }

      int incomingWidth = in.readInt();
      int incomingHeight = in.readInt();
      if (incomingWidth <= 0 || incomingHeight <= 0) {
        //println("Invalid stream size.");
        out.writeByte(0);
        out.flush();
        return;
      }

      streamWidth = incomingWidth;
      streamHeight = incomingHeight;

      synchronized (frameLock) {
        latestFrameBytes = new byte[streamWidth * streamHeight * 3];
        hasNewFrame = false;
      }
      
      int pdPrev = parent.pixelDensity;
      receivedImage = parent.createImage(streamWidth, streamHeight, RGB);
      pixelDensity(pdPrev);

      out.writeByte(1);
      out.flush();
      //println("Accepted TX: " + streamWidth + " x " + streamHeight);

      int expectedFrameSize = streamWidth * streamHeight * 3;
      while (running) {
        int frameSize = in.readInt();
        if (frameSize != expectedFrameSize) {
          //println("Invalid frame size. Closing TX connection.");
          break;
        }

        byte[] frame = new byte[expectedFrameSize];
        in.readFully(frame);

        synchronized (frameLock) {
          latestFrameBytes = frame;
          hasNewFrame = true;
        }
      }
    }
    catch (Exception e) {
      //println("TX disconnected.");
    }
    finally {
      try {
        if (in != null) in.close();
      }
      catch (Exception e) {
      }

      try {
        if (out != null) out.close();
      }
      catch (Exception e) {
      }

      try {
        clientSocket.close();
      }
      catch (Exception e) {
      }

      synchronized (clientLock) {
        clientActive = false;
      }

      //println("RX ready for another TX.");
    }
  }
}

void stop() {
  if (rx != null) {
    rx.stop();
  }
  super.stop();
}
