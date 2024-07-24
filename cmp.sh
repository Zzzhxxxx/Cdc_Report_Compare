#!/bin/bash

############################################################# Part 1 #############################################################

###############################  ###############################  ###############################  ###############################
##                           ##  ##                           ##  ##                           ##  ##                           ##
##  preliminary preparation  ##  ##  preliminary preparation  ##  ##  preliminary preparation  ##  ##  preliminary preparation  ##
##                           ##  ##                           ##  ##                           ##  ##                           ##
###############################  ###############################  ###############################  ###############################

MODE=sam_waive
RPT="./cdc_report_compare.rpt"
Script_Owner="Han.Zhang(JM0583)"

source /share/project/crete/dev/han.zhang/scripts/functions_for_cmp.sh

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        FILE1=*)
            FILE1="${key#*=}"
            shift
            ;;
        FILE2=*)
            FILE2="${key#*=}"
            shift
            ;;
        RPT=*)
            RPT="${key#*=}"
            shift
            ;;
        MODE=*)
            MODE="${key#*=}"
            shift
            ;;
        *)
			print_help
            ;;
    esac
done

if [ -z "$FILE1" ] || [ -z "$FILE2" ] || [ -z "$RPT" ] || [ ! -f "$FILE1" ] || [ ! -f "$FILE2" ] || [ -d "$RPT" ]; then
	print_help
fi

if [ "$MODE" != sam_waive ] && [ "$MODE" != netlist_rtl ]; then
	print_help
fi

if [ ! -f "$RPT" ]; then
    touch "$RPT"
else
	while true; do
    	echo "The file '$RPT' already exists. Do you want to overwrite it? [y/n]: "
    	read answer

    	case $answer in
    		[Yy]*)
    	    	> "$RPT"
				break
    	    	;;
    		[Nn]*)
    	    	echo "It looks like you don't want to overwrite the original file, so please specify a new one."
				echo "Exiting without overwriting the file."
    	    	exit 1
    	    	;;
    		*)
    	    	echo "Please answer with [y/n]."
    	    	;;
    	esac
	done
fi

start_time=$(date +%s)
declare -A file1_ordinary
declare -A file2_ordinary
declare -A file1_ordinary_temp
declare -A file2_ordinary_temp
declare -A file1_ordinary_id
declare -A file2_ordinary_id
declare -A file1_setup
declare -A file2_setup
declare -A file1_conv
declare -A file2_conv
declare -A file1_conv_temp
declare -A file2_conv_temp
declare -A file1_conv_tag
declare -A file2_conv_tag
declare -A file1_conv_id
declare -A file2_conv_id
declare -A file1_conv_point
declare -A file2_conv_point
declare -A file1_conv_paths
declare -A file2_conv_paths
declare -a ordinary_output_pass
declare -a ordinary_output_fail1
declare -a ordinary_output_fail2
declare -a setup_output
declare -a temp_array
declare -a temp_array_1
declare -a src_paths
declare -a dst_paths
total_line_number=0
line_number=0
percentage=0
last_reported_percentage=0

############################################### Part 2 ###############################################

########################  ########################  ########################  ########################
##                    ##  ##                    ##  ##                    ##  ##                    ##
##   sam_waive mode   ##  ##   sam_waive mode   ##  ##   sam_waive mode   ##  ##   sam_waive mode   ##
##                    ##  ##                    ##  ##                    ##  ##                    ##
########################  ########################  ########################  ########################

