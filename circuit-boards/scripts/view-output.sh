#!/bin/bash

pdfviewer=okular
htmlviewer=google-chrome
csvviewer=libreoffice
gerberviewer=gerbview
txtviewer=gvim
assemblyfiles="./Output-Files/Assembly-Files/"
designfiles="./Output-Files/Design-Files/"
gerberfiles="./Output-Files/Gerbers/"

pushd ${assemblyfiles}
$pdfviewer *.pdf &
$csvviewer *.csv &
$htmlviewer *.html &
$txtviewer *.txt &
popd

pushd ${designfiles}
$pdfviewer *.pdf &
popd

pushd ${gerberfiles}
$pdfviewer *.pdf &
$gerberviewer *.gbr *.drl &
popd

