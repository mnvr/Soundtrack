all: help

.PHONY: help release

help:
	@echo "Available Tasks:"
	@echo "    make archive"

archive:
	xcodebuild -target Soundtrack-macOS clean build
	rm build/Soundtrack.zip || true
	cd build/Release && zip -r ../Soundtrack.zip Soundtrack.app
	open build

	
