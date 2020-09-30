Write-Host "Running pdflatex as preparation in order to run Biber..."
pdflatex.exe -synctex=1 -interaction=nonstopmode script.tex
Write-Host "Running Biber..."
biber.exe script
Write-Host "Running pdflatex..."
pdflatex.exe -synctex=1 -interaction=nonstopmode script.tex > custom_log.log
Write-Host "Processing Errors..."
Get-Content custom_log.log | findstr /r "at( )*line[s]*[0-9]*" > custom_errors.log
Get-Content custom_log.log
if ((Get-Content custom_errors.log).length -ne 0){
	Write-Error "There were errors when compiling with latex!:"
	Get-Content custom_errors.log
	exit 1;
	} else {
	Write-Output "No errors or warnings found by regex."
	}
