#!/bin/bash

# This script is designed for the following use case:
#
# Students have uploaded their assignments to their Dropbox on
# Classesv2. The files themselves are assumed to contain no
# identifying characteristics of the students. (I ask them to not put
# their names in the files.) The script makes no assumptions about the
# names of the files themselves; we will rename them without the TF
# ever seeing the original names. The script assumes each Dropbox has
# only a single file in it. We only allow them to upload doc, docx, or
# pdf assignments.

# The files are correlated with a directory whose name is the
# student's user ID. We cannot simply use the classesv2 frontend to
# zip up the files and download them. This renames the directories to
# a hash which, while unique, varies each time the directory is
# accessed.

# Instead we use curl to access the WebDAV interface remotely and
# download each file into the directory whose name is the respective
# student's ID.

# We then rename each file in each directory to an appropriate
# hash. (At present I just calculate the md5sum of the student's
# submitted assignment.)

# We then construct a csv file which can be imported into Excel (or
# equivalent) and which correlates each Student ID with the
# appropriate md5sum.

# We finally copy all the student assignments into an output
# folder. They are now anonymized such that they can be graded by the
# TF. After grading the TF then correlates the names of the files with
# the student IDs given in the csv file.

# I should add that this is presently a total hackjob.

# TODO:
#
# 1. Implement a command-line option to use MAT to strip the files of
# identifying metadata. Ideally for security reasons we would also
# implement an option to clean pdf files along the lines described
# here:
# https://blog.invisiblethings.org/2013/02/21/converting-untrusted-pdfs-into-trusted.html
# Obviously as it stands this security measure is not portable.
#
# 2. Implement another script which de-anonymizes the files after
# grading is complete. This will facilitate returning any files that
# may have comments on them. Really what we should do is not calculate
# the md5 of the original file but instead try to generate some sort
# of a hash from their student IDs themselves, that way we can then
# just reverse the operation without saving any csv file at all.
#
# 3. I am unsure if there is also a way to correlate student IDs with
# email addresses. At present this must be manually done by the TF by
# looking at the Roster on classesv2.

# We should be able to generate this automatically so the user doesn't
# have to get it from the "upload/download multiple resources" tab of
# the Dropbox.
CLASSESV2="https://classesv2.yale.edu/dav/group-user/gman213_f16"

# I'll pretend to have a safe implementation of temporary directories.
tempdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
tempprop=$tempdir/propfind
# This should be implemented better.
CSV=$tempdir/"csv"

# First we need to download everything

# Cadaver, which is a command-line tool to interact with WebDAV, does
# not play nicely with downloading files in directories. Wget -r,
# which should work, has trouble accessing the hashed directory names
# used in classesv2's implementation of WebDAV.

# The hacky solution is to first use PROPFIND to get the proper
# directory structure from classesv2, then parse it and recursively
# download all the assignments.
echo "This does not yet support two-factor authentication."
echo "Make sure you are on Yale's campus or have already accepted a push."
echo "Enter your net ID"
read -s TFUSER
echo "Enter your password"
read -s PWD
echo "Using curl to fetch classesv2 directory structure..."
curl --user "$TFUSER":"$PWD" -i -X PROPFIND "$CLASSESV2" \
     --data "<D:propfind xmlns:D='DAV:'><D:prop><D:response/></D:prop></D:propfind>" \
    | grep -e doc -e pdf > $tempprop

# Verify that the expected number of assignments have been received.
echo "$(wc -l $tempprop | awk '{print $1}') files found. Type 'yes' to continue"
read reply
if [[ ! "$reply" = "yes" ]]; then
    echo "Exiting, check if all assignments have been submitted."
    exit 1
fi

# We now loop through each line of the propfind file. For each line,
# we parse it to generate three variables: the full name to be
# downloaded by curl, the student ID. Then we download each file into
# the appropriate directory. Then we calculate a hash of the files and
# store that in a variable. Then we append the student ID and the hash
# to the csv file. Finally we rename the file and move it to the final
# directory.

while read line; do
# Even if the students put one of our delimiters [<>] into their
# filename, it seems that WebDAV automatically replaces it with an
# underscore.
    davaddr="https://classesv2.yale.edu$(echo "$line" | awk -F '[<>]' '{print $5}')"
    sid=$(echo $davaddr | awk -F '/' '{print $(NF-1)}')
    filename=$(basename $davaddr)

    # Download the files. I wish there were a less resource intensive
    # way to do this.
    curl -u $TFUSER:"$PWD" $davaddr --output $tempdir/$filename
    md5=$(md5sum "$tempdir/$filename" | awk '{print $1}')

    mv $tempdir/"$filename" $tempdir/"$md5"."${filename##*.}"
    echo "$sid,$md5" >> $CSV
    
done < $tempprop

# Move the files back into the user's directory:
rm $tempprop
mv $tempdir/* .
rmdir $tempdir

