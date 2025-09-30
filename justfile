build:
    mkdir -p build
    odin build src/ -debug -out:build/my_magit.exe

run: build
    ./build/my_magit.exe
