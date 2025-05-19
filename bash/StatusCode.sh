#!/bin/bash
#
# bash script to check for status code, size, redirected url and the Title for a list of domains or ips
#

# Script name and version
PRG=${0##*/}
VERSION="2024-08-19"

# Function to display script usage
Usage() {
	while read -r line; do
		printf "%b\n" "$line"
	done <<-EOF
		\r$PRG: Reads a list of Domains or IPs and retrieves status code, size, redirected URL, and Title.
		\r
		\rUsage: $PRG [options]
		\r
		\rDescription:
		\r  This script takes a list of domains or IPs as input and performs curl requests to gather information such as HTTP status code, response size, redirected URL, and the title of the webpage. It supports multithreading for faster processing and allows filtering results by status code and saving output to a file.
		\r
		\rOptions:
		\r      -l, --list         - List of Domains or IPs.
		\r      -t, --Threads      - Threads number (Default: 5).
		\r      -s, --status       - Display only The specified Status Code.
		\r      -o, --output       - The output file to save the results.
		\r      -p, --path         - To use a specific path ex(/robots.txt).
		\r      -n, --nocolor      - Displays the Status code without color.
		\r      -h, --help         - Displays this Informations and Exit.
		\r      -v, --version      - Displays The Version
		\rExample:
		\r      $PRG -l domains.txt -t 20 -o status.txt
		\r
	EOF
}

# Initialize variables
list=False
threads=5
status=False
out=False
color=True
path=False

# Parse command-line arguments
while [ -n "$1" ]; do
	case $1 in
		-l|--list)
			if [ -z "$2" ]; then
				printf "[-] -l/--list requires a file containing a list of Domains or IPs.\n"
				exit 1
			fi
			list=$2
			shift ;;
		-t|--threads)
			if [ -z "$2" ]; then
				printf "[-] -t/--threads requires a number of threads.\n"
				exit 1
			fi
			threads=$2
			shift ;;
		-s|--status)
			status=$2
			shift ;;
		-p|--path)
			if [ -z "$2" ]; then
				printf "[-] -p/--path requires a path (e.g., /robots.txt).\n"
				exit 1
			fi
			path=$2
			shift ;;
		-o|--output)
			if [ -z "$2" ]; then
				printf "[-] -o/--output requires a file to write the results to.\n"
				exit 1
			fi
			out=$2
			shift ;;
		-h|--help)
			Usage
			exit ;;
		-v|--version)
			printf "%s\n" "$VERSION"
			exit ;;
		-n|--nocolor)
			color=False;;
		*)
			printf "[-] Error: Unknown Option: %s\n" "$1"
			Usage; exit 1 ;;
	esac
	shift
done

# Function to perform the curl request and process results
mycurl() {
	path=$4
	status=$5
	if [[ "$path" != False && "$path" != "/"* ]]; then
		path="/"$path
	fi

	# Perform curl request to get status code, effective URL, size, and redirect URL
	result=$(curl -sk $1$path --connect-timeout 10 -w '%{http_code} %{url_effective} %{size_download} %{redirect_url}\n' -o /dev/null)
	# Perform curl request to get the title
	title=$(curl --connect-timeout 10 $1$path -so - | grep -iPo '(?<=<title>)(.*)(?=</title>)')
	out=$2

	# Apply color based on status code if color is enabled
	if [[ "$3" == True ]]; then
		if [[ "$result" == "2"* ]]; then
			cresult="\e[32m$result\e[0m"
		elif [[ "$result" == "3"* ]]; then
			cresult="\e[34m$result\e[0m"
		elif [[ "$result" == "4"* ]]; then
			cresult="\e[31m$result\e[0m"
		else
			cresult="$result" # No color for other status codes
		fi
	else
		cresult="$result"
	fi
	[[ "$status" == False ]] && echo -e "$cresult [$title]" && [ $out != False ] && echo "$result [$title]" >> $out || {
		[[ "$result" == "$status"* ]] && echo -e "$cresult [$title]"
		[ $out != False ] && echo "$result [$title]" >> $out
	}

}

# Main function to process the list of domains/IPs
main() {
	cat $list | xargs -I{} -P $threads bash -c "mycurl {} $out $color $path $status"
}

# Check if the list file is provided
if [ "$list" == False ]; then
	printf "[!] Argument -l/--list is Required!\n"
	Usage
	exit 1
else
	export -f mycurl # Export the function for xargs
	main
fi
