#! /bin/sh

INKSCAPE=${INKSCAPE:-/Applications/Inkscape.app/Contents/Resources/bin/inkscape}
SOURCE_SVG=${SOURCE_SVG:-Artwork/benzene.svg}

MACOS_APPICONSET=Soundtrack-macOS/Assets.xcassets/AppIcon.appiconset

cd $(dirname $0)/..
src_root=$(pwd)

input_file=${src_root}/${SOURCE_SVG}

output_base_name=benzene

function gen_pdf () {
    local dest_dir=${src_root}/$1

    ${INKSCAPE} \
        --file=${input_file} \
        --export-pdf=${dest_dir}/${output_base_name}.pdf
}

function gen_png () {
    local dest_dir=${src_root}/$1
    local sz=${2:-1024}

    ${INKSCAPE} \
        --file=${input_file} \
        --export-png=${dest_dir}/${output_base_name}-${sz}.png \
        --export-width=${sz} \
        --export-height=${sz}
}

function gen_macos_icon () {
    gen_png ${MACOS_APPICONSET} "$@"
}

# gen_pdf

gen_macos_icon 1024
gen_macos_icon 512
gen_macos_icon 256
gen_macos_icon 128
gen_macos_icon 64
gen_macos_icon 32
gen_macos_icon 16
