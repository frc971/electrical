#!/bin/bash
set -x

num_layers=4
component_layer=FRONTandBACK
generate_ipc2581=1

source ./kicad-fab.cfg

if [ -z "$1" ]; then
    fnames=$(ls *.kicad_pro)
    fname_cnt=$(wc -w <<< "$fnames")
    if [[ "$fname_cnt" == 1 ]]; then
        fname=$(ls *.kicad_pro | cut -d'.' -f1)
    else
        echo "More than 1 file with *.kicad_pro"
        echo "Specify project name"
        exit
    fi
else
    fname=$1
fi
if [[ -z $kicad_local_plugins ]]; then
    kicad_local_plugins="$HOME/.local/share/kicad/8.0/3rdparty/plugins/"
fi
ibom_exe="org_openscopeproject_InteractiveHtmlBom/generate_interactive_bom.py"
sch=${fname}.kicad_sch
pcb=${fname}.kicad_pcb
pcb_fab_layers=User.1
#F.Mask

case $num_layers in
    2)
        gerber_layers=F.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,Edge.Cuts
        ;;
    4)
        gerber_layers=F.Cu,In1.Cu,In2.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,Edge.Cuts
        ;;
    *)
        echo "Layer Count Out of Range"
        exit
        ;;
esac

pcb_assembly_layers=User.2
src_files="./Analysis/*","./Components/*","*.kicad_sch","*.kicad_dru","*.kicad_pcb","*.kicad_prl","*.kicad_pro","fp-info-cache","fp_lib-table","3dModels/*","*.pretty"

function export_gerber () {
    layer=$1
    overlay_layer=$2
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
ZIP_DIR="./Output-Files/"

rm -r ${ZIP_DIR}
mkdir -p ${SCH_DIR}
mkdir -p ${FAB_DIR}
mkdir -p ${GERBER_DIR}

#check PCB DRC
kicad-cli pcb drc --schematic-parity --units mils --severity-all --output ${ZIP_DIR}/${fname}-drc.txt --exit-code-violations ${pcb}

#generate Interactive BOM

python3 $kicad_local_plugins/$ibom_exe --show-dialog $pcb

#generate schematic pdf
kicad-cli sch export pdf --output "${SCH_DIR}/${fname}-sch.pdf" ${sch}

#generate PCB gerbers
for layer in ${gerber_layers//,/ }
do
    export_gerber ${layer}
done

case $component_layer in
    FRONTandBACK)
        export_gerber F.Silkscreen 
        export_gerber B.Silkscreen 
        ;;
    FRONT)
        export_gerber F.Silkscreen 
        ;;
    BACK)
        export_gerber B.Silkscreen 
        ;;
    *)
        ;;
esac

#generate PCB NC drill file
kicad-cli pcb export drill --output ${GERBER_DIR}/ ${pcb}

#generate PCB Fab Drawing
kicad-cli pcb export pdf --drill-shape-opt 0 --output ${GERBER_DIR}/${fname}-fab.pdf --layers ${pcb_fab_layers} --include-border-title --black-and-white ${pcb} 

#generate BOM from schematic
kicad-cli sch export bom --sort-field "Reference" --sort-asc --group-by "MFG P/N" --fields "\${Item},\${QUANTITY},Reference,Value,MFG,MFG P/N,DIST,DIST P/N" --ref-range-delimiter "-" --exclude-dnp --output ${FAB_DIR}/${fname}-bom.csv $fname.kicad_sch 
update_bom_item_number ${FAB_DIR}/${fname}-bom.csv 

#generate Assembly Drawing
kicad-cli pcb export pdf --drill-shape-opt 0 --output ${FAB_DIR}/${fname}-assy.pdf --layers ${pcb_assembly_layers} --include-border-title --black-and-white ${pcb} 

#generate PnP file
case $component_layer in
    FRONTandBACK)
        kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-top-pos.txt --side front ${pcb} 
        kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-bot-pos.txt --side back ${pcb} 
        ;;
    FRONT)
        kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-top-pos.txt --side front ${pcb} 
        ;;
    BACK)
        kicad-cli pcb export pos --output ${FAB_DIR}/${fname}-bot-pos.txt --side back ${pcb} 
        ;;
    *)
        ;;
esac

#generate IPC2581 file
if [ ${generate_ipc2581} == 1 ]; then
    kicad-cli pcb export ipc2581 --output ${FAB_DIR}/${fname}-ipc2581.zip --compress --bom-col-mfg-pn "MFG P/N" --bom-col-mfg "MFG" --bom-col-dist-pn "DIST P/N" --bom-col-dist "DIST" ${pcb}
fi

#generate step file
kicad-cli pcb export step --output ${SCH_DIR}/${fname}.step --subst-models ${pcb}
pushd ${SCH_DIR}
zip ${fname}-step.zip ${fname}.step
rm ${fname}.step
popd


#create zip packages
pushd ${ZIP_DIR}
zip -r ${fname}-${timestamp}-gerbers.zip $(basename ${GERBER_DIR})
zip -r ${fname}-${timestamp}-fab.zip $(basename ${FAB_DIR})
popd

set +x
#print DRC report
cat ${ZIP_DIR}/${fname}-drc.txt

echo
echo "kicad-export-fab configuration"
echo
echo "Number of Layers: ${num_layers}"
echo "Component Layer: ${component_layer}"
echo "Generate ipc2581: ${generate_ipc2581}"

