package com.distress.roadmanager

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.usb.UsbDevice
import android.media.ImageReader
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
import java.util.concurrent.atomic.AtomicInteger
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
    private var knownSizes: List<Size> = emptyList()

    // A second way to get pictures: the library draws every picture onto this reader's surface. Used when the
    // direct (NV21) callback stays silent on a phone/webcam combination.
    private var reader: ImageReader? = null
    private val readerThread = android.os.HandlerThread("usb-webcam-reader").apply { start() }
    private val readerHandler = Handler(readerThread.looper)

    // What happened so far, shown on the preview while no picture has arrived (so a problem can be told apart).
    private val directCallbacks = AtomicInteger()
    private val directPictures = AtomicInteger()
    private val readerPictures = AtomicInteger()
    @Volatile private var lastDirectAt = 0L
    @Volatile private var lastNote = ""
    private var diagTicking = false

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
            "attached" -> result.success(describeAttached())
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

    /** Every USB device Android reports right now, so a missing webcam can be told apart from an unrecognised one. */
    private fun describeAttached(): String {
        val usb = activity.getSystemService(Context.USB_SERVICE) as? UsbManager
            ?: return "This phone has no USB host service."
        val all = usb.deviceList.values
        if (all.isEmpty()) return "Android sees no USB device on the port."
        return "Android sees " + all.size + " USB device(s): " + all.joinToString("; ") { d ->
            val classes = (0 until d.interfaceCount).map { d.getInterface(it).interfaceClass }.distinct()
            (d.productName ?: "unnamed") + " (id " + Integer.toHexString(d.vendorId) + ":" +
                Integer.toHexString(d.productId) + ", class " + d.deviceClass + ", interfaces " + classes + ")"
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
                attempts = emptyList()
                attemptIndex = 0
                helper?.openCamera()
            }

            override fun onCameraOpen(device: UsbDevice) {
                val hh = helper ?: return
                openGeneration++
                val generation = openGeneration
                val size = hh.previewSize
                frameWidth = size?.width ?: 0
                frameHeight = size?.height ?: 0
                val supported = try { hh.supportedSizeList } catch (e: Exception) { null } ?: emptyList()
                knownSizes = supported + listOfNotNull(size)
                if (attempts.isEmpty()) {
                    attempts = buildAttempts(supported)
                    supportSummary = summarise(supported)
                }
                directCallbacks.set(0)
                directPictures.set(0)
                readerPictures.set(0)
                lastDirectAt = 0L
                detachReader(hh)
                attachReader(hh)
                hh.setFrameCallback(frameCallback, UVCCamera.PIXEL_FORMAT_NV21)
                hh.startPreview()
                running = true
                starting = false
                startDiagnostics()
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
                // Some webcams refuse some size / format combinations and then simply send nothing.
                main.postDelayed({ checkPicturesArrive(generation) }, WATCHDOG_MS)
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

    /** One way of opening the webcam: a size / format (null = the library's own default) and USB quirks. */
    private class Attempt(val size: Size?, val quirks: Int, val label: String)

    private var attempts: List<Attempt> = emptyList()
    private var attemptIndex = 0
    private var openGeneration = 0
    private var supportSummary = ""

    private fun describe(s: Size): String {
        val kind = if (s.type == UVCCamera.UVC_VS_FRAME_MJPEG) "MJPEG" else "uncompressed"
        return "$kind ${s.width}x${s.height}"
    }

    private fun summarise(sizes: List<Size>): String {
        if (sizes.isEmpty()) return "no sizes reported"
        return sizes.take(8).joinToString(", ") { describe(it) } + if (sizes.size > 8) ", ..." else ""
    }

    /**
     * The library's default first, then moderate sizes (compressed first), then small ones, and finally the
     * "fix bandwidth" workaround that some webcams need for uncompressed video.
     */
    private fun buildAttempts(sizes: List<Size>): List<Attempt> {
        val out = mutableListOf(Attempt(null, 0, "the library default"))
        val compressed = sizes.filter { it.type == UVCCamera.UVC_VS_FRAME_MJPEG }
        val raw = sizes.filter { it.type != UVCCamera.UVC_VS_FRAME_MJPEG }
        fun nearest(list: List<Size>, width: Int) = list.minByOrNull { abs(it.width - width) }
        fun smallest(list: List<Size>) = list.minByOrNull { it.width * it.height }
        fun add(size: Size?, quirks: Int, note: String) {
            if (size == null) return
            if (out.any { it.size?.width == size.width && it.size?.height == size.height &&
                    it.size?.type == size.type && it.quirks == quirks }) return
            out.add(Attempt(size, quirks, describe(size) + note))
        }
        add(nearest(compressed, 640), 0, "")
        add(nearest(raw, 640), 0, "")
        add(nearest(raw, 640), UVCCamera.UVC_QUIRK_FIX_BANDWIDTH, " (fixed bandwidth)")
        add(smallest(compressed), 0, "")
        add(smallest(raw), 0, "")
        add(smallest(raw), UVCCamera.UVC_QUIRK_FIX_BANDWIDTH, " (fixed bandwidth)")
        add(nearest(compressed, 1280), 0, "")
        return out
    }

    /** The app's own recent log lines about USB / camera work, to show why a webcam stays silent. */
    private fun recentLog(): String {
        return try {
            val process = ProcessBuilder(
                "logcat", "-d", "-t", "600", "--pid=" + android.os.Process.myPid(), "-v", "brief",
            ).redirectErrorStream(true).start()
            val lines = process.inputStream.bufferedReader().readLines()
            process.destroy()
            val keep = Regex("uvc|usb|libusb|preview|render|isoc|stream|bandwidth|error|fail|denied|permission", RegexOption.IGNORE_CASE)
            val picked = lines.filter { keep.containsMatchIn(it) && !it.contains("flutter", ignoreCase = true) }
                .map { it.take(140) }
                .distinct()
                .takeLast(14)
            if (picked.isEmpty()) "(nothing relevant in the phone log)" else picked.joinToString(" | ")
        } catch (e: Exception) {
            "(could not read the phone log: ${e.javaClass.simpleName})"
        }
    }

    private fun picturesSoFar() =directCallbacks.get() + readerPictures.get()

    private fun checkPicturesArrive(generation: Int) {
        if (generation != openGeneration || !running) return
        if (picturesSoFar() > 0) return
        val h = helper ?: return
        attemptIndex++
        if (attemptIndex >= attempts.size) {
            val tried = attempts.joinToString("; ") { it.label }
            val log = recentLog()
            shutDown()
            status(
                "error",
                "The USB webcam opened but sent no pictures with any setting tried ($tried). " +
                    "The webcam reports: $supportSummary. Phone log: $log",
            )
            return
        }
        val next = attempts[attemptIndex]
        lastNote = "no pictures yet; trying ${next.label} (${attemptIndex + 1}/${attempts.size})"
        try {
            h.stopPreview()
        } catch (_: Exception) {
        }
        h.closeCamera()
        h.openCamera(UVCParam(next.size, next.quirks))
    }

    // -------------------------------------------------------------------------------- the pictures

    private val frameCallback = IFrameCallback { frame: ByteBuffer ->
        directCallbacks.incrementAndGet()
        lastDirectAt = SystemClock.elapsedRealtime()
        val now = lastDirectAt
        if (now - lastFrameAt < MIN_FRAME_GAP_MS) return@IFrameCallback
        try {
            val remaining = frame.remaining()
            var w = frameWidth
            var h = frameHeight
            if (w <= 0 || h <= 0 || w * h * 3 / 2 != remaining) {
                // The size we were told does not fit the data: find the size whose NV21 length matches.
                val match = knownSizes.firstOrNull { it.width * it.height * 3 / 2 == remaining }
                if (match == null) {
                    lastNote = "unexpected picture size ($remaining bytes)"
                    return@IFrameCallback
                }
                w = match.width
                h = match.height
                frameWidth = w
                frameHeight = h
            }
            val nv21 = ByteArray(w * h * 3 / 2)
            frame.get(nv21, 0, nv21.size)
            val out = ByteArrayOutputStream(64 * 1024)
            YuvImage(nv21, ImageFormat.NV21, w, h, null).compressToJpeg(Rect(0, 0, w, h), JPEG_QUALITY, out)
            lastFrameAt = now
            directPictures.incrementAndGet()
            val bytes = out.toByteArray()
            main.post { sink?.success(bytes) }
        } catch (e: Exception) {
            lastNote = "direct picture failed: ${e.javaClass.simpleName}"
            Log.w(TAG, "Dropped a USB webcam picture", e)
        }
    }

    /** Pictures the library drew onto our reader; used only while the direct callback is silent. */
    private fun attachReader(h: ICameraHelper) {
        val w = if (frameWidth > 0) frameWidth else TARGET_WIDTH
        val ht = if (frameHeight > 0) frameHeight else TARGET_WIDTH * 9 / 16
        try {
            val r = ImageReader.newInstance(w, ht, PixelFormat.RGBA_8888, 3)
            r.setOnImageAvailableListener({ ir ->
                val image = try { ir.acquireLatestImage() } catch (e: Exception) { null } ?: return@setOnImageAvailableListener
                try {
                    readerPictures.incrementAndGet()
                    val now = SystemClock.elapsedRealtime()
                    val directIsWorking = lastDirectAt != 0L && now - lastDirectAt < 1500
                    if (directIsWorking || now - lastFrameAt < MIN_FRAME_GAP_MS) return@setOnImageAvailableListener
                    val plane = image.planes[0]
                    val pixelStride = plane.pixelStride
                    val rowStride = plane.rowStride
                    val bmp = Bitmap.createBitmap(rowStride / pixelStride, image.height, Bitmap.Config.ARGB_8888)
                    bmp.copyPixelsFromBuffer(plane.buffer)
                    val out = ByteArrayOutputStream(64 * 1024)
                    val cropped = Bitmap.createBitmap(bmp, 0, 0, image.width, image.height)
                    cropped.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                    if (cropped !== bmp) cropped.recycle()
                    bmp.recycle()
                    lastFrameAt = now
                    val bytes = out.toByteArray()
                    main.post { sink?.success(bytes) }
                } catch (e: Exception) {
                    lastNote = "second path failed: ${e.javaClass.simpleName}"
                } finally {
                    image.close()
                }
            }, readerHandler)
            reader = r
            h.addSurface(r.surface, false)
        } catch (e: Exception) {
            lastNote = "second path unavailable: ${e.javaClass.simpleName}"
            Log.w(TAG, "Could not set up the second picture path", e)
        }
    }

    private fun detachReader(h: ICameraHelper) {
        val r = reader ?: return
        reader = null
        try {
            h.removeSurface(r.surface)
        } catch (_: Exception) {
        }
        try {
            r.close()
        } catch (_: Exception) {
        }
    }

    /** Once a second, tell the screen what is arriving (shown while the preview is still empty). */
    private fun startDiagnostics() {
        if (diagTicking) return
        diagTicking = true
        val tick = object : Runnable {
            override fun run() {
                if (!running) {
                    diagTicking = false
                    return
                }
                val message = "webcam opened ${frameWidth}x$frameHeight; direct " +
                    "${directCallbacks.get()} received/${directPictures.get()} sent; second path " +
                    "${readerPictures.get()}" + (if (lastNote.isNotEmpty()) "; $lastNote" else "") +
                    (if (picturesSoFar() == 0 && supportSummary.isNotEmpty()) "; webcam supports: $supportSummary" else "")
                sink?.success(
                    mapOf(
                        "state" to "diag",
                        "message" to message,
                        "width" to frameWidth,
                        "height" to frameHeight,
                    ),
                )
                main.postDelayed(this, 1000)
            }
        }
        main.postDelayed(tick, 1000)
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
            reader?.let { h.removeSurface(it.surface) }
        } catch (_: Exception) {
        }
        try {
            reader?.close()
        } catch (_: Exception) {
        }
        reader = null
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
        private const val WATCHDOG_MS = 4000L
    }
}
