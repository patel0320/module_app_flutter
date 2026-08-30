package com.soleux.sdm

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "soleux.device_manager/wifi_lock"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "acquire" -> {
                        acquireMulticastLock()
                        result.success(true)
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("WIFI_LOCK", e.message, null)
            }
        }
    }

    // WiFi NICs drop broadcast/multicast frames unless the app holds a
    // WifiManager.MulticastLock; without it UDP device discovery silently
    // fails on Android phones. Requires CHANGE_WIFI_MULTICAST_STATE.
    private fun acquireMulticastLock() {
        val lock = multicastLock
        if (lock != null && lock.isHeld) return
        val wifi =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val newLock = wifi.createMulticastLock("soleux-device-manager-discovery")
        newLock.setReferenceCounted(true)
        newLock.acquire()
        multicastLock = newLock
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock
        if (lock != null && lock.isHeld) {
            lock.release()
        }
    }
}