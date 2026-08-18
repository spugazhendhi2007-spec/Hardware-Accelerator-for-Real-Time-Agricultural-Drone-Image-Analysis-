# Git Auto-Sync Helper for Agricultural Drone Image Analysis Accelerator
param (
    [string]$CommitMessage = "update: incremental design and verification changes"
)

$gitDir = "$env:LOCALAPPDATA\Programs\MinGit\cmd"
$ghExe = (Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\gh" -Filter "gh.exe" -Recurse | Select-Object -First 1).FullName
$env:Path = "$gitDir;$([System.IO.Path]::GetDirectoryName($ghExe));$env:Path"

git add -A
$status = git status --porcelain
if ($status) {
    git commit -m $CommitMessage
    git push origin main
    Write-Output "[Git Sync] Successfully committed and pushed to GitHub main."
} else {
    Write-Output "[Git Sync] Working tree clean, no changes to commit."
}
