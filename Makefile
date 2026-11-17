.DEFAULT_GOAL := help
SUBMAKE := $(MAKE) --no-print-directory

ifeq ($(OS),Windows_NT)
SHELL := cmd.exe
FVM_FLUTTER_SDK := $(wildcard $(CURDIR)/.fvm/flutter_sdk)
LOCAL_FLUTTER := $(if $(FVM_FLUTTER_SDK),$(FVM_FLUTTER_SDK)/bin/flutter.bat,flutter.bat)
LOCAL_DART := $(if $(FVM_FLUTTER_SDK),$(FVM_FLUTTER_SDK)/bin/dart.bat,dart.bat)
BLANK_LINE := @echo.
else
SHELL := /bin/bash
FVM_FLUTTER_SDK := $(wildcard $(CURDIR)/.fvm/flutter_sdk)
LOCAL_FLUTTER := $(if $(FVM_FLUTTER_SDK),$(FVM_FLUTTER_SDK)/bin/flutter,flutter)
LOCAL_DART := $(if $(FVM_FLUTTER_SDK),$(FVM_FLUTTER_SDK)/bin/dart,dart)
BLANK_LINE := @echo
endif

# Command-line overrides also apply inside the example directory.
FLUTTER := $(LOCAL_FLUTTER)
DART := $(LOCAL_DART)
EXAMPLE_DIR := example
DART_DIRS := lib test $(EXAMPLE_DIR)/lib $(EXAMPLE_DIR)/test

# Machine output supplements the readable reporter and preserves test exit codes.
# MACHINE_OUT is relative to the repository root; example_<filename> is written
# beside it for the example suite so reports never overwrite each other.
CI ?= 0
MACHINE_OUT ?=
TEST_REPORTER := $(if $(filter 1,$(CI)),--reporter github,)
TEST_ARGS := $(TEST_REPORTER) \
             $(if $(MACHINE_OUT),--file-reporter="json:$(abspath $(MACHINE_OUT))",)
EXAMPLE_TEST_ARGS := $(TEST_REPORTER) \
             $(if $(MACHINE_OUT),--file-reporter="json:$(dir $(abspath $(MACHINE_OUT)))example_$(notdir $(MACHINE_OUT))",)

.PHONY: help bootstrap format format-check fix analyze test check aio

help:
	@echo "great_list_view_plus - automation entrypoints"
	$(BLANK_LINE)
	@echo "  bootstrap       Resolve package and example dependencies"
	@echo "  format          Format package and example Dart sources"
	@echo "  format-check    Verify Dart formatting without modifying files"
	@echo "  fix             Apply Dart fixes in package and example, then format"
	@echo "  analyze         Analyze the package and example"
	@echo "  test            Run package and example tests (CI=1, MACHINE_OUT=path optional)"
	@echo "  check           Resolve dependencies, check formatting, analyze, and test"
	@echo "  aio             Resolve dependencies, apply fixes, format, analyze, and test"

bootstrap:
	@"$(FLUTTER)" pub get
	@cd "$(EXAMPLE_DIR)" && "$(FLUTTER)" pub get

format:
	@"$(DART)" format $(DART_DIRS)

format-check:
	@"$(DART)" format --output=none --set-exit-if-changed $(DART_DIRS)

fix:
	@"$(DART)" fix --apply
	@cd "$(EXAMPLE_DIR)" && "$(DART)" fix --apply
	@$(SUBMAKE) format

analyze:
	@"$(FLUTTER)" analyze
	@cd "$(EXAMPLE_DIR)" && "$(FLUTTER)" analyze

test:
	@"$(FLUTTER)" test $(TEST_ARGS)
	@cd "$(EXAMPLE_DIR)" && "$(FLUTTER)" test $(EXAMPLE_TEST_ARGS)

# Keep composed workflows sequential, including under make -j.
check:
	@$(SUBMAKE) bootstrap
	@$(SUBMAKE) format-check
	@$(SUBMAKE) analyze
	@$(SUBMAKE) test

aio:
	@$(SUBMAKE) bootstrap
	@$(SUBMAKE) fix
	@$(SUBMAKE) analyze
	@$(SUBMAKE) test
