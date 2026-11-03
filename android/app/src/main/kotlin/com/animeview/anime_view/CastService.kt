package com.animeview.anime_view

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.InetAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * CastService — A lightweight Chromecast implementation using mDNS discovery
 * and the Google Cast V2 protocol (protobuf-like TLS communication).
 *
 * Uses the Default Media Receiver (CC1AD845) so no app registration is needed.
 */
class CastService(private val context: Context) {

    companion object {
        private const val TAG = "CastService"
        private const val CAST_SERVICE_TYPE = "_googlecast._tcp."
        private const val DEFAULT_MEDIA_RECEIVER_APP_ID = "CC1AD845"
        private const val CAST_PORT = 8009
    }

    data class CastDevice(
        val id: String,
        val name: String,
        val host: InetAddress,
        val port: Int,
        val model: String = ""
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val discoveredDevices = CopyOnWriteArrayList<CastDevice>()
    private var isDiscovering = false
    private var multicastLock: WifiManager.MulticastLock? = null

    private var castSocket: SSLSocket? = null
    private var outputStream: OutputStream? = null
    private var connectedDevice: CastDevice? = null
    private var transportId: String? = null
    private var mediaSessionId: Int = 0
    private var requestId: Int = 1
    private var receiverThread: Thread? = null
    private var isConnected = false

    var methodChannel: MethodChannel? = null

    // =================== DEVICE DISCOVERY ===================

    fun startDiscovery() {
        if (isDiscovering) return
        discoveredDevices.clear()
        isDiscovering = true

        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("CastMulticastLock")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire multicast lock: ${e.message}")
        }

        nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "mDNS discovery started for $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Found service: ${serviceInfo.serviceName}")
                nsdManager?.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.w(TAG, "Resolve failed for ${serviceInfo.serviceName}: $errorCode")
                    }

                    override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                        val host = serviceInfo.host
                        val port = serviceInfo.port
                        val name = serviceInfo.serviceName
                        val model = serviceInfo.attributes["md"]?.let { String(it) } ?: ""
                        val id = serviceInfo.attributes["id"]?.let { String(it) } ?: name

                        if (host != null) {
                            val device = CastDevice(
                                id = id,
                                name = name,
                                host = host,
                                port = port,
                                model = model
                            )
                            // Avoid duplicates
                            if (discoveredDevices.none { it.id == device.id }) {
                                discoveredDevices.add(device)
                                notifyDeviceFound(device)
                            }
                        }
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                discoveredDevices.removeAll { it.name == serviceInfo.serviceName }
                notifyDevicesUpdated()
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "mDNS discovery stopped")
                isDiscovering = false
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                isDiscovering = false
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }
        }

        try {
            nsdManager?.discoverServices(CAST_SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery: ${e.message}")
            isDiscovering = false
        }
    }

    fun stopDiscovery() {
        if (!isDiscovering) return
        try {
            discoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping discovery: ${e.message}")
        }
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (_: Exception) {}
        multicastLock = null
        isDiscovering = false
    }

    fun getDiscoveredDevices(): List<Map<String, Any>> {
        return discoveredDevices.map { device ->
            mapOf(
                "id" to device.id,
                "name" to device.name,
                "host" to device.host.hostAddress.orEmpty(),
                "port" to device.port,
                "model" to device.model
            )
        }
    }

    // =================== CAST CONNECTION ===================

    fun connectToDevice(deviceId: String, callback: (Boolean, String?) -> Unit) {
        val device = discoveredDevices.find { it.id == deviceId }
        if (device == null) {
            callback(false, "Device not found")
            return
        }

        executor.execute {
            try {
                disconnect()

                // Create TLS socket (trust all certs for Cast protocol)
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, arrayOf<TrustManager>(object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                    override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
                }), null)

                val socket = sslContext.socketFactory.createSocket(device.host, CAST_PORT) as SSLSocket
                socket.startHandshake()
                castSocket = socket
                outputStream = socket.outputStream
                connectedDevice = device
                isConnected = true

                // Start receiving messages
                startReceiver(socket)

                // Send CONNECT to receiver
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.tp.connection",
                    payload = """{"type":"CONNECT"}"""
                )

                // Launch Default Media Receiver
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.receiver",
                    payload = """{"type":"LAUNCH","appId":"$DEFAULT_MEDIA_RECEIVER_APP_ID","requestId":${requestId++}}"""
                )

                mainHandler.post { callback(true, null) }
                notifyConnectionChanged(true, device)

            } catch (e: Exception) {
                Log.e(TAG, "Connection failed: ${e.message}")
                isConnected = false
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    fun disconnect() {
        try {
            if (isConnected && castSocket != null) {
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.tp.connection",
                    payload = """{"type":"CLOSE"}"""
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error sending close: ${e.message}")
        }

        isConnected = false
        transportId = null
        mediaSessionId = 0
        receiverThread?.interrupt()
        receiverThread = null

        try { castSocket?.close() } catch (_: Exception) {}
        castSocket = null
        outputStream = null

        val wasConnected = connectedDevice != null
        connectedDevice = null
        if (wasConnected) {
            notifyConnectionChanged(false, null)
        }
    }

    // =================== MEDIA CONTROL ===================

    fun loadMedia(
        url: String,
        title: String,
        subtitle: String = "",
        thumbnailUrl: String = "",
        contentType: String = "video/mp4",
        startPosition: Double = 0.0,
        callback: (Boolean, String?) -> Unit
    ) {
        if (!isConnected || transportId == null) {
            callback(false, "Not connected to a Cast device")
            return
        }

        executor.execute {
            try {
                val mediaInfo = JSONObject().apply {
                    put("contentId", url)
                    put("contentType", contentType)
                    put("streamType", "BUFFERED")
                    put("metadata", JSONObject().apply {
                        put("type", 0)
                        put("metadataType", 0)
                        put("title", title)
                        put("subtitle", subtitle)
                        if (thumbnailUrl.isNotEmpty()) {
                            put("images", JSONArray().put(JSONObject().apply {
                                put("url", thumbnailUrl)
                            }))
                        }
                    })
                }

                val loadPayload = JSONObject().apply {
                    put("type", "LOAD")
                    put("media", mediaInfo)
                    put("autoplay", true)
                    put("currentTime", startPosition)
                    put("requestId", requestId++)
                }

                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = transportId!!,
                    namespace = "urn:x-cast:com.google.cast.media",
                    payload = loadPayload.toString()
                )

                mainHandler.post { callback(true, null) }

            } catch (e: Exception) {
                Log.e(TAG, "Load media failed: ${e.message}")
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    fun play() {
        sendMediaCommand("PLAY")
    }

    fun pause() {
        sendMediaCommand("PAUSE")
    }

    fun stop() {
        sendMediaCommand("STOP")
    }

    fun seek(position: Double) {
        if (!isConnected || transportId == null || mediaSessionId <= 0) return
        executor.execute {
            try {
                val payload = JSONObject().apply {
                    put("type", "SEEK")
                    put("mediaSessionId", mediaSessionId)
                    put("currentTime", position)
                    put("requestId", requestId++)
                }
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = transportId!!,
                    namespace = "urn:x-cast:com.google.cast.media",
                    payload = payload.toString()
                )
            } catch (e: Exception) {
                Log.e(TAG, "Seek failed: ${e.message}")
            }
        }
    }

    fun setVolume(volume: Double) {
        if (!isConnected) return
        executor.execute {
            try {
                val payload = JSONObject().apply {
                    put("type", "SET_VOLUME")
                    put("volume", JSONObject().apply {
                        put("level", volume.coerceIn(0.0, 1.0))
                    })
                    put("requestId", requestId++)
                }
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.receiver",
                    payload = payload.toString()
                )
            } catch (e: Exception) {
                Log.e(TAG, "Set volume failed: ${e.message}")
            }
        }
    }

    private fun sendMediaCommand(type: String) {
        if (!isConnected || transportId == null || mediaSessionId <= 0) return
        executor.execute {
            try {
                val payload = JSONObject().apply {
                    put("type", type)
                    put("mediaSessionId", mediaSessionId)
                    put("requestId", requestId++)
                }
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = transportId!!,
                    namespace = "urn:x-cast:com.google.cast.media",
                    payload = payload.toString()
                )
            } catch (e: Exception) {
                Log.e(TAG, "Media command $type failed: ${e.message}")
            }
        }
    }

    // =================== CAST PROTOCOL ===================

    /**
     * Send a Cast V2 protocol message.
     * The message format is a 4-byte big-endian length prefix followed by a
     * protobuf-serialized CastMessage. We use a simplified manual serialization
     * since we only need text-payload messages.
     */
    private fun sendCastMessage(
        sourceId: String,
        destinationId: String,
        namespace: String,
        payload: String
    ) {
        val os = outputStream ?: return

        synchronized(os) {
            try {
                // Build CastMessage protobuf manually
                // Field 1: protocol_version = 0 (CASTV2_1_0) — varint
                // Field 2: source_id — length-delimited string
                // Field 3: destination_id — length-delimited string
                // Field 4: namespace — length-delimited string
                // Field 5: payload_type = 0 (STRING) — varint
                // Field 7: payload_utf8 — length-delimited string

                val sourceBytes = sourceId.toByteArray(Charsets.UTF_8)
                val destBytes = destinationId.toByteArray(Charsets.UTF_8)
                val nsBytes = namespace.toByteArray(Charsets.UTF_8)
                val payloadBytes = payload.toByteArray(Charsets.UTF_8)

                val protoMessage = buildProtobuf(sourceBytes, destBytes, nsBytes, payloadBytes)

                // Write 4-byte big-endian length prefix
                val lengthPrefix = ByteBuffer.allocate(4)
                    .order(ByteOrder.BIG_ENDIAN)
                    .putInt(protoMessage.size)
                    .array()

                os.write(lengthPrefix)
                os.write(protoMessage)
                os.flush()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send message: ${e.message}")
            }
        }
    }

    private fun buildProtobuf(
        sourceId: ByteArray,
        destinationId: ByteArray,
        namespace: ByteArray,
        payload: ByteArray
    ): ByteArray {
        val buffer = mutableListOf<Byte>()

        // Field 1: protocol_version = 0, wire type 0 (varint)
        buffer.add(0x08.toByte()) // (1 << 3) | 0
        buffer.add(0x00.toByte()) // value = 0

        // Field 2: source_id, wire type 2 (length-delimited)
        buffer.add(0x12.toByte()) // (2 << 3) | 2
        buffer.addAll(encodeVarint(sourceId.size))
        buffer.addAll(sourceId.toList())

        // Field 3: destination_id, wire type 2
        buffer.add(0x1A.toByte()) // (3 << 3) | 2
        buffer.addAll(encodeVarint(destinationId.size))
        buffer.addAll(destinationId.toList())

        // Field 4: namespace, wire type 2
        buffer.add(0x22.toByte()) // (4 << 3) | 2
        buffer.addAll(encodeVarint(namespace.size))
        buffer.addAll(namespace.toList())

        // Field 5: payload_type = 0 (STRING), wire type 0
        buffer.add(0x28.toByte()) // (5 << 3) | 0
        buffer.add(0x00.toByte()) // value = 0

        // Field 7: payload_utf8, wire type 2
        buffer.add(0x3A.toByte()) // (7 << 3) | 2
        buffer.addAll(encodeVarint(payload.size))
        buffer.addAll(payload.toList())

        return buffer.toByteArray()
    }

    private fun encodeVarint(value: Int): List<Byte> {
        val result = mutableListOf<Byte>()
        var v = value
        while (v > 0x7F) {
            result.add((v and 0x7F or 0x80).toByte())
            v = v ushr 7
        }
        result.add((v and 0x7F).toByte())
        return result
    }

    // =================== MESSAGE RECEIVER ===================

    private fun startReceiver(socket: SSLSocket) {
        receiverThread = Thread {
            try {
                val inputStream = socket.inputStream
                val lengthBuffer = ByteArray(4)

                while (!Thread.currentThread().isInterrupted && isConnected) {
                    // Read 4-byte length prefix
                    var bytesRead = 0
                    while (bytesRead < 4) {
                        val read = inputStream.read(lengthBuffer, bytesRead, 4 - bytesRead)
                        if (read < 0) {
                            Log.d(TAG, "Socket closed by remote")
                            handleDisconnect()
                            return@Thread
                        }
                        bytesRead += read
                    }

                    val messageLength = ByteBuffer.wrap(lengthBuffer)
                        .order(ByteOrder.BIG_ENDIAN)
                        .int

                    if (messageLength <= 0 || messageLength > 1024 * 1024) {
                        continue
                    }

                    // Read message body
                    val messageBuffer = ByteArray(messageLength)
                    bytesRead = 0
                    while (bytesRead < messageLength) {
                        val read = inputStream.read(messageBuffer, bytesRead, messageLength - bytesRead)
                        if (read < 0) {
                            handleDisconnect()
                            return@Thread
                        }
                        bytesRead += read
                    }

                    // Parse protobuf manually
                    parseAndHandleMessage(messageBuffer)
                }
            } catch (e: Exception) {
                if (isConnected) {
                    Log.e(TAG, "Receiver error: ${e.message}")
                    handleDisconnect()
                }
            }
        }
        receiverThread?.isDaemon = true
        receiverThread?.start()

        // Start heartbeat
        startHeartbeat()
    }

    private fun parseAndHandleMessage(data: ByteArray) {
        try {
            // Extract fields from protobuf
            var offset = 0
            var namespace = ""
            var payload = ""
            var sourceId = ""

            while (offset < data.size) {
                val tag = data[offset].toInt() and 0xFF
                offset++

                val fieldNumber = tag ushr 3
                val wireType = tag and 0x07

                when (wireType) {
                    0 -> { // varint
                        var value = 0
                        var shift = 0
                        while (offset < data.size) {
                            val b = data[offset].toInt() and 0xFF
                            offset++
                            value = value or ((b and 0x7F) shl shift)
                            if (b and 0x80 == 0) break
                            shift += 7
                        }
                    }
                    2 -> { // length-delimited
                        var length = 0
                        var shift = 0
                        while (offset < data.size) {
                            val b = data[offset].toInt() and 0xFF
                            offset++
                            length = length or ((b and 0x7F) shl shift)
                            if (b and 0x80 == 0) break
                            shift += 7
                        }
                        if (offset + length <= data.size) {
                            val strValue = String(data, offset, length, Charsets.UTF_8)
                            when (fieldNumber) {
                                2 -> sourceId = strValue
                                4 -> namespace = strValue
                                7 -> payload = strValue
                            }
                            offset += length
                        } else {
                            break
                        }
                    }
                    else -> break
                }
            }

            if (payload.isNotEmpty()) {
                handleCastPayload(namespace, payload, sourceId)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse message: ${e.message}")
        }
    }

    private fun handleCastPayload(namespace: String, payload: String, sourceId: String) {
        try {
            val json = JSONObject(payload)
            val type = json.optString("type", "")

            when (namespace) {
                "urn:x-cast:com.google.cast.tp.heartbeat" -> {
                    if (type == "PING") {
                        sendCastMessage(
                            sourceId = "sender-0",
                            destinationId = sourceId,
                            namespace = "urn:x-cast:com.google.cast.tp.heartbeat",
                            payload = """{"type":"PONG"}"""
                        )
                    }
                }
                "urn:x-cast:com.google.cast.receiver" -> {
                    if (type == "RECEIVER_STATUS") {
                        val status = json.optJSONObject("status")
                        val apps = status?.optJSONArray("applications")
                        if (apps != null && apps.length() > 0) {
                            val app = apps.getJSONObject(0)
                            val newTransportId = app.optString("transportId", "")
                            if (newTransportId.isNotEmpty() && transportId != newTransportId) {
                                transportId = newTransportId
                                // Connect to the app's transport
                                sendCastMessage(
                                    sourceId = "sender-0",
                                    destinationId = newTransportId,
                                    namespace = "urn:x-cast:com.google.cast.tp.connection",
                                    payload = """{"type":"CONNECT"}"""
                                )
                            }
                        }

                        // Volume info
                        val volume = status?.optJSONObject("volume")
                        if (volume != null) {
                            val level = volume.optDouble("level", -1.0)
                            val muted = volume.optBoolean("muted", false)
                            if (level >= 0) {
                                notifyCastVolume(level, muted)
                            }
                        }
                    }
                }
                "urn:x-cast:com.google.cast.media" -> {
                    if (type == "MEDIA_STATUS") {
                        val statusArray = json.optJSONArray("status")
                        if (statusArray != null && statusArray.length() > 0) {
                            val mediaStatus = statusArray.getJSONObject(0)
                            mediaSessionId = mediaStatus.optInt("mediaSessionId", mediaSessionId)
                            val playerState = mediaStatus.optString("playerState", "UNKNOWN")
                            val currentTime = mediaStatus.optDouble("currentTime", 0.0)
                            val duration = mediaStatus.optJSONObject("media")
                                ?.optDouble("duration", 0.0) ?: 0.0

                            notifyMediaStatus(playerState, currentTime, duration)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to handle payload: ${e.message}")
        }
    }

    private fun startHeartbeat() {
        executor.execute {
            try {
                while (isConnected) {
                    Thread.sleep(5000)
                    if (isConnected) {
                        sendCastMessage(
                            sourceId = "sender-0",
                            destinationId = "receiver-0",
                            namespace = "urn:x-cast:com.google.cast.tp.heartbeat",
                            payload = """{"type":"PING"}"""
                        )
                    }
                }
            } catch (_: InterruptedException) {}
        }
    }

    private fun handleDisconnect() {
        isConnected = false
        connectedDevice = null
        transportId = null
        mediaSessionId = 0
        try { castSocket?.close() } catch (_: Exception) {}
        castSocket = null
        outputStream = null
        notifyConnectionChanged(false, null)
    }

    // =================== FLUTTER NOTIFICATIONS ===================

    private fun notifyDeviceFound(device: CastDevice) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastDeviceFound", mapOf(
                "id" to device.id,
                "name" to device.name,
                "host" to device.host.hostAddress.orEmpty(),
                "port" to device.port,
                "model" to device.model
            ))
        }
    }

    private fun notifyDevicesUpdated() {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastDevicesUpdated", getDiscoveredDevices())
        }
    }

    private fun notifyConnectionChanged(connected: Boolean, device: CastDevice?) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastConnectionChanged", mapOf(
                "connected" to connected,
                "deviceName" to (device?.name ?: ""),
                "deviceId" to (device?.id ?: "")
            ))
        }
    }

    private fun notifyMediaStatus(state: String, currentTime: Double, duration: Double) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastMediaStatus", mapOf(
                "state" to state,
                "position" to currentTime,
                "duration" to duration
            ))
        }
    }

    private fun notifyCastVolume(level: Double, muted: Boolean) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastVolumeChanged", mapOf(
                "level" to level,
                "muted" to muted
            ))
        }
    }

    fun isConnected(): Boolean = isConnected
    fun getConnectedDeviceName(): String = connectedDevice?.name ?: ""

    fun destroy() {
        stopDiscovery()
        disconnect()
        executor.shutdownNow()
    }
}
