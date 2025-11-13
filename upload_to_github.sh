#!/bin/bash

set -e

echo "================================================"
echo "🚀 Full GitHub Bootstrap & Upload Script"
echo "================================================"

# --- Check dependencies ---
if ! command -v git &> /dev/null; then
  echo "❌ git is not installed."
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) is not installed."
  echo "   Install from: https://cli.github.com/"
  exit 1
fi

# --- Check GitHub auth ---
USERNAME=$(gh api user --jq .login 2>/dev/null || true)
if [ -z "$USERNAME" ]; then
  echo "❌ You are not logged into GitHub CLI."
  echo "   Run: gh auth login"
  exit 1
fi

echo "🔑 Authenticated as: $USERNAME"
echo ""

# --- Ask for basic repo info ---
read -p "📦 GitHub repository name: " REPO_NAME
read -p "📝 Repository description: " DESCRIPTION

read -p "🔒 Visibility (public/private): " VISIBILITY
if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
  echo "❌ Invalid visibility. Must be 'public' or 'private'."
  exit 1
fi

# --- LICENSE info ---
CURRENT_YEAR=$(date +%Y)
read -p "👤 Your full name for LICENSE (e.g. John Doe): " FULL_NAME

# --- GitHub Pages option ---
read -p "📘 Enable GitHub Pages using /docs? (y/n): " ENABLE_PAGES

echo ""
echo "📁 Ensuring .github structure exists..."
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE

# -------------------------------------------------
# 1) Terraform CI workflow
# -------------------------------------------------
echo "⚙️  Creating Terraform CI workflow..."
cat > .github/workflows/terraform.yml <<'EOF'
name: Terraform CI

on:
  push:
    branches:
      - main
      - dev
  pull_request:

jobs:
  terraform:
    name: Terraform Validate & Plan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform -chdir=terraform init

      - name: Terraform Validate
        run: terraform -chdir=terraform validate

      - name: Terraform Plan
        run: terraform -chdir=terraform plan
EOF

# -------------------------------------------------
# 2) Dependabot config
# -------------------------------------------------
echo "🛡  Adding Dependabot config..."
cat > .github/dependabot.yml <<'EOF'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "terraform"
    directory: "/terraform"
    schedule:
      interval: "weekly"
EOF

# -------------------------------------------------
# 3) Pre-commit config
# -------------------------------------------------
echo "🧹 Adding pre-commit config..."
cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
EOF

# -------------------------------------------------
# 4) Pull Request template
# -------------------------------------------------
echo "📝 Creating PR template..."
cat > .github/pull_request_template.md <<'EOF'
## Description

Please include a summary of the change and which issue is fixed.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## How Has This Been Tested?

- [ ] terraform fmt
- [ ] terraform validate
- [ ] terraform plan

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
EOF

# -------------------------------------------------
# 5) Issue templates
# -------------------------------------------------
echo "🐛 Creating issue templates..."
cat > .github/ISSUE_TEMPLATE/bug_report.md <<'EOF'
---
name: Bug report
about: Create a report to help us improve
labels: bug
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:

1. Go to '...'
2. Run '...'
3. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Additional context**
Add any other context about the problem here.
EOF

cat > .github/ISSUE_TEMPLATE/feature_request.md <<'EOF'
---
name: Feature request
about: Suggest an idea for this project
labels: enhancement
---

**Is your feature request related to a problem?**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Any alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request here.
EOF

cat > .github/ISSUE_TEMPLATE/config.yml <<'EOF'
blank_issues_enabled: true
EOF

# -------------------------------------------------
# 6) CODEOWNERS
# -------------------------------------------------
echo "👥 Adding CODEOWNERS..."
cat > .github/CODEOWNERS <<EOF
* @$USERNAME
EOF

# -------------------------------------------------
# 7) MIT LICENSE
# -------------------------------------------------
echo "📄 Creating MIT LICENSE..."
cat > LICENSE <<EOF
MIT License

Copyright (c) $CURRENT_YEAR $FULL_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# -------------------------------------------------
# 8) Optional GitHub Pages docs
# -------------------------------------------------
if [[ "$ENABLE_PAGES" == "y" || "$ENABLE_PAGES" == "Y" ]]; then
  echo "📘 Creating /docs for GitHub Pages..."
  mkdir -p docs
  cat > docs/index.html <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <title>GitHub Pages - Terraform + Docker Project</title>
  </head>
  <body>
    <h1>Terraform + Docker EC2 Project</h1>
    <p>This site is served from the <code>/docs</code> folder via GitHub Pages.</p>
  </body>
</html>
EOF
  ENABLE_PAGES_FLAG=true
else
  ENABLE_PAGES_FLAG=false
