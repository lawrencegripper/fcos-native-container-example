# Fedora CoreOS - Managing Machine with Native Containers

This repo has my example scripts for creating and using
native containers to manager FCOS hosts. 

## How does it work?

### Getting a VM

First we create a VM, give it SSH keys and tell it to use our 
docker image for configuration. To do that I use [Butane](https://coreos.github.io/butane/examples/)

Run `build-image.sh matrix2` this will
1. Install tools needed
2. Use the butane config in the `./butane` folder to get an ignition file for boot strapping our VM
3. Download latest FCOS qcow image and expand it's size
4. Start it using libvirt for testing (requires linux host with libvirt)

The `butane` config uses the `merge` option to have a [`_shared-config`](butane/_shared-config.bu.tmpl) then combine this with a machine specific set of config like [`k3s.bu.tmpl`](butane/k3s.bu.tmpl)

In the butane I use the 1Password CLI to inject secrets, [like I do for Kube config](https://blog.gripdev.xyz/2024/02/26/homelab-using-1password-cli-to-handle-secrets-in-kubernetes-compose-yaml/). 

Mainly the config is about creating a `rebase` service which 
configures the host to use a Native container image. 

The `rebase` service executes:

```
ExecStart=/usr/bin/rpm-ostree rebase --reboot --bypass-driver ostree-unverified-registry:${IMAGE_URL}
```

Where `IMAGE_URL` is set in the host specific host and lets us pick what packages and services exist on a node by choosing a different docker image.

The `butane` also formats and mounts a `data` dir, in my case this ends up as ISCI mounted from TrueNAS after I've done testing.

### Changing the container image

The `ostree-native-container` folder holds the container image which will be used to configure the native FCOS hosts. 

It has 3 versions, `base`, `docker` and `k3s` each with different packages. 

To update the container image, and hence the VM, run `make build-fcos-native-container`

In these images I configure services, files and packages for the nodes. 

For example, here I add packages I want on the node:

```
ADD ./rpm-repos/tailscale-stable.repo /etc/yum.repos.d/
RUN rpm-ostree install tailscale && ostree container commit
```

and here I add files, like systemd services:

```
COPY overlay-base/ /
RUN systemctl enable tailscale-configure.service && systemctl enable tailscaled.service && systemctl enable update.service && ostree container commit
```

This copies the content of `overlay-base` into the root dir on the node. 

The files include scripts like [`rpm-ostree-container-update`](ostree-native-container/overlay-base/usr/bin/rpm-ostree-container-update.sh) which handle updating the node when a new image is available and [`tailscale-configure.service`](ostree-native-container/overlay-base/usr/lib/systemd/system/tailscale-configure.service) which setup Tailscale on the node. 

## Done

Now the VM you started will pull configuration from the docker image we push. 

Want to add a new user? Enable/Disable a systemd service? Add a package?

For all of these you update the docker file, build and push then the VM will pull and update itself. 