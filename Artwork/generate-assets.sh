#! /bin/sh

INKSCAPE=${INKSCAPE:-/Applications/Inkscape.app/Contents/Resources/bin/inkscape}
SOURCE_SVG=${SOURCE_SVG:-Artwork/Benzene.svg}

MACOS_APPICONSET=Soundtrack-macOS/Assets.xcassets/AppIcon.appiconset
MACOS_BENZENE_TEMPLATE_PDF=Soundtrack-macOS/Assets.xcassets/Benzene.imageset

cd $(dirname $0)/..
src_root=$(pwd)

input_file=${src_root}/${SOURCE_SVG}

output_base_name=Benzene

function gen_png () {
    local dest_dir=${src_root}/$1
    local sz=${2:-1024}

    ${INKSCAPE} \
        --file=${input_file} \
        --export-png=${dest_dir}/${output_base_name}-${sz}.png \
        --export-width=${sz} \
        --export-height=${sz}
}


function gen_template_pdf () {
    local dest_dir=${src_root}/$1
    
    local output_file=${dest_dir}/${output_base_name}-Template.pdf
    ${INKSCAPE} \
        --file=${input_file} \
        --export-pdf=${output_file}

    echo "Generated ${output_file}"
}

function gen_macos_icon () {
    gen_png ${MACOS_APPICONSET} "$@"
}

function gen_macos_benzene_template_pdf () {
    gen_template_pdf ${MACOS_BENZENE_TEMPLATE_PDF} "$@"
}

gen_macos_icon 1024
gen_macos_icon 512
gen_macos_icon 256
gen_macos_icon 128
gen_macos_icon 64
gen_macos_icon 32
gen_macos_icon 16

gen_macos_benzene_template_pdf
