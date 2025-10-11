#!/bin/bash

echo "==================================="
echo "HyprSpace Homebrew Tap Setup Script"
echo "==================================="
echo ""

# Check if this is being run in the right place
if [ ! -f "Casks/hyprspace.rb" ]; then
    echo "Error: This script must be run from the homebrew-tap-template directory"
    exit 1
fi

echo "This script will help you set up your own Homebrew tap for HyprSpace."
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " github_username

if [ -z "$github_username" ]; then
    echo "Error: GitHub username is required"
    exit 1
fi

echo ""
echo "Next steps to complete the setup:"
echo ""
echo "1. Create a new GitHub repository named 'homebrew-hyprspace'"
echo "   Visit: https://github.com/new"
echo ""
echo "2. Initialize and push this template to your new repository:"
echo ""
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/$github_username/homebrew-hyprspace.git"
echo "   git push -u origin main"
echo ""
echo "3. Configure repository secrets in GitHub:"
echo "   Go to: https://github.com/$github_username/homebrew-hyprspace/settings/secrets/actions"
echo ""
echo "   Add the following secrets:"
echo "   - GITHUB_TOKEN: Create at https://github.com/settings/tokens"
echo "     (needs 'repo' scope)"
echo ""
echo "4. Update the README.md to replace 'barutsrb' with '$github_username'"
echo ""
echo "5. Users can then install HyprSpace using:"
echo "   brew tap $github_username/hyprspace"
echo "   brew install --cask hyprspace"
echo ""
echo "The tap will automatically update when new releases are published!"
echo ""

# Optionally update files with the username
read -p "Would you like to automatically update the files with your username? (y/n): " update_files

if [ "$update_files" = "y" ] || [ "$update_files" = "Y" ]; then
    # Update README
    sed -i.bak "s/barutsrb/$github_username/g" README.md
    rm README.md.bak

    # Update Cask formula
    sed -i.bak "s/BarutSRB/$github_username/g" Casks/hyprspace.rb
    rm Casks/hyprspace.rb.bak

    # Update workflow
    sed -i.bak "s/BarutSRB/$github_username/g" .github/workflows/update-cask.yml
    rm .github/workflows/update-cask.yml.bak

    echo ""
    echo "Files have been updated with your username!"
fi

echo ""
echo "Setup complete! Follow the steps above to finish configuring your tap."