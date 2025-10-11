# HyprSpace Distribution Guide

This guide explains the complete distribution setup for HyprSpace and how to use it effectively.

## ❌ Mac App Store Compatibility

**HyprSpace CANNOT be distributed through the Mac App Store** due to:

1. **Private API Usage**: Uses `_AXUIElementGetWindow` which Apple forbids
2. **Sandbox Restrictions**: Accessibility API requires sandbox to be disabled
3. **System-wide Permissions**: Window managers need deep system access

This is normal - virtually all macOS window managers distribute outside the App Store.

## ✅ Available Distribution Methods

### 1. GitHub Releases (Automated)

**Setup Required**: Configure GitHub Actions secrets (see below)

**How it works**:
- Push a version tag (e.g., `v1.0.0`) to trigger automated release
- GitHub Actions builds, signs, notarizes, and uploads everything
- Users download DMG or ZIP from GitHub Releases page

### 2. Homebrew Tap

**Setup Required**: Create `homebrew-hyprspace` repository

**How it works**:
- Users add your tap: `brew tap yourusername/hyprspace`
- Install with: `brew install --cask hyprspace`
- Automatic updates when new releases are published

### 3. Direct Download

**No setup required** - Works immediately

**How it works**:
- Build locally with `./build-release.sh`
- Upload ZIP/DMG manually to GitHub Releases
- Users download and install manually

## 🚀 Quick Start Guide

### Step 1: Set Up GitHub Actions (Recommended)

1. Go to your repository settings on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Add these secrets:

#### Required for Basic Releases:
- None! Basic releases work without any secrets

#### For Code Signing (Recommended):
- `CODESIGN_IDENTITY`: Your Developer ID certificate name
- `CERTIFICATES_P12`: Base64-encoded certificate:
  ```bash
  base64 -i certificates.p12 | pbcopy
  ```
- `CERTIFICATES_PASSWORD`: Certificate password
- `KEYCHAIN_PASSWORD`: Any password for temporary keychain

#### For Notarization (Optional, requires Apple Developer account):
- `APPLE_ID`: Your Apple ID email
- `APPLE_ID_PASSWORD`: App-specific password (create at appleid.apple.com)
- `APPLE_TEAM_ID`: Your Apple Developer Team ID

#### For Homebrew Tap Updates:
- `HOMEBREW_TAP_TOKEN`: GitHub personal access token with `repo` scope

### Step 2: Create Your First Release

#### Option A: Automated (Easiest)

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
- Build universal binaries
- Sign and notarize (if configured)
- Create DMG installer
- Upload to GitHub Releases
- Update Homebrew tap (if configured)

#### Option B: Manual

```bash
# Build the release
./build-release.sh --build-version "1.0.0"

# Create DMG
cd .release
./create-dmg.sh "HyprSpace-v1.0.0.dmg" "HyprSpace.app"
cd ..

# Use automated publishing script
./script/publish-release-automated.sh --build-version "1.0.0"
```

### Step 3: Set Up Homebrew Tap (Optional)

1. Create a new GitHub repository named `homebrew-hyprspace`
2. Copy the template:
   ```bash
   cp -r homebrew-tap-template/* /path/to/homebrew-hyprspace/
   ```
3. Run the setup script:
   ```bash
   cd /path/to/homebrew-hyprspace
   ./setup.sh
   ```
4. Push to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/yourusername/homebrew-hyprspace.git
   git push -u origin main
   ```

## 📋 Distribution Checklist

Before each release:

- [ ] Run all tests: `./run-tests.sh`
- [ ] Update version in appropriate files
- [ ] Write release notes
- [ ] Test on both Intel and Apple Silicon Macs
- [ ] Verify accessibility permissions work correctly

For automated releases:

- [ ] Push version tag: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] Monitor GitHub Actions for completion
- [ ] Verify release appears on GitHub Releases page
- [ ] Test Homebrew installation (if tap is set up)

For manual releases:

- [ ] Build release: `./build-release.sh --build-version "1.0.0"`
- [ ] Create DMG: `cd .release && ./create-dmg.sh`
- [ ] Upload to GitHub Releases
- [ ] Update Homebrew tap (if applicable)

## 🔧 Advanced Configuration

### Apple Developer ID Signing

To properly sign your app for distribution:

1. Enroll in Apple Developer Program ($99/year)
2. Create a Developer ID Application certificate
3. Export as .p12 file
4. Configure in GitHub Actions secrets or use locally

Benefits:
- No quarantine warnings for users
- Gatekeeper approval
- Professional appearance

### Notarization

Notarization adds Apple's stamp of approval:

1. Requires Apple Developer account
2. Create app-specific password at appleid.apple.com
3. Configure credentials in GitHub Actions or build script
4. Automatically runs during release process

Benefits:
- Seamless installation experience
- No "unidentified developer" warnings
- Required for future macOS versions

### Homebrew Tap Automation

The tap automatically updates when:
- New GitHub releases are published
- Daily scheduled check finds new versions
- Manual workflow trigger

Users get updates via standard `brew upgrade`.

## 📁 File Structure

After setting up distribution, you'll have:

```
HyprSpace/
├── .github/
│   └── workflows/
│       ├── release.yml       # Automated release workflow
│       └── ci.yml            # CI testing workflow
├── .release/
│   ├── create-dmg.sh        # DMG creation script
│   └── (build outputs)
├── homebrew-tap-template/    # Homebrew tap template
│   ├── Casks/
│   │   └── hyprspace.rb
│   ├── .github/
│   │   └── workflows/
│   │       └── update-cask.yml
│   └── setup.sh
├── script/
│   ├── publish-release-automated.sh  # Automated publishing
│   └── build-brew-cask.sh           # Cask generation
└── DISTRIBUTION.md           # This guide
```

## 🆘 Troubleshooting

### GitHub Actions fails to sign

- Verify certificate is valid and not expired
- Check certificate is for "Developer ID Application"
- Ensure base64 encoding is correct
- Verify all secrets are set correctly

### Notarization fails

- Check Apple ID credentials are correct
- Ensure app-specific password (not regular password)
- Verify Team ID matches your developer account
- Check Apple Developer account is active

### Homebrew tap not updating

- Verify HOMEBREW_TAP_TOKEN has `repo` scope
- Check tap repository exists and is public
- Ensure workflow has correct repository name

### DMG creation fails

- Ensure HyprSpace.app exists in .release/
- Check disk space available
- Verify no conflicting volume mounts

## 📚 Resources

- [Apple Developer - Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Creating DMG Installers](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-disk-image-format)

## 🎉 Success!

Once configured, your distribution pipeline will:

1. **Automatically build** when you push tags
2. **Sign and notarize** for smooth installation
3. **Create professional DMG** installers
4. **Update Homebrew** tap automatically
5. **Generate release notes** from commits

Users will be able to install HyprSpace easily via Homebrew or direct download, with a professional experience rivaling commercial applications.