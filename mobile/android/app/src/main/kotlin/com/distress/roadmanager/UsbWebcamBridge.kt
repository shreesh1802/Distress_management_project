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
import android.hardware.usb.UsbManager
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.serenegiant.usb.IFrameCallback
import com.serenegiant.usb.Size
import com.serenegiant.usb.USBMonitor
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
 * to the webcam directly over USB with a UVC library. It drives the library's low-level camera class itself (no
 * drawing layer in between) and only hands JPEG pictures to the Flutter side; what happens to them afterwards
 * (shown on screen, sent to the server for detection) is the same as for the phone's own camera.
 *
 * Channels:
 *  - method channel [METHODS]: `devices`, `attached`, `start`, `stop`
 *  - event channel [EVENTS]: a ByteArray is one JPEG picture; a Map is a status change
 *    (`state` = connecting | running | diag | error, plus `message`, `width`, `height`).
 */
class UsbWebcamBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    // Everything that touches the webcam runs on this thread (the library wants a thread with a looper).
    private val camThread = HandlerThread("usb-webcam-camera").apply { start() }
    private val cam = Handler(camThread.looper)

    // Pictures drawn onto our own surface (the second way to get pictures) arrive on this thread.
    private val readerThread = HandlerThread("usb-webcam-reader").apply { start() }
    private val readerHandler = Handler(readerThread.looper)

    // Reading the phone log takes a moment, so it has its own thread.
    private val logThread = HandlerThread("usb-webcam-log").apply { start() }
    private val logHandler = Handler(logThread.looper)

    private var monitor: USBMonitor? = null
    @Volatile private var block: USBMonitor.UsbControlBlock? = null
    private var camera: UVCCamera? = null // camera thread only
    private var reader: ImageReader? = null // camera thread only
    @Volatile private var selected: UsbDevice? = null
    @Volatile private var starting = false
    @Volatile private var running = false
    private var pendingPermissionResult: MethodChannel.Result? = null

    @Volatile private var lastFrameAt = 0L
    @Volatile private var frameWidth = 0
    @Volatile private var frameHeight = 0
    @Volatile private var knownSizes: List<Size> = emptyList()

    // What happened so far, shown on the preview while no picture has arrived (so a problem can be told apart).
    private val directCallbacks = AtomicInteger()
    private val directPictures = AtomicInteger()
    private val readerPictures = AtomicInteger()
    @Volatile private var lastDirectAt = 0L
    @Volatile private var lastNote = ""
    @Volatile private var lastLog = ""
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
        cam.post { camThread.quitSafely() }
        readerThread.quitSafely()
        logThread.quitSafely()
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CAMERA) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            beginOpening()
        } else {
            starting = false
            // Android lets an app use a USB camera only if it may also use the camera.
            status("error", "Allow the Camera permission to use the USB webcam.")
        }
        result.success(null)
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

    private fun firstVideoDevice(): UsbDevice? {
        val usb = activity.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return null
        return usb.deviceList.values.firstOrNull { isVideo(it) }
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
        if (firstVideoDevice() == null) {
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

    private val usbListener = object : USBMonitor.OnDeviceConnectListener {
        override fun onAttach(device: UsbDevice) {}

        override fun onDetach(device: UsbDevice) {
            if (device == selected && (running || starting)) {
                shutDown()
                status("error", "The USB webcam was unplugged.")
            }
        }

        override fun onDeviceOpen(device: UsbDevice, ctrlBlock: USBMonitor.UsbControlBlock, createNew: Boolean) {
            if (device != selected || !starting) return
            block = ctrlBlock
            cam.post { openAttempt() }
        }

        override fun onDeviceClose(device: UsbDevice, ctrlBlock: USBMonitor.UsbControlBlock) {}

        override fun onCancel(device: UsbDevice) {
            if (device == selected) {
                shutDown()
                status("error", "USB access for the webcam was not allowed.")
            }
        }

        override fun onError(device: UsbDevice, e: USBMonitor.USBException) {
            Log.e(TAG, "USB webcam error", e)
            shutDown()
            status("error", "Could not open the USB webcam (${e.message}). Unplug it, plug it back in and try again.")
        }
    }

    private fun beginOpening() {
        val device = firstVideoDevice()
        if (device == null) {
            starting = false
            status("error", "The phone could not see the USB webcam. Unplug it and plug it back in.")
            return
        }
        selected = device
        attempts = emptyList()
        attemptIndex = 0
        supportSummary = ""
        lastNote = ""
        lastLog = ""
        val m = USBMonitor(activity, usbListener)
        monitor = m
        m.register()
        // Asks Android for permission to use the device (a dialog the first time), then opens it.
        m.requestPermission(device)
    }

    /** One way of opening the webcam: size / format (null = the webcam's default), USB quirks, own surface or not. */
    private class Attempt(val size: Size?, val quirks: Int, val surface: Boolean, val label: String)

    @Volatile private var attempts: List<Attempt> = emptyList()
    @Volatile private var attemptIndex = 0
    @Volatile private var openGeneration = 0
    @Volatile private var supportSummary = ""

    private fun describe(s: Size): String {
        val kind = if (s.type == UVCCamera.UVC_VS_FRAME_MJPEG) "MJPEG" else "uncompressed"
        return "$kind ${s.width}x${s.height}"
    }

    private fun summarise(sizes: List<Size>): String {
        if (sizes.isEmpty()) return "no sizes reported"
        return sizes.take(8).joinToString(", ") { describe(it) } + if (sizes.size > 8) ", ..." else ""
    }

    /**
     * The webcam's default first, then moderate sizes (compressed first, with and without our own surface), then
     * small ones, with the "fix bandwidth" workaround some webcams need for uncompressed video.
     */
    private fun buildAttempts(sizes: List<Size>): List<Attempt> {
        val out = mutableListOf(Attempt(null, 0, true, "the webcam's default"))
        val compressed = sizes.filter { it.type == UVCCamera.UVC_VS_FRAME_MJPEG }
        val raw = sizes.filter { it.type != UVCCamera.UVC_VS_FRAME_MJPEG }
        fun nearest(list: List<Size>, width: Int) = list.minByOrNull { abs(it.width - width) }
        fun smallest(list: List<Size>) = list.minByOrNull { it.width * it.height }
        fun add(size: Size?, quirks: Int, surface: Boolean, note: String) {
            if (size == null) return
            if (out.any { it.size?.width == size.width && it.size?.height == size.height &&
                    it.size?.type == size.type && it.quirks == quirks && it.surface == surface }) return
            out.add(Attempt(size, quirks, surface, describe(size) + note))
        }
        add(nearest(compressed, 640), 0, true, "")
        add(nearest(compressed, 640), 0, false, " (no surface)")
        add(nearest(raw, 640), 0, true, "")
        add(nearest(raw, 640), UVCCamera.UVC_QUIRK_FIX_BANDWIDTH, true, " (fixed bandwidth)")
        add(smallest(compressed), 0, true, "")
        add(smallest(raw), UVCCamera.UVC_QUIRK_FIX_BANDWIDTH, true, " (fixed bandwidth)")
        return out
    }

    /** Camera thread: open the webcam with the current attempt and start the pictures. */
    private fun openAttempt() {
        val b = block ?: return
        if (!starting && !running) return
        closeCamera()
        val attempt = attempts.getOrNull(attemptIndex)
        val param = if (attempt?.size != null) UVCParam(attempt.size, attempt.quirks) else UVCParam()
        val c = try {
            UVCCamera(param)
        } catch (e: Throwable) {
            failAll("The USB camera library could not start on this phone (${e.javaClass.simpleName}: ${e.message}).")
            return
        }
        val result = try {
            c.open(b)
        } catch (e: Exception) {
            -1000
        }
        if (result != 0) {
            try {
                c.destroy()
            } catch (_: Exception) {
            }
            lastNote = "opening with ${attempt?.label ?: "the webcam's default"} failed (code $result)"
            nextAttempt()
            return
        }
        camera = c
        val supported = try { c.supportedSizeList } catch (e: Exception) { null } ?: emptyList()
        if (attempts.isEmpty()) {
            attempts = buildAttempts(supported)
            supportSummary = summarise(supported)
        }
        val size = c.previewSize
        frameWidth = size?.width ?: 0
        frameHeight = size?.height ?: 0
        knownSizes = supported + listOfNotNull(size)
        directCallbacks.set(0)
        directPictures.set(0)
        readerPictures.set(0)
        lastDirectAt = 0L
        val current = attempts.getOrNull(attemptIndex)
        if (current?.surface != false) attachReader(c)
        try {
            c.setFrameCallback(frameCallback, UVCCamera.PIXEL_FORMAT_NV21)
            c.startPreview()
        } catch (e: Exception) {
            lastNote = "starting the pictures failed: ${e.javaClass.simpleName}"
        }
        lastNote = "trying ${current?.label ?: "the webcam's default"} (${attemptIndex + 1}/${attempts.size})"
        val generation = ++openGeneration
        if (!running) {
            running = true
            starting = false
            main.post {
                startDiagnostics()
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
        // Some webcams refuse some size / format combinations and then simply send nothing.
        cam.postDelayed({ checkPicturesArrive(generation) }, WATCHDOG_MS)
    }

    private fun picturesSoFar() = directCallbacks.get() + readerPictures.get()

    /** Camera thread. */
    private fun checkPicturesArrive(generation: Int) {
        if (generation != openGeneration || !running) return
        if (picturesSoFar() > 0) return
        nextAttempt()
    }

    /** Camera thread. */
    private fun nextAttempt() {
        attemptIndex++
        if (attemptIndex >= attempts.size) {
            val tried = attempts.joinToString("; ") { it.label }.ifEmpty { "the webcam's default" }
            failAll(
                "The USB webcam opened but sent no pictures with any setting tried ($tried). " +
                    "The webcam reports: ${supportSummary.ifEmpty { "nothing" }}. Phone log: ${recentLog(14, " | ")}",
            )
            return
        }
        openAttempt()
    }

    private fun failAll(message: String) {
        main.post {
            shutDown()
            status("error", message)
        }
    }

    /** The app's own recent log lines about USB / camera work, to show why a webcam stays silent. */
    private fun recentLog(count: Int, separator: String): String {
        return try {
            val process = ProcessBuilder(
                "logcat", "-d", "-t", "800", "--pid=" + android.os.Process.myPid(), "-v", "brief",
            ).redirectErrorStream(true).start()
            val lines = process.inputStream.bufferedReader().readLines()
            process.destroy()
            val keep = Regex(
                "uvc|usb|libusb|preview|render|isoc|stream|bandwidth|error|fail|denied|permission|frame",
                RegexOption.IGNORE_CASE,
            )
            val picked = lines.filter { keep.containsMatchIn(it) && !it.contains("flutter", ignoreCase = true) }
                .map { it.take(130) }
                .distinct()
                .takeLast(count)
            if (picked.isEmpty()) "(nothing relevant in the phone log)" else picked.joinToString(separator)
        } catch (e: Exception) {
            "(could not read the phone log: ${e.javaClass.simpleName})"
        }
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

    /** Camera thread: our own surface as the webcam's preview window; used while the direct callback is silent. */
    private fun attachReader(c: UVCCamera) {
        val w = if (frameWidth > 0) frameWidth else 640
        val ht = if (frameHeight > 0) frameHeight else 480
        try {
            val r = ImageReader.newInstance(w, ht, PixelFormat.RGBA_8888, 3)
            r.setOnImageAvailableListener({ ir ->
                val image = try {
                    ir.acquireLatestImage()
                } catch (e: Exception) {
                    lastNote = "second path: ${e.javaClass.simpleName} ${e.message?.take(70) ?: ""}"
                    null
                } ?: return@setOnImageAvailableListener
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
            c.setPreviewDisplay(r.surface)
        } catch (e: Exception) {
            lastNote = "second path unavailable: ${e.javaClass.simpleName}"
            Log.w(TAG, "Could not set up the second picture path", e)
        }
    }

    /** Once a second, tell the screen what is arriving (shown while the preview is still empty). */
    private fun startDiagnostics() {
        if (diagTicking) return
        diagTicking = true
        var ticks = 0
        val tick = object : Runnable {
            override fun run() {
                if (!running) {
                    diagTicking = false
                    return
                }
                val waiting = picturesSoFar() == 0
                if (waiting && ticks++ % 2 == 0) logHandler.post { lastLog = recentLog(6, "\n") }
                val message = "webcam opened ${frameWidth}x$frameHeight; direct " +
                    "${directCallbacks.get()} received/${directPictures.get()} sent; second path " +
                    "${readerPictures.get()}" + (if (lastNote.isNotEmpty()) "; $lastNote" else "") +
                    (if (waiting && supportSummary.isNotEmpty()) "; webcam supports: $supportSummary" else "") +
                    (if (waiting && lastLog.isNotEmpty()) "\nphone log:\n$lastLog" else "")
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

    /** Camera thread: stop and release the current webcam session (the USB permission stays). */
    private fun closeCamera() {
        val c = camera
        camera = null
        if (c != null) {
            try {
                c.setFrameCallback(null, UVCCamera.PIXEL_FORMAT_NV21)
            } catch (_: Exception) {
            }
            try {
                c.stopPreview()
            } catch (_: Exception) {
            }
            try {
                c.destroy()
            } catch (_: Exception) {
            }
        }
        val r = reader
        reader = null
        try {
            r?.close()
        } catch (_: Exception) {
        }
    }

    private fun shutDown() {
        pendingPermissionResult = null
        starting = false
        running = false
        selected = null
        block = null
        val m = monitor
        monitor = null
        cam.removeCallbacksAndMessages(null)
        cam.post {
            openGeneration++
            closeCamera()
            try {
                m?.destroy()
            } catch (_: Exception) {
            }
        }
    }

    companion object {
        private const val TAG = "UsbWebcam"
        const val METHODS = "road_inspection/usb_webcam"
        const val EVENTS = "road_inspection/usb_webcam/events"
        private const val REQUEST_CAMERA = 4711
        private const val USB_CLASS_VIDEO = 14
        private const val JPEG_QUALITY = 75
        private const val MIN_FRAME_GAP_MS = 100L
        private const val WATCHDOG_MS = 4000L
    }
}
