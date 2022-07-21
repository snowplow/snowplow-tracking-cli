.PHONY: all gox cli cli-linux-amd64 cli-darwin-amd64 cli-darwin-arm64 cli-windows-amd64 container format lint tidy update test-setup test goveralls container-release clean

# -----------------------------------------------------------------------------
#  CONSTANTS
# -----------------------------------------------------------------------------

version = `cat VERSION`

build_dir = build

coverage_dir  = $(build_dir)/coverage
coverage_out  = $(coverage_dir)/coverage.out
coverage_html = $(coverage_dir)/coverage.html

output_dir   = $(build_dir)/output
compiled_dir = $(build_dir)/compiled

linux_amd64_out_dir   = $(output_dir)/linux/amd64
darwin_amd64_out_dir  = $(output_dir)/darwin/amd64
darwin_arm64_out_dir  = $(output_dir)/darwin/arm64
windows_amd64_out_dir = $(output_dir)/windows/amd64

bin_name          = snowplow-tracking-cli
bin_linux_amd64   = $(linux_amd64_out_dir)/$(bin_name)
bin_darwin_amd64  = $(darwin_amd64_out_dir)/$(bin_name)
bin_darwin_arm64  = $(darwin_arm64_out_dir)/$(bin_name)
bin_windows_amd64 = $(windows_amd64_out_dir)/$(bin_name)

container_name = snowplow/$(bin_name)

# -----------------------------------------------------------------------------
#  BUILDING
# -----------------------------------------------------------------------------

all: cli container

gox:
	GO111MODULE=on go install github.com/mitchellh/gox@latest
	mkdir -p $(compiled_dir)

cli: gox cli-linux-amd64 cli-darwin-amd64 cli-darwin-arm64 cli-windows-amd64
	(cd $(linux_amd64_out_dir) && zip -r staging.zip $(bin_name))
	mv $(linux_amd64_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_linux_amd64.zip
	(cd $(darwin_amd64_out_dir) && zip -r staging.zip $(bin_name))
	mv $(darwin_amd64_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_darwin_amd64.zip
	(cd $(darwin_arm64_out_dir) && zip -r staging.zip $(bin_name))
	mv $(darwin_arm64_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_darwin_arm64.zip
	(cd $(windows_amd64_out_dir) && zip -r staging.zip $(bin_name).exe)
	mv $(windows_amd64_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_windows_amd64.zip

cli-linux-amd64: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=linux/amd64 -output=$(bin_linux_amd64) .

cli-darwin-amd64: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=darwin/amd64 -output=$(bin_darwin_amd64) .

cli-darwin-arm64: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=darwin/arm64 -output=$(bin_darwin_arm64) .

cli-windows-amd64: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=windows/amd64 -output=$(bin_windows_amd64) .

container: cli-linux-amd64
	docker build -t $(container_name):$(version) .

# -----------------------------------------------------------------------------
#  FORMATTING
# -----------------------------------------------------------------------------

format:
	GO111MODULE=on go fmt .
	GO111MODULE=on gofmt -s -w .

lint:
	GO111MODULE=on go install golang.org/x/lint/golint@latest
	GO111MODULE=on golint .

tidy:
	GO111MODULE=on go mod tidy

update:
	GO111MODULE=on go get -u

# -----------------------------------------------------------------------------
#  TESTING
# -----------------------------------------------------------------------------

test-setup:
	mkdir -p $(coverage_dir)
	GO111MODULE=on go install golang.org/x/tools/cmd/cover@latest

test: test-setup
	GO111MODULE=on go test . -tags test -v -covermode=count -coverprofile=$(coverage_out)
	GO111MODULE=on go tool cover -html=$(coverage_out) -o $(coverage_html)
	GO111MODULE=on go tool cover -func=$(coverage_out)

goveralls: test
	GO111MODULE=on go install github.com/mattn/goveralls@latest
	GO111MODULE=on goveralls -coverprofile=$(coverage_out) -service=github

# -----------------------------------------------------------------------------
#  RELEASE
# -----------------------------------------------------------------------------

container-release:
	@-docker login --username $(DOCKER_USERNAME) --password $(DOCKER_PASSWORD)
	docker push $(container_name):$(version)
	docker tag ${container_name}:${version} ${container_name}:latest
	docker push $(container_name):latest

# -----------------------------------------------------------------------------
#  CLEANUP
# -----------------------------------------------------------------------------

clean:
	rm -rf $(build_dir)
