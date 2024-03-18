
FCOS_HOMENET_REPO = ghcr.io/lawrencegripper/homenet-fcos

build-fcos-native-container:
	# Pulling the latest Fedora CoreOS image
	docker pull quay.io/fedora/fedora-coreos:stable

	# Build base layer
	docker build \
		-f machine-config-fcos/ostree-native-container/homenet-fcos.containerfile \
		--target homenet-fcos-base \
		--tag $(FCOS_HOMENET_REPO):base \
		--no-cache \
		machine-config-fcos/ostree-native-container/
	docker push $(FCOS_HOMENET_REPO):base

	# Build docker variant
	docker build \
		-f machine-config-fcos/ostree-native-container/homenet-fcos.containerfile \
		--target homenet-fcos-docker \
		--tag $(FCOS_HOMENET_REPO):docker \
		--no-cache \
		machine-config-fcos/ostree-native-container/
	docker push $(FCOS_HOMENET_REPO):docker

	# Build k3s variant
	docker build \
		-f machine-config-fcos/ostree-native-container/homenet-fcos.containerfile \
		--target homenet-fcos-k3s \
		--tag $(FCOS_HOMENET_REPO):k3s \
		--no-cache \
		machine-config-fcos/ostree-native-container/
	docker push $(FCOS_HOMENET_REPO):k3s
