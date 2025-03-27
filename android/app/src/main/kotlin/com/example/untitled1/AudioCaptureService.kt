package com.example.untitled1

import android.app.*
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.embedding.engine.FlutterEngine

class AudioCaptureService : Service() {

    private var mediaProjection: MediaProjection? = null
    private val mediaProjectionManager: MediaProjectionManager by lazy {
        getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    private val CHANNEL = "audio_capture"  // MethodChannel for Flutter communication
    private var flutterEngine: FlutterEngine? = null // Hold a reference to FlutterEngine

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
    }

    private fun startForegroundService() {
        val channelId = "audio_capture_service"
        val channelName = "Audio Capture Service"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Audio Capture Running")
            .setContentText("Capturing system audio in the background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)

        // Initialize FlutterEngine and the MethodChannel after the service is created
        flutterEngine = FlutterEngine(applicationContext)
        flutterEngine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onAudioCaptured", "This is the captured audio text.")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AudioCaptureService", "Service started")

        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data = intent?.getParcelableExtra<Intent>("data")

        if (resultCode == Activity.RESULT_OK && data != null) {
            mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)
            startAudioCapture()  // Start audio capture once permission is granted
        } else {
            Log.e("AudioCaptureService", "Permission denied or missing data.")
            stopSelf()
        }

        return START_STICKY
    }

    private fun startAudioCapture() {
        // Simulate captured text here (replace with actual audio capture logic)
        val recognizedText = "This is the captured system audio as text."

        // Send the recognized text back to Flutter via MethodChannel
        flutterEngine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onAudioCaptured", recognizedText)
        }

        Log.d("AudioCaptureService", "Started capturing system audio.")
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AudioCaptureService", "Service stopped")
    }
}
