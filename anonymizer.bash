#!/bin/bash

# This script is designed for the following use case:
#
# Students have uploaded their assignments to their Dropbox on
# Classesv2. The files themselves are assumed to contain no
# identifying characteristics of the students. I ask them to not put
# their names in the files. The script itself will rename their files,
# so it's fine if they put their names in the titles. The script
# assumes each Dropbox has only a single file in it. We only allow
# them to upload doc, docx, or pdf assignments.

# The files are correlated with a directory whose name is the
# student's full name on the web interface.  We cannot simply use the
# classesv2 frontend to zip up the files and download them. This
# renames the directories to a hash which, while unique, varies each
# time the directory is accessed.

# Instead we use curl to access the WebDAV interface remotely and
# download each file. We use rot47 to reversibly "encrypt" the name of
# each file in the format <class>-<assignment>-<student id>. These
# files are downloaded in a directory with the name
# <class>-<assignment>-anonymized.

# The script is designed to be fully interactive, and prompts the user
# for their classesv2 link, their username, their password (hidden,
# but here we have to hope that curl properly implements https access
# to WebDAV), and the assignment name. It also makes sure that the
# right number of files are available for download before we proceed.

# This script is coupled with deanonymizer.bash, which takes as its
# only argument the name of the <class>-<assignment>-anonymized
# directory, and then reverses the rot47 procedure to generate a new
# directory with the deanonymized files.

# I should add that this is presently a total hackjob.

# We'll work in a temporary directory to start:
TEMPDIR=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
# This file will store the propfind data we will parse to know what to
# download.
TEMPPROP=$TEMPDIR/propfind

# First we need to download everything

# Cadaver, which is a command-line tool to interact with WebDAV, does
# not play nicely with downloading files in directories. Wget -r,
# which should work, has trouble accessing the hashed directory names
# used in classesv2's implementation of WebDAV.

# The solution is to use curl twice. First use PROPFIND to get the
# proper directory structure from classesv2, then parse it and
# recursively download all the assignments.

# Spit out some warning messages first:
echo "This does not yet support two-factor authentication."
echo "Make sure you are on Yale's campus or have already accepted a push."

# We extract CLASS and the WebDav interface from their classesv2
# link. We will use the CLASS variable independently to organize files
# locally.

echo "Please copy and paste the base classesv2 link for your course"
echo "For example: https://classesv2.yale.edu/portal/site/gman213_f16"
read CLASSESV2
CLASS=$(echo "$CLASSESV2" | awk -F '/' '{print $NF}')
CV2WEBDAV="https://classesv2.yale.edu/dav/group-user/"$CLASS

echo "Enter your net ID:"
read TFUSER
echo "Enter your password: (It will not be displayed)"
read -s PWD

# This curl command is arcane, modified from
# https://blogs.oracle.com/arnaudq/entry/propfind_using_curl
# Note that here is where we only support doc, docx, and pdf. We use
# this to exclude extraneous D:response lines. (Otherwise it also
# matches all directories.)
echo "Using curl to fetch classesv2 directory structure..."
curl -u "$TFUSER":"$PWD" -i -X PROPFIND "$CV2WEBDAV" \
     --data "<D:propfind xmlns:D='DAV:'><D:prop><D:response/></D:prop></D:propfind>" \
    | grep -e doc -e pdf > $TEMPPROP

# Verify that the expected number of assignments have been
# received. Add warning that this downloads files for all TFs.
echo
echo "Warning: This script will download and anonymize the files for all sections."
echo "If you are only trying to anonymize some sections, this will not work." 
echo "$(wc -l $TEMPPROP | awk '{print $1}') files found. Type 'yes' to continue"
read reply
if [[ ! "$reply" = "yes" ]]; then
    echo "Exiting, check if all assignments have been submitted."
    exit 1
fi

# Ask the user for a way to describe the assignment
echo "Please enter a very short descrption for the assignment (e.g., 'Assignment 2')"
read ASSIGNMENTNAME

# We now loop through each line of the propfind file. For each line,
# we parse it to generate three variables: the full name to be
# downloaded by curl, the student ID, and the filename of their
# submission. We give each file an unobfuscated name that reflects the
# class, assignment, and student id. Then we use rot47 to calculate
# the obfuscated name of the file. Then we download each file into the
# temporary directory under its obfuscated name. 

while read line; do
# Even if the students put one of our delimiters [<>] into their
# filename, it seems that WebDAV automatically replaces it with an
# underscore.
    DAVADDR="https://classesv2.yale.edu$(echo "$line" | awk -F '[<>]' '{print $5}')"
    SID=$(echo $DAVADDR | awk -F '/' '{print $(NF-1)}')
    FILENAME=$(basename $DAVADDR)

    # Unobfuscated name
    UNOBNAME="$CLASS-$ASSIGNMENTNAME-$SID"
    # Obfuscated name (Using ROT47)
    OBNAME="$(echo "$UNOBNAME" | tr '\!-~' 'P-~\!-O')"."${FILENAME##*.}"

    # Download the files. I wish there were a less resource intensive
    # way to do this.
    curl -u "$TFUSER":"$PWD" "$DAVADDR" --output "$TEMPDIR"/"$OBNAME"

done < "$TEMPPROP"

# Finally we move the files into the anonymized directory and clean up:
OUTPUTDIR="$CLASS-$ASSIGNMENTNAME-anonymized"
rm $TEMPPROP
mkdir -p "$OUTPUTDIR"
mv $TEMPDIR/* "$OUTPUTDIR"
rmdir $TEMPDIR

echo
echo "Anonymization complete!"
echo "Run "bash deanonymizer.bash "$OUTPUTDIR"" when you are done grading!"
echo "If students submit documents as pdfs, write your comments in a docx or doc"
echo "file with exactly the same obfuscated name as the pdf in "$OUTPUTDIR". These"
echo "comment files will then also be deanonymized at the same time!."
