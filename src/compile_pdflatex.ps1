pdflatex.exe -synctex=1 -interaction=nonstopmode .\script.tex > custom_log.log
Get-Content custom_log.log | findstr /r "at( )*line[s]*[0-9]*" > custom_errors.log
Get-Content custom_errors.log
if ((Get-Content custom_errors.log).length -ne 0){
	Write-Error "There were errors when compiling with latex!"
	exit 1;
	} else {
	Write-Output "No errors or warnings found by regex."
	}
