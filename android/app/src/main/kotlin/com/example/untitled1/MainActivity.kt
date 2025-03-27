package com.example.untitled1

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.projection.MediaProjectionManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "audio_capture"
    private val REQUEST_CODE_CAPTURE_AUDIO = 1001
    private var mediaProjectionManager: MediaProjectionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> {
                    try {
                        // Initialize MediaProjectionManager
                        mediaProjectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        val captureIntent = mediaProjectionManager!!.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, REQUEST_CODE_CAPTURE_AUDIO)  // Start permission request
                        result.success("Capture started")
                    } catch (e: Exception) {
                        result.error("ERROR_START_SERVICE", "Failed to start service: ${e.localizedMessage}", null)
                    }
                }

                "stopCapture" -> {
                    val serviceIntent = Intent(this, AudioCaptureService::class.java)
                    stopService(serviceIntent)
                    result.success("Capture stopped")
                }
                else -> result.notImplemented()
            }
        }
    }

    // Handle permission result in MainActivity
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_CAPTURE_AUDIO) {
            if (resultCode == Activity.RESULT_OK) {
                // Permission granted
                Log.d("MainActivity", "Permission granted for capturing audio.")
                val serviceIntent = Intent(this, AudioCaptureService::class.java)
                serviceIntent.putExtra("resultCode", resultCode)
                serviceIntent.putExtra("data", data)
                startService(serviceIntent)  // Start AudioCaptureService with permission result
            } else {
                Log.e("MainActivity", "Permission denied.")
            }
        }
    }
}
