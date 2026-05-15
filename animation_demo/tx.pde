/*
 * Tx — Frame Transmitter (v1.0)
 *
 * Connects to an Rx receiver over TCP and sends each frame as raw RGB
 * bytes (3 bytes per pixel, no alpha). Before streaming begins, a
 * handshake exchanges the stream dimensions with the receiver.
 * If the connection is lost, the class retries automatically every second.
 * Images whose size differs from the declared stream size are resized
 * automatically before sending.
 *
 * Author: Tiago Martins — CDV Lab (cdv.dei.uc.pt)
 * Year: 2025-2026
 */

import java.net.*;
import java.io.*;

class Tx {

  private final String host;
  private final int port;
  private final int streamWidth;
  private final int streamHeight;

  private Socket socket;
  private DataOutputStream out;
  private DataInputStream in;

  private boolean connected = false;
  private long lastConnectAttempt = 0;
  private static final int RECONNECT_DELAY_MS = 1000;
  private static final int ACCEPTED = 1;

  private final byte[] rgbBuffer;

  Tx(int w, int h) {
    this("127.0.0.1", 5005, w, h);
  }

  Tx(String host, int port, int w, int h) {
    this.host = host;
    this.port = port;
    this.streamWidth = w;
    this.streamHeight = h;
    this.rgbBuffer = new byte[w * h * 3];
  }

  boolean isConnected() {
    return connected;
  }
  
  boolean send(PImage img) {
    if (!connected) tryReconnect();
    if (!connected) return false;

    PImage frame = img;
    if (img.width != streamWidth || img.height != streamHeight) {
      frame = img.copy();
      frame.resize(streamWidth, streamHeight);
    }

    try {
      frame.loadPixels();
      int idx = 0;
      for (int c : frame.pixels) {
        rgbBuffer[idx++] = (byte)((c >> 16) & 0xFF);
        rgbBuffer[idx++] = (byte)((c >>  8) & 0xFF);
        rgbBuffer[idx++] = (byte)(c & 0xFF);
      }
      out.writeInt(rgbBuffer.length);
      out.write(rgbBuffer);
      out.flush();
      return true;
    }
    catch (Exception e) {
      //println("Lost connection");
      closeConnection();
      return false;
    }
  }

  void dispose() {
    closeConnection();
  }

  private void tryReconnect() {
    long now = millis();
    if (now - lastConnectAttempt < RECONNECT_DELAY_MS) return;
    lastConnectAttempt = now;

    try {
      //println("Trying to connect to " + host + ":" + port + " ...");
      socket = new Socket();
      socket.connect(new InetSocketAddress(host, port), 1000);
      socket.setTcpNoDelay(true);
      socket.setSoTimeout(2000);

      out = new DataOutputStream(new BufferedOutputStream(socket.getOutputStream()));
      in  = new DataInputStream(new BufferedInputStream(socket.getInputStream()));

      out.writeUTF("RGB_STREAM_V1");
      out.writeInt(streamWidth);
      out.writeInt(streamHeight);
      out.flush();

      int response = in.readUnsignedByte();

      if (response == ACCEPTED) {
        connected = true;
        socket.setSoTimeout(0);
        //println("Connected");
      } else {
        //println("Connection rejected — another TX may already be connected.");
        closeConnection();
      }
    }
    catch (Exception e) {
      //println("Could not connect: " + e.getMessage());
      closeConnection();
    }
  }

  private void closeConnection() {
    connected = false;
    try {
      if (in  != null) in.close();
    }
    catch (Exception e) {
    }
    try {
      if (out != null) out.close();
    }
    catch (Exception e) {
    }
    try {
      if (socket != null) socket.close();
    }
    catch (Exception e) {
    }
    in = null;
    out = null;
    socket = null;
  }
}

void stop() {
  tx.dispose();
  super.stop();
}
