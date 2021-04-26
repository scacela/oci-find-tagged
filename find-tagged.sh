#!/usr/bin/env bash

init_vars()
{
uname_out="$(uname -s)"
case "${uname_out}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="Unknown OS:${uname_out}"
esac

# colors for messages
if [ "${machine}" == "Mac" ]; then
	color_none="\033[0m"
	color_black="\033[0;30m"
	color_red="\033[0;31m"
	color_green="\033[0;32m"
	color_yellow="\033[0;33m"
	color_blue="\033[0;34m"
	color_magenta="\033[0;35m"
	color_cyan="\033[0;36m"
	color_light_gray="\033[0;37m"
else
	color_none="\e[0m"
	color_black="\e[30m"
	color_red="\e[31m"
	color_green="\e[32m"
	color_yellow="\e[33m"
	color_blue="\e[34m"
	color_magenta="\e[35m"
	color_cyan="\e[36m"
	color_light_gray="\e[37m"
fi

# arrays for parameter handling
array_compartment_ocids=()
array_regions=()
array_oci_regions+=($(oci iam region list | jq .data[].name | sed "s|\"||g"))
array_namespaces=()
array_keys=()
array_values=()
}

# check whether dependencies are installed, error message and exit if not installed
check_dependencies()
{
jq --help &> /dev/null;
if [ $? -ne 0 ]; then
	str_message=$(cat <<- EOF
	${color_red}Error:${color_none} Dependency missing: please install jq. You can verify your install with ${color_helpful}jq --help${color_none}.\n
	Please refer to ${color_helpful}https://stedolan.github.io/jq/download/${color_none} for download instructions.\n
	EOF
	)
	echo -e "${str_message}"
	exit
fi

oci &> /dev/null;
if [ $? -ne 0 ]; then
	str_message=$(cat <<- EOF
	\n${color_red}Error:${color_none} Dependency missing: please install oci-cli. You can verify your install with ${color_helpful}oci${color_none}.\n
	Please refer to ${color_helpful}https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm${color_none} for download instructions.\n
	EOF
	)
	echo -e "${str_message}"
	exit
fi
}

# print options, for help or as a result of a user error
show_options()
{
local options_str=""
options_str=$(cat <<- EOF

Options:

Flag                          Description                                       Usage

-c          Compartment name(s) and/or ocid(s). If none specified, all          $0 -c samuel
             compartments are searched. If the string does not have ocid
             format, it is assumed to be the compartment name. If the
             name is not unique, the first value returned from an internal
             command will be used.
-r          Region identifier(s). If none specified, all regions are searched.  $0 -r us-ashburn-1 us-phoenix-1
-h          Show options.                                                       $0 -h
-n          Tag namespace                                                       $0 -n Oracle-Tag
-k          Tag key                                                             $0 -k CreatedBy
-v          Tag value                                                           $0 -v samuel

Sample run:

$ $0 -n Oracle-Tag -k CreatedBy -v samuel -c samuel -r us-ashburn-1 us-phoenix-1

EOF
)
echo -e "${options_str}\n" # in quotes to prevent field splitting in echo from eating spaces
exit
}

# search all compartments
search_all_compartments() {
array_compartment_ocids+=($(oci iam compartment list --compartment-id-in-subtree true --all | jq .data[].id | sed 's/\"//g'));
}

# search all regions
search_all_regions() {
array_regions+=($(oci iam region list | jq .data[].name | sed 's/\"//g'))
}

