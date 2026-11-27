package com.distress.roadmanager

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var usbWebcam: UsbWebcamBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbWebcam = UsbWebcamBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Whether the phone's "Auto rotate" setting is on (full-screen live view follows it).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "autoRotate" -> result.success(
                    try {
                        Settings.System.getInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1
                    } catch (e: Exception) {
                        null
                    },
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usbWebcam?.dispose()
        usbWebcam = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        usbWebcam?.onPermissionResult(requestCode, grantResults)
    }

    companion object {
        private const val DISPLAY_CHANNEL = "road_inspection/display"
    }
}
