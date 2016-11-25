# blind-grader

This project contains two scripts designed to automate the anonymizing
of student submissions to classesv2. It requires curl, bash, and
awk. It can also optionally use libreoffice to manipulate classesv2
rosters.

The first script, anonymizer.bash, is entirely interactive. We assume
that each student's Dropbox has a single file (the relevant
assignment) of type docx, doc, or pdf. We ask that the students not
put their names in the document itself. (Files will be renamed so
filenames are irrelevant.)

We correlate each file with the class name, assignment name, and the
uid of each student. This information is then scrambled with rot47 and
downloaded into a directory. The TF is then free to grade them. It is
recommended that if the students submit pdfs that the TF wants to
comment on, the TF either comment directly on the pdf or make a doc
or docx file with exactly the same obfuscated name as the pdf in the
same directory as the pdf. That way the deanonymization script will
also unobfuscate the name of the comments file.

Anonymizer.bash now has two modes. In "all" mode, it anonymizes all
assignments. This is appropriate for classes with one TF, or classes
where any TF will grade any assignment. In "section" mode, it
anonymizes assignments section-by-section. This is not fully
automated, and requires that the user download individual rosters for
each section from classesv2. The user is prompted to do this.

The second script, deanonymizer.bash, is run after the TF is done
grading the assignments. It copies the files into a new directory and
unscrambles the names with a second application of
rot47. deanonymizer.bash now includes the option to correlate the
student's ID with email addresses and names. This depends on having
access to a class roster file in csv format, or an xls file and
libreoffice.

The author welcomes all comments and questions at dmoerner@gmail.com.
