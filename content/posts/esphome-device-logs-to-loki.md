---
title: "Shipping ESPHome device logs to Loki + debugging adventure"
date: 2025-06-28
draft: false
---

I have a random smattering of ESP32 microcontrollers around the house running ESPHome, one of which was having random disconnects throughout the day. This ESP32 in particular was responsible for controlling one of my Mitsubishi heat pumps, so I was keen on making sure
it was reliable. 

ESPHome has a device log viewer you can access via the web, however the logs are only collected if that browser session is active.
You can also get device logs directly off the device from the UART bus, neither of which seemed particularly appealing.

Fortunately, ESPHome also has a built in HTTP client I could potentially use to just `POST` logs to the Loki instance I run in my homelab.
I also figured this would be a good opportunity to try out Gemini 2.5 flash against some more technical questions than what I usually throw at it.
I've been a big fan of Gemini 2.5 flash recently, it seems to be fairly accurate with reasonably well grounded "facts" and frequently citing sources. 
Plus having a very generous (unlimited?) free tier, it's brought me around to using AI for more day to day tasks and questions. 

The first step was enabling ingress to expose Loki's push API. After that was done I started taking a crack at the ESPHome side of things.
Loki has a pretty simple endpoint that allows you to `POST` logs to it, it's looking for the following simple JSON schema:
```json
{
  "streams": [
    {
      "stream": {
        "label": "value"
      },
      "values": [
          [ "<unix epoch in nanoseconds>", "<log line>" ],
          [ "<unix epoch in nanoseconds>", "<log line>" ]
      ]
    }
  ]
}
// grafana.com/docs/loki/latest/reference/loki-http-api/#ingest-logs
```

I asked Gemini to convert this to the ArduinoJson, which is the underlying JSON library ESPHome uses, it gave me a pretty decent starting point.
```c++
JsonArray streams = root.createNestedArray("streams");
JsonObject stream_object = streams.createNestedObject();
JsonObject stream_labels = stream_object.createNestedObject("stream");

// Populate stream labels
stream_labels["instance"] = "south-bedroom-heatpump"; // Device name
stream_labels["level"] = level; // Log level (INFO, DEBUG, etc.)
stream_labels["tag"] = tag;     // Log tag

// Create the values array
JsonArray values_array = stream_object.createNestedArray("values");

// Get current time in microseconds
long long current_time_us = id(ha_time).now().timestamp; 
// Convert to nanoseconds
std::string nanoseconds_str = to_string(current_time_us) + "0000"; 

// Create the inner array for the log entry [timestamp, log_line]
JsonArray log_entry = values_array.createNestedArray();
log_entry.add(nanoseconds_str); // Add timestamp string
log_entry.add(message)
```

While this was a pretty good starting point, it made some incorrect assumptions. Mainly the timestamp being in microseconds (it's actually just seconds), and the log messages containing ANSI color codes.
Both of which caused Loki to refuse the request and lead me down an interesting debugging path.

### Debugging
I was unable to get the response from Loki to log out on the ESP32 side, and all I was able to see from ingress logs was that Loki returned a 400 status code. 
Loki itself was also not emitting any logs showing it received a malformed payload. So the next thing I tried was pointing the ESP32 to send the logs to webhook.site momentarily,
so I could inspect the payload. Other than the ANSI color codes and the timestamp obviously not being in nanoseconds, the payload itself looked fine. I padded the timestamp with a bunch of zeros
and tried sending the same payload to Loki via Curl on my machine, and the request succeeded. Easy enough fix I thought, I added some additional zeros and pointed the ESP32 back to Loki, yet still no logs were appearing.

At this point I was pretty stumped, the payload appeared to be correct, I could send it from my machine but the ESP32 could not. I figured at this point I needed to inspect the traffic between the ESP32 and Loki a little more closely. I asked Gemini to give me a simple Kubernetes manifest for a privileged pod running [netshoot](https://github.com/nicolaka/netshoot) I could use to do packet capture on the node Loki runs on.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: netshoot-privileged
  labels:
    app: netshoot
spec:
  # This section ensures the pod is only scheduled on a node
  # with the label 'kubernetes.io/hostname: metal1'.
  nodeSelector:
    kubernetes.io/hostname: metal1
  hostNetwork: true
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    # The 'securityContext' allows the container to run in privileged mode,
    # which grants it all capabilities of the host. Use with caution.
    securityContext:
      privileged: true
    # This command keeps the container running indefinitely,
    # allowing you to exec into it for network troubleshooting.
    command: ["tail", "-f", "/dev/null"]
```

After the pod was running I ran 
```console
$ kubectl exec -i netshoot-privileged -- tcpdump -i cni0 -w - | wireshark -k -i -
```
on my machine to open a session on the netshoot pod, running tcpdump against the container network interface device, finally piping the output to wireshark on my machine.

This let me inspect the traffic going to Loki (and every other container running on the node)