#!/bin/sh
#
#Allows for script-based management of Apache modules and other configuration files
#Inspired by "a2enmod" and co. on Debian distributions
#
#Example usage:
#	apache-config.sh enable module rewrite
#	apache-config.sh install


#Exit immediately if any of the commands in this script fail
set -e

#Check for existence of Apache in the current PATH
if which httpd 1>/dev/null 2>&1
then
	#If present, parse the config options to get the path to the config directory
	configRoot="$(httpd -V | grep "SERVER_CONFIG_FILE" | awk '{print $2}' | sed -e 's#^SERVER_CONFIG_FILE="##' -e 's#/httpd.conf"$##')"

else
	#If not present, show an error message and exit with failure
	cat 1>&2 <<-EOF
		This script requires Apache ('httpd') to be present in the current PATH
		Please install Apache, or link it so it can be found in PATH
	
	EOF
	
	exit 1
fi


#Set a bunch of variables to keep from repeating values, for easy changing if needed
version="0_1"
environmentVariable="VENDOR_MPLEWIS_CONFIG_CONTROLLER"

configPath="other"
configDirectory="${configRoot}/${configPath}"
fileSuffix="conf"
controllerFileName="config-controller.${fileSuffix}"
availablePath="available"
enabledPath="enabled"

module="module"
config="config"
site="site"
cleanup="cleanup"


#Initialize a variable for the loudness of the script
quiet=false


#Store a function for the usage message for easy use later
printUsageMessage()
{
	cat <<-EOF
		Install:    ${0} [--quiet] install
		Usage:      ${0} [--quiet] (enable | disable) (${module} | ${config} | ${site} | ${cleanup}) {NAME} [{NAME}...]
		Help:       ${0} --help [--verbose]
		
	EOF
}

#Print a message saying Apache needs to be restarted
printApacheRestart()
{
	if [ "${quiet}" != "true" ]
	then
		cat <<-EOF
		${1} complete. You will need to restart Apache for the changes to take effect.
		
		EOF
	fi
}

#Print status messages only if output is not silenced
printStatus()
{
	if [ "${quiet}" != "true" ]
	then
		printf "%s" "${1}"
	fi
}

#Print status messages only if output is not silenced
echoStatus()
{
	if [ "${quiet}" != "true" ]
	then
		echo "${1}"
	fi
}


