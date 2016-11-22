#!/bin/bash
# 2016-11-18_13_08_10
# 

cat_accepted_args()
{
# Here is where accepted arguments are stored. Add one here and modify the caseblocks as needed to expose a value.
# No whitespace allowed in argument names.
cat << _EOF_
COUNT : Start outputting files with filename number COUNT+1 .
DIGITS : Minimum number of digits out of which to assign filename numbers.
_ROOTDIR : Directory in which to make out and tmp directories. 
REMOTE_PREFIX_IMAGE : URL to prefix to found images. Useful for capturing those pesky relative pathnames.
REMOTE_PREFIX_PAGE : URL to prefix to the frontend pages being scraped. Again, useful for pesky relative pathnames.
LOCAL_PREFIX : Prefix to assign to outputted files. This is in front of the assigned number.
WEBPAGE : Page on which to start scraping. Importantly, this is NOT prefixed by REMOTE_PREFIX_PAGE.
REGEX_IMAGE_LINK : GNU ERE sed script to find images. Is triggered only on lines which match REGEX_IMAGE_SEARCH. Backreferences are your friend.
REGEX_IMAGE_SEARCH : GNU ERE sed address to find lines containing webcomic pages. Triggers sed to use REGEX_IMAGE_LINK. Can have an address range, insert '\@,\@' in between desired regexes to trigger. 
REGEX_NEXT_LINK : As REGEX_IMAGE_LINK; except finds the next page to scrape.
REGEX_NEXT_SEARCH : As REGEX_IMAGE_SEARCH; except finds the line containing the next page to scrape.
KNOWN_END : Stop when the scraper would walk off of this URL. If using relative pathnames (see REMOTE_PREFIX_* arguments) then ensure this argument contains only that which would be found in the HTML code.
USER_AGENT : Optional. User agent to feed cURL to get around unauthorized client errors. Those are annoying. Defaults to \'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0\'
SLEEPTIME_IMAGE : Time in seconds to wait until next execution of image scraping. Useful for not overloading a given server.
SLEEPTIME_PAGE : As SLEEPTIME_IMAGE, except for scraping the next webpage.
CURL_RATELIMIT : Optional. Limit cURL's transfer rate per instance. Useful if one needs to use their internet connection for other activities whilst scraping.
MD5CHECK : Optional. If downloaded image matches the hashes of previously-downloaded images, then discard the current image and go on to the next one.
_EOF_
}

setup_dirs()
{
#make dirs if needed and set directory vars
#called during argparse, ensure _ROOTDIR is specified prior to any REGEX arguments.

for OUTPUT in tmp out;
	do
		if ! [ -d "${_ROOTDIR}/${OUTPUT}" ]; 
			then
				mkdir -p "${_ROOTDIR}/${OUTPUT}"
		fi	
#		lower=$(echo ${OUTPUT} | sed -rn 's@.*@\L&@p')
		upper=$(echo ${OUTPUT} | sed -rn 's@.*@\U&@p')
		export _${upper}DIR=${_ROOTDIR}/${OUTPUT}
done
}
argparse()
{

if [ "$(echo $@ | grep -iE -e ' --help | -h | /\? ')" ];
	then
		echo Accepted arguments:
		cat_accepted_args | sed 's@.*@&\n@'
		echo All REGEX\* arguments really quite should be encased in single quotes \' regex \' to prevent shell interpretation.
		exit
fi


ACCEPTED_ARGUMENTS=$(cat_accepted_args | sed -rn ':a;N;$!ba;:b;s@[ \t]*:[^\n]+\n?@\n@;tb;s@\n@,@g;s@(.*),$@\1@p')

while [ "${1+defined}" ]; 
	do

	ARGNAME=$(echo ${1} | cut -d= -f 1)
	ARGVAL="$(echo ${1} | sed -r 's@[^=]+=@@')"

	for OUTPUT in $(echo ${ACCEPTED_ARGUMENTS} | sed 's@,@ @g');
		do
			if  [ "${ARGNAME}" = "${OUTPUT}" ];
				then
					case ${OUTPUT} in
						_ROOTDIR)
							export _ROOTDIR="${ARGVAL}"
							setup_dirs "${!OUTPUT}"
							;;
						REGEX*)
							echo "${ARGVAL}" > "${_TMPDIR}/${OUTPUT}.cat"
							;;
						*)
							export ${OUTPUT}=${ARGVAL}
							;;
					esac
			fi
	done


