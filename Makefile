SDK_CFG ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
SDK_ROOT ?= $(shell cat "$(SDK_CFG)" 2>/dev/null | sed 's:/*$$::')
MONKEYC ?= $(SDK_ROOT)/bin/monkeyc
MONKEYDO ?= $(SDK_ROOT)/bin/monkeydo
UNAME_S := $(shell uname -s)
JUNGLE ?= $(CURDIR)/monkey.jungle
OUT_DIR ?= $(CURDIR)/bin
OUT_PRG ?= $(OUT_DIR)/macromicrolaps.prg
DEVICE ?= enduro_sim
DEV_KEY ?=
KEY_DIR ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ/keys
KEY_DER ?= $(KEY_DIR)/developer_key.der
KEY_PEM ?= $(KEY_DIR)/developer_key.pem

ifneq ($(strip $(DEV_KEY)),)
KEY_FLAG := -y "$(DEV_KEY)"
endif

.PHONY: all build clean key sim sim-run sim-console package install

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
	"$(MONKEYC)" -f "$(JUNGLE)" -d "$(DEVICE)" -y "$(DEV_KEY)" -e -o "$(OUT_DIR)/MacroLap.iq"

install: package
	@echo "Install $(OUT_DIR)/MacroLap.iq via Garmin Express or the Connect IQ mobile app (developer mode)."

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
