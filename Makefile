# ---------------------------------------
# Default behavior:
#   make / make all         -> builds ALL boards + syncs docs + postprocess docs
#   make BOARD=2-term       -> builds ONLY 2-term + syncs docs + postprocess docs
#   make BOARD=3-term       -> builds ONLY 3-term + syncs docs + postprocess docs
#   make BOARD=led-module   -> builds ONLY led-module + syncs docs + postprocess docs
#   make BOARD=dipsw-module -> builds ONLY dipsw-module + syncs docs + postprocess docs
#
# Convenience:
#   make build              -> run KiBot only (all boards by default)
#   make zip                -> zip fab outputs (all boards by default)
#   make sync_docs          -> rsync artifacts into docs/artifacts (all boards by default)
#   make mkdocs             -> mkdocs serve (after sync_docs + postprocess)
#   make list               -> print derived paths per board
# ---------------------------------------

BOARD  ?= all
BOARDS := 2-term 3-term led-module dipsw-module

# KiBot config (repo-relative)
KIBOT_CFG := hardware/kibot/kibot.yaml

IMAGE     := niktt332/kicad9-kibot:1.8.4
PLATFORM  := --platform linux/amd64
REPO_ROOT := $(shell pwd)

DOCS_DIR := docs

.PHONY: all all_boards build zip sync_docs mkdocs clean check list \
        build_one zip_one sync_docs_one post_docs

# ----------------------------
# Top-level targets
# ----------------------------

all:
ifeq ($(BOARD),all)
	@$(MAKE) all_boards
else
	@$(MAKE) build_one BOARD=$(BOARD)
	@$(MAKE) zip_one BOARD=$(BOARD)
	@$(MAKE) sync_docs_one BOARD=$(BOARD)
endif
	@$(MAKE) post_docs

all_boards:
	@for b in $(BOARDS); do \
	  $(MAKE) build_one BOARD=$$b; \
	  $(MAKE) zip_one BOARD=$$b; \
	  $(MAKE) sync_docs_one BOARD=$$b; \
	done

# Convenience aliases
build:
ifeq ($(BOARD),all)
	@for b in $(BOARDS); do \
	  $(MAKE) build_one BOARD=$$b; \
	done
else
	@$(MAKE) build_one BOARD=$(BOARD)
endif

zip:
ifeq ($(BOARD),all)
	@for b in $(BOARDS); do \
	  $(MAKE) zip_one BOARD=$$b; \
	done
else
	@$(MAKE) zip_one BOARD=$(BOARD)
endif

sync_docs:
ifeq ($(BOARD),all)
	@for b in $(BOARDS); do \
	  $(MAKE) sync_docs_one BOARD=$$b; \
	done
else
	@$(MAKE) sync_docs_one BOARD=$(BOARD)
endif
	@$(MAKE) post_docs

mkdocs: sync_docs
	@echo "==> Serving MkDocs..."
	mkdocs serve

# Runs once after syncing artifacts (for one board or all boards)
post_docs:
	@echo "==> Rendering CSV tables (HTML) for wide-table viewing (all boards)..."
	@python3 tools/render_csv_tables.py 2>/dev/null || true
	@echo "==> Generating MkDocs pages (docs/*.md)..."
	@python3 tools/gen_mkdocs_pages.py
	@echo "==> Cleaning macOS junk..."
	@find docs/artifacts -name ".DS_Store" -delete 2>/dev/null || true

list:
	@echo "BOARD     = $(BOARD)"
	@echo "BOARDS    = $(BOARDS)"
	@echo "KIBOT_CFG = $(KIBOT_CFG)"
	@for b in $(BOARDS); do \
	  pd=$$(find "hardware/pcb/kicad/$$b" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1 | xargs basename); \
	  echo ""; \
	  echo "[$$b] PROJECT_DIR     = $$pd"; \
	  echo "[$$b] PROJECT         = $$pd"; \
	  echo "[$$b] KICAD_DIR       = hardware/pcb/kicad/$$b/$$pd"; \
	  echo "[$$b] OUT_DIR         = outputs/$$b"; \
	  echo "[$$b] DOCS_ARTIFACTS  = docs/artifacts/$$b"; \
	done

# ----------------------------
# Per-board targets (internal)
# ----------------------------

build_one: check
	@PROJECT_DIR=$$(find "hardware/pcb/kicad/$(BOARD)" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1 | xargs basename); \
	PROJECT="$$PROJECT_DIR"; \
	KICAD_DIR="hardware/pcb/kicad/$(BOARD)/$$PROJECT_DIR"; \
	OUT_DIR="outputs/$(BOARD)"; \
	echo "==> Running KiBot (Docker) for BOARD=$(BOARD)..."; \
	echo "    PROJECT=$$PROJECT"; \
	echo "    KICAD_DIR=$$KICAD_DIR"; \
	echo "    OUT_DIR=$$OUT_DIR"; \
	docker run --rm -t $(PLATFORM) \
	  -v "$(REPO_ROOT)":/work \
	  -w /work/$$KICAD_DIR \
	  $(IMAGE) \
	  sh -lec 'set -e; \
	    kibot -d "/work/'"$$OUT_DIR"'" -c "/work/$(KIBOT_CFG)" -e "'"$$PROJECT"'.kicad_sch" -b "'"$$PROJECT"'.kicad_pcb"'

