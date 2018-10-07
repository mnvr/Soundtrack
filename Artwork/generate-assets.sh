#! /bin/sh

INKSCAPE=${INKSCAPE:-/Applications/Inkscape.app/Contents/Resources/bin/inkscape}

TEMPLATE_SVG=Artwork/Benzene.svg
MACOS_APPICON_SVG=Artwork/Benzene-macOS-appicon.svg
MACOS_STATUSBARICON_SVG=Artwork/Benzene-macOS-statusBarIcon.svg
IOS_APPICON_SVG=Artwork/Benzene-iOS-appicon.svg

MACOS_APPICONSET=Soundtrack-macOS/Assets.xcassets/AppIcon.appiconset
MACOS_PLAYBUTTON=Soundtrack-macOS/Assets.xcassets/PlayButton.imageset
MACOS_STATUSBARBUTTON=Soundtrack-macOS/Assets.xcassets/StatusBarButton.imageset

IOS_APPICONSET=Soundtrack-iOS/Assets.xcassets/AppIcon.appiconset
IOS_PLAYBUTTON=Soundtrack-iOS/Assets.xcassets/PlayButton.imageset

cd $(dirname $0)/..
src_root=$(pwd)

output_base_name=Benzene

function gen_png () {
    local input_file=${src_root}/$1
    local dest_dir=${src_root}/$2
    local sz=${3:-1024}
    local suffix=$4

    local output_file=${dest_dir}/${output_base_name}-${sz}${suffix}.png

    ${INKSCAPE} \
        --without-gui \
        --file=${input_file} \
        --export-png=${output_file} \
        --export-width=${sz} \
        --export-height=${sz}
}

function gen_template_pdf () {
    local input_file=${src_root}/$1
    local dest_dir=${src_root}/$2
    
    local output_file=${dest_dir}/${output_base_name}.pdf

    ${INKSCAPE} \
        --without-gui \
        --file=${input_file} \
        --export-pdf=${output_file}

    echo "Generated ${output_file}"
}

function gen_macos_icon () {
    gen_png "${MACOS_APPICON_SVG}" "${MACOS_APPICONSET}" "$@"
}

function gen_macos_playbutton () {
    gen_template_pdf "${TEMPLATE_SVG}" "${MACOS_PLAYBUTTON}" "$@"
}

function gen_macos_statusbarbutton () {
    for scale in 1 2 3
    do
        sz=$(( scale * 23 ))
        gen_png "${MACOS_STATUSBARICON_SVG}" "${MACOS_STATUSBARBUTTON}" $sz
    done
}

function gen_ios_icon () {
    gen_png "${IOS_APPICON_SVG}" "${IOS_APPICONSET}" "$@"
}

function gen_ios_playbutton () {
    gen_template_pdf "${TEMPLATE_SVG}" "${IOS_PLAYBUTTON}" "$@"
}

gen_macos_icon 1024
gen_macos_icon 512
gen_macos_icon 256
gen_macos_icon 128
gen_macos_icon 64
gen_macos_icon 32
gen_macos_icon 16

gen_macos_playbutton

gen_macos_statusbarbutton

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

gen_ios_playbutton
