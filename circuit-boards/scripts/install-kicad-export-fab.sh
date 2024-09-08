#!/bin/bash
target_dir=$1

scripts_path=$(realpath -s --relative-to="$target_dir" "$PWD")

pushd ${target_dir} >> /dev/null


if [ ! -f kicad-export-fab.sh ]; then
    echo "Creating kicad-export-fab.sh symbolic link"
    ln -s $scripts_path/kicad-export-fab.sh kicad-export-fab.sh
else
    echo "kicad-export-fab.sh exists"
fi

if [ ! -f view-output.sh ]; then
    echo "Creating view-output.sh symbolic link"
    ln -s $scripts_path/view-output.sh view-output.sh
else
    echo "view-output.sh exists"
fi

if [ ! -f kicad-fab.cfg ]; then
    echo "copying default kicad-fab.cfg"
    cp $scripts_path/kicad-fab.cfg .
else
    echo "kicad-fab.cfg exists"
fi

popd >> /dev/null


