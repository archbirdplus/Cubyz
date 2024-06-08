#!/bin/bash

cd "$(dirname "$0")"

BASE_VERSION=$(< .zig-version)

case "$(uname -s)" in
"Darwin")
	OS=macos;;
*)
	OS=linux;;
esac

if [ -n $ARCH ]
then
	case "$(uname -m)" in
	"arm64" | "aarch64")
		ARCH=aarch64;;
	"arm*")
		ARCH=armv7a;;
	"amd64" | "x86_64")
		ARCH=x86_64;;
	"x86*")
		ARCH=x86;;
	*)
		echo "Machine architecture could not be recognized ($(uname -m)). Report this bug with the result of \`uname -m\` and your preferred Zig release name."
		echo "Defaulting architecture to x86_64."
		ARCH=x86_64;;
	esac
fi

VERSION=zig-$OS-$ARCH-$BASE_VERSION

mkdir -p compiler/zig
wget -O compiler/archive.tar.xz https://ziglang.org/builds/"$VERSION".tar.xz --no-verbose
if [ $? != 0 ]
then
	echo "Failed to download the Zig compiler."
	fail
fi
tar --xz -xf compiler/archive.tar.xz --directory compiler/zig --strip-components 1

./compiler/zig/zig build -Doptimize=ReleaseFast

# Cubyz is now in ./zig-out/bin/Cubyzig

