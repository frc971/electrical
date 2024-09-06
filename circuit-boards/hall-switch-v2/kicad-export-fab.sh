#!/bin/bash
set -x

#./kicad-export-fab.sh NameofFile

#fname=NX-J401-Adapter
fname=$1

sch=${fname}.kicad_sch
pcb=${fname}.kicad_pcb
pcb_fab_layers=User.1,User.Drawings,User.Comments,Edge.Cuts
#F.Mask
gerber_layers=F.Cu,In1.Cu,In2.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,Edge.Cuts,F.Silkscreen,B.Silkscreen
pcb_assy_top_layers=Edge.Cuts,F.Fab
pcb_assy_bot_layers=Edge.Cuts,B.Fab
pcb_assembly_layers=User.2
src_files="./Analysis/*","./Components/*","*.kicad_sch","*.kicad_dru","*.kicad_pcb","*.kicad_prl","*.kicad_pro","fp-info-cache","fp_lib-table","3dModels/*","*.pretty"

function export_gerber () {
    layer=$1
    layer_fname=$(echo $layer| tr "." _ )
    /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export gerber --output "${GERBER_DIR}/${fname}-${layer_fname}.gbr" --layers ${layer} ${pcb}
}

timestamp=$(date +"%d%b%Y")

SCH_DIR="./Output-Files/Design-Files/"
FAB_DIR="./Output-Files/Assembly-Files/"
GERBER_DIR="./Output-Files/Gerbers/"
ZIP_DIR="./Output-Files/"
plugin_path="/Applications/KiCad/KiCad.app/Contents/SharedSupport/scripting/plugins/"

mkdir -p ${SCH_DIR}
mkdir -p ${FAB_DIR}
mkdir -p ${GERBER_DIR}

#generate schematic pdf
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli sch export pdf --output "${SCH_DIR}/${fname}-sch-$timestamp.pdf" ${sch}

#generate PCB gerbers
for layer in ${gerber_layers//,/ }
do
    export_gerber ${layer}
done

#generate PCB NC drill file
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export drill --output ${GERBER_DIR}/ ${pcb}

#generate PCB Fab Drawing
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export pdf --output ${GERBER_DIR}/${fname}-fab-${timestamp}.pdf --layers ${pcb_fab_layers} --include-border-title --black-and-white ${pcb}

#generate BOM from schematic
./kicad-group-bom.py -i ${fname}.csv -o ${FAB_DIR}/${fname}-bom-${timestamp}.csv
cp bom/ibom.html ${FAB_DIR}/${fname}-ibom-${timestamp}.html

#generate PCB assembly drawing
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export pdf --output ${FAB_DIR}/${fname}-assy-${timestamp}.pdf --layers ${pcb_assembly_layers} --include-border-title --black-and-white ${pcb}

#generate PnP file
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-top-pos.txt --side front ${pcb}
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-bot-pos.txt --side back ${pcb}

#create zip file
pushd ${SCH_DIR}
zip ${fname}-step-${timestamp}.zip ${fname}.step
rm ${fname}.step
popd

#create zip packages
pushd ${ZIP_DIR}
zip -r ${fname}-gerbers-$timestamp.zip $(basename ${GERBER_DIR})
zip -r ${fname}-fab-$timestamp.zip $(basename ${FAB_DIR})
popd
