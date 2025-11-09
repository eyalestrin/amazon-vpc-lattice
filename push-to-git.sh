#!/bin/bash

# Script to push code to GitHub repository
# Repository: https://github.com/eyalestrin/amazon-vpc-lattice

set -e

echo "Preparing to push code to GitHub..."

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
fi

# Add all files
echo "Adding files to git..."
git add .

# Commit changes
echo "Enter commit message (or press Enter for default):"
read COMMIT_MSG

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Initial commit: AWS VPC Lattice cross-account transaction store"
fi

git commit -m "$COMMIT_MSG"

# Check if remote exists
if ! git remote | grep -q "origin"; then
    echo "Adding remote repository..."
    git remote add origin https://github.com/eyalestrin/amazon-vpc-lattice.git
fi

# Set main branch
git branch -M main

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main

echo "Successfully pushed to https://github.com/eyalestrin/amazon-vpc-lattice"