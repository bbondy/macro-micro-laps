SDK_CFG ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
SDK_ROOT ?= $(shell cat "$(SDK_CFG)" 2>/dev/null | sed 's:/*$$::')
MONKEYC ?= $(SDK_ROOT)/bin/monkeyc
MONKEYDO ?= $(SDK_ROOT)/bin/monkeydo
UNAME_S := $(shell uname -s)
JUNGLE ?= $(CURDIR)/monkey.jungle
OUT_DIR ?= $(CURDIR)/bin
OUT_PRG ?= $(OUT_DIR)/micromacrolap.prg
OUT_IQ ?= $(OUT_DIR)/MicroMacroLap.iq
DEVICE ?= enduro3
DEV_KEY ?=
KEY_DIR ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ/keys
KEY_DER ?= $(KEY_DIR)/developer_key.der
KEY_PEM ?= $(KEY_DIR)/developer_key.pem

ifneq ($(strip $(DEV_KEY)),)
KEY_FLAG := -y "$(DEV_KEY)"
endif

.PHONY: all build clean key sim sim-run sim-console package package-local install device-list

all: build

build:
	@mkdir -p "$(OUT_DIR)"
	@if [ -z "$(strip $(DEV_KEY))" ]; then \
		echo "ERROR: DEV_KEY is not set. Run 'make key' or set DEV_KEY in .envrc."; \
		exit 1; \
	fi
	@if [ ! -f "$(DEV_KEY)" ]; then \
		echo "ERROR: DEV_KEY not found at $(DEV_KEY). Run 'make key' or update DEV_KEY."; \
		exit 1; \
	fi
	"$(MONKEYC)" -f "$(JUNGLE)" -d "$(DEVICE)" -o "$(OUT_PRG)" $(KEY_FLAG)

sim: build
ifeq ($(UNAME_S),Darwin)
	@if ! pgrep -x "ConnectIQ" >/dev/null 2>&1; then \
		open "$(SDK_ROOT)/bin/ConnectIQ.app"; \
		sleep 2; \
	fi
endif
	"$(MONKEYDO)" "$(OUT_PRG)" "$(DEVICE)"

sim-run: build
	"$(MONKEYDO)" "$(OUT_PRG)" "$(DEVICE)"

sim-console:
	"$(SDK_ROOT)/bin/ConnectIQ.app/Contents/MacOS/simulator"

package: build
	@rm -f "$(OUT_IQ)"
	"$(MONKEYC)" -f "$(JUNGLE)" -d "$(DEVICE)" -y "$(DEV_KEY)" -e -o "$(OUT_IQ)"
	@if [ ! -s "$(OUT_IQ)" ]; then \
		echo "ERROR: package output missing at $(OUT_IQ)"; \
		exit 1; \
	fi
	@if command -v rg >/dev/null 2>&1; then \
		bsdtar -tf "$(OUT_IQ)" | rg -q '^manifest\.xml$$'; \
	else \
		bsdtar -tf "$(OUT_IQ)" | grep -q '^manifest\.xml$$'; \
	fi; \
	if [ $$? -ne 0 ]; then \
		echo "ERROR: $(OUT_IQ) is not a valid export package (missing manifest.xml)."; \
		exit 1; \
	fi

package-local: build
	@rm -f "$(OUT_IQ)"
	"$(MONKEYC)" -f "$(JUNGLE)" -d "$(DEVICE)" -y "$(DEV_KEY)" -o "$(OUT_IQ)"
	@if [ ! -s "$(OUT_IQ)" ]; then \
		echo "ERROR: package output missing at $(OUT_IQ)"; \
		exit 1; \
	fi

install: package
	@echo "Install $(OUT_IQ) via Garmin Express or the Connect IQ mobile app (developer mode)."

device-list:
	@DEVICE_REF_DIR="$(SDK_ROOT)/resources/device-reference"; \
	if [ ! -d "$$DEVICE_REF_DIR" ]; then \
		echo "ERROR: Could not find device metadata at $$DEVICE_REF_DIR"; \
		echo "Check SDK_ROOT or $(SDK_CFG)."; \
		exit 1; \
	fi; \
	find "$$DEVICE_REF_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort

key:
	@mkdir -p "$(KEY_DIR)"
	openssl genrsa -out "$(KEY_PEM)" 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER -in "$(KEY_PEM)" -out "$(KEY_DER)" -nocrypt
ifneq ($(strip $(DEV_KEY)),)
	@if [ "$(KEY_DER)" != "$(DEV_KEY)" ]; then \
		mkdir -p "$(dir $(DEV_KEY))"; \
		cp "$(KEY_DER)" "$(DEV_KEY)"; \
	fi
endif

clean:
	@rm -rf "$(OUT_DIR)"
