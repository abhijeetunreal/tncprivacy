#Requires -Modules PowerShellGet
#Requires -Version 5.0

<#
.SYNOPSIS
    Automates the creation of a new Hugo website using the PaperMod theme, including dependency installation and CI/CD setup.
.DESCRIPTION
    This script prompts the user for a website name and a GitHub username, then performs the following actions:
    1. Checks for and installs dependencies like Hugo and Git using Chocolatey.
    2. Creates a new Hugo site in a new folder.
    3. Initializes a Git repository inside the new site folder.
    4. Adds the PaperMod theme as a submodule.
    5. Creates and configures the 'hugo.yaml' file.
    6. Creates 'archive.md' and 'search.md' content files.
    7. Creates a custom footer partial.
    8. Creates a GitHub Actions workflow file for automatic deployment to GitHub Pages.
.NOTES
    Author: Your Name
    Date: 20/07/2025
    Requires PowerShell to be run as an Administrator to install software.
    Uses Chocolatey for package management.
#>

# --- Check for Administrator privileges ---
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges to install software. Please re-run PowerShell as an Administrator."
    return
}


# --- Function to check if a command exists ---
function Test-CommandExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )
    return (Get-Command $Command -ErrorAction SilentlyContinue)
}

# --- Check for dependencies ---
# 1. Check for Chocolatey
if (-not (Test-CommandExists "choco")) {
    Write-Host "Chocolatey is not installed. It is required to automatically install Hugo and Git." -ForegroundColor Yellow
    Write-Host "Please install Chocolatey by running the following command in an Administrator PowerShell and then re-run this script:" -ForegroundColor Yellow
    Write-Host 'Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(''https://community.chocolatey.org/install.ps1''))' -ForegroundColor Cyan
    return
}

# 2. Check for Hugo
if (-not (Test-CommandExists "hugo")) {
    Write-Host "Hugo not found. Installing with Chocolatey..." -ForegroundColor Yellow
    choco install hugo -y
    if (-not (Test-CommandExists "hugo")) {
        Write-Host "Hugo installation failed. Please install it manually and re-run the script." -ForegroundColor Red
        return
    }
}

# 3. Check for Git
if (-not (Test-CommandExists "git")) {
    Write-Host "Git not found. Installing with Chocolatey..." -ForegroundColor Yellow
    choco install git -y
    if (-not (Test-CommandExists "git")) {
        Write-Host "Git installation failed. Please install it manually and re-run the script." -ForegroundColor Red
        return
    }
}

# --- User Input ---
$websiteName = Read-Host -Prompt "Enter the name of your website (e.g., MyFreshWebsite)"
if ([string]::IsNullOrWhiteSpace($websiteName)) {
    Write-Host "Website name cannot be empty." -ForegroundColor Red
    return
}

$githubUsername = Read-Host -Prompt "Enter your GitHub username"
if ([string]::IsNullOrWhiteSpace($githubUsername)) {
    Write-Host "GitHub username cannot be empty." -ForegroundColor Red
    return
}

# --- Script Execution ---
$initialDirectory = Get-Location

