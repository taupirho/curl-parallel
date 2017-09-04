
$! A DCL file to download a large  (approx 9G Zipped ) file from an FTP site using Curl
$! Initially we do a series of 9 commands like the one below to download 1 Gig at a time.  
$! The important bit in this is the --range flag followed by a start and end byte position. 
$! This tells CURL to only download the specified bytes between the start and end offset position. 
$! In this case we start at the beginning of the file - position 0 - and download 1 billion bytes of data - position 10000000000. 
$! We repeat this 9 times with the start position 
$! of the next command starting at 1 + the end position of the previous command. The ‘&’  at the end of 
$! each command tell the operating system to do this command in the background and continue with the next 
$! command in the sequence.
$! NB
$! We use a couple of extra utilities ported to DCL from other systems , namely unzip2 which can unzip very large files and 
$! a port of the sed unix command to more easily do text manipluitaion oeprations. 
$! Obviously the number of CURL commands and start/end byte positions you choose will depend on the size of file you are downloading.
$!
$! Run all comamnds below in the background in parallel 
$!
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 0-1000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part1.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 1000000001-20000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part2.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 2000000001-30000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part3.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 3000000001-40000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part4.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 4000000001-50000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part5.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 5000000001-60000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part6.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 6000000001-70000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part7.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 7000000001-80000000000 ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part8.zip -s -S &
$ pipe curl2 --insecure --user myusername:mypassword --disable-epsv --keepalive-time 5 --range 8000000001- ftp://edx.standardandpoors.com/Products/OwnershipDetailV2/Ownership.zip -o part9.zip -s -S &
$!
$! For the final CURL command above we simply get everything else from byte position 80000000001 to the end of 
$! the file. At this stage we have two main tasks left. We need to recognise when all the background 
$! CURL jobs have finished and then reconstitute the individual partN.zip files into the original file.
$!
$! The next task is to determine when all the above curl commands have finished. After some trial and error I discovered 
$! that running the command `unzip -lb part*.zip` would result in the following 
$! 2 lines being returned when all the CURL commands had finished successfully.
$!
$!             9 files had no zipfile directory.
$!             No zipfiles found.
$!
$! It was therefore simply a matter of, within a loop, running that unzip command and 
$! checking for the last two lines being identical to the above. If the lines matched we reconstitute the original 
$! big zip file by concatenating all the partN.zip files together, unzipping it and carrying on with any further 
$! processing as required. 
$!
$ start:
$ wait 00:05                                             ! pause for 5 seconds
$! unzip2 is a version of ZIP for our openVMS system that can deal with huge files
$ pipe unzip2 -lb part*.zip 2> info2.txt                 ! send the output to a file
$
$! get last 2 lines into a second file
$ pipe sed -e :a -e "$q;N;3,$D;ba" info2.txt > info.txt   
$!
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
$! unzip2 is a version of ZIP for our openVMS system that can deal with huge files
$    unzip2 -aob bigfile.zip
$!
$! At this stage the original files contained in the ZIP should be reconstituted and any further 
$! processing on them can go here or elsewhere
$!
$ else
$! the curl commands haven't ended yet so go back to the beginning of the loop and try again
$     goto start
$ endif
