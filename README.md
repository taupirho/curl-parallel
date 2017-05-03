
<h3>Using CURL to parallel download large datafiles</h3>

Just documenting a method of using Curl to parallel download a large financial data file from an FTP site.

One of the financial data services we use on a daily basis is Standard and Poors Capital IQ product. Our main reason for using this is that it is one of the few data providers that holds detailed company ownership information. We use this to determine the free floats of companies so that we can accurately know when to include them in certain indices and calculate their weights in the indices. So far so good.

The Capital IQ model of data provision is that on their FTP site - once per week - they provide a full refresh of all company ownership data followed by daily incremental change files - all in ZIP format. To ensure we have the most up-to-date set of data, our data loading model follows that same principal. We do a full refresh of our company ownership database by loading in the full file once each week followed by the incremental changes on a daily basis. The problem is, is that the initial full ownership ZIP file that we download is extremely large i.e in excess of  8.5 billion bytes. I don’t know if you’ve tried to download a large file like this from an FTP server but I can assure you it takes a while! So this was a real issue for us until I discovered that one of the bits of software we use for downloading data from another financial provider (Markit) - a tool called CURL can actually be used to download sections of a file at a time. 

This means that we could kick off several processes at the same time, each downloading a different section of the data, then re-combine them at the end to reconstitute the original data file. The operating system I use is OpenVMS and its equivalent to a DOS batch file or shell script file in UNIX is called a DCL command file. So although you might not have seen this type of file before you should be able to follow it reasonably easily

<b>NB The ability to do this with Curl is only available with later versions of it. The version I use is 7.19.5 for OpenVMS 8.4 (IA64-HP-VMS)</b>