fi

# -------------------------------------------------
# 9) Initialize git & first commit
# -------------------------------------------------
echo ""
echo "📁 Initializing git (if not already)..."
if [ ! -d .git ]; then
  git init -q
fi

# Ensure main branch
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
  git checkout -b main -q
elif [ "$CURRENT_BRANCH" != "main" ]; then
  git branch -M main
fi

echo "📝 Creating initial commit..."
git add .
git commit -m "feat: initial project with CI, templates, and tooling" -q

# -------------------------------------------------
# 10) Create GitHub repo & push main
# -------------------------------------------------
echo ""
echo "🌐 Creating GitHub repository..."
gh repo create "$REPO_NAME" \
  --"$VISIBILITY" \
  --description "$DESCRIPTION" \
  --source=. \
  --remote=origin \
  --push

echo "✅ Repository created: https://github.com/$USERNAME/$REPO_NAME"

# -------------------------------------------------
# 11) Create dev & prod branches
# -------------------------------------------------
echo ""
echo "🌱 Creating dev and prod branches..."
git checkout -b dev -q
git push -u origin dev -q

git checkout -b prod -q
git push -u origin prod -q

git checkout main -q
echo "✅ Branches dev & prod created and pushed."

# -------------------------------------------------
# 12) Enable GitHub Pages (if chosen)
# -------------------------------------------------
if [ "$ENABLE_PAGES_FLAG" = true ]; then
  echo ""
  echo "📘 Enabling GitHub Pages from /docs..."
  gh api \
    repos/$USERNAME/$REPO_NAME/pages \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    --input - <<'EOF'
{
  "source": {
    "branch": "main",
    "path": "/docs"
  }
}
EOF
  echo "✅ GitHub Pages enabled: https://$USERNAME.github.io/$REPO_NAME/"
fi

# -------------------------------------------------
# 13) Create labels
# -------------------------------------------------
echo ""
echo "🏷️ Creating default labels..."
# Ignore errors if labels exist
gh label create bug --color FF0000 --description "Something isn't working" 2>/dev/null || true
gh label create enhancement --color 00FF00 --description "New feature or improvement" 2>/dev/null || true
gh label create documentation --color 0000FF --description "Docs updates" 2>/dev/null || true
gh label create chore --color 888888 --description "Chore or maintenance" 2>/dev/null || true

echo "✅ Labels configured."

# -------------------------------------------------
# 14) Create some starter issues
# -------------------------------------------------
echo ""
echo "📌 Creating starter issues..."
gh issue create \
  --title "Set up AWS credentials and S3 backend" \
  --body "Configure AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) and create the S3 bucket for Terraform backend before running 'terraform init' and 'terraform apply'." \
  --label chore \
  >/dev/null || true

gh issue create \
  --title "Run initial terraform apply" \
  --body "Run 'terraform init', 'terraform plan', and 'terraform apply' to deploy the EC2 instance with Nginx Docker container." \
  --label enhancement \
  >/dev/null || true

gh issue create \
  --title "Improve README with architecture diagram" \
  --body "Add an architecture diagram (Terraform -> AWS EC2 -> Docker -> Nginx) to the README for better documentation." \
  --label documentation \
  >/dev/null || true

echo "✅ Starter issues created."

# -------------------------------------------------
# 15) Create a repo project board (classic)
# -------------------------------------------------
echo ""
echo "📋 Creating GitHub project board (classic)..."
gh api \
  repos/$USERNAME/$REPO_NAME/projects \
  -H "Accept: application/vnd.github.inertia+json" \
  --method POST \
  -f name="Main Board" \
  -f body="Kanban board for this Terraform + Docker EC2 project." \
  >/dev/null || true
echo "✅ Project board created (see the Projects tab in the repo)."

# -------------------------------------------------
# 16) Tag & Release
# -------------------------------------------------
echo ""
echo "🏷️ Creating v1.0.0 tag and release..."
git tag v1.0.0
git push origin v1.0.0 -q

gh release create v1.0.0 \
  --title "Initial Release" \
  --notes "First automated release of the Terraform + Docker EC2 project." \
  >/dev/null

echo "✅ Release v1.0.0 created."

echo ""
echo "================================================"
echo "🎉 All done!"
echo "GitHub Repository: https://github.com/$USERNAME/$REPO_NAME"
if [ "$ENABLE_PAGES_FLAG" = true ]; then
  echo "GitHub Pages:    https://$USERNAME.github.io/$REPO_NAME/"
fi
echo "Branches:        main, dev, prod"
echo "Tools added:     CI, Dependabot, pre-commit, PR & issue templates, CODEOWNERS, LICENSE, labels, project board, release."
echo "================================================"
