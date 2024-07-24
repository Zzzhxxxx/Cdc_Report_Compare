#!/bin/bash

print_help() {
	echo "-----------------------------------------------------------------------------------------------------------------------------------"
	echo ""
	echo "    Please use the script in the correct way:"
	echo "        /share/project/crete/dev/han.zhang/scripts/cmp.sh FILE1=<file1_path> FILE2=<file2_path> RPT=<report_path>* MODE=<mode>*"
	echo ""
	echo "    Parameters Description:"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo "        | Parameters | Description                                        | Required or Optional | Default                  |"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo "        | FILE1      | The first file to be compared                      | Required             | N/A                      |"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo "        | FILE2      | The second file to be compared                     | Required             | N/A                      |"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo "        | RPT        | The comparison result will be printed to this file | Optional             | ./cdc_report_compare.rpt |"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo "        | MODE       | Available modes are sam_waive and netlist_rtl      | Optional             | sam_waive                |"
	echo "        |------------|----------------------------------------------------|----------------------|--------------------------|"
	echo ""
	echo "    Notes:"
	echo "        - The order of these parameters is arbitrary."
	echo "        - <file1_path>, <file2_path>, <report_path> should be file path rather than directory path."
    echo "        - About the two modes:"
	echo "            - The mode netlist_rtl features setup treatment of ports in the netlist while the other mode doesn't."
	echo "            - The waived cases of netlist_rtl are involved in the comparison while those of sam_model are not."
	echo "        - If you have other questions, please contact "$Script_Owner" directly."
	echo ""
	echo "-----------------------------------------------------------------------------------------------------------------------------------"
	exit 1
}

print_boxed_title() {
    local title="$1"
    local length=${#title}
    local border=$(printf '%*s' "$length" '' | tr ' ' '#')
    local border1=$(printf '%*s' "$length" '')
    echo ""
    echo "####${border}####"
    echo "##  ${border1}  ##"
    echo "##  ${title}  ##"
    echo "##  ${border1}  ##"
    echo "####${border}####"
    echo ""
}

print_title_1() {
	print_boxed_title "Category 1: Tags named SETUP* without SRC_PATH or DST_PATH"
	printf "%-40s %-40s %-40s %-40s\n" "Tag" "Number in "$FILE1"" "Number in "$FILE2"" "Result"
	printf '%*s\n' 160 | tr ' ' '*'
	printf '%*s\n' 160 | tr ' ' '*'
}

print_title_2() {
	print_boxed_title "Category 2: Tags named *CONV* with Multiple SRC_PATHs and DST_PATHs"
	printf "%-40s %-40s %-40s %-40s\n" "Tag" "ID in "$FILE1"" "ID in "$FILE2"" "Result"
	printf '%*s\n' 160 | tr ' ' '*'
	printf '%*s\n' 160 | tr ' ' '*'
}

print_title_3() {
	print_boxed_title "Category 3: Ordinary Tags with Single SRC_PATH and DST_PATH"
	printf "%-40s %-40s %-40s %-40s\n" "Tag" "ID in "$FILE1"" "ID in "$FILE2"" "Result"
	printf '%*s\n' 160 | tr ' ' '*'
	printf '%*s\n' 160 | tr ' ' '*'
}

strip_id() {
    echo "$1" | awk '{for (i=1; i<=NF; i++) if (i != 2) printf "%s ", $i; print ""}'
}

extract_tag() {
    echo "$1" | awk '{print $1}'
}

extract_id() {
    echo "$1" | awk '{print $2}'
}

extract_convergence_point() {
    echo "$1" | awk '{print $3}'
}

format_paths() {
    local paths=("${!1}")
	local group_number=1
    for ((i = 0; i < ${#paths[@]}; i+=2)); do
        echo "SRC_PATH"$group_number": ${paths[i]}"
        echo "DST_PATH"$group_number": ${paths[i+1]}"
		((group_number++))
    done
}

extract_paths() {
    local key="$1"
    local paths=()
    IFS=' ' read -ra parts <<< "$key"
    for ((i = 3; i < ${#parts[@]}; i+=2)); do
        paths+=("${parts[i]}" "${parts[i+1]}")
    done
    echo "${paths[@]}"
}

deal_with_path() {
    local path="$1"
    local number1=""
    local number2=""
    if [[ $path =~ (_reg(_([0-9]+)_)(_([0-9]+)_)?\/Q(N)?)$ ]]; then
        number1=${BASH_REMATCH[3]}
        number2=${BASH_REMATCH[5]}
        if [[ -z "$number2" ]]; then
            path=${path/_reg_$number1*_\/Q*/\[$number1\]}
        else
            path=${path/_reg_$number1\_\_$number2*_\/Q*/\[$number1\]\[$number2\]}
        fi
        number1=""
        number2=""
    fi
    while [[ $path =~ (.+)\[[0-9]+\]$ ]]; do
        path=${BASH_REMATCH[1]}
    done
    echo "$path"
}
