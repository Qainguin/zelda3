# Makefile for zelda3 with Emscripten support
#
# Usage:
#   make              - Build for native platform (Linux, macOS, Windows)
#   make PLATFORM=web - Build for WebAssembly using Emscripten
#   make clean        - Clean all builds

# --- Common Configuration ---
ROM:=tables/zelda3.sfc
SRCS:=$(wildcard src/*.c snes/*.c) third_party/gl_core/gl_core_3_1.c third_party/opus-1.3.1-stripped/opus_decoder_amalgam.c
OBJS:=$(SRCS:%.c=%.o)
PYTHON:=/usr/bin/env python3

# Platform can be 'native' or 'web'
PLATFORM ?= native

# --- Platform-Specific Configuration ---

ifeq ($(PLATFORM), web)
# --- Emscripten (Web) Build Configuration ---
TARGET_EXEC := zelda3.html
CC := emcc
# Use -O3 for better optimization in WebAssembly. -Werror can be strict.
CFLAGS := -O3 -I . -DSYSTEM_VOLUME_MIXER_AVAILABLE=0 -s USE_SDL=2
# LDFLAGS for Emscripten
# -s USE_SDL=2: Use SDL2 library
# -s ALLOW_MEMORY_GROWTH=1: Allows the heap to grow dynamically, important for games.
# --preload-file: Packages the assets into a virtual filesystem.
# -sINITIAL_MEMORY=64mb: Allocate a generous starting heap. Adjust if needed.
LDFLAGS := -s USE_SDL=2 -s EXPORTED_RUNTIME_METHODS=['requestFullscreen'] -s ALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=64mb --preload-file zelda3_assets.dat --preload-file zelda3.ini --shell-file shell.html
# Files to be removed by the clean rule
CLEAN_TARGETS := zelda3.html zelda3.js zelda3.wasm zelda3.data

else
# --- Native Build Configuration (Original) ---
TARGET_EXEC := zelda3
CC := gcc
CFLAGS := $(if $(CFLAGS),$(CFLAGS),-O2 -Werror) -I .
CFLAGS += $(shell sdl2-config --cflags) -DSYSTEM_VOLUME_MIXER_AVAILABLE=0
CLEAN_TARGETS := $(TARGET_EXEC)

ifeq (${OS},Windows_NT)
    TARGET_EXEC := zelda3.exe
    WINDRES := windres
    RES := zelda3.res
    SDLFLAGS := -Wl,-Bstatic $(shell sdl2-config --static-libs)
    CLEAN_TARGETS += $(RES)
else
    RES :=
    SDLFLAGS := $(shell sdl2-config --libs) -lm
endif

endif

# --- Build Rules ---

.PHONY: all clean clean_obj clean_gen

all: $(TARGET_EXEC)

# Linking rule for native builds
ifeq ($(PLATFORM), native)
$(TARGET_EXEC): $(OBJS) $(RES)
	$(CC) $^ -o $@ $(LDFLAGS) $(SDLFLAGS)
endif

# Linking rule for Emscripten build
# Note: zelda3_assets.dat is a dependency for the final link step.
# We use $(OBJS) specifically instead of $^ so the asset file isn't passed as an object file.
ifeq ($(PLATFORM), web)
$(TARGET_EXEC): $(OBJS) zelda3_assets.dat
	@echo "Linking for WebAssembly..."
	$(CC) $(OBJS) -o $@ $(LDFLAGS)
endif

# Compilation rule (works for both gcc and emcc)
%.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

# Asset generation rule (platform-independent)
zelda3_assets.dat:
	@echo "Extracting game resources from $(ROM)..."
	$(PYTHON) assets/restool.py --extract-from-rom

# Windows resource compilation (only for native Windows build)
$(RES): src/platform/win32/zelda3.rc
	@echo "Generating Windows resources..."
	@$(WINDRES) $< -O coff -o $@

# --- Clean Rules ---

clean: clean_obj clean_gen

clean_obj:
	@echo "Cleaning objects and executables..."
	@$(RM) $(OBJS) $(CLEAN_TARGETS)

clean_gen:
	@echo "Cleaning generated assets..."
	@$(RM) zelda3_assets.dat tables/zelda3_assets.dat tables/*.txt tables/*.png tables/sprites/*.png tables/*.yaml
	@rm -rf tables/__pycache__ tables/dungeon tables/img tables/overworld tables/sound