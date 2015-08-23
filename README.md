# ifi-ffv1
 FFv1/lossless verification/Inmagic DB Textworks mediainfo ingest
 
 This will do the following to your v210.mov
 1. Compress using FFv1 version 3 inter-frame in a matroska wrapper
 2. run framemd5s on both the v210.mov and the ffv1.mkv
 3. Tell you if your transcode is lossless or not
 4. run verbose mediainfos on both the v210.mov and the ffv1.mkv
 5. generate a qctools xml document
 6. convert mediainfo xml tags into Inmagic DB/Textworks for SQL compliant elements
 7. Ask the user for non embedded administrative metadata
 

Instructions: <br>
Copy script into user directory, eg admin or ifi-edit <br>
open terminal <br>
type `chmod a+x ifi-ffv1.sh`  <br>
to run the program: <br>
open terminal <br>
type `./ifi-ffv1.sh <br>
press space <br>
drag and drop your v210.mov into the terminal and press ok <br>
