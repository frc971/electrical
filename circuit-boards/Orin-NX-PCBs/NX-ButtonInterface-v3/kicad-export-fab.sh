#!/bin/bash
set -x

#fname=NX-J401-Adapter
fname=$1

kicad_local_plugins="$HOME/.local/share/kicad/8.0/3rdparty/plugins/"
ibom_exe="org_openscopeproject_InteractiveHtmlBom/generate_interactive_bom.py"
sch=${fname}.kicad_sch
pcb=${fname}.kicad_pcb
pcb_fab_layers=User.1
#F.Mask
gerber_layers=F.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,Edge.Cuts,F.Silkscreen,B.Silkscreen
pcb_assy_top_layers=Edge.Cuts,F.Fab
pcb_assy_bot_layers=Edge.Cuts,B.Fab
pcb_assembly_layers=User.2
src_files="./Analysis/*","./Components/*","*.kicad_sch","*.kicad_dru","*.kicad_pcb","*.kicad_prl","*.kicad_pro","fp-info-cache","fp_lib-table","3dModels/*","*.pretty"

function export_gerber () {
    layer=$1
    layer_fname=$(echo $layer| tr "." _ )
    kicad-cli pcb export gerber --output "${GERBER_DIR}/${fname}-${layer_fname}.gbr" --layers ${layer} ${pcb}
}
function update_bom_item_number () {
    set +x
    fileName=$1
    item=1
    touch ${fileName}.tmp
    while IFS= read -r line; do
        if [[ "${line}" =~ "{Item}" ]]; then
            echo ${line/\$\{Item\}/${item}} >> ${fileName}.tmp
            item=$((item+1))
        else
            echo ${line} >> ${fileName}.tmp
        fi
    done < ${fileName}
    rm ${fileName}
    mv ${fileName}.tmp ${fileName}
    set -x
}


timestamp=$(date +"%d%b%Y")

SCH_DIR="./Output-Files/Design-Files/"
FAB_DIR="./Output-Files/Assembly-Files/"
GERBER_DIR="./Output-Files/Gerbers/"
#TEMP_DIR="./Output-Files/Temp/"
ZIP_DIR="./Output-Files/"
plugin_path="/usr/share/kicad/plugins/"


mkdir -p ${SCH_DIR}
mkdir -p ${FAB_DIR}
mkdir -p ${GERBER_DIR}

#generate schematic pdf
kicad-cli sch export pdf --output "${SCH_DIR}/${fname}-sch.pdf" ${sch}

generate PCB gerbers
for layer in ${gerber_layers//,/ }
do
    export_gerber ${layer}
done

#check DRC
kicad-cli pcb drc --output ${ZIP_DIR}/${fname}-drc.txt --schematic-parity --units mils --severity-all ${pcb}

#generate PCB NC drill file
kicad-cli pcb export drill --output ${GERBER_DIR}/ ${pcb}

#generate PCB Fab Drawing
kicad-cli pcb export pdf --drill-shape-opt 0 --output ${GERBER_DIR}/${fname}-fab.pdf --layers ${pcb_fab_layers} --include-border-title --black-and-white ${pcb} 

#generate BOM from schematic
kicad-cli sch export bom --sort-field "Reference" --sort-asc --group-by "MFG P/N" --fields "\${Item},\${QUANTITY},Reference,Value,MFG,MFG P/N,DIST,DIST P/N" --ref-range-delimiter "-" --exclude-dnp --output ${FAB_DIR}/${fname}-bom.csv $fname.kicad_sch 
update_bom_item_number ${FAB_DIR}/${fname}-bom.csv

#generate Assembly Drawing
kicad-cli pcb export pdf --drill-shape-opt 0 --output ${FAB_DIR}/${fname}-assy.pdf --layers ${pcb_assembly_layers} --include-border-title --black-and-white ${pcb} 

#generate Interactive BOM

python3 $kicad_local_plugins/$ibom_exe --show-dialog $pcb

#generate PnP file
kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-top-pos.txt --side front ${pcb} 
kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-bot-pos.txt --side back ${pcb} 

#generate step file
kicad-cli pcb export step --output ${SCH_DIR}/${fname}.step --subst-models ${pcb}
pushd ${SCH_DIR}
zip ${fname}-step.zip ${fname}.step
rm ${fname}.step
popd


#create zip packages
pushd ${ZIP_DIR}
zip -r ${fname}-gerbers.zip $(basename ${GERBER_DIR})
zip -r ${fname}-fab.zip $(basename ${FAB_DIR})
popd

#print drc file
cat ${ZIP_DIR}/${fname}-drc.txt
