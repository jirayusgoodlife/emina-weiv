package com.animeview.anime_view

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.util.Rational
import android.net.Uri
import java.io.File
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.animeview.anime_view/pip"
        private const val UPDATER_CHANNEL = "com.animeview.anime_view/updater"
        private const val CAST_CHANNEL = "com.animeview.anime_view/cast"
        private const val ACTION_MEDIA_CONTROL = "com.animeview.anime_view.MEDIA_CONTROL"
        private const val EXTRA_CONTROL_TYPE = "control_type"
        private const val CONTROL_TYPE_PLAY = 1
        private const val CONTROL_TYPE_PAUSE = 2
    }

    private var methodChannel: MethodChannel? = null
    private var castService: CastService? = null
    private var autoPipEnabled = false
    private var aspectRatioNumerator = 16
    private var aspectRatioDenominator = 9
    private var isPlaying = true

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null || intent.action != ACTION_MEDIA_CONTROL) return
            val controlType = intent.getIntExtra(EXTRA_CONTROL_TYPE, 0)
            when (controlType) {
                CONTROL_TYPE_PLAY -> {
                    isPlaying = true
                    methodChannel?.invokeMethod("onPipAction", "play")
                }
                CONTROL_TYPE_PAUSE -> {
                    isPlaying = false
                    methodChannel?.invokeMethod("onPipAction", "pause")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register PiP control broadcast receiver
        val filter = IntentFilter(ACTION_MEDIA_CONTROL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipReceiver, filter)
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val num = call.argument<Int>("numerator") ?: 16
                            val den = call.argument<Int>("denominator") ?: 9
                            val playing = call.argument<Boolean>("isPlaying") ?: true
                            isPlaying = playing
                            aspectRatioNumerator = num
                            aspectRatioDenominator = den

                            val rational = getSafeAspectRatio(num, den)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                                .setActions(buildPipActions(isPlaying))
                            val success = enterPictureInPictureMode(builder.build())
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("NOT_SUPPORTED", "PiP requires Android 8.0+", null)
                    }
                }
                "setAutoPip" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    autoPipEnabled = enabled
                    val num = call.argument<Int>("numerator") ?: 16
                    val den = call.argument<Int>("denominator") ?: 9
                    val playing = call.argument<Boolean>("isPlaying") ?: true
                    isPlaying = playing
                    aspectRatioNumerator = num
                    aspectRatioDenominator = den

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val rational = getSafeAspectRatio(num, den)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                                .setActions(buildPipActions(isPlaying))
                                .setAutoEnterEnabled(enabled)
                            setPictureInPictureParams(builder.build())
                        } catch (e: Exception) {
                            // ignore if not supported by device
                        }
                    }
                    result.success(true)
                }
                "updatePipActions" -> {
                    val playing = call.argument<Boolean>("isPlaying") ?: true
                    isPlaying = playing
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
                        try {
                            val rational = getSafeAspectRatio(aspectRatioNumerator, aspectRatioDenominator)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                                .setActions(buildPipActions(isPlaying))
                            setPictureInPictureParams(builder.build())
                        } catch (e: Exception) {
                            // ignore
                        }
                    }
                    result.success(true)
                }
                "getBrightness" -> {
                    val lp = window.attributes
                    val b = if (lp.screenBrightness < 0f) {
                        try {
                            Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255f
                        } catch (e: Exception) {
                            0.5f
                        }
                    } else {
                        lp.screenBrightness
                    }
                    result.success(b.toDouble())
                }
                "setBrightness" -> {
                    val brightness = (call.argument<Double>("brightness") ?: 0.5).toFloat()
                    val lp = window.attributes
                    lp.screenBrightness = brightness.coerceIn(0.001f, 1.0f)
                    window.attributes = lp
                    result.success(true)
                }
                "resetBrightness" -> {
                    val lp = window.attributes
                    lp.screenBrightness = -1f
                    window.attributes = lp
                    result.success(true)
                }
                "getVolume" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val vol = if (max > 0) current.toDouble() / max.toDouble() else 0.0
                    result.success(vol)
                }
                "setVolume" -> {
                    val volume = (call.argument<Double>("volume") ?: 0.5).toFloat()
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val target = (volume.coerceIn(0f, 1f) * max).roundToInt()
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Updater channel
        val updaterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
        updaterChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        val data = mapOf(
                            "versionName" to (pInfo.versionName ?: "1.0.0"),
                            "versionCode" to versionCode
                        )
                        result.success(data)
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                "canInstallUnknownPackages" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "File path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${packageName}.fileProvider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Cast channel
        castService = CastService(applicationContext)
        val castChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAST_CHANNEL)
        castService?.methodChannel = castChannel
        castChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startDiscovery" -> {
                    castService?.startDiscovery()
                    result.success(true)
                }
                "stopDiscovery" -> {
                    castService?.stopDiscovery()
                    result.success(true)
                }
                "getDevices" -> {
                    val devices = castService?.getDiscoveredDevices() ?: emptyList<Map<String, Any>>()
                    result.success(devices)
                }
                "connect" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    castService?.connectToDevice(deviceId) { success, error ->
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("CONNECT_ERROR", error ?: "Failed to connect", null)
                        }
                    }
                }
                "disconnect" -> {
                    castService?.disconnect()
                    result.success(true)
                }
                "loadMedia" -> {
                    val url = call.argument<String>("url") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val thumbnailUrl = call.argument<String>("thumbnailUrl") ?: ""
                    val contentType = call.argument<String>("contentType") ?: "video/mp4"
                    val startPosition = call.argument<Double>("startPosition") ?: 0.0

                    castService?.loadMedia(
                        url = url,
                        title = title,
                        subtitle = subtitle,
                        thumbnailUrl = thumbnailUrl,
                        contentType = contentType,
                        startPosition = startPosition
                    ) { success, error ->
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("LOAD_ERROR", error ?: "Failed to load media", null)
                        }
                    }
                }
                "play" -> {
                    castService?.play()
                    result.success(true)
                }
                "pause" -> {
                    castService?.pause()
                    result.success(true)
                }
                "stop" -> {
                    castService?.stop()
                    result.success(true)
                }
                "seek" -> {
                    val position = call.argument<Double>("position") ?: 0.0
                    castService?.seek(position)
                    result.success(true)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 0.5
                    castService?.setVolume(volume)
                    result.success(true)
                }
                "isConnected" -> {
                    result.success(castService?.isConnected() ?: false)
                }
                "getConnectedDeviceName" -> {
                    result.success(castService?.getConnectedDeviceName() ?: "")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildPipActions(playing: Boolean): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return emptyList()
        }

        val actions = ArrayList<RemoteAction>()
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        if (playing) {
            val intent = Intent(ACTION_MEDIA_CONTROL).apply {
                putExtra(EXTRA_CONTROL_TYPE, CONTROL_TYPE_PAUSE)
                setPackage(packageName)
            }
            val pendingIntent = PendingIntent.getBroadcast(this, CONTROL_TYPE_PAUSE, intent, flag)
            val icon = Icon.createWithResource(this, android.R.drawable.ic_media_pause)
            actions.add(RemoteAction(icon, "Pause", "Pause", pendingIntent))
        } else {
            val intent = Intent(ACTION_MEDIA_CONTROL).apply {
                putExtra(EXTRA_CONTROL_TYPE, CONTROL_TYPE_PLAY)
                setPackage(packageName)
            }
            val pendingIntent = PendingIntent.getBroadcast(this, CONTROL_TYPE_PLAY, intent, flag)
            val icon = Icon.createWithResource(this, android.R.drawable.ic_media_play)
            actions.add(RemoteAction(icon, "Play", "Play", pendingIntent))
        }

        return actions
    }

    private fun getSafeAspectRatio(numerator: Int, denominator: Int): Rational {
        var num = if (numerator <= 0) 16 else numerator
        var den = if (denominator <= 0) 9 else denominator
        val ratio = num.toFloat() / den.toFloat()
        // Android enforces Rational between 1:2.39 (0.41841) and 2.39:1 (2.39)
        if (ratio < 0.41841f) {
            num = 100
            den = 239
        } else if (ratio > 2.39f) {
            num = 239
            den = 100
        }
        return Rational(num, den)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // On Android 8.0 to 11, auto enter PiP on user leaving the app
        if (autoPipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val rational = getSafeAspectRatio(aspectRatioNumerator, aspectRatioDenominator)
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .setActions(buildPipActions(isPlaying))
                enterPictureInPictureMode(builder.build())
            } catch (e: Exception) {
                // ignore
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
        if (isInPictureInPictureMode && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val rational = getSafeAspectRatio(aspectRatioNumerator, aspectRatioDenominator)
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .setActions(buildPipActions(isPlaying))
                setPictureInPictureParams(builder.build())
            } catch (e: Exception) {
                // ignore
            }
        }
    }

    override fun onDestroy() {
        try {
            castService?.destroy()
            castService = null
        } catch (e: Exception) {
            // ignore
        }
        try {
            unregisterReceiver(pipReceiver)
        } catch (e: Exception) {
            // ignore
        }
        super.onDestroy()
    }
}
