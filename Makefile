.PHONY: default build-remote bumpversion release minikube-test build-remote-minikube

VERSION=$(shell git describe --tags)
SHELL:=/bin/bash

default:
	@echo "See http://www.telepresence.io/additional-information/developing.html"

version:
	@echo $(VERSION)

build-remote:
	cd remote && sudo docker build . -t datawire/telepresence-k8s:$(VERSION)

virtualenv:
	virtualenv --python=python3 virtualenv
	virtualenv/bin/pip install -r dev-requirements.txt
	virtualenv/bin/pip install -r remote/requirements.txt

virtualenv/bin/sshuttle-telepresence:
	packaging/build-sshuttle.py

bumpversion: virtualenv
	virtualenv/bin/bumpversion --verbose --list minor
	@echo "Please run: git push origin master --tags"

build-remote-minikube:
	eval $(shell minikube docker-env) && \
		cd remote && \
		docker build . -q -t datawire/telepresence-k8s:$(VERSION)

run-minikube: virtualenv/bin/sshuttle-telepresence
	source virtualenv/bin/activate && \
		env TELEPRESENCE_VERSION=$(VERSION) cli/telepresence --method=vpn-tcp --new-deployment test --run-shell

# Run tests in minikube:
minikube-test: virtualenv build-remote-minikube
	@echo "IMPORTANT: this will change kubectl context to minikube!\n\n"
	kubectl config use-context minikube
	env TELEPRESENCE_VERSION=$(VERSION) ci/test.sh

release: build-remote
	sudo docker push datawire/telepresence-k8s:$(VERSION)
	env TELEPRESENCE_VERSION=$(VERSION) packaging/homebrew-package.sh
	packaging/create-linux-packages.py $(VERSION)
	packaging/upload-linux-packages.py $(VERSION)
