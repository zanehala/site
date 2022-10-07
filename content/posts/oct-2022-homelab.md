---
title: "State of the Homelab - October 2022"
date: 2022-10-06
draft: false
---

I started writing this sometime back in August but never got around to finishing this post until
a few coworkers started asking about my homelab to build their own. So I figured I could kill a
couple birds with a few stones, help them out and finally start putting something interesting
on this site.

I've been a homelabber since middle school, initially using old laptops and netbooks that people
were throwing out. At one point I think I had a stack of 6 laptops piled up in my basement running
various flavors of Ubuntu or Centos. Eventually in highschool after I got my first job as a sysadmin
intern I bought a Dell R410 with a pair of *old* Xeon's and 48GB of ECC RAM (a reasonably impressive feat
to have in your basement at the time). I ran VMware ESXi on the R410 and set it up to somewhat emulate
the data center we ran at my job. I used what I learned from that set up to get my next 2 
internships and eventually my first full time job. I still have the R410 around but I don't fire it
up often since my mom isn't paying for the power bill anymore. 

### High Level Overview
My homelab at this current moment consists of:
 - A HP T620 plus thin client running PFsense
 - A cheap semi managed 8 port TP-Link switch
 - 5 micro form factor Dell Optiplex 7050's
 - An old Dell Optiplex 390 running Truenas Scale

My main goals with this set up are:
 - Be quiet
 - Be cheap
 - Use as little power as possible

## Networking
### HP T620 plus
This was one of my first purchases for the lab. In the past on my R410 I just ran PFsense in a VM to handle
routing and separating my lab subnet from the rest of my LAN. However this time I wanted to put it between 
my WAN and LAN so I could use it to protect my LAN and run ad blocking tools on it. I bought this off of
eBay along with a cheap Intel 4 port NIC card to put in it. This has a pretty old AMD Jaguar processor in it
but it supports the AES-IN instruction set so it handles most crypto operations pretty well and so far hasn't
been a bottleneck. 

### TP-Link TL-SG108E
I don't have a ton to say about this switch. It was cheap, low power, and supports link aggregation.
It did happen to default to an IP already in use on my lab subnet when I initially got it. That was a little
bit of a head scratcher to figure out. But otherwise its been pretty solid since.

## Compute
### Dell 7050 Micro's
I've been reading ServeTheHome's [TinyMinyMicro](https://www.servethehome.com/tag/tinyminimicro/) 
series for a while which is where I got the idea to use micro form factor PC's. After looking around 
on eBay for a few weeks it seemed like the Dell 7050's were the best bang for the buck, and I thought 
they looked the best too. I snagged all of them from eBay as well, I bought one
and then found a lot of 4 for sale for a steal. The lot of 4 also conveniently happened to be in Des Moines, so I 
bought them and emailed the recycling company to see if I could just go pick them up, which they agreed to.

They came in various builds, some with no drives, some with no RAM, some Intel 6600T's, 7600T's and one 7600 (non T). 
I had a couple older SSD's lying around I threw in and ordered a couple Samsung NVME drives for the others as well 
as enough RAM to bring them all up to at least 16GB.

I use four of the five 7050's to run a Kubernetes cluster, which I'll get into later on in this post.
The fifth one I kitted out with a 1TB NVME drive and 32GB of RAM to run Proxmox on. I use this to host various VM's
and to try out Proxmox since the only other hypervisor I've had experience with is ESX.

These machines idle anywhere between 9-15w and are usually inaudible. These plus my networking gear draws ~100w which
is not bad in my book.

![Nodes](/images/nodes.jpeg)

## Storage
### Dell 390
I had an old Dell Optiplex 390 laying around that my previous job was getting rid of. It's got an i5-2500 and 
32GB of RAM and an old 240GB SSD for the boot drive. It's also got an LSI 9207 HBA card in it which has 2 SAS ports,
I split those SAS ports out into 8 SATA ports which I use to hook up 5 used HGST Ultrastar 7K4000 4TB hard drives I got
off eBay. A few of the drives I bought were DOA, which I expected with buying used hard drives from eBay, though the 
seller promptly sent me some replacements. I also have 2 SATA power extension cords running out the back of an empty 
PCI slot to power the drives. Which sit in 3D printed caddies inside a 3D printed drive cage. This works pretty well 
except it looks very janky and the drives get warm enough to warp the drive cage. 

It runs TrueNas Scale, which has so far worked out pretty well. I've got the drives in a RAIDZ2 configuration.
Since I expect these used drives to die at any moment I figured being able to tank 2 simultaneous drive failures 
would probably be a good idea. I've got TrueNas exposing a NFS share for Kubernetes to use, and I'm also using the 
built in Minio functionality to have some S3 like object storage.

![Storage](/images/storage.jpeg)

### Kubernetes
One of the biggest drivers behind this lab was to get a much deeper familiarity with Kubernetes. I was already fairly 
proficient in my knowledge of Kubernetes from my current job, having written some applications and operators that 
run in our clusters. But I wanted to get a more hands on feel and break things without interrupting the other guys
at work. 

I spent a lot of time looking into how I was going to initially provision my machines, most solutions were pretty heavy
and cumbersome. I eventually found [Khue's homelab repo](https://github.com/khuedoan/homelab) which just spins up a 
container to handle PXE booting the machines and then uses ansible for the rest. I liked how his repo was laid out 
and setup so I forked it and used it as the base of my cluster as well. It uses ArgoCD applicationsets and watches
the repo for any changes, when it detects a change it attempts to reconcile the cluster to match the repo. This gitops
approach has worked out pretty well so far, however secrets management and the occasional prometheus custom resource
being too large has made some changes more manual than automated. 

For a more in depth look at my cluster you can [check out my repo](https://github.com/zanehala/homelab). 
The readme shows most of the things I run in it.

## The Future
At some point I'd like to get a 10GBE switch for the lab. The prices on those have dropped a lot in recent years and
MikroTik offers to pretty nice 8 port SFT+ switches for < $300. The 7050's however can't handle 10GBE, but the USBC 3.1 
ports on the front can handle 2.5GBE dongles, which would still be a 150% increase.

I may at some point also put Proxmox on all the 7050's and cluster them together and run Kubernetes on VM's. That way I
have a little more flexibility in doling out compute resources. That would also allow me to use an immutable OS so any 
OS level changes I need to make I don't have to make a ansible playbook to apply to all nodes, I can just build a new image
and cycle them.