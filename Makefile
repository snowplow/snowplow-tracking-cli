.PHONY: all format lint test goveralls release release-dry clean

# -----------------------------------------------------------------------------
#  CONSTANTS
# -----------------------------------------------------------------------------

build_dir     = build

coverage_dir  = $(build_dir)/coverage
coverage_out  = $(coverage_dir)/coverage.out
coverage_html = $(coverage_dir)/coverage.html

output_dir    = $(build_dir)/output

linux_dir     = $(output_dir)/linux
darwin_dir    = $(output_dir)/darwin
windows_dir   = $(output_dir)/windows

bin_name      = snowplow-tracking-cli
bin_linux     = $(linux_dir)/$(bin_name)
bin_darwin    = $(darwin_dir)/$(bin_name)
bin_windows   = $(windows_dir)/$(bin_name)

# -----------------------------------------------------------------------------
#  BUILDING
# -----------------------------------------------------------------------------

all:
	go get -u -t ./...
	go get -u github.com/mitchellh/gox/...
	gox -osarch=linux/amd64 -output=$(bin_linux) .
	gox -osarch=darwin/amd64 -output=$(bin_darwin) .
	gox -osarch=windows/amd64 -output=$(bin_windows) .

# -----------------------------------------------------------------------------
#  FORMATTING
# -----------------------------------------------------------------------------

format:
	go fmt .
	gofmt -s -w .

lint:
	go get -u github.com/golang/lint/golint
	golint .

# -----------------------------------------------------------------------------
#  TESTING
# -----------------------------------------------------------------------------

test:
	mkdir -p $(coverage_dir)
	go get -u golang.org/x/tools/cmd/cover/...
	go test . -tags test -v -covermode=count -coverprofile=$(coverage_out)
	go tool cover -html=$(coverage_out) -o $(coverage_html)

goveralls: test
	go get -u github.com/mattn/goveralls/...
	goveralls -coverprofile=$(coverage_out) -service=travis-ci

# -----------------------------------------------------------------------------
#  RELEASE
# -----------------------------------------------------------------------------

release:
	release-manager --config .release.yml --check-version --make-artifact --make-version --upload-artifact

release-dry:
	release-manager --config .release.yml --check-version --make-artifact

# -----------------------------------------------------------------------------
#  CLEANUP
# -----------------------------------------------------------------------------

clean:
	rm -rf $(build_dir)
