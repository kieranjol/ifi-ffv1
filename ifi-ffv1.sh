#!/bin/bash 
 
ffmpeg -i "$1" -c:v ffv1 -level 3 -g 1 -c:a copy "$1.mkv" -f framemd5 "$1.framemd5"
ffmpeg -i "$1.mkv" -f framemd5 "$1"_output.framemd5

#http://stackoverflow.com/a/1379904/2188572 looks like it might be a better option
if cmp -s "$1"_output.framemd5 "$1".framemd5; then
	read -p "The transcode appears to be lossless. Press Enter to continue"
else
    read -p "The transcode does not appear to have been lossless. The framemd5s do not match. ABORT!"
	exit 1
fi

mediainfo -f --language=raw --output=XML "$1" > "$1_mediainfo.xml"
mediainfo -f --language=raw --output=XML "$1.mkv" > "$1.mkv_mediainfo.xml"

#generate qctools xml - both silent and audio options enabled for now. silent ones fail if put through the audio commands
ffprobe -f lavfi -i "movie=$1.mkv:s=v+a[in0][in1],[in0]signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr[out0];[in1]ebur128=metadata=1[out1]" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz"

ffprobe -f lavfi -i "movie=$1.mkv,signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz" 
#MAKE A DUPE OF THE UNTOUCHED MEDIAINFO FIRST!!
#http://stackoverflow.com/questions/32160571/how-to-make-long-sed-script-leaner-and-more-readable-as-code/32160751?noredirect=1#comment52210665_32160751

SEDSTR='s/<Codec>/<inm:Video-codec>/g'
SEDSTR="$SEDSTR;"'s/<Duration_String4>/<inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<Width>/<inm:Width>/g'
SEDSTR="$SEDSTR;"'s/<\/Codec>/<\/inm:Video-codec>/g'
SEDSTR="$SEDSTR;"'s/<\/Duration_String4>/<\/inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<\/Width>/<\/inm:Width>/g'
SEDSTR="$SEDSTR;"'s/<FileExtension>/<inm:Wrapper>/g'
SEDSTR="$SEDSTR;"'s/<\/FileExtension>/<\/inm:Wrapper>/g'

sed -i -e "$SEDSTR" "$1.mkv_mediainfo.xml"

#the first one deletes lines that do not start with in magic but doesn't work for long strings as they move to a new line. the second one deletes everything starting with inm. the ! negates the inclusion."
sed -i '' '/^<inm/!d' "$1.mkv_mediainfo.xml"
#sed -i '' '/^<\/inm/d' "$1.mkv_mediainfo.xml"

#http://stackoverflow.com/a/7362610/2188572 Having spaces after the echo print will result in everything output just fine, but a common not found error popping up. using bash-x shows + $'\r' hidden in the blank line
echo '<inm:filmtapedvd>'Digital File'<\/inm:filmtapedvd>"' >> "$1.mkv_mediainfo.xml"
echo '<inm:Master-Viewing>'Preservation Master'</inm:Master-Viewing>' >> "$1.mkv_mediainfo.xml"

#http://unix.stackexchange.com/questions/65510/how-do-i-append-text-to-the-beginning-and-end-of-multiple-text-files-in-bash
echo "Your files have been converted but you'll need more non embedded info."
echo "reference number?"
read "ref";
echo '<inm:reference-number>'$ref'</inm:reference-number>' >> "$1.mkv_mediainfo.xml"

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

#awk '1; END {print "<inm:reference-number>'$ref'<\/inm:reference-number>"}' "$1" > tmp && mv tmp "$1"
echo "Created By?"
read "cre";
echo '<inm:createdby>'$cre'</inm:createdby>' >> "$1.mkv_mediainfo.xml"

#awk '1; END {print "<inm:createdby>'$cre'<\/inm:createdby>"}' "$1" > tmp && mv tmp "$1"
PS3="Type of acquisition? "
select option in Generated_in_House Deposit Exit 
do
	case $option in
		Generated_in_House)
			echo "<inm:typeofacquisition>7. Generated In House</inm:typeofacquisition>" >> "$1.mkv_mediainfo.xml" 
			break ;;				
		Deposit)
			echo "<inm:typeofacquisition>3. Deposit</inm:typeofacquisition>" >> "$1.mkv_mediainfo.xml" 
			break ;;
		Exit)
			echo 'exiting'
			break
			;;
		*)
		echo "not valid option"
	esac
done	
		

#http://stackoverflow.com/a/21950403/2188572
sed -i '' '1i\
<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?> 
' "$1.mkv_mediainfo.xml"
sed -i '' '2i\
<inm:Results productTitle="Inmagic DB/TextWorks for SQL" productVersion="13.00" xmlns:inm="http://www.inmagic.com/webpublisher/query"> 
' "$1.mkv_mediainfo.xml"

echo "You should now have an xml file that can be ingested into DB/Textworks for SQL"
