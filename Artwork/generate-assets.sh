#! /bin/sh

INKSCAPE=${INKSCAPE:-/Applications/Inkscape.app/Contents/Resources/bin/inkscape}

TRANSPARENT_SVG=${SOURCE_SVG:-Artwork/Benzene.svg}
FILLED_SVG=${SOURCE_SVG:-Artwork/Benzene-Filled.svg}

MACOS_APPICONSET=Soundtrack-macOS/Assets.xcassets/AppIcon.appiconset
IOS_APPICONSET=Soundtrack-iOS/Assets.xcassets/AppIcon.appiconset

MACOS_BENZENE_TEMPLATE_PDF=Soundtrack-macOS/Assets.xcassets/Benzene.imageset

cd $(dirname $0)/..
src_root=$(pwd)

output_base_name=Benzene

function gen_png () {
    local input_file=${src_root}/$1
    local dest_dir=${src_root}/$2
    local sz=${3:-1024}

    ${INKSCAPE} \
        --without-gui \
        --file=${input_file} \
        --export-png=${dest_dir}/${output_base_name}-${sz}.png \
        --export-width=${sz} \
        --export-height=${sz}
}

function gen_template_pdf () {
    local input_file=${src_root}/$1
    local dest_dir=${src_root}/$2
    
    local output_file=${dest_dir}/${output_base_name}-Template.pdf
    ${INKSCAPE} \
        --without-gui \
        --file=${input_file} \
        --export-pdf=${output_file}

    echo "Generated ${output_file}"
}

function gen_macos_icon () {
    gen_png "${TRANSPARENT_SVG}" "${MACOS_APPICONSET}" "$@"
}

function gen_macos_benzene_template_pdf () {
    gen_template_pdf "${TRANSPARENT_SVG}" "${MACOS_BENZENE_TEMPLATE_PDF}" "$@"
}

function gen_ios_icon () {
    gen_png "${FILLED_SVG}" "${IOS_APPICONSET}" "$@"
}

gen_macos_icon 1024
gen_macos_icon 512
gen_macos_icon 256
gen_macos_icon 128
gen_macos_icon 64
gen_macos_icon 32
gen_macos_icon 16

gen_macos_benzene_template_pdf

gen_ios_icon 1024
gen_ios_icon 180
gen_ios_icon 120
gen_ios_icon 167
gen_ios_icon 152
gen_ios_icon 120
gen_ios_icon 87
gen_ios_icon 80
gen_ios_icon 76
gen_ios_icon 60
gen_ios_icon 58
gen_ios_icon 40
gen_ios_icon 29
gen_ios_icon 20
