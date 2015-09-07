#!/bin/bash -x
	
#http://unix.stackexchange.com/questions/65510/how-do-i-append-text-to-the-beginning-and-end-of-multiple-text-files-in-bash 
#http://stackoverflow.com/a/965072/2188572
#This stores various file/path names for later use.
sourcepath="$(dirname "$1")" 
filename="$(basename "$1")"
# temporary. eventually, archived files should be video.mkv, rather video.mov.mkv
archived_filename="$(basename "$1.mkv")"

#Stores just the filename without the .extension. 
filenoext="${filename%.*}"

#check if sidecar folder already exists. if it does, abort!
if [ -d "$sourcepath/$filenoext" ]; then
	echo "It looks like these files already exist, aborting.";
	exit 1

#makes loads of directories for later use. some of these should only be created if various options are selected
else
	mkdir "$sourcepath/$filenoext"
	mkdir "$sourcepath/$filenoext/tmp"
	mkdir "$sourcepath/$filenoext/provenance"
	mkdir "$sourcepath/$filenoext/inmagic"
	mkdir "$sourcepath/$filenoext/fixity"
	mkdir "$sourcepath/$filenoext/video"
	mkdir "$sourcepath/$filenoext/logs"
fi

#Creating variables for the directories to make life easier later on.
provenance="$sourcepath/$filenoext/provenance"
inmagic="$sourcepath/$filenoext/inmagic"
fixity="$sourcepath/$filenoext/fixity"
tmp="$sourcepath/$filenoext/tmp"
video="$sourcepath/$filenoext/video"
mezzanine="$sourcepath/$filenoext/mezzanine"
proxy="$sourcepath/$filenoext/proxy"
logs="$sourcepath/$filenoext/logs"

#Interview looking for non embedded metadata which will later be added to inmagic xml.
echo "We will proceed with your FFV1 transcode but please fill in these Inmagic DB/Textworks fields first."
echo "reference number?"
read "ref";

echo "Created By?"
read "cre";

echo "Process, eg Bestlight/Grade/OneLight etc?"
read "proc";

echo "Source Accession Number? Please retrospectively accesion the item if required"
read "acc";

#Multiple choice. This currently doesn't print the question which could be confusing for user.
PS3="Type of acquisition? "
select option in Generated_in_House Deposit Exit 
do
	case $option in
		Generated_in_House)
			tod="<inm:Type-Of-Deposit>6. Generated in-house</inm:Type-Of-Deposit>"
			break ;;				
		Deposit)
			tod="<inm:Type-Of-Deposit>4. Deposit</inm:Type-Of-Deposit>"
			break ;;
		Exit)
			break
			;;
		*)
		echo "not valid option"
	esac
done	

