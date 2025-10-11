#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_version=""
cask_git_repo_path=""
site_git_repo_path=""
create_dmg="true"
upload_to_github="true"
draft="false"
prerelease="false"
github_token="${GITHUB_TOKEN:-}"

while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --cask-git-repo-path) cask_git_repo_path="$2"; shift 2;;
        --site-git-repo-path) site_git_repo_path="$2"; shift 2;;
        --no-dmg) create_dmg="false"; shift;;
        --no-upload) upload_to_github="false"; shift;;
        --draft) draft="true"; shift;;
        --prerelease) prerelease="true"; shift;;
        --github-token) github_token="$2"; shift 2;;
        *) echo "Unknown option $1"; exit 1;;
    esac
done

if test -z "$build_version"; then
    echo "--build-version flag is mandatory" > /dev/stderr
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null && [ "$upload_to_github" = "true" ]; then
    echo "GitHub CLI (gh) is not installed. Please install it with: brew install gh" > /dev/stderr
    exit 1
fi

echo "Building release version $build_version..."
./run-tests.sh
./build-release.sh --build-version "$build_version"

# Create DMG if requested
if [ "$create_dmg" = "true" ]; then
    echo "Creating DMG installer..."
    cd .release

    # Extract the app from the ZIP
    temp_dir=$(mktemp -d)
    unzip -q "HyprSpace-v$build_version.zip" -d "$temp_dir"

    # Create DMG
    ../create-dmg.sh "HyprSpace-v$build_version.dmg" "$temp_dir/HyprSpace-v$build_version/HyprSpace.app"

    # Clean up
    rm -rf "$temp_dir"
    cd ..
fi

# Create and push git tag
echo "Creating git tag v$build_version..."
git tag -a "v$build_version" -m "Release v$build_version"
git push origin "v$build_version"

# Upload to GitHub if requested
if [ "$upload_to_github" = "true" ]; then
    echo "Creating GitHub release..."

    # Generate release notes
    previous_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

    release_notes="## Release v$build_version

### What's Changed"

    if [ -n "$previous_tag" ]; then
        # Get commit messages since last tag
        release_notes="$release_notes

$(git log --pretty=format:"* %s (%h)" "$previous_tag".."v$build_version")"
    else
        release_notes="$release_notes

* Initial release"
    fi

    release_notes="$release_notes

### Installation

#### Homebrew
\`\`\`bash
brew tap barutsrb/hyprspace
brew install hyprspace
\`\`\`

#### Manual Installation
1. Download the DMG or ZIP file from the assets below
2. For DMG: Open and drag HyprSpace to Applications
3. For ZIP: Extract and move HyprSpace.app to /Applications
4. Grant accessibility permissions when prompted

**Note:** If macOS blocks the app, run: \`xattr -cr /Applications/HyprSpace.app\`

### Requirements
- macOS 13.0 (Ventura) or later
- Accessibility permissions"

    # Create release using gh CLI
    release_args=""
    if [ "$draft" = "true" ]; then
        release_args="$release_args --draft"
    fi
    if [ "$prerelease" = "true" ]; then
        release_args="$release_args --prerelease"
    fi

    # Set GitHub token if provided
    if [ -n "$github_token" ]; then
        export GITHUB_TOKEN="$github_token"
    fi

    # Create release and upload assets
    echo "$release_notes" | gh release create "v$build_version" \
        --title "HyprSpace v$build_version" \
        --notes-file - \
        $release_args \
        ".release/HyprSpace-v$build_version.zip"

    # Upload DMG if it exists
    if [ -f ".release/HyprSpace-v$build_version.dmg" ]; then
        gh release upload "v$build_version" ".release/HyprSpace-v$build_version.dmg"
    fi

    echo "GitHub release created successfully!"
    echo "View at: https://github.com/BarutSRB/HyprSpace/releases/tag/v$build_version"
fi

# Update Homebrew cask if repo path is provided
if test -n "$cask_git_repo_path" && test -d "$cask_git_repo_path"; then
    echo "Updating Homebrew cask..."

    ./script/build-brew-cask.sh \
        --cask-name hyprspace \
        --zip-uri "https://github.com/BarutSRB/HyprSpace/releases/download/v$build_version/HyprSpace-v$build_version.zip" \
        --build-version "$build_version"

    eval "$cask_git_repo_path/pin.sh"
    cp -r .brew/hyprspace.rb "$cask_git_repo_path/Casks/hyprspace.rb"

    echo "Homebrew cask updated. Don't forget to commit and push the changes!"
fi

# Update site if repo path is provided
if test -n "$site_git_repo_path" && test -d "$site_git_repo_path"; then
    echo "Updating documentation site..."
    rm -rf "${site_git_repo_path:?}/*"
    cp -r .site/* "$site_git_repo_path"
    echo "Site updated. Don't forget to commit and push the changes!"
fi

echo "Release process complete!"