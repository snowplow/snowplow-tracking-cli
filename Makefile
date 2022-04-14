.PHONY: all gox cli cli-linux cli-darwin cli-windows format lint tidy update test-setup test goveralls clean

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

linux_out_dir   = $(output_dir)/linux
darwin_out_dir  = $(output_dir)/darwin
windows_out_dir = $(output_dir)/windows

bin_name    = snowplow-tracking-cli
bin_linux   = $(linux_out_dir)/$(bin_name)
bin_darwin  = $(darwin_out_dir)/$(bin_name)
bin_windows = $(windows_out_dir)/$(bin_name)

# -----------------------------------------------------------------------------
#  BUILDING
# -----------------------------------------------------------------------------

all: cli

gox:
	GO111MODULE=on go install github.com/mitchellh/gox@latest
	mkdir -p $(compiled_dir)

cli: gox cli-linux cli-darwin cli-windows
	(cd $(linux_out_dir) && zip -r staging.zip $(bin_name))
	mv $(linux_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_linux_amd64.zip
	(cd $(darwin_out_dir) && zip -r staging.zip $(bin_name))
	mv $(darwin_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_darwin_amd64.zip
	(cd $(windows_out_dir) && zip -r staging.zip $(bin_name).exe)
	mv $(windows_out_dir)/staging.zip $(compiled_dir)/snowplow_tracking_cli_$(version)_windows_amd64.zip

cli-linux: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=linux/amd64 -output=$(bin_linux) .

cli-darwin: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=darwin/amd64 -output=$(bin_darwin) .

cli-windows: gox
	GO111MODULE=on CGO_ENABLED=0 gox -osarch=windows/amd64 -output=$(bin_windows) .

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
#  CLEANUP
# -----------------------------------------------------------------------------

clean:
	rm -rf $(build_dir)
