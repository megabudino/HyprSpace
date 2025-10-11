#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="${CODESIGN_IDENTITY:-hyprspace-codesign-certificate}"
notarize_app="false"
apple_id="${APPLE_ID:-}"
apple_id_password="${APPLE_ID_PASSWORD:-}"
apple_team_id="${APPLE_TEAM_ID:-}"

while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        --notarize) notarize_app="true"; shift;;
        --apple-id) apple_id="$2"; shift 2;;
        --apple-id-password) apple_id_password="$2"; shift 2;;
        --apple-team-id) apple_team_id="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

# Auto-enable notarization if credentials are available
if [ -n "$apple_id" ] && [ -n "$apple_id_password" ] && [ -n "$apple_team_id" ]; then
    notarize_app="true"
fi

generate-git-hash() {
cat > Sources/Common/gitHashGenerated.swift <<EOF
public let gitHash = "$(git rev-parse HEAD)"
public let gitShortHash = "$(git rev-parse --short HEAD)"
EOF
}

#############
### BUILD ###
#############

./build-docs.sh
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity"

generate-git-hash
swift build -c release --arch arm64 --arch x86_64 --product hyprspace # CLI

# todo: make xcodebuild use the same toolchain as swift
# toolchain="$(plutil -extract CFBundleIdentifier raw ~/Library/Developer/Toolchains/swift-6.1-RELEASE.xctoolchain/Info.plist)"
# xcodebuild -toolchain "$toolchain" \
# Unfortunately, Xcode 16 fails with:
#     2025-05-05 15:51:15.618 xcodebuild[4633:13690815] Writing error result bundle to /var/folders/s1/17k6s3xd7nb5mv42nx0sd0800000gn/T/ResultBundle_2025-05-05_15-51-0015.xcresult
#     xcodebuild: error: Could not resolve package dependencies:
#       <unknown>:0: warning: legacy driver is now deprecated; consider avoiding specifying '-disallow-use-new-driver'
#     <unknown>:0: error: unable to execute command: <unknown>

rm -rf .release && mkdir .release

xcode_configuration="Release"
xcodebuild -version
xcodebuild-pretty .release/xcodebuild.log clean build \
    -scheme HyprSpace \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath .xcode-build

git checkout .

cp -r ".xcode-build/Build/Products/$xcode_configuration/HyprSpace.app" .release
cp -r .build/apple/Products/Release/hyprspace .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/hyprspace

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/HyprSpace.app
.release/HyprSpace.app/Contents
.release/HyprSpace.app/Contents/_CodeSignature
.release/HyprSpace.app/Contents/_CodeSignature/CodeResources
.release/HyprSpace.app/Contents/MacOS
.release/HyprSpace.app/Contents/MacOS/HyprSpace
.release/HyprSpace.app/Contents/Resources
.release/HyprSpace.app/Contents/Resources/default-config.toml
.release/HyprSpace.app/Contents/Resources/AppIcon.icns
.release/HyprSpace.app/Contents/Resources/Assets.car
.release/HyprSpace.app/Contents/Info.plist
.release/HyprSpace.app/Contents/PkgInfo
EOF
)

if test "$expected_layout" != "$(find .release/HyprSpace.app)"; then
    echo "!!! Expect/Actual layout don't match !!!"
    find .release/HyprSpace.app
    exit 1
fi

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-contains-hash() {
    hash=$(git rev-parse HEAD)
    if ! strings "$1" | grep --fixed-string "$hash" > /dev/null; then
        echo "$1 doesn't contain $hash"
        exit 1
    fi
}

check-universal-binary .release/HyprSpace.app/Contents/MacOS/HyprSpace
check-universal-binary .release/hyprspace

check-contains-hash .release/HyprSpace.app/Contents/MacOS/HyprSpace
check-contains-hash .release/hyprspace

codesign -v .release/HyprSpace.app
codesign -v .release/hyprspace

#################
### NOTARIZE ###
#################

if [ "$notarize_app" = "true" ]; then
    echo "Notarizing HyprSpace.app..."

    # Create a temporary ZIP for notarization
    cd .release
    zip -r HyprSpace-notarize.zip HyprSpace.app

    # Submit for notarization
    echo "Submitting app for notarization..."
    xcrun notarytool submit HyprSpace-notarize.zip \
        --apple-id "$apple_id" \
        --password "$apple_id_password" \
        --team-id "$apple_team_id" \
        --wait \
        --verbose

    # Staple the notarization to the app
    echo "Stapling notarization to HyprSpace.app..."
    xcrun stapler staple HyprSpace.app

    # Also notarize the CLI binary
    echo "Notarizing hyprspace CLI..."
    zip -j hyprspace-notarize.zip hyprspace

    xcrun notarytool submit hyprspace-notarize.zip \
        --apple-id "$apple_id" \
        --password "$apple_id_password" \
        --team-id "$apple_team_id" \
        --wait

    # Note: We can't staple the CLI binary directly, but it will be included
    # in the notarized package

    # Clean up temporary files
    rm -f HyprSpace-notarize.zip hyprspace-notarize.zip
    cd ..

    echo "Notarization complete!"

    # Verify notarization
    spctl -a -vvv -t install .release/HyprSpace.app || true
fi

############
### PACK ###
############

mkdir -p ".release/HyprSpace-v$build_version/manpage" && cp .man/*.1 ".release/HyprSpace-v$build_version/manpage"
cp -r ./legal ".release/HyprSpace-v$build_version/legal"
cp -r .shell-completion ".release/HyprSpace-v$build_version/shell-completion"
cd .release
    mkdir -p "HyprSpace-v$build_version/bin" && cp -r hyprspace "HyprSpace-v$build_version/bin"
    cp -r HyprSpace.app "HyprSpace-v$build_version"
    zip -r "HyprSpace-v$build_version.zip" "HyprSpace-v$build_version"
cd -

#################
### Brew Cask ###
#################
for cask_name in hyprspace hyprspace-dev; do
    ./script/build-brew-cask.sh \
        --cask-name "$cask_name" \
        --app-bundle-dir-name "HyprSpace.app" \
        --zip-uri ".release/HyprSpace-v$build_version.zip" \
        --build-version "$build_version"
done