#mezzanine/proxy creation. the proxy does a fps check so that the timecode is correct. 
#The timecode will only appear in the correct position for PAL video.
PS3="Prores/BITC h264 or both?"
select choice in None Prores H264 Both 
do
	case $choice in
		None)
			break ;;
		Prores)
			mkdir "$sourcepath/$filenoext/mezzanine"
			ffmpeg -i "$1" -map 0 -c:v prores -aspect 4:3 -c:a copy -dn "$mezzanine/${filenoext}_PRORES.mov"
			break ;;	
		H264)
		mkdir "$sourcepath/$filenoext/proxy"
		
		#https://trac.ffmpeg.org/wiki/FFprobeTips
		framerate=($(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$1"))


		#https://trac.ffmpeg.org/wiki/FFprobeTips
		IFS=: read -a timecode < <(ffprobe -v error -show_entries stream_tags=timecode -of default=noprint_wrappers=1:nokey=1 "$1")
		printf -v timecode "'%s\:%s\:%s\:%s'" "${timecode[@]}"
		echo "$timecode"

		drawtext_options=(
		    fontsize=45
		    fontfile="/Library/Fonts/Arial Black.ttf"
		    fontcolor=white
		    timecode="$timecode"
		    rate="$framerate"
		    boxcolor=0x000000AA
		    box=1
		    x=360-text_w/2
		    y=480
		)

		drawtext_options=$(IFS=:; echo "${drawtext_options[*]}")
		ffmpeg -i "$1" -c:v libx264 -crf 23 -pix_fmt yuv420p -vf \
		    drawtext="$drawtext_options" \
		    "$proxy/${filenoext}_BITC.mov"
		break;;
		
		Both)
			mkdir "$sourcepath/$filenoext/mezzanine"
			mkdir "$sourcepath/$filenoext/proxy"
			
			ffmpeg -i "$1" -map 0 -c:v prores -aspect 4:3 -c:a copy -dn "$mezzanine/${filenoext}_PRORES.mov"
			IFS=: read -a timecode < <(ffprobe -v error -show_entries stream_tags=timecode -of default=noprint_wrappers=1:nokey=1 "$1")
			printf -v timecode "'%s\:%s\:%s\:%s'" "${timecode[@]}"
			echo "$timecode"

			drawtext_options=(
			    fontsize=45
			    fontfile="/Library/Fonts/Arial Black.ttf"
			    fontcolor=white
			    timecode="$timecode"
			    rate=25/1
			    boxcolor=0x000000AA
			    box=1
			    x=360-text_w/2
			    y=480
			)

			drawtext_options=$(IFS=:; echo "${drawtext_options[*]}")
			ffmpeg -i "$1" -c:v libx264 -crf 23 -pix_fmt yuv420p -vf \
			    drawtext="$drawtext_options" \
			    "$proxy/${filenoext}_BITC.mov"
			break;;
			
		
	esac
done	
#transcode to ffv1 and make framemd5 of source
ffmpeg -i "$1" -map 0 -c:v ffv1 -level 3 -g 1 -aspect 4:3 -c:a copy -dn "$1.mkv" -f framemd5 -an "$1.framemd5" 2> "$logs/${filenoext}_transcode.log"
#make framemd5 of ffv1
ffmpeg -i "$1.mkv" -f framemd5 -an "$1"_output.framemd5 2> "$logs/${filenoext}_framemd5.log"


#http://stackoverflow.com/a/1379904/2188572 looks like it might be a better option
#compare both framemd5s and only continue if identical
if cmp -s "$1"_output.framemd5 "$1".framemd5; then
	echo "The transcode appears to be lossless. Press Enter to continue"
else
    read -p "The transcode does not appear to have been lossless. The framemd5s do not match. ABORT!"
	exit 1
fi

#move framemd5s to appropriate location
mv "$1".framemd5 "$provenance"
mv "$1"_output.framemd5 "$fixity"

#mediainfo of source and move to provenance folder. reduce this to one line without MV
mediainfo -f --language=raw --output=XML "$1" > "$1_mediainfo.xml"
mv "$1_mediainfo.xml" "$provenance"

#mediainfo of ffv1 which will ultimately be transformed into the inmagic xml.
mediainfo -f --language=raw --output=XML "$1.mkv" > "$1.mkv_mediainfo_inmagic.xml" 

#mediainfo of source . I don't think that this is used again, so maybe it could be moved to video folder earlier?
mediainfo -f --language=raw --output=XML "$1.mkv" > "$1_ffv1_mediainfo.xml" 

#generate qctools xml ADD AN IF STATEMENT OR A CASE SELECT- both silent and audio options enabled for now. silent ones fail if put through the audio commands
#ffprobe -f lavfi -i "movie=$1.mkv:s=v+a[in0][in1],[in0]signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr[out0];[in1]ebur128=metadata=1[out1]" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz"
ffprobe -f lavfi -i "movie=$1.mkv,signalstats=stat=tout+vrep+brng,cropdetect=reset=1,split[a][b];[a]field=top[a1];[b]field=bottom[b1],[a1][b1]psnr" -show_frames -show_versions -of xml=x=1:q=1 -noprivate | gzip > "$1.mkv.qctools.xml.gz" 
mv "$1.mkv.qctools.xml.gz" "$video"

#http://stackoverflow.com/questions/32160571/how-to-make-long-sed-script-leaner-and-more-readable-as-code/32160751?noredirect=1#comment52210665_32160751
#Bad code, will change to xml transforms at some stage :[
SEDSTR='s/<Duration_String4>/<inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<Codec>PCM<\/Codec>/<inm:D-Audio-codec>PCM<\/inm:D-Audio-codec>/g'
SEDSTR="$SEDSTR;"'s/<Codec>/<inm:Video-codec>/g'
SEDSTR="$SEDSTR;"'s/<Width>/<inm:D-video-width >/g'
SEDSTR="$SEDSTR;"'s/<\/Codec>/<\/inm:Video-codec>/g'
#mkv duration has a ; for NTSC drop frames
SEDSTR="$SEDSTR;"'s/<\/Duration_String4>/<\/inm:D-Duration>/g'
SEDSTR="$SEDSTR;"'s/<FileSize_String4>/<inm:D-File-Size >/g'
SEDSTR="$SEDSTR;"'s/<\/FileSize_String4>/<\/inm:D-File-Size >/g'
SEDSTR="$SEDSTR;"'s/<\/Width>/<\/inm:D-video-width >/g'
SEDSTR="$SEDSTR;"'s/<\/FileExtension>/<\/inm:Wrapper>/g'
SEDSTR="$SEDSTR;"'s/<FileExtension>/<inm:Wrapper>/g'
SEDSTR="$SEDSTR;"'s/<Height>/<inm:D-video-height >/g'
SEDSTR="$SEDSTR;"'s/<\/Height>/<\/inm:D-video-height >/g'
SEDSTR="$SEDSTR;"'s/<DisplayAspectRatio>/<inm:Display-Aspect-ratio >/g'
SEDSTR="$SEDSTR;"'s/<\/DisplayAspectRatio>/<\/inm:Display-Aspect-ratio >/g'
#this changes mmkv timecode  ; to :. Monitor this as it may mess other things up.
#SEDSTR="$SEDSTR;"'s/;/:/g'

sed -i.backup "$SEDSTR" "$1.mkv_mediainfo_inmagic.xml"

#the first one deletes lines that do not start with in magic but doesn't work for long strings as they move to a new line. 
#the second one deletes everything starting with inm. the ! negates the inclusion." http://stackoverflow.com/a/8068399/2188572
sed -i '' '/^<inm/!d' "$1.mkv_mediainfo_inmagic.xml"
#sed -i '' '/^<\/inm/d' "$1.mkv_mediainfo_inmagic.xml"

# the caret ^ indiciates start of line or not.  these functions will delete bad transforms.
sed -i '' '/^<inm:Video-codec>MPEG-4/d' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '/^<inm:Video-codec>PCM/d' "$1.mkv_mediainfo_inmagic.xml"
sed -i '' '/^<inm:Video-codec>Matroska/d' "$1.mkv_mediainfo_inmagic.xml"

#http://stackoverflow.com/a/7362610/2188572 Having spaces after the echo print will result in everything output just fine, but a common not found error popping up.  using bash-x shows + $'\r' hidden in the blank line also no need to close slashes, or whatever the term is when echoing
echo '<inm:Film-Or-Tape>'Digital File'</inm:Film-Or-Tape>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Master-Viewing>'Preservation Master'</inm:Master-Viewing>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Donor>'Irish Film Institute'</inm:Donor>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Reference-Number>'$ref'</inm:Reference-Number>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:AccessionNumber>'$acc'</inm:AccessionNumber>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:DProcess >'$proc'</inm:DProcess >' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Created-By>'$cre'</inm:Created-By>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:EditedNew>'$cre'</inm:EditedNew>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Edited-By>'$cre'</inm:Edited-By>' >> "$1.mkv_mediainfo_inmagic.xml"
#md5 xml injection http://stackoverflow.com/a/5773761/2188572
md5=($(md5deep "$1.mkv"))
echo '<inm:D-Checksum >'$md5'</inm:D-Checksum >' >> "$1.mkv_mediainfo_inmagic.xml"

echo "$tod" >> "$1.mkv_mediainfo_inmagic.xml"
echo '<inm:Filename >'$archived_filename'</inm:Filename>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Record>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Recordset>' >> "$1.mkv_mediainfo_inmagic.xml"
echo '</inm:Results>' >> "$1.mkv_mediainfo_inmagic.xml"

#can be harvested via this script
#<inm:Filename />
#<inm:DHabitat />
#<inm:LTO-creation-date />
#<inm:DTransfer-source />
#<inm:DTelecine-facility />
#<inm:DProcess />
#<inm:D-operator-notes />
#<inm:Wrapper />
#<inm:D-Frame-rate />
#<inm:D-Scan-type />
#<inm:D-File-size />
#<inm:Active-picture-ratio />
#more in magic fields to add in
#<inm:Title-Main />
#<inm:Title-Series />
#<inm:CollectionTitle />


#http://stackoverflow.com/a/21950403/2188572
#add static inmagic xml header/footers
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

#removes duplicate lines without re-sorting everything.
awk '!a[$0]++' "$1.mkv_mediainfo_inmagic.xml" > "$1.mkv_mediainfo_inmagic_final.xml"

#prints the contents of inmagic xml to terminal
cat "$1.mkv_mediainfo_inmagic_final.xml" 

#Final move of gnerated files to final destination. This should happen automatically, current system is messy.
mv "$1.mkv_mediainfo_inmagic_final.xml" "$inmagic"
mv "$1.mkv_mediainfo_inmagic.xml" "$tmp"
mv "$1.mkv_mediainfo_inmagic.xml.backup" "$tmp"
mv "$1.mkv" "$video"
mv "$1_ffv1_mediainfo.xml" "$video"

#change dir is necessary as relative paths don't seem to work well with recursive hashes
cd "$sourcepath"

#ler - l=relative paths e=shows time remaining r=recursive
md5deep -ler "$filenoext" > "$sourcepath/$filenoext.md5"
trash -rf $tmp


echo "You should now have an xml file that can be ingested into DB/Textworks for SQL. When importing into Inmagic, DO NOT enable 'Check for matching records'"

