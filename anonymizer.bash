#!/bin/bash

# This script is (c) 2016 Daniel Moerner <dmoerner@gmail.com> and
# licensed under the MIT License.
#
# This script is designed to anonymize student submissions to
# classesv2. It is entirely interactive and explains to the user what
# they need to provide.
#
# The script requires bash, curl, and awk.
#
# The script assumes the following:
#
# 1. The students have uploaded a submission in doc, docx, or pdf to
# their Dropbox on classesv2. This is the only file in their Dropbox.
#
# 2. The students themselves have not included their names in the
# documents. (Whether or not they put their name in the filename is
# irrelevant because we will rename all files. We don't bother trying
# to strip metadata, especially since MAT is currently broken for
# pdfs: https://0xacab.org/mat/mat/issues/11067.)
#
# The script runs in two modes: "all" and "section".
#
# The "all" mode anonymizes all submissions to the classesv2
# Dropboxes. This is appropriate when there is only a single TF, or
# when TFs agree in advance to all anonymously grade each others'
# work.
#
# The "section" mode anonymizes section by section. This is not fully
# automated because of weaknesses in the WebDAV interface. The TF has
# to manually download a roster file from classesv2. The script loops
# through user-provided roster files, putting anonymized files for
# each section in their respective directories.
#
# We maintain anonymity by using rot47 encryption. (This is hopefully
# more obscure than mere rot13 but this something that might need to
# be explored in the future. It requires a certain lack of attention
# from the TF.)

# This script is coupled with deanonymizer.bash, which takes as its
# only argument the name of the anonymized directory, and then
# reverses the rot47 procedure to generate a new directory with the
# deanonymized files.

# I should add that this is presently a total hackjob.

# Error handling:
# exit 1 = we got some user input that wasn't "yes" or ne of the options.
# exit 2 = some file we expected isn't present
# exit 3 = catastrophe has occurred (i.e., something we already
#          error-checked has recurred somehow)

# We'll work in a temporary directory to start:
TEMPDIR=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
# This file will store the propfind data we will parse to know what to
# download.
TEMPPROP=$TEMPDIR/propfind

# First we need to download everything.

# Cadaver, which is a command-line tool to interact with WebDAV, does
# not play nicely with downloading files in directories. Wget -r,
# which should work, has trouble accessing the hashed directory names
# used in classesv2's implementation of WebDAV.

# The solution is to use curl twice. First use PROPFIND to get the
# proper directory structure from classesv2, then parse it and
# recursively download all the assignments.

# Spit out some warning messages first:
echo "Welcome to blind-grader! Feel free to contact dmoerner@gmail.com"
echo
echo "Warning: This does not yet support two-factor authentication."
echo "Make sure you are on Yale's campus or have already accepted a push."
echo

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
echo "$(wc -l $TEMPPROP | awk '{print $1}') total assignments found."
echo
echo "You now have the choice to either anonymize all assignments or try to"
echo "anonymize by section."
echo
echo "Warning: Anonymizing by section is not completely automated and is "
echo "somewhat experimental."
echo
echo "Type 'all' to anonymize the whole class, or 'section' to anonymize"
echo "by section:"
read reply
case "$reply" in
    "all")
	USE="all"
	echo "Anonymizing all sections!"
	;;
    "section")
	USE="section"
	echo "Anonymizing section-by-section!"
	;;
    *)
	echo "Option not recognized, exiting now."
	exit 1
	;;
esac


# Ask the user for a way to describe the assignment
echo
echo "Great! Please enter a name for the assignment:"
read ASSIGNMENT

echo
echo "Downloading all files now. This may take a second."
echo

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
    UNOBNAME="$CLASS-$ASSIGNMENT-$SID"
    # Obfuscated name (Using ROT47)
    OBNAME="$(echo "$UNOBNAME" | tr '\!-~' 'P-~\!-O')"."${FILENAME##*.}"

    # Download the files. I wish there were a less resource intensive
    # way to do this.
    curl -s -u "$TFUSER":"$PWD" "$DAVADDR" --output "$TEMPDIR"/"$OBNAME"

done < "$TEMPPROP"

echo "Files downloaded!"
echo

