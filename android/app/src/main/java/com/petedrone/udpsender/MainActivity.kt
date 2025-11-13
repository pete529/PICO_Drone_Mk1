package com.petedrone.udpsender

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.*
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                SenderScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SenderScreen() {
    val coroutineScope = rememberCoroutineScope()
    var ip by remember { mutableStateOf("192.168.4.1") }
    var port by remember { mutableStateOf("8888") }
    var throttle by remember { mutableStateOf(0f) }
    var roll by remember { mutableStateOf(0f) }
    var pitch by remember { mutableStateOf(0f) }
    var yaw by remember { mutableStateOf(0f) }
    var bat by remember { mutableStateOf("") }
    var rssi by remember { mutableStateOf("") }
    var armed by remember { mutableStateOf(false) }
    var useSignature by remember { mutableStateOf(true) }

    var ack by remember { mutableStateOf("") }
    var sendJob by remember { mutableStateOf<Job?>(null) }

    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedTextField(value = ip, onValueChange = { ip = it }, label = { Text("Pico IP (AP)") })
        OutlinedTextField(value = port, onValueChange = { port = it }, label = { Text("UDP Port") })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Armed",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            Switch(
                checked = armed,
                onCheckedChange = { armed = it },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = MaterialTheme.colorScheme.primary,
                    checkedTrackColor = MaterialTheme.colorScheme.primaryContainer,
                    uncheckedThumbColor = MaterialTheme.colorScheme.surfaceVariant,
                    uncheckedTrackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                )
            )
            Text(
                text = "Signature DRN",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            Switch(
                checked = useSignature,
                onCheckedChange = { useSignature = it },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = MaterialTheme.colorScheme.primary,
                    checkedTrackColor = MaterialTheme.colorScheme.primaryContainer,
                    uncheckedThumbColor = MaterialTheme.colorScheme.surfaceVariant,
                    uncheckedTrackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                )
            )
        }
        // Dual joysticks: left (yaw/throttle Y), right (roll/pitch)
        JetStickPair(
            onLeft = { x, y ->
                yaw = x.coerceIn(-1f, 1f)
                throttle = ((y + 1f) / 2f).coerceIn(0f, 1f) // map [-1..1] -> [0..1]
            },
            onRight = { x, y ->
                roll = x.coerceIn(-1f, 1f)
                pitch = y.coerceIn(-1f, 1f)
            }
        )
        Text("T=${"%.2f".format(throttle)} R=${"%.2f".format(roll)} P=${"%.2f".format(pitch)} Y=${"%.2f".format(yaw)}")

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Button(
                onClick = {
                    if (sendJob?.isActive == true) return@Button
                    val targetPort = port.toIntOrNull()
                    if (targetPort == null) {
                        ack = "Invalid port"
                        return@Button
                    }
                    val address = runCatching { InetAddress.getByName(ip) }.getOrElse {
                        ack = "Invalid IP"
                        return@Button
                    }
                    val job = coroutineScope.launch(Dispatchers.IO) {
                        DatagramSocket().use { sock ->
                            sock.soTimeout = 200
                            while (isActive) {
                                val prefix = if (useSignature) "DRN," else ""
                                val throttleValue = if (armed) throttle else 0f
                                val msg = "$prefix${throttleValue},${roll},${pitch},${yaw}\n"
                                val bytes = msg.toByteArray()
                                val pkt = DatagramPacket(bytes, bytes.size, address, targetPort)
                                sock.send(pkt)
                                try {
                                    val buf = ByteArray(128)
                                    val rx = DatagramPacket(buf, buf.size)
                                    sock.receive(rx)
                                    val response = String(rx.data, 0, rx.length).trim()
                                    withContext(Dispatchers.Main) {
                                        ack = response
                                        response.split(" ").forEach { part ->
                                            when {
                                                part.startsWith("BAT=") -> bat = part.removePrefix("BAT=")
                                                part.startsWith("RSSI=") -> rssi = part.removePrefix("RSSI=")
                                            }
                                        }
                                    }
                                } catch (_: Exception) {
                                    // We only care about successful ACK frames
                                }
                                delay(20)
                            }
                        }
                    }
                    job.invokeOnCompletion {
                        coroutineScope.launch {
                            sendJob = null
                        }
                    }
                    sendJob = job
                },
                enabled = sendJob?.isActive != true
            ) { Text("Start") }
            Button(
                onClick = {
                    sendJob?.cancel()
                    sendJob = null
                },
                enabled = sendJob != null
            ) { Text("Stop") }
            Column {
                Text("ACK: $ack")
                if (bat.isNotEmpty()) Text("BAT: $bat V")
                if (rssi.isNotEmpty()) Text("RSSI: $rssi dBm")
            }
        }
    }
}
