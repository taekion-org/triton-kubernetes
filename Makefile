VERSION=$(shell git describe --tags)
LDFLAGS=-X github.com/joyent/triton-kubernetes/cmd.cliVersion=$(shell git rev-list -1 HEAD)
BUILD_PATH=build

OSX_ARCHIVE_PATH=$(BUILD_PATH)/triton-kubernetes_$(VERSION)_osx-amd64.zip
OSX_BINARY_PATH=$(BUILD_PATH)/triton-kubernetes_osx-amd64
OSX_TMP_DIR=$(BUILD_PATH)/build-osx-tmp

LINUX_ARCHIVE_PATH=$(BUILD_PATH)/triton-kubernetes_$(VERSION)_linux-amd64.zip
LINUX_BINARY_PATH=$(BUILD_PATH)/triton-kubernetes_linux-amd64
LINUX_TMP_DIR=$(BUILD_PATH)/build-linux-tmp

RPM_FILE_NAME=triton-kubernetes_$(VERSION)_linux-amd64.rpm
RPM_PATH=$(BUILD_PATH)/$(RPM_FILE_NAME)
RPM_INSTALL_DIR=/usr/bin
RPM_TMP_DIR=$(BUILD_PATH)/build-rpm-tmp

DEB_FILE_NAME=triton-kubernetes_$(VERSION)_linux-amd64.deb
DEB_PATH=$(BUILD_PATH)/$(DEB_FILE_NAME)
DEB_INSTALL_DIR=/usr/bin
DEB_TMP_DIR=$(BUILD_PATH)/build-deb-tmp

clean:
	@rm -rf ./build

build: clean build-osx build-linux build-rpm build-deb
	@echo "Generating checksums..."
	@cd build; shasum -a 256 * > sha256-checksums.txt

build-local: clean build-osx

build-osx: clean
	@echo "Building OSX..."
#	Copying and renaming the linux binary to just 'triton-kubernetes'. Making a temp directory to avoid potential naming conflicts.
	@mkdir -p $(OSX_TMP_DIR)
	@mkdir -p $(BUILD_PATH)
	@GOOS=darwin GOARCH=amd64 go build -v -ldflags="$(LDFLAGS)" -o $(OSX_BINARY_PATH)
	@cp $(OSX_BINARY_PATH) $(OSX_TMP_DIR)/triton-kubernetes
	@zip --junk-paths $(OSX_ARCHIVE_PATH) $(OSX_TMP_DIR)/triton-kubernetes
	@rm -rf $(OSX_TMP_DIR)

build-linux: clean
	@echo "Building Linux..."
	@mkdir -p $(LINUX_TMP_DIR)
	@mkdir -p $(BUILD_PATH)
	@GOOS=linux GOARCH=amd64 go build -v -ldflags="$(LDFLAGS)" -o $(LINUX_BINARY_PATH)
	@cp $(LINUX_BINARY_PATH) $(LINUX_TMP_DIR)/triton-kubernetes
	@zip --junk-paths $(LINUX_ARCHIVE_PATH) $(LINUX_TMP_DIR)/triton-kubernetes
	@rm -rf $(LINUX_TMP_DIR)

build-rpm: build-linux
	@echo "Building RPM..."
#	Copying and renaming the linux binary to just 'triton-kubernetes'. Making a temp directory to avoid potential naming conflicts.
	@mkdir -p $(RPM_TMP_DIR)
	@cp $(LINUX_BINARY_PATH) $(RPM_TMP_DIR)/triton-kubernetes
	@fpm \
		--chdir $(RPM_TMP_DIR) \
		--input-type dir \
		--output-type rpm \
		--rpm-os linux \
		--name triton-kubernetes \
		--version $(VERSION) \
		--prefix $(RPM_INSTALL_DIR) \
		--package $(RPM_PATH) triton-kubernetes
#	Cleaning up the tmp directory
	@rm -rf $(RPM_TMP_DIR)

build-deb: build-linux
	@echo "Building DEB..."
#	Copying and renaming the linux binary to just 'triton-kubernetes'. Making a temp directory to avoid potential naming conflicts.
	@mkdir -p $(DEB_TMP_DIR)
	@cp $(LINUX_BINARY_PATH) $(DEB_TMP_DIR)/triton-kubernetes
# 	fpm fails with a tar error when building the DEB package on OSX 10.10.
# 	Current workaround is to modify PATH so that fpm uses gnu-tar instead of the regular tar command.
#	Issue URL: https://github.com/jordansissel/fpm/issues/882
	@PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$$PATH" fpm \
		--chdir $(DEB_TMP_DIR) \
		--input-type dir \
		--output-type deb \
		--name triton-kubernetes \
		--version $(VERSION) \
		--prefix $(DEB_INSTALL_DIR) \
		--package $(DEB_PATH) triton-kubernetes
#	Cleaning up the tmp directory
	@rm -rf $(DEB_TMP_DIR)

test:
	@echo "Running unit-tests..."
	go test ./...