zip_one: build_one
	@PROJECT_DIR=$$(find "hardware/pcb/kicad/$(BOARD)" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1 | xargs basename); \
	PROJECT="$$PROJECT_DIR"; \
	OUT_DIR="outputs/$(BOARD)"; \
	FAB_DIR="$$OUT_DIR/fab/gerbers"; \
	FAB_ZIP="$$OUT_DIR/fab/$${PROJECT}_fab.zip"; \
	echo "==> Creating fab zip for BOARD=$(BOARD)..."; \
	mkdir -p "$$OUT_DIR/fab"; \
	rm -f "$$FAB_ZIP"; \
	cd "$$FAB_DIR" && zip -r "../$$(basename "$$FAB_ZIP")" .; \
	echo "==> Done: $$FAB_ZIP"

sync_docs_one: build_one
	@PROJECT_DIR=$$(find "hardware/pcb/kicad/$(BOARD)" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1 | xargs basename); \
	PROJECT="$$PROJECT_DIR"; \
	OUT_DIR="outputs/$(BOARD)"; \
	DOCS_ARTIFACTS="$(DOCS_DIR)/artifacts/$(BOARD)"; \
	echo "==> Syncing KiBot outputs into MkDocs ($$DOCS_ARTIFACTS)..."; \
	mkdir -p "$$DOCS_ARTIFACTS"; \
	rsync -a --delete "$$OUT_DIR/docs/"     "$$DOCS_ARTIFACTS/docs/"; \
	rsync -a --delete "$$OUT_DIR/assembly/" "$$DOCS_ARTIFACTS/assembly/"; \
	rsync -a --delete "$$OUT_DIR/fab/"      "$$DOCS_ARTIFACTS/fab/"; \
	rsync -a --delete "$$OUT_DIR/mcad/"     "$$DOCS_ARTIFACTS/mcad/"; \
	echo "==> Removing stale SVG renders (KiBot now generates PNG renders)..."; \
	rm -f "$$DOCS_ARTIFACTS/docs/renders/"*.svg 2>/dev/null || true; \
	echo "==> Generating PDF preview thumbnails (macOS sips)..."; \
	mkdir -p "$$DOCS_ARTIFACTS/previews"; \
	sips -s format png "$$DOCS_ARTIFACTS/docs/schematic/$$PROJECT-schematic.pdf" --out "$$DOCS_ARTIFACTS/previews/schematic.png" >/dev/null 2>&1 || true; \
	sips -s format png "$$DOCS_ARTIFACTS/docs/fab/$$PROJECT-fab-drawing.pdf" --out "$$DOCS_ARTIFACTS/previews/fab-drawing.png" >/dev/null 2>&1 || true; \
	sips -s format png "$$DOCS_ARTIFACTS/docs/assembly/$$PROJECT-assembly-top.pdf" --out "$$DOCS_ARTIFACTS/previews/assembly-top.png" >/dev/null 2>&1 || true

# ----------------------------
# Housekeeping
# ----------------------------

clean:
	@echo "==> Cleaning outputs and synced artifacts..."
	@find "outputs" -mindepth 1 -delete 2>/dev/null || true
	@find "docs/artifacts" -mindepth 1 -delete 2>/dev/null || true
	@echo "==> Cleaning C build artifacts..."
	@find software -type d \( -name Debug -o -name Release \) -exec rm -rf {} + 2>/dev/null || true
	@find software -type f \( -name "*.o" -o -name "*.d" -o -name "*.out" -o -name "*.map" \) -delete 2>/dev/null || true
	@find software -type d \( -name ".clangd" -o -name ".cache" \) -exec rm -rf {} + 2>/dev/null || true

check:
	@command -v docker >/dev/null 2>&1 || (echo "Docker not found in PATH" && exit 1)
	@command -v rsync  >/dev/null 2>&1 || (echo "rsync not found (try: brew install rsync)" && exit 1)
	@command -v mkdocs >/dev/null 2>&1 || (echo "mkdocs not found (try: pipx install mkdocs mkdocs-material --include-deps)" && exit 1)
	@command -v sips   >/dev/null 2>&1 || (echo "sips not found (macOS-only tool)" && exit 1)

	@test -f "$(KIBOT_CFG)" || (echo "Missing $(KIBOT_CFG)" && exit 1)
	@for b in $(BOARDS); do \
	  test -d "hardware/pcb/kicad/$$b" || (echo "Missing board dir: hardware/pcb/kicad/$$b" && exit 1); \
	  find "hardware/pcb/kicad/$$b" -mindepth 1 -maxdepth 1 -type d | grep -q . || (echo "No KiCad project directory found in hardware/pcb/kicad/$$b" && exit 1); \
	done
