
# Image URL to use all building/pushing image targets
IMG ?= controller:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:preserveUnknownFields=false,crdVersions=v1,trivialVersions=true"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

all: manager

# Run tests
test: generate fmt vet manifests
	go test ./... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./main.go

# Install CRDs into a cluster
install: manifests
	kustomize build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall: manifests
	kustomize build config/crd | kubectl delete -f -

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	cd config/manager && kustomize edit set image controller=${IMG}
	kustomize build config/default | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Build manager binary for container
release-build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o manager main.go

# Build the docker image
docker-build:
	docker build . -t ${IMG}

# Push the docker image
docker-push:
	docker push ${IMG}

# Clean up binary
clean:
	rm manager

# Build and push container image
release: test release-build docker-build docker-push clean

# find or download controller-gen
# download controller-gen if necessary
controller-gen:
ifeq (, $(shell which controller-gen))
	@{ \
	set -e ;\
	CONTROLLER_GEN_TMP_DIR=$$(mktemp -d) ;\
	cd $$CONTROLLER_GEN_TMP_DIR ;\
	go mod init tmp ;\
	go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.2.5 ;\
	rm -rf $$CONTROLLER_GEN_TMP_DIR ;\
	}
CONTROLLER_GEN=$(GOBIN)/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif

# Build the companion CLI
build-cli:
	go build -o bin/tanzu-ns-ctl cmd/tanzu-ns-ctl/main.go

k8s-platform:
	kubectl apply -f config/crd/bases/tenancy.platform.cnr.vmware.com_tanzunamespaces.yaml -f config/rbac/clusterrole.yaml -f config/samples/deployment.yaml

k8s-resources-backwards:
	kubectl apply -f config/samples/backwards_tenancy_v1alpha_tanzunamespace.yaml

k8s-resources-defaults:
	kubectl apply -f config/samples/defaults_tenancy_v1alpha1_tanzunamespace.yaml

k8s-resources-sample:
	kubectl apply -f config/samples/tenancy_v1alpha1_tanzunamespace.yaml

k8s-platform-clean:
	kubectl delete -f config/samples/deployment.yaml -f config/crd/bases/tenancy.platform.cnr.vmware.com_tanzunamespaces.yaml -f config/rbac/clusterrole.yaml

k8s-resources-clean:
	kubectl delete -f config/samples/backwards_tenancy_v1alpha_tanzunamespace.yaml -f config/samples/tenancy_v1alpha1_tanzunamespace.yaml