if [ "${2}EMPTY" = "EMPTY" ]; 
	then
		break
	else
		shift
fi

done

# if not defined, setup default vars
# uses bash expansion trickery, see http://wiki.bash-hackers.org/syntax/pe under 'Use a default value' for more info
for OUTPUT in $(echo ${ACCEPTED_ARGUMENTS} | sed 's@,@ @g');
	do
		case ${OUTPUT} in
			#HAVE DEFAULTS
			DIGITS)
				DIGITS=${DIGITS:-4}
				;;
			_ROOTDIR)
				_ROOTDIR=${_ROOTDIR:-$PWD}
				;;
			LOCAL_PREFIX)
				LOCAL_PREFIX=${LOCAL_PREFIX:-comic_}
				;;
			#REQUIRED
			REMOTE_PREFIX_IMAGE|REMOTE_PREFIX_PAGE|REGEX_IMAGE_LINK|REGEX_IMAGE_SEARCH|REGEX_NEXT_LINK|REGEX_NEXT_SEARCH|WEBPAGE)

				if  [ "${!OUTPUT}" = "NULL" ] ; 
					then
						echo Parameter ${OUTPUT} has been passed as NULL, wiping...
						export ${OUTPUT}=
						return 2
				fi

				
				if ! [ "$?" = "2" ];
					then
						if  [ "${!OUTPUT:-ERROR}" = "ERROR" ] ; 
							then
								echo Parameter ${OUTPUT} has no default value, please define in arguments before retrying. Try "$0" --help .
								export NODEF=1
								return 1
						fi
				fi
				;;
	esac
done

if ! [ ${NODEF:-0} = 0 ]
	then
		echo A required argument is undefined, so operation cannot continue. Exiting with error 50.
		exit 50	
fi
}

init_vars()
{
EXITSCRIPT=0
#init after dirsetup

IMAGECOUNT=${COUNT:-$(ls "${_OUTDIR}" | sed -rn "$ {s@${LOCAL_PREFIX}0+([0-9]+)\..*@\1@;teof;s@.*@0@;:eof;p}")}

SLEEPTIME_PAGE=${SLEEPTIME_PAGE:-1}
SLEEPTIME_IMAGE=${SLEEPTIME_IMAGE:-1}

CURL_RATELIMIT=${CURL_RATELIMIT:-170K}

CURL_ARGS="-A ${USER_AGENT:-\'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0\'} -L --limit-rate ${CURL_RATELIMIT}"

}

#sed_REGEX* fed to sed via -f <(funcname)
#heredocs and process substitution are useful things

sed_REGEX()
{
cat << _EOF_
\@$(cat "${_TMPDIR}/REGEX_${1^^}_SEARCH.cat")@{$(cat "${_TMPDIR}/REGEX_${1^^}_LINK.cat")}
_EOF_
}

