all: help

.PHONY: all help release

help:
	@echo "Available Tasks:"
	@echo "    make archive"
	@echo "    make helpindex"

archive:
	xcodebuild -target Soundtrack-macOS clean build
	rm build/Soundtrack.zip || true
	cd build/Release && zip -r ../Soundtrack.zip Soundtrack.app
	open build

helpindex:
	cd Soundtrack-macOS/Soundtrack.help/Contents/Resources/ && \
	    hiutil --create . --file index.helpindex -vvv
