all: help

.PHONY: all help archive

help:
	@echo "Available Tasks:"
	@echo "    make archive"
	@echo "    make helpindex"

archive:
	xcodebuild -target Soundtrack-macOS clean build
	rm build/Soundtrack.zip || true
	cd build/Release && zip -r ../Soundtrack.zip Soundtrack.app
	open build
