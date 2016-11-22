# blind-grader

This is a script designed to automate the anonymizing of student
submissions to classesv2.

It requires curl to access the WebDAV interface. The TF using the
script must edit it and change the CLASSESV2 variable to the
appropriate WebDAV interface for their course. (I hope to add this as
a command-line switch soon.)

We assume that each student's Dropbox has a single file (the relevant
assignment) of type docx, doc, or pdf. We assume that the files
themselves contain no identifying information.

We download the files, keeping track of the uid of each student. We
rename them to a unique hash and correlate the uid with the hash in a
csv file. The TF is then free to grade them, and then correlate them
with the student's uid at the end.

Future improvements will include a second script which automatically
renames the files to the student's user id. If anyone knows a way to
correlate user IDs with student email addresses, short of manually
looking at the class roster, this would also be helpful.