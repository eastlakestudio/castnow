package com.eastlakestudio.castnow.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.hardware.display.DisplayManager.DisplayListener
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), DisplayListener {

    private val PROJECTION_CHANNEL = "castnow_picker"
    private var methodChannel: MethodChannel? = null
    private var castCode: String? = null

    // Broadcast receiver to handle stop signals from the Foreground Service notification
    private val stopReceiver =
            object : android.content.BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.eastlakestudio.castnow.app.STOP_SESSION") {
                        Log.d(
                                "CastNow",
                                "MainActivity: Stop broadcast received. Sycing with Flutter."
                        )
                        Handler(Looper.getMainLooper()).post {
                            methodChannel?.invokeMethod("onStopPressed", null)
                        }
                    }
                }
            }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register DisplayListener to detect when the virtual display is stopped by the system
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(this, Handler(Looper.getMainLooper()))

        // Register receiver for Android 14 compatibility
        val filter = IntentFilter("com.eastlakestudio.castnow.app.STOP_SESSION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(stopReceiver, filter)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROJECTION_CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMediaProjectionService" -> {
                    val type = call.argument<String>("type") ?: "mediaProjection"
                    castCode = call.argument<String>("code")
                    val serviceIntent =
                            Intent(this, MediaProjectionService::class.java).apply {
                                putExtra("type", type)
                                putExtra("code", castCode)
                            }
                    startForegroundService(serviceIntent)
                    result.success(null)
                }
                "stopMediaProjectionService" -> {
                    val serviceIntent = Intent(this, MediaProjectionService::class.java)
                    stopService(serviceIntent)
                    castCode = null
                    result.success(null)
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // 🛑 CRITICAL: We must upgrade the service BEFORE the plugin processes the result.
        // flutter_webrtc will consume the result in super.onActivityResult() and immediately try to
        // start projection.
        // If the service isn't "mediaProjection" type by then, it crashes.
        if (resultCode == RESULT_OK && Build.VERSION.SDK_INT >= 34) {
            Log.d(
                    "CastNow",
                    "MainActivity: Permission granted (OK). Pre-emptively upgrading service to mediaProjection."
            )
            val upgradeIntent =
                    Intent(this, MediaProjectionService::class.java).apply {
                        putExtra("type", "mediaProjection")
                        putExtra("code", castCode)
                    }
            startForegroundService(upgradeIntent)

            // Give the system a tiny moment to process the service type update?
            // We can't really sleep on main thread, but execution order matters.
            // DELAY the plugin processing to ensure Service has processed the command.
            Handler(Looper.getMainLooper())
                    .postDelayed({ super.onActivityResult(requestCode, resultCode, data) }, 1000)
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    // --- DisplayListener Implementation ---
    override fun onDisplayAdded(displayId: Int) {
        Log.d("CastNow", "Display Added: $displayId")
    }

    override fun onDisplayChanged(displayId: Int) {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(displayId)
        if (display != null && castCode != null) {
            // Logic: If a virtual display turns OFF (state 1), or matches criteria
            // it usually means the system has paused or stopped the projection.
            // checking state == 1 (STATE_OFF)
            if (display.state == 1 &&
                            (display.name.contains("ScreenCapture") ||
                                    display.name.contains("flutter_webrtc"))
            ) {
                Log.d("CastNow", "Virtual display ($displayId) turned OFF. Stopping session.")
                val serviceIntent = Intent(this, MediaProjectionService::class.java)
                stopService(serviceIntent)
                castCode = null
                runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
            }
        }
    }

    override fun onDisplayRemoved(displayId: Int) {
        Log.d("CastNow", "Display Removed: $displayId.")
        if (castCode != null) {
            Log.d("CastNow", "Display removed while casting. Stopping service synchronously.")
            val serviceIntent = Intent(this, MediaProjectionService::class.java)
            stopService(serviceIntent)
            castCode = null
            runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(stopReceiver)
        } catch (e: Exception) {}
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(this)
    }
}