#feed save_images "${_TMPDIR}/webpage.html"
save_images()
{
echo function save_images
for IMAGELINK in $(sed -rn -f <(sed_REGEX IMAGE) "${1}");
	do
		IMAGECOUNT=$((${IMAGECOUNT:-0}+1))
		IMAGENAME=$(echo ${IMAGECOUNT} | sed -rn "s@.*@000000000000000000000000000000&@;s@0*(0[0-9]{${DIGITS},})\$@\1@p")
#IMAGEEXT being defined without prevention of extra characters is a bad thing. if you can't find an extension from the link, then don't bother with it
# also eliminate trailing slashs, including any pathnames afterwards.
# note to dev: needs a better regex.
		IMAGEEXT=$(echo ${IMAGELINK} | sed -n 's@.*\.@@p')

		echo debug save_images imagelink is "${IMAGELINK}"

		if [ "${MD5CHECK:-false}" = "TRUE" ] ;
			then

				curl "${CURL_ARGS}" "${REMOTE_PREFIX_IMAGE}${IMAGELINK}"  2>/dev/null | tee "${_OUTDIR}/${LOCAL_PREFIX}${IMAGENAME}.${IMAGEEXT:-needsparsing}" | md5sum - | sed 's@\([0-9a-f]\+\).*@\1@' | tee "${_TMPDIR}/thismd5.cat" | [ "$(grep -v -f <(echo ${MD5STORAGE[@]:-NOSUMS} | tr ' ' '\n'))HAVEFILE" == "HAVEFILE" ]

#if we have the file, as determined by the md5sum of the curled image, then delete the new iteration thereof, otherwise add md5 to array for next iteration
#teeing the sedded md5 to a file to cat later saves computation time

			if [ "$?" = "0" ];
				then
					rm -f "${_OUTDIR}/${LOCAL_PREFIX}${IMAGENAME}.${IMAGEEXT:-needsparsing}"
					IMAGECOUNT=$((${IMAGECOUNT}-1))
				else
					MD5COUNT=$((${#MD5STORAGE[@]:-1}+1))
					MD5STORAGE[${MD5COUNT}]=$(cat "${_TMPDIR}/thismd5.cat")
			fi
		else
			curl "${CURL_ARGS}" "${REMOTE_PREFIX_IMAGE}${IMAGELINK}" > "${_OUTDIR}/${LOCAL_PREFIX}${IMAGENAME}.${IMAGEEXT##/*:-needsparsing}" 2>/dev/null
		fi
		
		echo debug md5storage has "${#MD5STORAGE[@]}" items, latest is number "${MD5COUNT}" \""$(echo ${MD5STORAGE[@]} | sed 's@.* @@')"\"

		sleep ${SLEEPTIME_IMAGE}
done
}

#feed curl_page WEBPAGE
curl_page()
{
echo curling "${1}"
curl ${CURL_ARGS} "${1}" > "${_TMPDIR}/webpage.html" 2>/dev/null
save_images "${_TMPDIR}/webpage.html"
}

#begin script body

__main_loop__()
{
echo debug new iteration of __main_loop__
WEBPAGEERROR=${WEBPAGE}

	if [ "$(echo ${WEBPAGE} | grep -o ${KNOWN_END:-0})" = "${KNOWN_END:-1}" ];
		then
			echo found the known end!
			echo breaking out of here!
			EXITSCRIPT=1
			break
	fi


echo debug WEBPAGE=$(sed -rn -f <(sed_REGEX NEXT) "${_TMPDIR}/webpage.html" | uniq)

WEBPAGE=$(sed -rn -f <(sed_REGEX NEXT) "${_TMPDIR}/webpage.html" | uniq)

if [ "${WEBPAGE}ERROR" = "ERROR" ];
	then
		echo cannot find next page, breaking!
		echo was on "${WEBPAGEERROR}"
		echo "${WEBPAGEERROR}" > "${_TMPDIR}/continue_webpage.txt"
		break
fi

curl_page "${REMOTE_PREFIX_PAGE}${WEBPAGE}"

sleep ${SLEEPTIME_PAGE}

}

# exit_script handles the saving of configuration files, including the md5sum array if enabled, but also the current COUNT, WEBPAGE, etc.
exit_script()
{
echo function exit_script
#go save all the MD5s we currently have, only
echo "${MD5STORAGE[@]}" | tr ' ' '\n' > "${_TMPDIR}/md5storage.per"
echo Scraped "$(ls ${_OUTDIR} | wc -l)" images.
}
#begin scraping

argparse "$@"
init_vars  

#Begin script header

echo debug rootdir is "${_ROOTDIR}"
echo debug outdir is "${_OUTDIR}"
echo debug curlargs are "${CURL_ARGS}"

#init the webpage
curl ${CURL_ARGS} "${WEBPAGE}" > "${_TMPDIR}/webpage.html" 2>/dev/null

#get the first page
save_images "${_TMPDIR}/webpage.html"

while [ "${EXITSCRIPT:-0}" == "0" ];
	do	
		__main_loop__
done



#begin script footer
echo call exit_script to finish up.
exit_script



exit