try {
    # Check if a directory with the same name already exists
    if (Test-Path -Path $websiteName) {
        Write-Host "A directory named '$websiteName' already exists here. Please choose a different name or run the script from another directory." -ForegroundColor Red
        return
    }

    Write-Host "Creating new Hugo site: $websiteName" -ForegroundColor Green
    hugo new site $websiteName --format yaml
    
    # Verify site creation and change directory
    if (-not (Test-Path -Path $websiteName -PathType Container)) {
        Write-Host "Failed to create the site directory. Aborting." -ForegroundColor Red
        return
    }
    Set-Location $websiteName

    Write-Host "Initializing Git repository..." -ForegroundColor Green
    git init
    
    # Add all initial files to git
    git add .
    git commit -m "Initial commit of Hugo site structure"

    Write-Host "Adding PaperMod theme as a submodule..." -ForegroundColor Green
    git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
    git submodule update --init --recursive

    # --- Configure hugo.yaml ---
    Write-Host "Configuring hugo.yaml..." -ForegroundColor Green
    $configContent = @"
baseURL: "https://$($githubUsername).github.io/$($websiteName)/"
title: $websiteName
theme: PaperMod

enableRobotsTXT: true

minify:
  disableXML: true
  minifyOutput: true

menu:
  main:
    - identifier: home
      name: Home
      url: /
      weight: 10
    - identifier: archive
      name: Archive
      url: /archives
      weight: 12
    - identifier: search
      name: Search
      url: /search/
      weight: 15
"@
    # Note: This overwrites the default 'hugo.yaml' created by the 'hugo new site' command.
    Set-Content -Path "hugo.yaml" -Value $configContent -Force

    # --- Create content files ---
    $contentPath = "content"
    if (-not (Test-Path -Path $contentPath -PathType Container)) {
        New-Item -ItemType Directory -Path $contentPath
    }

    Write-Host "Creating archive.md..." -ForegroundColor Green
    $archiveContent = @"
---
title: "Archive"
layout: "archives"
url: "/archives/"
summary: "archives"
---
"@
    Set-Content -Path (Join-Path $contentPath "archives.md") -Value $archiveContent

    Write-Host "Creating search.md..." -ForegroundColor Green
    $searchContent = @"
---
title: "Search"
layout: "search"
url: "/search/"
placeholder: "Search by post or keyword"
summary: "search"
description: "Search for any keyword..."
---
"@
    Set-Content -Path (Join-Path $contentPath "search.md") -Value $searchContent
    
    # Commit the configuration and content changes
    git add .
    git commit -m "Configure PaperMod theme and add initial content"

    # --- Create custom footer ---
    Write-Host "Creating custom footer partial..." -ForegroundColor Green
    $partialsPath = "layouts/partials"
    New-Item -Path $partialsPath -ItemType Directory -Force
    
    $footerContent = @"
{{- if not (.Param "hideFooter") }}
<footer class="footer">
    {{- if not site.Params.footer.hideCopyright }}
        {{- if site.Copyright }}
        <span>{{ site.Copyright | markdownify }}</span>
        {{- else }}
        <span>&copy; {{ now.Year }} <a href="{{ "" | absLangURL }}">{{ site.Title }}</a></span>
        {{- end }}
        {{- print " · "}}
    {{- end }}

    {{- with site.Params.footer.text }}
        {{ . | markdownify }}
        {{- print " · "}}
    {{- end }}

    <span>
        Powered by
        <a href="https://gohugo.io/" rel="noopener noreferrer" target="_blank">Hugo</a> &
        <a href="https://github.com/adityatelange/hugo-PaperMod/" rel="noopener" target="_blank">PaperMod</a>
    </span>
</footer>
{{- end }}
"@
    Set-Content -Path (Join-Path $partialsPath "footer.html") -Value $footerContent

    # --- Create GitHub Actions CI/CD workflow ---
    Write-Host "Creating GitHub Actions workflow for deployment..." -ForegroundColor Green
    $workflowPath = ".github/workflows"
    New-Item -Path $workflowPath -ItemType Directory -Force
    
    $deployYamlContent = @"
name: Deploy Hugo site to GitHub Pages

on:
  push:
    branches:
      - main # or master

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3
        with:
          submodules: true # Fetch Hugo themes (true OR recursive)
          fetch-depth: 0 # Fetch all history for .GitInfo and .Lastmod

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: 'latest'
          # extended: true # Uncomment if you need extended version

      - name: Build
        run: hugo --minify

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: `$`{{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
          # publish_branch: gh-pages # Default is gh-pages
"@
    # Note: The backtick ` before ${{ is to escape it in PowerShell's here-string
    Set-Content -Path (Join-Path $workflowPath "deploy.yml") -Value $deployYamlContent
    
    # Commit the workflow file and footer
    git add .
    git commit -m "Add custom footer and GitHub Actions workflow"

    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Hugo project '$websiteName' created successfully!" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Create a new repository on GitHub named '$websiteName'."
    Write-Host "2. Link your local repository to GitHub and push the 'main' branch."
    Write-Host "3. The GitHub Actions workflow will automatically build and deploy your site."
    Write-Host "To start the local server, run: 'hugo server'" -ForegroundColor White
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan

}
catch {
    Write-Host "An error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    # Return to the original directory where the script was run
    Write-Host "Returning to original directory: $($initialDirectory.Path)" -ForegroundColor Gray
    Set-Location $initialDirectory
}
