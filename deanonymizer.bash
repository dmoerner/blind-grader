#!/bin/bash

# This script is (c) 2016 Daniel Moerner <dmoerner@gmail.com) and
# licensed under the MIT License.

# This script takes as an argument a folder which contains rot47
# encrypted filenames. It reverses the rot47 encryption and copies the
# renamed files into a new directory.

# I know my error handling is crap.
if [ $# -ne 1 ]; then
    echo "Please run this script with the anonymized directory as its argument."
    exit 1
fi

ANONDIR="$1"

if [ ! -d "$ANONDIR" ]; then
    echo "Please make sure the only argument is the anonymized directory."
    exit 2
fi

echo "Are you sure you want to deanonymize the files? 'yes' to continue."
read reply
if [[ ! "$reply" = "yes" ]]; then
    echo "Exiting, finish your grading first!"
    exit 3
fi

DEANONDIR="${ANONDIR%-*}"-deanonymized
mkdir -p "$DEANONDIR"

for i in "$ANONDIR"/*; do
    OBNAME="$(basename "$i")"
    # We need some arcane bashisms to make sure the endings persist.
    UNOBNAME="$(echo "${OBNAME%.*}" | tr '\!-~' 'P-~\!-O')"."${OBNAME##*.}"
    cp "$i" "$DEANONDIR"/"$UNOBNAME"
done

echo "The deanonymized files are available in "$DEANONDIR"."