# We now have two huge if blocks that I really should have properly
# implemented with function calls. The first is for "all" mode, the
# second is for "section" mode.
if [[ "$USE" == "all" ]]; then
   echo "Anonymizing all student assignments"
   OUTPUTDIR="$CLASS-$ASSIGNMENT-anonymized"
   rm $TEMPPROP   
   mkdir -p "$OUTPUTDIR"
   mv $TEMPDIR/* "$OUTPUTDIR"

   echo
   echo "Done!"
   echo
   echo "Run "bash deanonymizer.bash "$OUTPUTDIR"" when you are done grading!"
   echo "If students submit documents as pdfs, write your comments in a doc(x)"
   echo "file with exactly the same obfuscated name as the pdf in "
   echo ""$OUTPUTDIR"."
   echo "These comment files will then also be deanonymized at the same time!."
elif [[ "$USE" == "section" ]]; then
    echo "Anonymizing assignments section-by-section."
    echo
    echo "The script will now loop. On each loop it will ask you for a name for"
    echo "each section and to upload a roster for that section. Typing 'done'"
    echo "as the section name will terminate the loop."
    echo
    echo "Rosters are downloaded from classesv2 as xls files, but the script "
    echo "requires that they be converted to csv (comma separated value)."
    if command -v libreoffice > /dev/null; then
	echo "Libreoffice found! anonymizer.bash will do the conversion for you."
	LOFFICE=y
    else
	echo "Libreoffice not found. You will have to use Excel to manually export"
	echo "the roster files from xls to csv."
	LOFFICE=n
    fi
    echo

    # We now begin the loop.
    while :
    do
	echo "Please enter a name for this section. Type 'done' if you are finished."
	read reply
	if [[ "$reply" == "done" ]]; then
	    break
	else
	    SECTION="$reply"
	fi

	echo "You now need to supply a roster file for this section."
	echo "Go to "Roster" on Classesv2 and view the section you want."
	echo "Then "export" the roster (upper-right-hand corner)"
	if [[ "$LOFFICE" == "y" ]]; then
	    echo "Please save the roster in the current directory under the name"
	    echo ""$SECTION".xls."
	    echo "Type 'ok' when the roster is saved here."
	    read reply
	    if [[ ! "$reply" == "ok" ]]; then
		echo "Exiting! Please try again. Deleting student data"
		rm -rf $TEMPDIR
		exit 1
	    fi	
	    if [[ ! -f "$SECTION".xls ]]; then
		echo "Roster file not found!"
		echo "Exiting and deleting student data."
		rm -rf $TEMPDIR
		exit 2
	    fi
	    libreoffice --headless --convert-to csv "$SECTION".xls
	    rm "$SECTION".xls
	else
	    echo "Please convert the roster yourself (e.g., with Excel) to csv"
	    echo "and then save it in the current directory under the name"
	    echo ""$SECTION".csv."
	    echo "Type 'ok' when the roster is saved here."
	    read reply 
	    if [[ ! "$reply" == "ok" ]]; then
		echo "Exiting! Please try again. Deleting student data"
		rm -rf $TEMPDIR
		exit 1
	    fi	
	    if [[ ! -f "$SECTION".csv ]]; then
		echo "Roster file not found!"
		echo "Exiting and deleting student data."
		rm -rf $TEMPDIR
		exit 2
	    fi
	fi

	# We make the directory:
	SECTIONDIR="$CLASS"-"$SECTION"-"$ASSIGNMENT"-anonymized
	mkdir -p "$TEMPDIR"/"$SECTIONDIR"
	# awk with csv:
	# https://www.gnu.org/software/gawk/manual/gawk.html#Splitting-By-Content
	# We use the grep to filter out the column names, and use the
	# xargs so that the for loop is happy.
	SIDS="$(grep "Student" "$SECTION".csv | awk -vFPAT="([^,]+)|(\"[^\"]+\")" '{print $2}' | xargs)"
	# Here "$SIDS" can't be quoted, or for only loops a single
	# time over the whole string.
	for SID in $SIDS; do
	    echo "$SID"
	    # Here we ROT47 the name in accordance with the original.
	    UNOBNAME="$CLASS-$ASSIGNMENT-$SID"
	    echo "$UNOBNAME"
	    OBNAME="$(echo "$UNOBNAME" | tr '\!-~' 'P-~\!-O')"
	    echo "$OBNAME"
	    cp $TEMPDIR/"$OBNAME"* $TEMPDIR/"$SECTIONDIR"
	done

	mv $TEMPDIR/"$SECTIONDIR" .
	echo "Created "$SECTIONDIR"! Looping again..."
	
		
    done

    echo
    echo "Section-by-section anonymization complete!"
    echo "Created the following anonymized section directories:"
    # We have to use this monstrosity because otherwise if you only
    # anonymize one section, ls "$CLASS"- will list the contents of
    # that directory.
    ls | grep "$CLASS"-
    echo
    echo "We have not removed the roster csv files so you can use them"
    echo "to deanonymize the section directories."
    echo 
    echo "Run 'bash deanonymizer.bash dirname' when you are done grading each!"
    echo "If students submit documents as pdfs, write your comments in a doc(x)"
    echo "file with exactly the same obfuscated name as the pdf in the same directory."
    echo "These comment files will then also be deanonymized at the same time!."

else
    echo "Something has gone very wrong. Exiting."
    # We must cleanup before we exit since student files are on the PC.
    rm -rf "$TMPDIR"
    exit 3
fi

# Clean up temp files at the end.
rm -rf $TEMPDIR
