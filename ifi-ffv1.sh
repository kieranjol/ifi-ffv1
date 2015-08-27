#!/bin/bash 
	
#http://unix.stackexchange.com/questions/65510/how-do-i-append-text-to-the-beginning-and-end-of-multiple-text-files-in-bash 



echo "We will proceed with your FFV1 transcode but please fill in these Inmagic DB/Textworks fields first."
echo "reference number?"
read "ref";

#awk '1; END {print "<inm:reference-number>'$ref'<\/inm:reference-number>"}' "$1" > tmp && mv tmp "$1"
echo "Created By?"
read "cre";

echo "Process, eg Bestlight/Grade/OneLight etc?"
read "proc";

#awk '1; END {print "<inm:createdby>'$cre'<\/inm:createdby>"}' "$1" > tmp && mv tmp "$1"
PS3="Type of acquisition? "
select option in Generated_in_House Deposit Exit 
do
	case $option in
		Generated_in_House)
			tod="<inm:Type-Of-Deposit>6. Generated In House</inm:Type-Of-Deposit>"
			#echo "<inm:typeofacquisition>7. Generated In House</inm:typeofacquisition>" >> "$1.mkv_mediainfo_inmagic.xml" 
			break ;;				
		Deposit)
			#echo "<inm:typeofacquisition>3. Deposit</inm:typeofacquisition>" >> "$1.mkv_mediainfo_inmagic.xml" 
			tod="<inm:Type-Of-Deposit>3. Deposit</inm:Type-Of-Deposit>"
			break ;;
		Exit)
			#echo 'exiting'
			break
			;;
		*)
		echo "not valid option"
	esac
done	

PS3="Pro res?"
select choice in Y N
do
	case $choice in
		Y)
			ffmpeg -i "$1" -map 0 -c:v prores -c:a copy -dn "$1_PRORES.mov"
			#echo "<inm:typeofacquisition>7. Generated In House</inm:typeofacquisition>" >> "$1.mkv_mediainfo_inmagic.xml" 
			break ;;				
		N)
			#echo "<inm:typeofacquisition>3. Deposit</inm:typeofacquisition>" >> "$1.mkv_mediainfo_inmagic.xml"
			break ;;
	esac
done	

ffmpeg -i "$1" -map 0 -c:v ffv1 -level 3 -g 1 -c:a copy -dn "$1.mkv" -f framemd5 -an "$1.framemd5" 
ffmpeg -i "$1.mkv" -f  framemd5 -an "$1"_output.framemd5


#http://stackoverflow.com/a/1379904/2188572 looks like it might be a better option
if cmp -s "$1"_output.framemd5 "$1".framemd5; then
	echo "The transcode appears to be lossless. Press Enter to continue"
else
    read -p "The transcode does not appear to have been lossless. The framemd5s do not match. ABORT!"
	exit 1
fi

mediainfo -f --language=raw --output=XML "$1" > "$1_mediainfo.xml"
mediainfo -f --language=raw --output=XML "$1.mkv" > "$1.mkv_mediainfo_inmagic.xml" 
mediainfo -f --language=raw --output=XML "$1.mkv" > "$1_ffv1_mediainfo.xml" 

#generate qctools xml ADD AN IF STATEMENT OR A CASE SELECT- both silent and audio options enabled for now. silent ones fail if put through the audio commands
#ffprobe -f lavfi -i "movie=$1.mkv:s=v+a[in0][in1],[in0]signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr[out0];[in1]ebur128=metadata=1[out1]" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz"

ffprobe -f lavfi -i "movie=$1.mkv,signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz" 