#If there are 1 or 2 arguments, this is either a help call or an install call (or an error)
if [ "${#}" -gt 0 ] && [ "${#}" -le 2 ]
then
	#Print help message to stdout and exit if the help flag is present
	if [ "${1}" = "--help" ]
	then
		cat <<-EOF
			apache-config:  allows for script-based management of Apache modules and other configuration files
			                inspired by "a2enmod" and co. on Debian distributions
			
		EOF
		
		printUsageMessage
		
		cat <<-EOF
			All paths listed below are relative to the following path:
			    ${configRoot}/${configDirectory}
			
			Example usage:
			    ${0} enable ${module} rewrite
			
			Arguments:
			    "--quiet":  silence all messages about the script's status
			
			Commands:
			    "install":  creates the needed files, directories, and configuration directives needed for this script
			    "enable":   enables the specified config file type and name
			    "disable":  disables the specified config file type and name
			    
			Supported types:
			    "${module}":    files for loading and configuring an Apache module
			                        stored in the "${module}s-${availablePath}" directory
			    "${config}":    generic Apache configuration files
			                        stored in the "${config}s-${availablePath}" directory
			    "${site}":      files for configuring a specific host or site
			                        stored in the "${site}s-${availablePath}" directory
			    "${cleanup}":   files for cleaning up after all other files have been included
			                        stored in the "${cleanup}s-${availablePath}" directory
			
		EOF
		
		
		#Print additional help messages when requested
		if [ "${#}" = "2" ] && [ "${2}" = "--verbose" ]
		then
			cat <<-EOF
				
				The various types of configuration files will be loaded in the following order:
				    ${module}s, ${config}s, ${site}s
				
				"${module}s" are intended to be Apache module loading and configuration directives, if the defaults must be changed
				"${config}s" are intended to be server-wide directives that should be set before any hosts or sites are loaded
				"${site}s" are intended to be configuration for hosts, virtual or otherwise
				"${cleanup}s" are intended to cleaning up after all other files have been included (such as unsetting macro definitions)
				
				Modules should be stored in (or symlinked into) "${module}s-${availablePath}"
				Configs should be stored in (or symlinked into) "${config}s-${availablePath}"
				Sites should be stored in (or symlinked into) "${site}s-${availablePath}"
				Cleanups should be stored in (or symlinked into) "${cleanup}s-${availablePath}"
				
				When a command is run for a specific configuration file, the given name is used to search for the specific file to use by appending ".${fileSuffix}"
				
				All enabled configuration will be symlinked into the corresponding "${enabledPath}" directory; for example, when running:
				    ${0} enable ${module} rewrite
				the file "${module}s-${availablePath}/rewrite.conf" will be symlinked into "${module}s-${enabledPath}/rewrite.conf"
				
				When disabling a configuration file, the link in "${enabledPath}" will be removed, but the original file will remain in the "${availablePath}" directory
				
				You should never modify the "*-${enabledPath}" directories directly, as anything in that directory can be deleted at any time
				
			EOF
		
		#Only display message indicating more help is available when not called for
		else
			cat <<-EOF
				Run "${0} --help --verbose" for more detailed information.
				
			EOF
		fi
		
		exit 0
	
	#Process the installation if requested
	elif [ "${1}" = "install" ] || [ "${2}" = "install" ]
	then
		if [ "${#}" = "2" ] && [ "${1}" = "--quiet" ]
		then
			quiet=true
		fi
		
		#Set variables for the files being output to
		httpdFile="${configRoot}/httpd.conf"
		controllerFile="${configDirectory}/${controllerFileName}"
		
		
		#Create the config directory if it doesn't exist
		printStatus "Creating directory '${configDirectory}'... "
		mkdir -p "${configDirectory}"
		
		echoStatus "done"
		
		
		#Add a version environment variable to prevent multiple versions from conflicting
		#This directive will be replaced every time an installation is performed
		printStatus "Adding/updating version environment variable in '${httpdFile}'... "
		defineDirective="Define ${environmentVariable}"
		
		if ! grep "${defineDirective}" "${httpdFile}" 1>/dev/null 2>&1
		then
			cat <<-EOF >> "${httpdFile}"
				
				
				# Do **NOT** delete this line; it is managed by apache-config and will be updated along with the script
				${defineDirective}_${version} 'true'
				
			EOF
			
			echoStatus "added"
		
		else
			sed -i '' -e "s/${defineDirective}_[0-9]*_[0-9]*/${defineDirective}_${version}/" "${httpdFile}"
			echoStatus "updated"
		fi
		
		
		#Add directive that includes the controller conf file to the main httpd.conf
		#There doesn't seem to be a better way to do this on a default config file, so an environment variable was added to prevent multiple blocks from executing simultaneously
		printStatus "Adding include statement to '${httpdFile}'... "
		
		if ! grep "reqenv('${environmentVariable}_${version}') == 'true'" "${httpdFile}" 1>/dev/null 2>&1
		then
			cat <<-EOF >> "${httpdFile}"
				
				<IfDefine ${environmentVariable}_${version}>
				    <IfDefine !${environmentVariable}>
				        Define ${environmentVariable} '${version}'
				        Include ${controllerFile}
				    </IfDefine>
				</IfDefine>
				
			EOF
			
			echoStatus "done"
		
		else
			echoStatus "already present"
		fi
		
		
		#Echo a top comment to the controller conf file warning users against editing this file
		echo "# Do **NOT** modify this file. It is managed by apache-config, and may be overwritten at any point" > "${controllerFile}"
		
		
		#Iterate through the config types, create the necessary directories, and include those directories in the controller file
		printStatus "Creating and installing configuration directories (if not already present)... "
		
		cat <<-EOF |
			${module}
			${config}
			${site}
			${cleanup}
		EOF
		{
			while read -r configType
			do
				configTypeDirectory="${configDirectory}/${configType}s"
				mkdir -p "${configTypeDirectory}-${availablePath}"
				mkdir -p "${configTypeDirectory}-${enabledPath}"
				
				echo "IncludeOptional ${configTypeDirectory}-${enabledPath}/*.${fileSuffix}" >> "${controllerFile}"
			done
		}
		
		echoStatus "done"
		
		
		#Print Apache restart message
		printApacheRestart "Installation"
		
		
		exit 0
	
	#Otherwise, the call is an error, so print a usage message and quit
	else
		printUsageMessage 1>&2
		exit 2
	fi

