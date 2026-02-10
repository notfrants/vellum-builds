#!/bin/bash

set -eux

setup() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > install
    sh install -y
    rm -f install
    . "$HOME/.cargo/env"
    rustup target add "$RUST_ARCH"

    apt-get update
    apt-get install -y git-lfs cmake
    case "$RUST_ARCH" in
        armv7-unknown-linux-gnueabihf)
            apt-get install -y gcc-arm-linux-gnueabihf
            ;;
        aarch64-unknown-linux-gnu)
            apt-get install -y gcc-aarch64-linux-gnu
            ;;
    esac
    git lfs install

    mkdir -p builds
}

fastfetch() {
    git clone https://github.com/notfrants/fastfetch.git
    cd fastfetch
    git checkout vellum

    mkdir -p build
    cd build

    (
        . /opt/codex/*/*/environment-setup-*

        cmake ..
        cmake --build . --target fastfetch
    )

    cd ..
    mkdir -p build-host
    cd build-host

    cmake ..
    cmake --build . --target fastfetch

    cd ..

    python3 <<'EOF'
import json
import sys
import subprocess

def main():
    with open("completions/fastfetch.bash") as f:
        completions = f.read()
    
    completions = completions.replace(
        "\n  # Check if Python is available\n  if ! command -v python3 &>/dev/null; then\n    return\n  fi\n",
        ""
    )
    
    start = completions.find("    local -a opts")
    end = completions.find("EOF\n)") + 6

    with open("completions/fastfetch.bash", "w") as f:
        f.write(completions[:start])
        f.write("    local -a opts=(\n")
    
        # Use fastfetch --help-raw to get option data
        output = subprocess.check_output(['./build-host/fastfetch', '--help-raw'], stderr=subprocess.DEVNULL)
        data = json.loads(output)

        for category in data.values():
            for flag in category:
                if flag.get("pseudo", False):
                    continue

                if "short" in flag:
                    f.write(f"      -{flag['short']}\n")

                if "long" in flag:
                    if flag["long"] == "logo-color-[1-9]":
                        for i in range(1, 10):
                            f.write(f"      --logo-color-{i}\n")
                    else:
                        f.write(f"      --{flag['long']}\n")
        
        f.write("    )\n")
        f.write(completions[end:])

if __name__ == "__main__":
    main()
EOF

    cd ..
    mkdir -p builds/fastfetch

    cp fastfetch/build/fastfetch builds/fastfetch/fastfetch
    cp -r fastfetch/presets builds/fastfetch/presets
    cp fastfetch/completions/fastfetch.bash builds/fastfetch/fastfetch.bash
    
    cp fastfetch/LICENSE builds/fastfetch/LICENSE
    commit=$(git -C fastfetch rev-parse HEAD)
    echo "https://github.com/notfrants/fastfetch/archive/$commit.tar.gz" > builds/fastfetch/SOURCES
    git -C fastfetch describe --tags --long --always > builds/fastfetch/VERSION

    rm -rf fastfetch

    cd builds/fastfetch
    tar -czf ../fastfetch.tar.gz ./*
    cd ../..
}

hyfetch() {    
    git clone https://github.com/notfrants/hyfetch.git
    cd hyfetch

    export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
    export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc

    cargo build --release --target "$RUST_ARCH"

    cargo build --release
    target/release/hyfetch --bpaf-complete-style-bash > hyfetch.bash

    cd ..
    mkdir -p builds/hyfetch

    cp "hyfetch/target/$RUST_ARCH/release/hyfetch" builds/hyfetch/hyfetch
    cp hyfetch/hyfetch.bash builds/hyfetch/hyfetch.bash

    cp hyfetch/LICENSE.md builds/hyfetch/LICENSE
    commit=$(git -C hyfetch rev-parse HEAD)
    echo "https://github.com/notfrants/hyfetch/archive/$commit.tar.gz" > builds/hyfetch/SOURCES
    git -C hyfetch describe --tags --long --always > builds/hyfetch/VERSION

    rm -rf hyfetch

    cd builds/hyfetch
    tar -czf ../hyfetch.tar.gz ./*
    cd ../..
}

tilem() {
    git clone https://github.com/notfrants/rM2-stuff.git
    cd rM2-stuff
    git checkout tilem-full

    (
        . /opt/codex/*/*/environment-setup-*

        cmake --preset dev
        cmake --build build/dev --target tilem
    )

    cd ..
    mkdir -p builds/tilem

    cp rM2-stuff/build/dev/apps/tilem/tilem builds/tilem/tilem
    cp rM2-stuff/apps/tilem/draft/tilem.png builds/tilem/icon.png
    cat >builds/tilem/external.manifest.json <<EOF
{
    "name": "TilEm",
    "application": "tilem",
    "args": ["ti84plus.rom", "--full"],
    "environment": {
        "LD_LIBRARY_PATH": ".",
        "LD_PRELOAD": "/home/root/shims/qtfb-shim.so"
    },
    "qtfb": true
}
EOF

    cp rM2-stuff/LICENSE builds/tilem/LICENSE
    commit=$(git -C rM2-stuff rev-parse HEAD)
    echo "https://github.com/notfrants/rM2-stuff/archive/$commit.tar.gz" > builds/tilem/SOURCES
    git -C rM2-stuff describe --tags --long --always > builds/tilem/VERSION

    rm -rf rM2-stuff

    cd builds/tilem
    tar -czf ../tilem.tar.gz ./*
    cd ../..
}

less() {
    local version="692"

    curl -Lfo less.tar.gz https://greenwoodsoftware.com/less/less-$version.tar.gz
    mkdir -p less
    tar --strip-components=1 -xzf less.tar.gz -C less
    rm -f less.tar.gz
    cd less

    (
        . /opt/codex/*/*/environment-setup-*

        sh configure --host remarkable
        make
    )

    cd ..
    mkdir -p builds/less

    cp less/less builds/less/less

    cp less/LICENSE builds/less/LICENSE
    echo "https://greenwoodsoftware.com/less/less-$version.tar.gz" > builds/less/SOURCES
    echo $version > builds/less/VERSION

    rm -rf less

    cd builds/less
    tar -czf ../less.tar.gz ./*
    cd ../..
}

setup

fastfetch
hyfetch
tilem
less
