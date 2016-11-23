# blind-grader

This project contains two scripts designed to automate the anonymizing
of student submissions to classesv2. It requires curl and bash.

The first script, anonymizer.bash, is entirely interactive. We assume
that each student's Dropbox has a single file (the relevant
assignment) of type docx, doc, or pdf. We assume that the files
themselves contain no identifying information, although we will rename them.

We correlate each file with the class name, assignment name, and the
uid of each student. This information is then scrambled with rot47 and
downloaded into a directory. The TF is then free to grade them.

The second script, deanonymizer.bash, is run after the TF is done
grading the assignments. It copies the files into a new directory and
unscrambles the names with a second application of rot47.

The TF then has to correlate the student ID's with email addresses and
names. I hope in a future version of this script to find some way to
do this automatically.

This project is (C) Daniel Moerner <dmoerner@gmail.com> and licensed
under the MIT license. I welcome all comments and questions.
