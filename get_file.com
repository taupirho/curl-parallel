$! Initially we do a series of 9 commands like the one below.. The important bit in this is the --range flag 
$! followed by a start and end byte position. This tells CURL to only download the specified bytes between 
$! the start and end offset position. In this case we start at the beginning of the file - position 0 - and 
$! download 1 billion bytes of data - position 10000000000. We repeat this 9 times with the start position 
$! of the next command starting at 1 + the end position of the previous command. The ‘&’  at the end of 
$! each command tell the operating system to do this command in the background and continue with the next 
$! command in the sequence.

$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 0-1000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part1.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 1000000001-20000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part2.zip -s -S &

$! Etc …. Repeat a further 6 times increasing the range parameters as required  followed by the final command of :

$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 8000000001- ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part9.zip -s -S &

$! For the last CURL command above we simply say get everything else from byte position 80000000001 to the end of 
$! the file. At this stage we have two main tasks left. We need to recognise when all the background 
$! CURL jobs have finished and then reconstitute the individual partN.zip files into the original file.

$ unzip -lb part*.zip

$! After some trial and error I discovered that the above unzip command would result in the following 
$! 2 lines being returned when all the CURL commands had finished successfully.
$!
$!             9 files had no zipfile directory.
$!             No zipfiles found.
$!
$! It was therefore simply a matter of , within a loop, running the above unzip command and 
$! checking for the last two lines being the above. If the lines matched we reconstitute the original 
$! big zip file by copying all its part zip files to it, unzip it and carry on with any further 
$! processing as required. 
$!
$ start:
$ wait 00:05                                             ! pause for 5 seconds
$ pipe unzip2 -lb part*.zip 2> info2.txt                 ! send the output to a file
$
$! get last 2 lines into a second file
$ pipe sed -e :a -e "$q;N;3,$D;ba" info2.txt > info.txt   
$! read those 2 lines into variable that we can check
$ OPEN IN info.txt
$ READ IN line1
$ READ IN line2
$ CLOSE IN
$! Test for the required lines being present
$! If they are, recombine the ZIPS into one file then unzip that file
$! If not, go back to the beginning of the loop
$! For a belt and & braces approach and to prevent going around the loop 
$! indefinitely If there was some kind of problem we could increment  a 
$! variable at the loop start  and break out if this variable exceeded a 
$! certain predetermined value
$!
$ if(  (line1 .eqs. "9 files had no zipfile directory.") .and. (line2 .eqs. "No zipfiles found.") )
$ then
$    set file/attribute=(rfm=udf) part%.zip
$    copy part1.zip,part2.zip,part3.zip,part4.zip,part5.zip,part6.zip,part7.zip,part8.zip,part9.zip bigfile.zip
$    set file/attribute=(rfm=udf) bigfile.zip
$    unzip2 -aob bigfile.zip
$!
$!  … and any further processing can go here or elsewhere
$!
$ else
$     goto start
$ endif
