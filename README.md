# blind-grader

This project contains two scripts designed to automate the anonymizing
of student submissions to classesv2. It requires curl and bash.

WARNING: anonymizer.bash will anonymize all assignments submitted to
the class at once. If you are one TF of many and only want to
anonymize your own sections, this will not work for you. There is no
easy way to implement more fine-grained anonymization, but I will try
to work on it.

The first script, anonymizer.bash, is entirely interactive. We assume
that each student's Dropbox has a single file (the relevant
assignment) of type docx, doc, or pdf. We assume that the files
themselves contain no identifying information, although we will rename them.

We correlate each file with the class name, assignment name, and the
uid of each student. This information is then scrambled with rot47 and
downloaded into a directory. The TF is then free to grade them. It is
recommended that if the students submit pdfs that the TF wants to
comment on, the TF either comment directly on the pdf or make a .doc
or .docx file with exactly the same obfuscated name as the pdf in the
same directory as the pdf. That way the deanonymization script will
also unobfuscate the name of the comments file.

The second script, deanonymizer.bash, is run after the TF is done
grading the assignments. It copies the files into a new directory and
unscrambles the names with a second application of rot47.

deanonymizer.bash now includes the option to correlate the student's
ID with email addresses and names. This requires that the user
download the class roster as a .xls file from classesv2. This file
must be converted to csv to be used by the deanonymizer; if
libreoffice is installed, deanonymizer.bash can do this conversion
automatically. Otherwise the user must do it themselves.

The author welcomes all comments and questions at dmoerner@gmail.com.
