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
echo

echo
echo "Do you want to try to associate student IDs with real names and emails?"
echo "This requires either libreoffice or that you use Excel to convert the "
echo "roster spreadsheet to csv. Type 'yes' to continue."
read reply
if [[ ! "$reply" = "yes" ]]; then
    echo "Correlate the uid's yourself in "$DEANONDIR"! Exiting."
    exit 0
fi
echo
echo "Please export the roster file from classesv2 and save it here as "
echo "xls or csv."
echo
echo "Here are the csv and xls files available in the current directory:"
ls | grep -e xls -e csv
echo
echo "Please type the name of the roster file:"
read ROSTER
echo

if [[ ! -f "$ROSTER" ]]; then
    echo "Roster "$ROSTER" not found! Correlate yourself!"
    exit 2
fi

# Have to be careful with quotation here:
# http://stackoverflow.com/a/407334
if [[ $ROSTER == *.csv ]]; then
    echo "csv roster found!"
    CSV="$ROSTER"
elif [[ $ROSTER == *.xls ]]; then
    if command -v libreoffice > /dev/null; then
	echo "Libreoffice found, we will convert xls files automatically."
	libreoffice --headless --convert-to csv "$ROSTER"
	CSV="${ROSTER%*.}".csv
    else
	echo "Libreoffice not found! Correlate uid's yourself! Exiting."
	exit 5
    fi
else
    echo "Filetype of $ROSTER not supported."
    echo "Please try again with xls or csv."
    exit 6
fi

# We now go through each deanonymized file and rename it to include
# the student's full name and email.

# I know that this implementation horribly moves back and forth
# between bashisms and awk.
for i in "$DEANONDIR"/*; do
    FILENAME="$(basename "$i")"
    EXT="${FILENAME##*.}"
    NAME="${FILENAME%.*}"
    CLASS="$(echo "$NAME" | awk -F '-' '{print $1}')"
    ASSIGNMENT="$(echo "$NAME" | awk -F '-' '{print $2}')"
    SID="$(echo "$NAME" | awk -F '-' '{print $3}')"
    FULLINFO="$(grep "$SID" "$CSV")"

    # Using awk with csv files is non-trivial, here is some helpful
    # documentation:
    # https://www.gnu.org/software/gawk/manual/gawk.html#Splitting-By-Content
    FULLNAME="$(echo "$FULLINFO" | awk -vFPAT="([^,]+)|(\"[^\"]+\")" '{print $1}')"
    EMAIL="$(echo "$FULLINFO" | awk -vFPAT="([^,]+)|(\"[^\"]+\")" '{print $3}')"
    NEWNAME="$ASSIGNMENT"-"$FULLNAME"-\""$EMAIL"\"-"$NAME"."$EXT"
    mv "$i" "$DEANONDIR"/"$NEWNAME"
done

echo "Deanonymized files now include full names and emails!"
