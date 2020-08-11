#!/bin/bash

# color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;44m'
NC='\033[0;0m'

# prints an error (just for common formatting)
error(){
	printf "${RED}Error:${NC} %s\n" "$1"
}

# seaches an array for a specific value, returning 1 if found, 0 else
contains(){
	search="$1"
	shift 1
	for ele in "$@"
	do
		if [[ "$ele" == "$search" ]]
		then
			return 1
		fi
	done
	return 0
}

# prompt the user, then scan and if wished work with scanned file
scanner(){
	# set default values
	preferences=(jpg A4 portrait 300 Flatbed crop pdf noBatch)

	# read given parameters
	for ele in $@
	do
		case "$ele" in
			fileformat=*)  preferences[0]="${ele#fileformat=}";  preset[0]=true;;
			paperformat=*) preferences[1]="${ele#paperformat=}"; preset[1]=true;;
			orientation=*) preferences[2]="${ele#orientation=}"; preset[2]=true;;
			resolution=*)  preferences[3]="${ele#resolution=}";  preset[3]=true;;
			source=*)      preferences[4]="${ele#source=}";      preset[4]=true;;
			crop)          preferences[5]=yes;                   preset[5]=true;;
			pdf)           preferences[6]=yes;                   preset[6]=true;;
			batch)         preferences[7]=yes;                   preset[7]=true;;
			skip)          skip=true;;
		esac
	done

	# check if the user wants to skip, user interaction (taking only default values/given parameters)
	if [[ "$skip" != true ]]
	then
		# read the possible settings from file and generate possible settings array
		readarray -t settings < /media/daten/scripts/printer/settings
		stat=""
		for line in "${settings[@]}"
		do
			if [[ "$line" == \#\#* ]]
			then continue
			elif [[ "$line" == \#* ]]
			then
				stat="${line#\# }"
			else
				case "$stat" in
					Fileformat)
						fileformat+=("$line")
						;;
					Paperformat)
						paperformat+=("$line")
						;;
					Orientation)
						orientation+=("$line")
						;;
					Resolution)
						resolution+=("$line")
						;;
					Source)
						srces+=("$line")
						;;
					Crop)
						crop+=("$line")
						;;
					PDF)
						pdf+=("$line")
						;;
					Batch)
						batch+=("$line")
						;;
				esac
			fi
		done

		# let the user change settings (interactive dmenu menu)
		while true
		do
			# display the settings categories, with the current setting
			resp=$(printf "%s\n"\
				"Scan" \
				 "Fileformat [${preferences[0]}]" \
				"Paperformat [${preferences[1]}]" \
				"Orientation [${preferences[2]}]" \
				 "Resolution [${preferences[3]}]" \
					 "Source [${preferences[4]}]" \
					   "Crop [${preferences[5]}]" \
						"PDF [${preferences[6]}]" \
					  "Batch [${preferences[7]}]"
				| dmenu -i -l 9)

			# if the user didn't input anything, exit
			if [[ -z "$resp" ]]
			then
				exit 1
			fi

			# check which category was selected and display available options
			case "$resp" in
				Fileformat*)
					tmp=$(printf "%s\n" ${fileformat[@]} "Back" | dmenu -i -l "$(( ${#fileformat[@]} +1 ))")
					contains "${tmp}" ${fileformat[@]} && notify-send "Invalid input" && continue
					preferences[0]="$tmp";;
				Paperformat*)
					tmp=$(printf "%s\n" ${paperformat[@]} "Back" | dmenu -i -l "$(( ${#paperformart[@]} +1 ))")
					contains "${tmp}" ${paperformat[@]} && notify-send "Invalid input" && continue
					preferences[1]="$tmp";;
				Orientation*)
					tmp=$(printf "%s\n" ${orientation[@]} "Back" | dmenu -i -l "$(( ${#orientation[@]} +1 ))")
					contains "${tmp}" ${orientation[@]} && notify-send "Invalid input" && continue
					preferences[2]="$tmp";;
				Resolution*)
					tmp=$(printf "%s\n" ${resolution[@]} "Back" | dmenu -i -l "$(( ${#resolution[@]} +1 ))")
					contains "${tmp}" ${srces[@]} && notify-send "Invalid input" && continue
					preferences[3]="$tmp";;
				Source*)
					tmp=$(printf "%s\n" ${srces[@]} "Back" | dmenu -i -l "$(( ${#srces[@]} +1 ))")
					contains "${tmp}" ${resolution[@]} && notify-send "Invalid input" && continue
					preferences[4]="$tmp";;
				Crop*)
					tmp=$(printf "%s\n" ${crop[@]} "Back" | dmenu -i -l "$(( ${#crop[@]} +1 ))")
					contains "${tmp}" ${crop[@]} && notify-send "Invalid input" && continue
					preferences[5]="$tmp";;
				PDF*)
					tmp=$(printf "%s\n" ${pdf[@]} "Back" | dmenu -i -l "$(( ${#pdf[@]} +1 ))")
					contains "${tmp}" ${pdf[@]} && notify-send "Invalid input" && continue
					preferences[6]="$tmp";;
				Batch*)
					tmp=$(printf "%s\n" ${batch[@]} "Back" | dmenu -i -l "$(( ${#batch[@]} +1 ))")
					contains "$tmp" ${batch[@]} && notify-send "Invalid input" && continue
					preferences[7]="$tmp";;
				Scan) break;;
			esac
		done
	fi

	# TODO should be able to remove this, since this is already checked when entering the option
	# sanity check if all options are valid
	contains "${preferences[0]}" ${fileformat[@]} && error "Invalid input" && exit 1
	contains "${preferences[1]}" ${paperformat[@]} && error "Invalid input" && exit 1
	contains "${preferences[2]}" ${orientation[@]} && error "Invalid input" && exit 1
	contains "${preferences[3]}" ${srces[@]} && error "Invalid input" && exit 1
	contains "${preferences[4]}" ${resolution[@]} && error "Invalid input" && exit 1
	contains "${preferences[5]}" ${crop[@]} && error "Invalid input" && exit 1
	contains "${preferences[6]}" ${pdf[@]} && error "Invalid input" && exit 1
	contains "${preferences[7]}" ${batch[@]} && error "Invalid input" && exit 1

	# look up the dimensions of the paperformat (in mm and in inches*10)
	case "${settings[1]}" in
		A4) x=210; y=297; xIn=83; yIn=117;;
		A5) x=148; y=210; xIn=58; yIn=83;;
		*) error "Unknown papersize"; exit 1;;
	esac

	# swap dimensions if landscape is selected
	if [[ "${settings[2]}" == landscape ]]
	then
		tmp="$x"  ;   x="$y"  ;   y="$tmp"
		tmp="$xIn"; xIn="$yIn"; yIn="$tmp"
	fi

	# get outputpath (dependant wether batch was selected and if batch but not ADF selected, prompt the user)
	if [[ "${preferences[7]}" == batch ]]
	then
		mkdir -p "${HOME}/scans/$(date +%Y-%m-%d+%s)"
		outfile="${HOME}/scans/$(date +%Y-%m-%d+%s)/$(date +%Y-%m-%d)_%d.${settings[0]}"
		if [[ "${settings[3]}" == "ADF" ]] # only prompt before scanning the next page if source is non ADF
		then
			out="--batch=$outfile"
		else
			out="--batch-prompt --batch=$outfile"
		fi
	else
		outfile="${HOME}/scans/$(date +%Y-%m-%d+%s)_%d.${settings[0]}"
		out="--output-file=$outfile"
	fi

	# scan image (and print the command in advance)
	echo scanimage --format="${settings[0]}" --progress --source="${settings[3]}" --resolution="${settings[4]}" -x "$x" -y "$y" $out
	scanimage --format="${settings[0]//jpg/jpeg}" --progress --source="${settings[3]}" --resolution="${settings[4]}" -x "$x" -y "$y" $out

	for file in ${outfile//%d/+([0-9])}
	do
		filelist+=("$file")
	done

	# remove white borders if wished
	if [[ "${preferences[5]}" == "crop" ]]
	then
		# for the case thst more than one set of files should be cropped
		notify-send "You can now remove distortions in the white border (which is to be removed), to improve the cropping result"
		gimp "${filelist[@]}" #let the user remove black dots in the white border to improve the result

		for file in ${filelist[@]}
		do
			# check what should be removed
			echo convert "$file" -virtual-pixel edge -blur 0x10 -fuzz 15% -trim  -format '%wx%h%O\n' info:
			crop1="$(convert "$file" -virtual-pixel edge -blur 0x10 -fuzz 15% -trim  -format '%wx%h%O\n' info:)"
			# tmp="$(mktemp)"
			# convert "$file" -crop "${crop1}" "${tmp}"

			# crop2="$(convert "$tmp" -chop 40x0 -virtual-pixel edge -blur 0x10 -fuzz 15% -trim  -format '%wx%h%O\n' info:)"
			# convert "$tmp" -crop "${crop2}" "${file%.${settings[0]}}-cropped.${settings[0]}"

			# really crop the picture
			echo convert "$file" -crop "${crop1}" "${file%.${settings[0]}}-cropped.${settings[0]}"
			convert "$file" -crop "${crop1}" "${file%.${settings[0]}}-cropped.${settings[0]}"
			filelist1+=("${file%.${settings[0]}}-cropped.${settings[0]}")
			# rm -v "$tmp"
		done
	fi

	# enhance pictures after (potentially) cropping
	for file in ${filelist[@]}
	do
		convert "$file" -normalize -gamma 0.8,0.8,0.8 +dither -posterize 3 "${file%${preferences[0]}}-enh.${preferences[0]}"
		filelist2+=("${file%${preferences[0]}}-enh.${preferences[0]}")
	done

	# make a pdf out of the picture(s) if wished
	if [[ "${preferences[6]}" == "pdf" ]]
	then
		# paperdimensions will be the ones that were scanned, each image will be on a new page

		# pdf out of original pictures
		echo convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist[@]})  -units pixelsperinch -density 150 "${outfile%${settings[0]}}pdf"
		convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist[@]})  -units pixelsperinch -density 150 "${outfile%${settings[0]}}pdf"

		# pdf out of cropped pictures
		echo convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist1[@]})  -units pixelsperinch -density 150 "${outfile%.${settings[0]}}-crop.pdf"
		convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist1[@]})  -units pixelsperinch -density 150 "${outfile%.${settings[0]}}-crop.pdf"

		# pdf out of enhanced pictures
		echo convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist2[@]})  -units pixelsperinch -density 150 "${outfile%.${settings[0]}}-enh.pdf"
		convert $(printf "( -size $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) xc:white %s -resize $(( (xIn*105)/10 ))x$(( (yIn*150)/10 )) -composite ) "  ${filelist2[@]})  -units pixelsperinch -density 150 "${outfile%.${settings[0]}}-enh.pdf"
	fi
}

if [[ -z "$1" ]]
then
	# action="$(printf "%s\n" "scan" "print" | dmenu -i -f)"
	action=scanner
else
	action="$1"
fi

scanner $@

# case "$action" in
# 	scan) scanner;;
# 	print) printer;;
# 	*) error "Unknown action selected";;
# esac


# yad --text=Scanner --form --field=Fileformat:CB 'png!jpg!tiff' --field=Papersize:CB 'A4!A5' --field=Orientation:CB 'Portrait!Landscape' --field=res:NUM '300!0..600!50!0' --field=Outputfile:SFL