if [[ $MODE == sam_waive ]]; then

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 1st time  ##
	##                                       ##
	###########################################

	total_line_number=$(awk '
		!/(warning[s]?)\// { count++ }
		/(warning[s]?)\// {
			print count
			exit
		}
	' "$FILE1")
	echo "Number of lines describing errors in "$FILE1": "$total_line_number"."

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 2nd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ .*warning.*SETUP.* ]] || [[ $line =~ .*info.*SETUP.* ]]; then
			for pair in "${temp_array[@]}"; do
	        	file1_setup["$pair"]=1
			done
			temp_array=()
			break
		elif [[ $line =~ .*error.*SETUP.* ]]; then
			tag=$(echo "$line" | awk -F' ' '{print $3}')
			error_number=$(echo "$line" | awk -F' ' '{print $4}')
			temp_array+=("$tag $error_number")
		fi
	done < "$FILE1"

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 3rd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ CDC: ]]; then
	        id=$(echo "$line" | awk -F':' '{print $NF}')
	    elif [[ $line =~ ^[[:space:]]*Tag[[:space:]]*:[[:space:]]* ]]; then
	        tag=$(echo "$line" | awk -F':' '{print $2}')
	        src_paths=()
	        dst_paths=()
	        if [[ $tag != *CONV* ]]; then
	            break
	        fi
	    elif [[ $line =~ ConvergencePoint ]]; then
			ConvergencePoint=$(echo "$line" | awk -F':' '{print $2}')
	    elif [[ $line =~ DestObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        dst_path=$(echo "$line" | awk -F':' '{print $2}')
	        if [[ $dst_path != "" ]]; then
	            dst_paths+=("$dst_path")
	        fi
	    elif [[ $line =~ SrcObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        src_path=$(echo "$line" | awk -F':' '{print $2}')
	        if [[ $src_path != "" ]]; then
	            src_paths+=("$src_path")
	        fi
	    elif [[ $line =~ State ]]; then
	        state=$(echo "$line" | awk -F':' '{print $2}' | xargs)
	    elif [[ $line =~ ----------------------------------------------------------------------------- ]]; then
	        if [[ $state != Waived ]]; then
	            if [[ ${#src_paths[@]} -eq ${#dst_paths[@]} ]] && [[ ${#src_paths[@]} -gt 1 ]] && [[ ${#dst_paths[@]} -gt 1 ]]; then
	                combined_paths=""
	                for i in "${!src_paths[@]}"; do
	                    combined_paths+="${src_paths[$i]} ${dst_paths[$i]} "
	                done
	                file1_conv["$tag $id $ConvergencePoint $combined_paths"]=1
	            fi
	        fi
	        src_paths=()
	        dst_paths=()
	        state=""
	    fi
	done < "$FILE1"

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 4th time  ##
	##                                       ##
	###########################################

	awk -v file="$FILE1" -v total_lines="$total_line_number" '
		BEGIN {
			last_reported_percentage = -1;
			line_number = 0;
			OFS = " ";
		}
		{
	    	line_number++;
	    	percentage = int(line_number * 100 / total_lines / 10) * 10;
			while (percentage >= last_reported_percentage + 10) {
	            last_reported_percentage = percentage;
	            printf("Progress on %s: %d%%\n", file, percentage);
	        }
			if ($0 ~ /CDC:/) {
				id = $3;
				sub(/CDC:/, "", id);
        	} else if ($0 ~ /^[[:space:]]*Tag[[:space:]]*:[[:space:]]*/) {
				tag = $3;
	            if (tag !~ /CDC.*/) {
	                exit;
	            }
	        } else if ($0 ~ /DestObject[[:space:]]/ && $0 !~ /Description/) {
				dst_path = $3;
	            if (dst_path != "" && src_path != "") {
	                temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	                src_path = "";
	                dst_path = "";
	            }
	        } else if ($0 ~ /SrcObject[[:space:]]/ && $0 !~ /Description/) {
				src_path = $3;
	            if (dst_path != "" && src_path != "") {
	                temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	                src_path = "";
	                dst_path = "";
	            }
	        } else if ($0 ~ /State/) {
				state = $3;
	        } else if ($0 ~ /----------------------------------------------------------------------------/) {
				if (state != "Waived" && tag !~ /CONV/) {
				    for (i = 1; i <= temp_array_count; i++) {
				        print temp_array[i] > "TEMP_FILE1"
				    }
				}
	            temp_array_count = 0;
	            state = "";
	        }
	    }
	' "$FILE1"

	while IFS= read -r line; do
    	file1_ordinary["$line"]=1
 	done < "TEMP_FILE1"
 	rm -rf "TEMP_FILE1"
	echo "Progress on "$FILE1": 100%"

	total_line_number=0
	line_number=0
	percentage=0
	last_reported_percentage=0
	error_number=0

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 1st time  ##
	##                                       ##
	###########################################

	total_line_number=$(awk '
	    !/(warning[s]?)\// { count++ }
	    /(warning[s]?)\// {
			print count
	        exit
	    }
	' "$FILE2")
	echo "Number of lines describing errors in "$FILE2": "$total_line_number"."

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 2nd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ .*warning.*SETUP.* ]] || [[ $line =~ .*info.*SETUP.* ]]; then
			for pair in "${temp_array[@]}"; do
	        	file2_setup["$pair"]=1
			done
			temp_array=()
			break
		elif [[ $line =~ .*error.*SETUP.* ]]; then
			tag=$(echo "$line" | awk -F' ' '{print $3}')
			error_number=$(echo "$line" | awk -F' ' '{print $4}')
			temp_array+=("$tag $error_number")
		fi
	done < "$FILE2"

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 3rd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ CDC: ]]; then
	        id=$(echo "$line" | awk -F':' '{print $NF}')
	    elif [[ $line =~ ^[[:space:]]*Tag[[:space:]]*:[[:space:]]* ]]; then
	        tag=$(echo "$line" | awk -F':' '{print $2}')
	        src_paths=()
	        dst_paths=()
	        if [[ $tag != *CONV* ]]; then
	            break
	        fi
	    elif [[ $line =~ ConvergencePoint ]]; then
			ConvergencePoint=$(echo "$line" | awk -F':' '{print $2}')
	    elif [[ $line =~ DestObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        dst_path=$(echo "$line" | awk -F':' '{print $2}')
	        if [[ $dst_path != "" ]]; then
	            dst_paths+=("$dst_path")
	        fi
	    elif [[ $line =~ SrcObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        src_path=$(echo "$line" | awk -F':' '{print $2}')
	        if [[ $src_path != "" ]]; then
	            src_paths+=("$src_path")
	        fi
	    elif [[ $line =~ State ]]; then
	        state=$(echo "$line" | awk -F':' '{print $2}' | xargs)
	    elif [[ $line =~ ----------------------------------------------------------------------------- ]]; then
	        if [[ $state != Waived ]]; then
	            if [[ ${#src_paths[@]} -eq ${#dst_paths[@]} ]] && [[ ${#src_paths[@]} -gt 1 ]] && [[ ${#dst_paths[@]} -gt 1 ]]; then
	                combined_paths=""
	                for i in "${!src_paths[@]}"; do
	                    combined_paths+="${src_paths[$i]} ${dst_paths[$i]} "
	                done
	                file2_conv["$tag $id $ConvergencePoint $combined_paths"]=1
	            fi
	        fi
	        src_paths=()
	        dst_paths=()
	        state=""
	    fi
	done < "$FILE2"

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 4th time  ##
	##                                       ##
	###########################################

	awk -v file="$FILE2" -v total_lines="$total_line_number" '
		BEGIN {
	    	last_reported_percentage = -1;
	    	line_number = 0;
	    	OFS = " ";
		}
		{
	    	line_number++;
	    	percentage = int(line_number * 100 / total_lines / 10) * 10;
	        while (percentage >= last_reported_percentage + 10) {
	            last_reported_percentage = percentage;
	            printf("Progress on %s: %d%%\n", file, percentage);
	        }
			if ($0 ~ /CDC:/) {
				id = $3;
				sub(/CDC:/, "", id);
        	} else if ($0 ~ /^[[:space:]]*Tag[[:space:]]*:[[:space:]]*/) {
				tag = $3;
	            if (tag !~ /CDC.*/) {
	                exit;
	            }
	        } else if ($0 ~ /DestObject[[:space:]]/ && $0 !~ /Description/) {
				dst_path = $3;
	            if (dst_path != "" && src_path != "") {
	                temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	                src_path = "";
	                dst_path = "";
	            }
	        } else if ($0 ~ /SrcObject[[:space:]]/ && $0 !~ /Description/) {
				src_path = $3;
	            if (dst_path != "" && src_path != "") {
	                temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	                src_path = "";
	                dst_path = "";
	            }
	        } else if ($0 ~ /State/) {
				state = $3;
	        } else if ($0 ~ /----------------------------------------------------------------------------/) {
				if (state != "Waived" && tag !~ /CONV/) {
				    for (i = 1; i <= temp_array_count; i++) {
				        print temp_array[i] > "TEMP_FILE2"
				    }
				}
	            temp_array_count = 0;
	            state = "";
	        }
	    }
	' "$FILE2"

	while IFS= read -r line; do
    	file2_ordinary["$line"]=1
 	done < "TEMP_FILE2"
 	rm -rf "TEMP_FILE2"
	echo "Progress on "$FILE2": 100%"

	##################################################################
	##                                                              ##
	##  Category 1: Tags named SETUP* without SRC_PATH or DST_PATH  ##
	##                                                              ##
	##################################################################

	print_title_1 >> "$RPT"
	for key1 in "${!file1_setup[@]}"; do
		flag=0
		value_1=(${key1})
		for key2 in "${!file2_setup[@]}"; do
			value_2=(${key2})
			if [[ "${value_1[0]}" == "${value_2[0]}" ]] && [[ "${value_1[1]}" == "${value_2[1]}" ]]; then
				setup_output+=("${value_1[0]}" "${value_1[1]}" "${value_2[1]}" "PASS")
				flag=1
			elif [[ "${value_1[0]}" == "${value_2[0]}" ]] && [[ "${value_1[1]}" != "${value_2[1]}" ]]; then
				setup_output+=("${value_1[0]}" "${value_1[1]}" "${value_2[1]}" "FAIL")
				flag=1
			fi
		done
		if [[ $flag == 0 ]]; then
			setup_output+=("${value_1[0]}" "${value_1[1]}" "0" "FAIL")
		fi
	done

	for key2 in "${!file2_setup[@]}"; do
		flag=0
		value_2=(${key2})
		for key1 in "${!file1_setup[@]}"; do
			value_1=(${key1})
			if [[ "${value_2[0]}" == "${value_1[0]}" ]]; then
				flag=1
			fi
		done
		if [[ $flag == 0 ]]; then
			setup_output+=("${value_2[0]}" "0" "${value_1[1]}" "FAIL")
		fi
	done

	if [ ${#setup_output[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\n" "${setup_output[@]}" >> "$RPT"
	fi

	###########################################################################
	##                                                                       ##
	##  Category 2: Tags named *CONV* with Multiple SRC_PATHs and DST_PATHs  ##
	##                                                                       ##
	###########################################################################

	print_title_2 >> "$RPT"
	for key in "${!file1_conv[@]}"; do
	    stripped_key=$(strip_id "$key")
		tag=$(extract_tag "$key")
		id=$(extract_id "$key")
		convergence_point=$(extract_convergence_point "$key")
    	paths=($(extract_paths "$key"))
	    file1_conv_temp[$stripped_key]=1
		file1_conv_tag[$stripped_key]=$tag
		file1_conv_id[$stripped_key]=$id
    	file1_conv_point[$stripped_key]=$convergence_point
    	file1_conv_paths[$stripped_key]="${paths[@]}"
	done

	for key in "${!file2_conv[@]}"; do
	    stripped_key=$(strip_id "$key")
		tag=$(extract_tag "$key")
		id=$(extract_id "$key")
		convergence_point=$(extract_convergence_point "$key")
    	paths=($(extract_paths "$key"))
	    file2_conv_temp[$stripped_key]=1
		file2_conv_tag[$stripped_key]=$tag
		file2_conv_id[$stripped_key]=$id
    	file2_conv_point[$stripped_key]=$convergence_point
    	file2_conv_paths[$stripped_key]="${paths[@]}"
	done

	{
	    if [ ${#file1_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file1_conv_temp[@]}"; do
	            if [[ -z ${file2_conv_temp[$key]} ]]; then
	                result="FAIL: only in "$FILE1""
	                id2="/"
					printf "%-40s %-40s %-40s %-40s\n" "${file1_conv_tag[$key]}" "${file1_conv_id[$key]}" "$id2" "$result"
	                echo "Convergence_Point: ${file1_conv_point[$key]}"
					paths1=(${file1_conv_paths[$key]})
	                format_paths paths1[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	    if [ ${#file2_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file2_conv_temp[@]}"; do
	            if [[ -z ${file1_conv_temp[$key]} ]]; then
	                result="FAIL: only in "$FILE2""
	                id1="/"
					printf "%-40s %-40s %-40s %-40s\n" "${file2_conv_tag[$key]}" "$id1" "${file2_conv_id[$key]}" "$result"
	                echo "Convergence_Point: ${file2_conv_point[$key]}"
					paths2=(${file2_conv_paths[$key]})
	                format_paths paths2[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	    if [ ${#file1_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file1_conv_temp[@]}"; do
	            if [[ -n ${file2_conv_temp[$key]} ]]; then
	                result="PASS: both in 2 files"
	                id2=${file2_conv_id[$key]}
					printf "%-40s %-40s %-40s %-40s\n" "${file1_conv_tag[$key]}" "${file1_conv_id[$key]}" "$id2" "$result"
	            	echo "Convergence_Point: ${file1_conv_point[$key]}"
					paths1=(${file1_conv_paths[$key]})
	            	format_paths paths1[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	} >> "$RPT"

	###################################################################
	##                                                               ##
	##  Category 3: Ordinary Tags with Single SRC_PATH and DST_PATH  ##
	##                                                               ##
	###################################################################

	print_title_3 >> "$RPT"
	for key1 in "${!file1_ordinary[@]}"; do
	    value_1=(${key1})
	    key_hash="${value_1[0]},${value_1[2]},${value_1[3]}"
	    file1_ordinary_temp[$key_hash]=1
	    file1_ordinary_id[$key_hash]=${value_1[1]}
	done

	for key2 in "${!file2_ordinary[@]}"; do
		value_2=(${key2})
	    key_hash="${value_2[0]},${value_2[2]},${value_2[3]}"
	    file2_ordinary_temp[$key_hash]=1
	    file2_ordinary_id[$key_hash]=${value_2[1]}
	done

	for key1 in "${!file1_ordinary[@]}"; do
	    value_1=(${key1})
	    key_hash="${value_1[0]},${value_1[2]},${value_1[3]}"
	    if [[ -n "${file2_ordinary_temp[$key_hash]}" ]]; then
	        ordinary_output_pass+=("${value_1[0]}" "${value_1[1]}" "${file2_ordinary_id[$key_hash]}" "PASS: both in 2 files" "${value_1[2]}" "${value_1[3]}")
	    else
	        ordinary_output_fail1+=("${value_1[0]}" "${value_1[1]}" "/" "FAIL: only in "$FILE1"" "${value_1[2]}" "${value_1[3]}")
	    fi
	done

	for key2 in "${!file2_ordinary[@]}"; do
		value_2=(${key2})
	    key_hash="${value_2[0]},${value_2[2]},${value_2[3]}"
	    if [[ -z "${file1_ordinary_temp[$key_hash]}" ]]; then
	        ordinary_output_fail2+=("${value_2[0]}" "/" "${value_2[1]}" "FAIL: only in "$FILE2"" "${value_2[2]}" "${value_2[3]}")
	    fi
	done

	if [ ${#ordinary_output_fail1[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_fail1[@]}" >> "$RPT"
	fi
	if [ ${#ordinary_output_fail2[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_fail2[@]}" >> "$RPT"
	fi
	if [ ${#ordinary_output_pass[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_pass[@]}" >> "$RPT"
	fi
fi

############################################### Part 3 ###############################################

########################  ########################  ########################  ########################
##                    ##  ##                    ##  ##                    ##  ##                    ##
##  netlist_rtl mode  ##  ##  netlist_rtl mode  ##  ##  netlist_rtl mode  ##  ##  netlist_rtl mode  ##
##                    ##  ##                    ##  ##                    ##  ##                    ##
########################  ########################  ########################  ########################

if [[ $MODE == netlist_rtl ]]; then

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 1st time  ##
	##                                       ##
	###########################################

	total_line_number=$(awk '
	    !/(warning[s]?)\// { count++ }
	    /(warning[s]?)\// {
			print count
	        exit
	    }
	' "$FILE1")
	echo "Number of lines describing errors in "$FILE1": "$total_line_number"."

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 2nd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ .*warning.*SETUP.* ]] || [[ $line =~ .*info.*SETUP.* ]]; then
			for pair in "${temp_array[@]}"; do
	        	file1_setup["$pair"]=1
			done
			temp_array=()
			break
		elif [[ $line =~ .*error.*SETUP.* ]]; then
			tag=$(echo "$line" | awk -F' ' '{print $3}')
			error_number1=$(echo "$line" | awk -F' ' '{print $4}')
			error_number2=$(echo "$line" | awk -F' ' '{print $5}')
			error_number=$(($error_number1 + $error_number2))
			temp_array+=("$tag $error_number")
		fi
	done < "$FILE1"

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 3rd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ CDC: ]]; then
	        id=$(echo "$line" | awk -F':' '{print $NF}')
	    elif [[ $line =~ ^[[:space:]]*Tag[[:space:]]*:[[:space:]]* ]]; then
	        tag=$(echo "$line" | awk -F':' '{print $2}')
	        src_paths=()
	        dst_paths=()
	        if [[ $tag != *CONV* ]]; then
	            break
	        fi
	    elif [[ $line =~ ConvergencePoint ]]; then
			ConvergencePoint=$(echo "$line" | awk -F':' '{print $2}')
	    elif [[ $line =~ DestObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        dst_path=$(echo "$line" | awk -F':' '{print $2}')
			dst_path=$(deal_with_path "$dst_path")
	        if [[ $dst_path != "" ]]; then
	            dst_paths+=("$dst_path")
	        fi
	    elif [[ $line =~ SrcObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        src_path=$(echo "$line" | awk -F':' '{print $2}')
			src_path=$(deal_with_path "$src_path")
	        if [[ $src_path != "" ]]; then
	            src_paths+=("$src_path")
	        fi
	    elif [[ $line =~ ----------------------------------------------------------------------------- ]]; then
	        if [[ ${#src_paths[@]} -eq ${#dst_paths[@]} ]] && [[ ${#src_paths[@]} -gt 1 ]] && [[ ${#dst_paths[@]} -gt 1 ]]; then
	            combined_paths=""
	            for i in "${!src_paths[@]}"; do
	                combined_paths+="${src_paths[$i]} ${dst_paths[$i]} "
	            done
	            file1_conv["$tag $id $ConvergencePoint $combined_paths"]=1
	        fi
	        src_paths=()
	        dst_paths=()
	        state=""
	    fi
	done < "$FILE1"

	###########################################
	##                                       ##
	##  Iterate over FILE1 for the 4th time  ##
	##                                       ##
	###########################################

	awk -v file="$FILE1" -v total_lines="$total_line_number" '
		function deal_with_path(path) {
		    number1 = ""
		    number2 = ""
		    if (match(path, /_reg_([0-9]+)__([0-9]+)_\/Q(N)?$/)) {
		        number1 = substr(path, RSTART + 5, RLENGTH - 12)
		        number2 = substr(path, RSTART + 7 + length(number1), RLENGTH - 10 - length(number1))
		        path = gensub(/_reg_[0-9]+__[0-9]+_\/Q(N)?$/, "[" number1 "][" number2 "]", "g", path)
		    }
		    else if (match(path, /_reg_([0-9]+)_\/Q(N)?$/)) {
		        number1 = substr(path, RSTART + 5, RLENGTH - 8)
		        path = gensub(/_reg_[0-9]+_\/Q(N)?$/, "[" number1 "]", "g", path)
		    }
		    while (match(path, /(.+)\[[0-9]+\]$/)) {
		        path = gensub(/\[[0-9]+\]$/, "", 1, path)
		    }
		    return path
		}
		BEGIN {
			last_reported_percentage = -1;
			line_number = 0;
			OFS = " ";
		}
		{
	    	line_number++;
	    	percentage = int(line_number * 100 / total_lines / 10) * 10;
			while (percentage >= last_reported_percentage + 10) {
	            last_reported_percentage = percentage;
	            printf("Progress on %s: %d%%\n", file, percentage);
	        }
			if ($0 ~ /CDC:/) {
				id = $3;
				sub(/CDC:/, "", id);
        	} else if ($0 ~ /^[[:space:]]*Tag[[:space:]]*:[[:space:]]*/) {
				tag = $3;
	            if (tag !~ /CDC.*/) {
	                exit;
	            }
	        } else if ($0 ~ /DestObject[[:space:]]/ && $0 !~ /Description/) {
				dst_path = $3;
				dst_path = deal_with_path(dst_path);
	            if (dst_path != "" && src_path != "") {
	                temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	               	src_path = "";
	               	dst_path = "";
				}
	        } else if ($0 ~ /SrcObject[[:space:]]/ && $0 !~ /Description/) {
				src_path = $3;
				src_path = deal_with_path(src_path);
	            if (dst_path != "" && src_path != "") {
	            	temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	            	src_path = "";
	            	dst_path = "";
				}
	        } else if ($0 ~ /----------------------------------------------------------------------------/) {
				if (tag !~ /CONV/) {
				    for (i = 1; i <= temp_array_count; i++) {
				        print temp_array[i] > "TEMP_FILE1"
				    }
				}
	            temp_array_count = 0;
	        }
	    }
	' "$FILE1"

	while IFS= read -r line; do
    	file1_ordinary["$line"]=1
 	done < "TEMP_FILE1"
 	rm -rf "TEMP_FILE1"
	echo "Progress on "$FILE1": 100%"

	total_line_number=0
	line_number=0
	percentage=0
	last_reported_percentage=0
	error_number=0

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 1st time  ##
	##                                       ##
	###########################################

	total_line_number=$(awk '
	    !/(warning[s]?)\// { count++ }
	    /(warning[s]?)\// {
			print count
	        exit
	    }
	' "$FILE2")
	echo "Number of lines describing errors in "$FILE2": "$total_line_number"."

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 2nd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ .*warning.*SETUP.* ]] || [[ $line =~ .*info.*SETUP.* ]]; then
			for pair in "${temp_array[@]}"; do
	        	file2_setup["$pair"]=1
			done
			temp_array=()
			break
		elif [[ $line =~ .*error.*SETUP.* ]]; then
			tag=$(echo "$line" | awk -F' ' '{print $3}')
			error_number1=$(echo "$line" | awk -F' ' '{print $4}')
			error_number2=$(echo "$line" | awk -F' ' '{print $5}')
			error_number=$(($error_number1 + $error_number2))
			temp_array+=("$tag $error_number")
		fi
	done < "$FILE2"

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 3rd time  ##
	##                                       ##
	###########################################

	while IFS= read -r line
	do
	    if [[ $line =~ CDC: ]]; then
	        id=$(echo "$line" | awk -F':' '{print $NF}')
	    elif [[ $line =~ ^[[:space:]]*Tag[[:space:]]*:[[:space:]]* ]]; then
	        tag=$(echo "$line" | awk -F':' '{print $2}')
	        src_paths=()
	        dst_paths=()
	        if [[ $tag != *CONV* ]]; then
	            break
	        fi
	    elif [[ $line =~ ConvergencePoint ]]; then
			ConvergencePoint=$(echo "$line" | awk -F':' '{print $2}')
	    elif [[ $line =~ DestObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        dst_path=$(echo "$line" | awk -F':' '{print $2}')
			dst_path=$(deal_with_path "$dst_path")
	        if [[ $dst_path != "" ]]; then
	            dst_paths+=("$dst_path")
	        fi
	    elif [[ $line =~ SrcObject[[:space:]] ]] && ! [[ $line =~ Description ]]; then
	        src_path=$(echo "$line" | awk -F':' '{print $2}')
			src_path=$(deal_with_path "$src_path")
	        if [[ $src_path != "" ]]; then
	            src_paths+=("$src_path")
	        fi
	    elif [[ $line =~ ----------------------------------------------------------------------------- ]]; then
	        if [[ ${#src_paths[@]} -eq ${#dst_paths[@]} ]] && [[ ${#src_paths[@]} -gt 1 ]] && [[ ${#dst_paths[@]} -gt 1 ]]; then
	            combined_paths=""
	            for i in "${!src_paths[@]}"; do
	                combined_paths+="${src_paths[$i]} ${dst_paths[$i]} "
	            done
	            file2_conv["$tag $id $ConvergencePoint $combined_paths"]=1
	        fi
	        src_paths=()
	        dst_paths=()
	        state=""
	    fi
	done < "$FILE2"

	###########################################
	##                                       ##
	##  Iterate over FILE2 for the 4th time  ##
	##                                       ##
	###########################################

	awk -v file="$FILE2" -v total_lines="$total_line_number" '
		function deal_with_path(path) {
		    number1 = ""
		    number2 = ""
		    if (match(path, /_reg_([0-9]+)__([0-9]+)_\/Q(N)?$/)) {
		        number1 = substr(path, RSTART + 5, RLENGTH - 12)
		        number2 = substr(path, RSTART + 7 + length(number1), RLENGTH - 10 - length(number1))
		        path = gensub(/_reg_[0-9]+__[0-9]+_\/Q(N)?$/, "[" number1 "][" number2 "]", "g", path)
		    }
		    else if (match(path, /_reg_([0-9]+)_\/Q(N)?$/)) {
		        number1 = substr(path, RSTART + 5, RLENGTH - 8)
		        path = gensub(/_reg_[0-9]+_\/Q(N)?$/, "[" number1 "]", "g", path)
		    }
		    while (match(path, /(.+)\[[0-9]+\]$/)) {
		        path = gensub(/\[[0-9]+\]$/, "", 1, path)
		    }
		    return path
		}
		BEGIN {
			last_reported_percentage = -1;
			line_number = 0;
			OFS = " ";
		}
		{
	    	line_number++;
	    	percentage = int(line_number * 100 / total_lines / 10) * 10;
			while (percentage >= last_reported_percentage + 10) {
	            last_reported_percentage = percentage;
	            printf("Progress on %s: %d%%\n", file, percentage);
	        }
			if ($0 ~ /CDC:/) {
				id = $3;
				sub(/CDC:/, "", id);
        	} else if ($0 ~ /^[[:space:]]*Tag[[:space:]]*:[[:space:]]*/) {
				tag = $3;
	            if (tag !~ /CDC.*/) {
	                exit;
	            }
	        } else if ($0 ~ /DestObject[[:space:]]/ && $0 !~ /Description/) {
				dst_path = $3;
				dst_path = deal_with_path(dst_path);
	            if (dst_path != "" && src_path != "") {
	            	temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	            	src_path = "";
	            	dst_path = "";
				}
	        } else if ($0 ~ /SrcObject[[:space:]]/ && $0 !~ /Description/) {
				src_path = $3;
				src_path = deal_with_path(src_path);
	            if (dst_path != "" && src_path != "") {
	            	temp_array[++temp_array_count] = tag OFS id OFS src_path OFS dst_path;
	            	src_path = "";
	            	dst_path = "";
				}
	        } else if ($0 ~ /----------------------------------------------------------------------------/) {
				if (tag !~ /CONV/) {
				    for (i = 1; i <= temp_array_count; i++) {
				        print temp_array[i] > "TEMP_FILE2"
				    }
				}
	            temp_array_count = 0;
	        }
	    }
	' "$FILE2"

	while IFS= read -r line; do
    	file2_ordinary["$line"]=1
 	done < "TEMP_FILE2"
 	rm -rf "TEMP_FILE2"
	echo "Progress on "$FILE2": 100%"

	##################################################################
	##                                                              ##
	##  Category 1: Tags named SETUP* without SRC_PATH or DST_PATH  ##
	##                                                              ##
	##################################################################

	print_title_1 >> "$RPT"
	for key1 in "${!file1_setup[@]}"; do
		flag=0
		value_1=(${key1})
		for key2 in "${!file2_setup[@]}"; do
			value_2=(${key2})
			if [[ "${value_1[0]}" == "${value_2[0]}" ]] && [[ "${value_1[1]}" == "${value_2[1]}" ]]; then
				setup_output+=("${value_1[0]}" "${value_1[1]}" "${value_2[1]}" "PASS")
				flag=1
			elif [[ "${value_1[0]}" == "${value_2[0]}" ]] && [[ "${value_1[1]}" != "${value_2[1]}" ]]; then
				setup_output+=("${value_1[0]}" "${value_1[1]}" "${value_2[1]}" "FAIL")
				flag=1
			fi
		done
		if [[ $flag == 0 ]]; then
			setup_output+=("${value_1[0]}" "${value_1[1]}" "0" "FAIL")
		fi
	done

	for key2 in "${!file2_setup[@]}"; do
		flag=0
		value_2=(${key2})
		for key1 in "${!file1_setup[@]}"; do
			value_1=(${key1})
			if [[ "${value_2[0]}" == "${value_1[0]}" ]]; then
				flag=1
			fi
		done
		if [[ $flag == 0 ]]; then
			setup_output+=("${value_2[0]}" "0" "${value_1[1]}" "FAIL")
		fi
	done

	if [ ${#setup_output[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\n" "${setup_output[@]}" >> "$RPT"
	fi

	###########################################################################
	##                                                                       ##
	##  Category 2: Tags named *CONV* with Multiple SRC_PATHs and DST_PATHs  ##
	##                                                                       ##
	###########################################################################

	print_title_2 >> "$RPT"
	for key in "${!file1_conv[@]}"; do
	    stripped_key=$(strip_id "$key")
		tag=$(extract_tag "$key")
		id=$(extract_id "$key")
		convergence_point=$(extract_convergence_point "$key")
    	paths=($(extract_paths "$key"))
	    file1_conv_temp[$stripped_key]=1
		file1_conv_tag[$stripped_key]=$tag
		file1_conv_id[$stripped_key]=$id
    	file1_conv_point[$stripped_key]=$convergence_point
    	file1_conv_paths[$stripped_key]="${paths[@]}"
	done

	for key in "${!file2_conv[@]}"; do
	    stripped_key=$(strip_id "$key")
		tag=$(extract_tag "$key")
		id=$(extract_id "$key")
		convergence_point=$(extract_convergence_point "$key")
    	paths=($(extract_paths "$key"))
	    file2_conv_temp[$stripped_key]=1
		file2_conv_tag[$stripped_key]=$tag
		file2_conv_id[$stripped_key]=$id
    	file2_conv_point[$stripped_key]=$convergence_point
    	file2_conv_paths[$stripped_key]="${paths[@]}"
	done

	{
	    if [ ${#file1_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file1_conv_temp[@]}"; do
	            if [[ -z ${file2_conv_temp[$key]} ]]; then
	                result="FAIL: only in "$FILE1""
	                id2="/"
					printf "%-40s %-40s %-40s %-40s\n" "${file1_conv_tag[$key]}" "${file1_conv_id[$key]}" "$id2" "$result"
	                echo "Convergence_Point: ${file1_conv_point[$key]}"
					paths1=(${file1_conv_paths[$key]})
	                format_paths paths1[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	    if [ ${#file2_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file2_conv_temp[@]}"; do
	            if [[ -z ${file1_conv_temp[$key]} ]]; then
	                result="FAIL: only in "$FILE2""
	                id1="/"
					printf "%-40s %-40s %-40s %-40s\n" "${file2_conv_tag[$key]}" "$id1" "${file2_conv_id[$key]}" "$result"
	                echo "Convergence_Point: ${file2_conv_point[$key]}"
					paths2=(${file2_conv_paths[$key]})
	                format_paths paths2[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	    if [ ${#file1_conv_temp[@]} -ne 0 ]; then
	        for key in "${!file1_conv_temp[@]}"; do
	            if [[ -n ${file2_conv_temp[$key]} ]]; then
	                result="PASS: both in 2 files"
	                id2=${file2_conv_id[$key]}
					printf "%-40s %-40s %-40s %-40s\n" "${file1_conv_tag[$key]}" "${file1_conv_id[$key]}" "$id2" "$result"
	            	echo "Convergence_Point: ${file1_conv_point[$key]}"
					paths1=(${file1_conv_paths[$key]})
	            	format_paths paths1[@]
	            	echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
	            fi
	        done
	    fi
	} >> "$RPT"

	###################################################################
	##                                                               ##
	##  Category 3: Ordinary Tags with Single SRC_PATH and DST_PATH  ##
	##                                                               ##
	###################################################################

	print_title_3 >> "$RPT"
	for key1 in "${!file1_ordinary[@]}"; do
	    value_1=(${key1})
	    key_hash="${value_1[0]},${value_1[2]},${value_1[3]}"
	    file1_ordinary_temp[$key_hash]=1
	    file1_ordinary_id[$key_hash]=${value_1[1]}
	done

	for key2 in "${!file2_ordinary[@]}"; do
		value_2=(${key2})
	    key_hash="${value_2[0]},${value_2[2]},${value_2[3]}"
	    file2_ordinary_temp[$key_hash]=1
	    file2_ordinary_id[$key_hash]=${value_2[1]}
	done

	for key1 in "${!file1_ordinary[@]}"; do
	    value_1=(${key1})
	    key_hash="${value_1[0]},${value_1[2]},${value_1[3]}"
	    if [[ -n "${file2_ordinary_temp[$key_hash]}" ]]; then
	        ordinary_output_pass+=("${value_1[0]}" "${value_1[1]}" "${file2_ordinary_id[$key_hash]}" "PASS: both in 2 files" "${value_1[2]}" "${value_1[3]}")
	    else
	        ordinary_output_fail1+=("${value_1[0]}" "${value_1[1]}" "/" "FAIL: only in "$FILE1"" "${value_1[2]}" "${value_1[3]}")
	    fi
	done

	for key2 in "${!file2_ordinary[@]}"; do
		value_2=(${key2})
	    key_hash="${value_2[0]},${value_2[2]},${value_2[3]}"
	    if [[ -z "${file1_ordinary_temp[$key_hash]}" ]]; then
	        ordinary_output_fail2+=("${value_2[0]}" "/" "${value_2[1]}" "FAIL: only in "$FILE2"" "${value_2[2]}" "${value_2[3]}")
	    fi
	done

	if [ ${#ordinary_output_fail1[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_fail1[@]}" >> "$RPT"
	fi
	if [ ${#ordinary_output_fail2[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_fail2[@]}" >> "$RPT"
	fi
	if [ ${#ordinary_output_pass[@]} -ne 0 ]; then
		printf "%-40s %-40s %-40s %-40s\nSRC_PATH: %s\nDST_PATH: %s\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n" "${ordinary_output_pass[@]}" >> "$RPT"
	fi
fi

################################################# Part 4 #################################################

#########################  #########################  #########################  #########################
##                     ##  ##                     ##  ##                     ##  ##                     ##
##  calculate runtime  ##  ##  calculate runtime  ##  ##  calculate runtime  ##  ##  calculate runtime  ##
##                     ##  ##                     ##  ##                     ##  ##                     ##
#########################  #########################  #########################  #########################

end_time=$(date +%s)
diff_time=$((end_time-start_time))

hours=$((diff_time/3600))
mins=$(((diff_time-3600*hours)/60))
secs=$((diff_time-3600*hours-60*mins))

hour_string="hour"
min_string="minute"
sec_string="second"

if [[ "$hours" -gt 1 ]]; then
    hour_string="hours"
fi
if [[ "$mins" -gt 1 ]]; then
    min_string="minutes"
fi
if [[ "$secs" -gt 1 ]]; then
    sec_string="seconds"
fi

echo "Total runtime: $hours $hour_string $mins $min_string $secs $sec_string."
