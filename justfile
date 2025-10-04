build:
    mkdir -p build
    odin build src/ -debug -out:build/my_magit.exe

run: build
    ghostty -e "./build/my_magit.exe; sleep 5"
