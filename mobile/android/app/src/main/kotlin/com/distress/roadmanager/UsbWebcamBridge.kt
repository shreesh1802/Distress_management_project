package com.distress.roadmanager

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.herohan.uvcapp.CameraException
import com.herohan.uvcapp.CameraHelper
import com.herohan.uvcapp.ICameraHelper
import com.serenegiant.usb.IFrameCallback
import com.serenegiant.usb.Size
import com.serenegiant.usb.UVCCamera
import com.serenegiant.usb.UVCParam
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import kotlin.math.abs

/**
 * Lets the app use a USB webcam plugged into the phone (through an OTG adapter).
 *
 * Android's normal camera system (what the `camera` plugin uses) does not list most USB webcams, so this talks
 * to the webcam directly over USB with a UVC library. It only hands JPEG pictures to the Flutter side; what
 * happens to them afterwards (shown on screen, sent to the server for detection) is the same as for the phone's
 * own camera.
 *
 * Channels:
 *  - method channel [METHODS]: `devices`, `start`, `stop`
 *  - event channel [EVENTS]: a ByteArray is one JPEG picture; a Map is a status change
 *    (`state` = connecting | running | error, plus `message`, `width`, `height`).
 */
class UsbWebcamBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private var helper: ICameraHelper? = null
    private var selected: UsbDevice? = null
    private var starting = false
    private var running = false
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var searchAttempts = 0

    private var lastFrameAt = 0L
    private var frameWidth = 0
    private var frameHeight = 0

    init {
        MethodChannel(messenger, METHODS).setMethodCallHandler(this)
        EventChannel(messenger, EVENTS).setStreamHandler(this)
    }

    // -------------------------------------------------------------------------------- Flutter side

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "devices" -> result.success(listVideoDevices())
            "start" -> startRequested(result)
            "stop" -> {
                shutDown()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        shutDown()
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CAMERA) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            beginOpening()
            result.success(null)
        } else {
            starting = false
            // Android lets an app use a USB camera only if it may also use the camera.
            status("error", "Allow the Camera permission to use the USB webcam.")
            result.success(null)
        }
    }

    // ---------------------------------------------------------------------------------- listing

    /** USB devices that look like a webcam (they have a "video" interface). */
    private fun listVideoDevices(): List<Map<String, Any?>> {
        val usb = activity.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return emptyList()
        return usb.deviceList.values.filter { isVideo(it) }.map {
            mapOf(
                "name" to (it.productName ?: "USB webcam"),
                "vendorId" to it.vendorId,
                "productId" to it.productId,
            )
        }
    }

    private fun isVideo(device: UsbDevice): Boolean {
        if (device.deviceClass == USB_CLASS_VIDEO) return true
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == USB_CLASS_VIDEO) return true
        }
        return false
    }

    // ----------------------------------------------------------------------------------- opening

    private fun startRequested(result: MethodChannel.Result) {
        if (starting || running) {
            result.success(null)
            return
        }
        if (listVideoDevices().isEmpty()) {
            status("error", "No USB webcam found. Plug it in through the OTG adapter and try again.")
            result.success(null)
            return
        }
        starting = true
        status("connecting", "Connecting to the USB webcam...")
        if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            pendingPermissionResult = result
            activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
            return
        }
        beginOpening()
        result.success(null)
    }

    private fun beginOpening() {
        shutDownHelper()
        searchAttempts = 0
        val h = CameraHelper()
        helper = h
        h.setStateCallback(object : ICameraHelper.StateCallback {
            override fun onAttach(device: UsbDevice) {
                if (selected == null && starting && isVideo(device)) pick(device)
            }

            override fun onDeviceOpen(device: UsbDevice, isFirstOpen: Boolean) {
                openWithBestSize(device)
            }

            override fun onCameraOpen(device: UsbDevice) {
                val hh = helper ?: return
                hh.setFrameCallback(frameCallback, UVCCamera.PIXEL_FORMAT_NV21)
                hh.startPreview()
                val size = hh.previewSize
                frameWidth = size?.width ?: 0
                frameHeight = size?.height ?: 0
                running = true
                starting = false
                main.post {
                    sink?.success(
                        mapOf(
                            "state" to "running",
                            "message" to "USB webcam ready",
                            "width" to frameWidth,
                            "height" to frameHeight,
                        ),
                    )
                }
            }

            override fun onCameraClose(device: UsbDevice) {}
            override fun onDeviceClose(device: UsbDevice) {}

            override fun onDetach(device: UsbDevice) {
                if (device == selected) {
                    val wasActive = running || starting
                    shutDownHelper()
                    if (wasActive) status("error", "The USB webcam was unplugged.")
                }
            }

            override fun onCancel(device: UsbDevice) {
                if (device == selected) {
                    selected = null
                    starting = false
                    status("error", "USB access for the webcam was not allowed.")
                }
            }

            override fun onError(device: UsbDevice, e: CameraException) {
                Log.e(TAG, "USB webcam error", e)
                starting = false
                val busy = e.code == CameraException.CAMERA_OPEN_ERROR_BUSY
                status(
                    "error",
                    if (busy) "The USB webcam is busy. Unplug it, plug it back in and try again."
                    else "Could not open the USB webcam. Unplug it, plug it back in and try again.",
                )
            }
        })
        // Normally onAttach reports a webcam that is already plugged in. As a safety net, also look for it.
        searchForDevice()
    }

    private fun searchForDevice() {
        main.postDelayed({
            if (!starting || selected != null) return@postDelayed
            val list = try {
                helper?.deviceList
            } catch (e: Exception) {
                null
            }
            val device = list?.firstOrNull { isVideo(it) }
            if (device != null) {
                pick(device)
            } else if (++searchAttempts < 20) {
                searchForDevice()
            } else {
                starting = false
                status("error", "The phone could not see the USB webcam. Unplug it and plug it back in.")
            }
        }, 400)
    }

    private fun pick(device: UsbDevice) {
        selected = device
        // This asks Android for permission to use the device (a dialog the first time).
        helper?.selectDevice(device)
    }

    private fun openWithBestSize(device: UsbDevice) {
        val h = helper ?: return
        val sizes = try {
            h.supportedSizeList
        } catch (e: Exception) {
            null
        }
        val best = chooseSize(sizes)
        if (best != null) h.openCamera(UVCParam(best, 0)) else h.openCamera()
    }

    /**
     * About 1280 px wide: the server shrinks every picture to at most 640 px anyway, so more detail than this
     * only costs upload time, and less loses small cracks. Compressed (MJPEG) sizes are preferred: they allow a
     * higher frame rate over a USB 2 cable.
     */
    private fun chooseSize(sizes: List<Size>?): Size? {
        if (sizes.isNullOrEmpty()) return null
        return sizes.minByOrNull { s ->
            val compressedPenalty = if (s.type == UVCCamera.UVC_VS_FRAME_MJPEG) 0 else 100_000
            val tooSmall = if (s.width < 640) 50_000 else 0
            abs(s.width - TARGET_WIDTH) + compressedPenalty + tooSmall
        }
    }

    // -------------------------------------------------------------------------------- the pictures

    private val frameCallback = IFrameCallback { frame: ByteBuffer ->
        val now = SystemClock.elapsedRealtime()
        if (now - lastFrameAt < MIN_FRAME_GAP_MS) return@IFrameCallback
        val w = frameWidth
        val h = frameHeight
        if (w <= 0 || h <= 0) return@IFrameCallback
        try {
            val needed = w * h * 3 / 2
            if (frame.remaining() < needed) return@IFrameCallback
            val nv21 = ByteArray(needed)
            frame.get(nv21, 0, needed)
            val out = ByteArrayOutputStream(64 * 1024)
            YuvImage(nv21, ImageFormat.NV21, w, h, null).compressToJpeg(Rect(0, 0, w, h), JPEG_QUALITY, out)
            lastFrameAt = now
            val bytes = out.toByteArray()
            main.post { sink?.success(bytes) }
        } catch (e: Exception) {
            Log.w(TAG, "Dropped a USB webcam picture", e)
        }
    }

    private fun status(state: String, message: String) {
        main.post { sink?.success(mapOf("state" to state, "message" to message)) }
    }

    // --------------------------------------------------------------------------------- closing

    private fun shutDown() {
        pendingPermissionResult = null
        starting = false
        shutDownHelper()
    }

    private fun shutDownHelper() {
        running = false
        selected = null
        val h = helper ?: return
        helper = null
        try {
            h.setFrameCallback(null, UVCCamera.PIXEL_FORMAT_NV21)
        } catch (_: Exception) {
        }
        try {
            h.stopPreview()
        } catch (_: Exception) {
        }
        try {
            h.closeCamera()
        } catch (_: Exception) {
        }
        try {
            h.release()
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TAG = "UsbWebcam"
        const val METHODS = "road_inspection/usb_webcam"
        const val EVENTS = "road_inspection/usb_webcam/events"
        private const val REQUEST_CAMERA = 4711
        private const val USB_CLASS_VIDEO = 14
        private const val TARGET_WIDTH = 1280
        private const val JPEG_QUALITY = 75
        private const val MIN_FRAME_GAP_MS = 100L
    }
}