handle_custom_params()
{
while test $# -gt 0; do
	case $1 in
		-c)
			firstpass=true
			if test $# -eq 1; then search_all_compartments; fi
			while test $# -gt 1; do
				oci iam compartment get --compartment-id $2 &> /dev/null; # silence output (redirect stdout and stderr to null
				# if command successful i.e. if compartment exists and is accessible
				if [ $? -eq 0 ]; then
					# success
					array_compartment_ocids+=($2)
				else
					case $2 in
						-*)
							if [ "${firstpass}" = true ]; then search_all_compartments; echo "all compartments"; fi
							break # break escapes from the while loop you are in
							;;
						*)
							array_compartment_ocids+=($(export name="$2"; oci iam compartment list --compartment-id-in-subtree true --all | jq '.data[] | select(.name|contains(env.name)).id + "    " + .name' | sed 's/\"//g' | head -1 | awk '{print $1}'))
							# str_message=$(cat <<- EOF
							# \n${color_red}Error:${color_none}  $2: Not authorized to access compartment, or compartment not found.\n
							# EOF
							# )
							# echo -e "${str_message}"
							# exit
					esac
				fi
				shift
				firstpass=false
			done
			shift
			;;
		-h)
			show_options
			;;
		-n)
			if test $# -eq 1; then
				str_message=$(cat <<- EOF
				\n${color_red}Error:${color_none}  No value was passed to ${color_yellow}$1${color_none} flag.\n
				EOF
				)
				echo -e "${str_message}"
				show_options
			fi
			while test $# -gt 1; do
				if [[ "$2" =~ ^- ]]; then # check if param is a flag
					break
				else
					# success
					is_using_param_name=true
					array_namespaces+=("$2")
				fi
				shift
			done
			shift
			;;
		-k)
			if test $# -eq 1; then
				str_message=$(cat <<- EOF
				\n${color_red}Error:${color_none}  No value was passed to ${color_yellow}$1${color_none} flag.\n
				EOF
				)
				echo -e "${str_message}"
				show_options
			fi
			while test $# -gt 1; do
				if [[ "$2" =~ ^- ]]; then # check if param is a flag
					break
				else
					# success
					is_using_param_name=true
					array_keys+=("$2")
				fi
				shift
			done
			shift
			;;
		-v)
			if test $# -eq 1; then
				str_message=$(cat <<- EOF
				\n${color_red}Error:${color_none}  No value was passed to ${color_yellow}$1${color_none} flag.\n
				EOF
				)
				echo -e "${str_message}"
				show_options
			fi
			while test $# -gt 1; do
				if [[ "$2" =~ ^- ]]; then # check if param is a flag
					break
				else
					# success
					is_using_param_name=true
					array_values+=("$2")
				fi
				shift
			done
			shift
			;;
		-r)
			firstpass=true
			if test $# -eq 1; then search_all_regions; fi
			while test $# -gt 1; do
				# check that region is in list of oci regions
				if [[ " ${array_oci_regions[@]} " =~ " $2 " ]]; then
					# success
					array_regions+=($2)
				elif [[ "$2" =~ ^- ]]; then # check if param is a flag
					if [ "${firstpass}" = true ]; then search_all_regions; fi
					break
				else
					str_message=$(cat <<- EOF
					\n${color_red}Error:${color_none}  ${color_yellow}$2${color_none}: Not a valid region. Valid regions are:\n
					$(for oci_region in "${array_oci_regions[@]}"; do echo "${oci_region}"; done)
					EOF
					)
					echo -e "${str_message}"
					exit
				fi
				shift
				firstpass=false
			done
			shift
			;;
		*)
			str_message=$(cat <<- EOF
			\n${color_red}Error:${color_none} ${color_yellow}$1${color_none} is not a valid option.\n
			EOF
			)
			echo -e "${str_message}"
			show_options
			;;
	esac
done
}

handle_valid_custom_params()
{

# e.g. search <compartment ocid 1> and regions us-ashburn-1, us-phoenix-1 and ap-osaka-1 for compute instances that were created by someone whose name contains the string: samuel
# colors
color_namespace=${color_blue}
color_key=${color_blue}
color_value=${color_blue}
color_region=${color_cyan}
color_compartment=${color_magenta}
color_alternating=${color_yellow}
color_reset=${color_none}

# if array empty, i.e. if option not used, then search all
if [ ${#array_compartment_ocids[@]} -eq 0 ]; then search_all_compartments; fi
if [ ${#array_regions[@]} -eq 0 ]; then search_all_regions; fi

# troubleshooting
# echo "tag namespaces:"; for i in "${array_namespaces}"; do echo $i; done
# echo "tag keys:"; for i in "${array_keys}"; do echo $i; done
# echo "tag values:"; for i in "${array_values}"; do echo $i; done
# echo "compartment ocids:"; for i in "${array_compartment_ocids}"; do echo $i; done
# echo "regions:"; for i in "${array_regions}"; do echo $i; done

# for each region
for tag_namespace in "${array_namespaces[@]}"; do
echo -e "${color_namespace}${tag_namespace}${color_reset}" # print the tag namespace

# for each region
for tag_key in "${array_keys[@]}"; do
echo -e "${color_key}${tag_key}${color_reset}" # print the tag key

# for each region
for tag_value in "${array_values[@]}"; do
export tag_value=${tag_value} # store as environment variable so jq can access it
echo -e "${color_value}${tag_value}${color_reset}" # print the tag value

# for each compartment
for compartment_ocid in "${array_compartment_ocids[@]}"; do
# get the name of the current compartment and print it along with the compartment id
compartment_name=$(oci iam compartment get --compartment-id ${compartment_ocid} | jq .data.name | sed 's/\"//g')
echo -e "${color_compartment}${compartment_ocid}    ${compartment_name}${color_reset}"; # print the compartment id and name

# for each region
for region in "${array_regions[@]}"; do
echo -e "${color_region}${region}${color_reset}" # print the region identifier

compute_list=()
# read in each line of output from a command, where each line contains a compute id and compute display name
while IFS= read -r line; do
compute_list+=("${line}") # store each line as an array element
done < <( oci compute --region ${region} instance list --compartment-id ${compartment_ocid} | jq --arg tag_namespace "${tag_namespace}" --arg tag_key "${tag_key}" '.data[] | select(."defined-tags" != null ) | select(."defined-tags"[$tag_namespace] != null ) | select(."defined-tags"[$tag_namespace][$tag_key] |contains(env.tag_value)).id + "    " + ."display-name"' | sed 's/\"//g')
# for each array element, i.e. each line, print the line with alternating colored text
for ((c=0;c<${#compute_list[@]};c++)); do
if [ $(($c%2)) -eq 0 ]; then echo -en "${color_alternating}"; fi; echo -e "${compute_list[$c]}${color_reset}"

done;done;done;
done;done;done;
}


main()
{
init_vars
check_dependencies
handle_custom_params "$@"
handle_valid_custom_params
}

main "$@"