build:
    #!/usr/bin/env bash
    mkdir -p build
    time odin build src/ -debug -out:build/my_magit.exe

run: build
    #!/usr/bin/env bash
    ghostty -e "./build/my_magit.exe"