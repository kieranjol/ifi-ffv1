# ifi-ffv1 - <b>DEPRECATED!</b> - Development will now be focused on the python version - https://github.com/kieranjol/pyffv1md5 <br>


 FFv1/lossless verification/Inmagic DB Textworks mediainfo ingest roughly inspired by Dave Rice's 'makelossless' https://github.com/dericed/mediamicroservices/blob/master/makelossless
 
 This will do the following to your v210.mov
 1. Compress using FFv1 version 3 inter-frame in a matroska wrapper
 2. run framemd5s on both the v210.mov and the ffv1.mkv
 3. Tell you if your transcode is lossless or not
 4. run verbose mediainfos on both the v210.mov and the ffv1.mkv
 5. generate a qctools xml document
 6. convert mediainfo xml tags into Inmagic DB/Textworks for SQL compliant elements and add md5
 7. Ask the user for non embedded administrative metadata
 8. Generate md5 checksums of all files in package
 9. Move files into subfolders
 10. Create BITC h264 with framerate detection via ffprobe
 

Instructions: <br>
The following dependencies need to be installed via Homebrew: ffmpeg, ffplay, ffprobe, mediainfo, md5deep. <br>
1. Copy script into user directory, eg admin or ifi-edit <br>
2. Open terminal <br>
3. type `chmod a+x ifi-ffv1.sh`  <br>
4. to run the program: <br>
5. open terminal <br>
6. type `./ifi-ffv1.sh`<br>
7. press space <br>
8. drag and drop your v210.mov into the terminal and press ok <br>

Instructional video to follow