#Otherwise, the number of arguments is at least correct for a normal call, so start processing
else
	#Quiet the script if requested
	if [ "${1}" = "--quiet" ]
	then
		quiet=true
		shift
	fi
	
	
	#Validate the command given, either "enable" or "disable"
	method="${1}"
	if [ "${1}" != "enable" ] && [ "${1}" != "disable" ]
	then
		echo "Unrecognized command '${1}'" 1>&2
		printUsageMessage 1>&2
		exit 2
	fi
	
	shift
	
	
	#Validate the config type, one of the predefined types
	configType="${1}"
	if [ "${1}" != "${module}" ] && [ "${1}" != "${config}" ] && [ "${1}" != "${site}" ] && [ "${1}" != "${cleanup}" ]
	then
		echo "Unrecognized configuration type '${1}'" 1>&2
		printUsageMessage 1>&2
		exit 2
	fi
	
	shift
	
	
	#If, after shifting the variables, no names remain, fail in error
	if [ "${#}" -lt "1" ]
	then
		echo "No ${module}/${config}/${site}/${cleanup} names were provided" 1>&2
		printUsageMessage 1>&2
		
		exit 2
	fi
fi


#Set variable for the prefix to the available/enabled directories
directoryPrefix="${configDirectory}/${configType}s"


#If an enable was requested, link the files from the available directory into the enabled directory
if [ "${method}" = "enable" ]
then
	#Multiple config names can be provided, so shift through each argument and process each
	while [ "${#}" -gt "0" ]
	do
		#Set variables to each of the files
		fileName="${1}.${fileSuffix}"
		availableFile="${directoryPrefix}-${availablePath}/${fileName}"
		enabledFile="${directoryPrefix}-${enabledPath}/${fileName}"
		
		#Check if the file is actually available, fail if not
		if [ ! -f "${availableFile}" ]
		then
			echo "File '${availableFile}' does not exist" 1>&2
			exit 3
		
		#Check if the file is already enabled, fail if so
		elif [ -e "${enabledFile}" ]
		then
			echo "File '${enabledFile}' is already enabled (symlinked into the '${configType}-${enabledPath}' directory)" 1>&2
			exit 4
		fi
		
		
		#Symlink the config file from the available directory into the enabled directory
		printStatus "Enabling ${configType} '${1}'... "
		
		if ln -s "../${configType}s-${availablePath}/${fileName}" "${enabledFile}"
		then
			echoStatus "done"
		
		else
			echoStatus "ERROR"
		fi
		
		
		shift
	done
	
	#Print Apache restart message
	printApacheRestart "Enabling"
	

#If an enable was requested, unlink the files from the enabled directory
elif [ "${method}" = "disable" ]
then
	#Multiple config names can be provided, so shift through each argument and process each
	while [ "${#}" -gt "0" ]
	do
		#Set variables for the file to be unlinked
		fileName="${1}.${fileSuffix}"
		file="${directoryPrefix}-${enabledPath}/${fileName}"
		
		#Check to see if the symlink actually exists in the enabled directory, fail if not
		if [ ! -L "${file}" ]
		then
			echo "File '${file}' does not exist" 1>&2
			exit 3
		fi
		
		
		#Remove the symlink file pointing at the available directory
		printStatus "Disabling ${configType} '${1}'... "
		
		if rm "${directoryPrefix}-${enabledPath}/${fileName}"
		then
			echoStatus "done"
		
		else
			echoStatus "ERROR"
		fi
		
		shift
	done
	
	#Print Apache restart message
	printApacheRestart "Disabling"
	

#Provide a final catch block to prevent silent failure
else
	echo "Uhh, this is embarassing. There shouldn't be a way for this message to trigger, but somehow you've gotten here anyway. Please report this as an issue on GitHub so it can be fixed!" 1>&2
	exit 4
fi


exit 0
