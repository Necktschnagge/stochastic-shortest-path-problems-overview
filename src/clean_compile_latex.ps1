$confirmation = Read-Host "Are you Sure You Want To Proceed? This will reset files using git!"
if ($confirmation -eq 'y') {
    Push-Location
    cd ..
    Write-Host "Cleaning files.."
    .\clean_init.ps1
    Pop-Location
    .\compile_pdflatex.ps1
}
