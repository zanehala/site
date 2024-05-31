---
title: "Monitoring Water Usage With Radio, Prometheus, and Grafana"
date: 2024-5-31
draft: false
---

A few months ago I got a water bill that was suspiciously high. I assumed I had a leak so I went to my water meter to check the low flow indicator (the small dial on most water meters) to see if it was moving.
It didn't move at all, but while I was there I noticed my water meter had a small gray box with an FCC ID on top. I threw that into google and came across a project, [rtlamr](https://github.com/bemasher/rtlamr), to receive and decode messages sent by consumption meters
and I happened to have a compatible meter. I also already happened to have a cheap RTL-SDR (Realtek Software Defined Radio) dongle from a few years ago. At this point I had everything I needed to begin receiving and decoding the messages sent by my water meter.
I was just missing one thing, the ability to track water usage over time. The first thing that came to mind was to use [Prometheus](https://prometheus.io/), a high fairly high performance and efficient time-series database for metrics. I have that set up in my home
Kubernetes cluster already so that seemed like a natural choice. I just needed something to translate the JSON output from rtlamr to Prometheus format and set up a scrape configuration to tell Prometheus to begin collecting these metrics.

I wrote a small program [rtlamr-exporter](https://github.com/zanehala/rtlamr-exporter) to do just that. It simply reads the output of rtlamr over `stdin` and runs a small web server that emits the Prometheus metrics.
```bash
$ rtlamr -format=json | rtlamr-exporter
```

I set up the RTL-SDR, rtlamr and rtlamr-exporter on a Raspberrypi I also had sitting around and configured Prometheus to begin scraping it.
```yaml
        - job_name: "rtlamr-exporter"
          scrape_interval: 60s
          scheme: http
          static_configs:
            - targets: ['192.168.1.245:9090']
```

After a few minutes passed I started seeing a number of consumption meters showing up.

I've let this run for about a month at this point collecting data on any sort of meter that happens to be broadcasting, and found some interesting things.

The first oddity is the rate at which I'm picking up unique consumption meters. I assumed I would get a sharp spike initially, and then pick up a few new ones here and there.
However I seem to be steadily gaining new ones about every day. The graph below shows the count of unique consumption meters by their ID's.

![Unique meter count](/images/meter-count.png)

The next is the type of meters I've been picking up. Each "type" of meter broadcasts what commodity it is measuring, generally, water, gas or electricity. This is generally known as its "ERT type".
The rtlamr repository keeps track of a list of meters by make and model and the ERT type they measure, however I've been getting a lot of meters that are not on that list. Finding any sort of information on what these types
represent is fairly tricky since this is a rather niche subject. The graph below shows a count of consumption meters by their ERT type.

![Meter types](/images/meter-types.png)

You might be wondering if I was able to use this to find out if I had a leak or not. Unfortunately (or more likely, fortunately), it looks like we just used more water than usual that month.
I had a good opportunity to check for leaks one week while both my wife and I were out of the house, and we no water usage during that time. Below is the water usage for our house specifically.
The units are in cubic feet, which roughly equates to 7.48 gallons per cubic foot of water.

![Meter usage](/images/meter-usage.png)

Depending on your power or gas meter you might also be able to pick those up as well, unfortunately, both my power and gas meters are incompatible with rtlamr.

Some of the protocols rtlamr can pick up contain some other interesting tidbits, like tamper flags, leak and backflow flags as well. I decided to not include those in my Prometheus exporter to keep cardinality a bit lower. While I'm picking up
less that 200 meters at the moment, if you were to run this in a city it's very likely you'd get thousands. 

Pretty cool stuff right? But this is all being transmitted unencrypted in plain text and unsigned so there are probably some security concerns here right? Probably.
In theory you could broadcast spoofed packets with greater power than your meter at a fixed consumption reading. Although that may constitute jamming, a federal offense, but then again tampering with public utility readings will probably also get you in trouble.
Or if you know someones meter ID, determine some habits like when they are home or not. Generally the meter ID's are printed on the outside case of the meter itself.
