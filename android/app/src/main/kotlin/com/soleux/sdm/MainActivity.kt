package com.soleux.sdm

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

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
                    "ipv4LinkInfo" -> {
                        result.success(activeIpv4LinkInfo())
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

    // Returns the active network's IPv4 link address (interface name, address,
    // and CIDR prefix length) for the Dart-side directed-broadcast math.
    // Reading /proc/net/route is blocked by SELinux for untrusted_app, so the
    // prefix is sourced from ConnectivityManager.LinkProperties instead.
    // Requires API 23+; returns null (Dart falls back to /24 + global
    // broadcast) on older releases. Needs ACCESS_NETWORK_STATE.
    private fun activeIpv4LinkInfo(): Map<String, Any>? {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M) {
            return null
        }
        val cm =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager
        val network = cm.activeNetwork ?: return null
        val lp = cm.getLinkProperties(network) ?: return null
        for (link in lp.linkAddresses) {
            val address = link.address ?: continue
            if (address is Inet4Address) {
                return mapOf(
                    "interface" to (lp.interfaceName ?: ""),
                    "ip" to address.hostAddress,
                    "prefix" to link.prefixLength
                )
            }
        }
        return null
    }
}