#http://stackoverflow.com/questions/32160571/how-to-make-long-sed-script-leaner-and-more-readable-as-code/32160751?noredirect=1#comment52210665_32160751
# remove redundant information, eg video codec showing up as PCM
SEDSTR='s/<Codec>/<inm:Video-codec>/g'
SEDSTR="$SEDSTR;"'s/<Duration_String4>/<inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<Width>/<inm:D-video-width >/g'
SEDSTR="$SEDSTR;"'s/<\/Codec>/<\/inm:Video-codec>/g'
#mkv duration has a ; for frames
SEDSTR="$SEDSTR;"'s/<\/Duration_String4>/<\/inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<\/Width>/<\/inm:D-video-width >/g'
SEDSTR="$SEDSTR;"'s/<\/FileExtension>/<\/inm:Wrapper>/g'
SEDSTR="$SEDSTR;"'s/<FileExtension>/<inm:Wrapper>/g'
SEDSTR="$SEDSTR;"'s/<Height>/<inm:D-video-height >/g'
SEDSTR="$SEDSTR;"'s/<\/Height>/<\/inm:D-video-height >/g'
SEDSTR="$SEDSTR;"'s/<DisplayAspectRatio>/<inm:Display-Aspect-ratio >/g'
SEDSTR="$SEDSTR;"'s/<\/DisplayAspectRatio>/<\/inm:Display-Aspect-ratio >/g'
#this changes mmkv timecode  ; to :. Monitor this as it may mess other things up.
SEDSTR="$SEDSTR;"'s/;/:/g'

sed -i -e "$SEDSTR" "$1.mkv_mediainfo_inmagic.xml"

#the first one deletes lines that do not start with in magic but doesn't work for long strings as they move to a new line. the second one deletes everything starting with inm. the ! negates the inclusion." http://stackoverflow.com/a/8068399/2188572
sed -i '' '/^<inm/!d' "$1.mkv_mediainfo_inmagic.xml"
#sed -i '' '/^<\/inm/d' "$1.mkv_mediainfo_inmagic.xml"

# the caret ^ indiciates start of line or not.  these functions will delete bad transforms.
sed -i '' '/^<inm:Video-codec>MPEG-4/d' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '/^<inm:Video-codec>PCM/d' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '/^<inm:Video-codec>Matroska/d' "$1.mkv_mediainfo_inmagic.xml"

#http://stackoverflow.com/a/7362610/2188572 Having spaces after the echo print will result in everything output just fine, but a common not found error popping up.  using bash-x shows + $'\r' hidden in the blank line also no need to close slashes, or whatever the term is when echoing
echo '<inm:Film-Or-Tape>'Digital File'</inm:Film-Or-Tape>"' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Master-Viewing>'Preservation Master'</inm:Master-Viewing>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Donor>'Irish Film Institute'</inm:Donor>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Reference-Number>'$ref'</inm:Reference-Number>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Dprocess >'$proc'</inm:Dprocess >' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Created-By>'$cre'</inm:Created-By>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:EditedNew>'$cre'</inm:EditedNew>' >> "$1.mkv_mediainfo_inmagic.xml"

echo "$tod" >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Record>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Recordset>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Results>' >> "$1.mkv_mediainfo_inmagic.xml"

#can be harvested via this script
#<inm:Filename />
#<inm:DAccession-number />
#<inm:DHabitat />
#<inm:LTO-creation-date />
#<inm:DTransfer-source />
#<inm:DTelecine-facility />
#<inm:DProcess />
#<inm:D-operator-notes />
#<inm:D-Duration />
#<inm:Video-codec />
#<inm:Wrapper />
#<inm:D-video-height />
#<inm:D-video-width />
#<inm:D-Frame-rate />
#<inm:D-Scan-type />
#<inm:Display-Aspect-ratio />
#<inm:D-Audio-codec />
#<inm:D-File-size />
#<inm:Active-picture-ratio />
#<inm:D-Checksum />

#more in magic fields to add in
#<inm:Title-Main />
#<inm:Title-Series />
#<inm:CollectionTitle />


#http://stackoverflow.com/a/21950403/2188572
sed -i '' '1i\
<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?> 
' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '2i\
<inm:Results productTitle="Inmagic DB/TextWorks for SQL" productVersion="13.00" xmlns:inm="http://www.inmagic.com/webpublisher/query"> 
' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '3i\
<inm:Recordset setCount="1"> 
' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '4i\
<inm:Record setEntry="0">
' "$1.mkv_mediainfo_inmagic.xml"

#prints the contents of inmagic sml to terminal
cat "$1.mkv_mediainfo_inmagic.xml" 

echo "You should now have an xml file that can be ingested into DB/Textworks for SQL"




