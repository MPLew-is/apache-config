#!/bin/sh
#
#Updates the homebrew formula file for this project when called
#
#Example usage:
#	./scripts/deploy.sh

#Exit immediately if any of the commands in this script fail
set -e


projectHost="github.com"
projectUser="MPLew-is"
projectRepository="apache-config"

tapHost="${projectHost}"
tapUser="${projectUser}"
tapRepository="homebrew-experimental"
tapFormula="apache-config"


#Get current tagged release
tag="$(git describe --tags)"


#Change into the home directory
cd ../


#Download the tagged release's archive
repositoryPrefix="https://${projectHost}/${projectUser}/${projectRepository}/archive"
archiveURL="${repositoryPrefix}/${tag}.tar.gz"
wget --output-document="archive.tar.gz" "${archiveURL}"

#Get the archive's hash
tagHash="$(shasum --portable --algorithm 256 "archive.tar.gz" | awk '{print $1}')"

#Remove the archive
rm "archive.tar.gz"


#If the tap has not been cached, clone it
if [ ! -d "brew-tap" ]
then
	git clone "git@${tapHost}:${tapUser}/${tapRepository}.git" "brew-tap"
fi

#Change directories into the tap, then initialize git settings and make sure it's up-to-date
cd "brew-tap/Formula"
git config user.name "homebrew-experimental (CircleCI)"
git config user.email "mike@mplew.is"

git fetch
git pull


#Replace the old archive URL with the new archive URL
sed -i'' -e "s#url \"${repositoryPrefix}/[^/]*.tar.gz\"\$#url \"${archiveURL}\"#g" "${tapFormula}.rb"

#Repalce the old hash with the new hash
sed -i'' -e "s/sha256 \"[a-f0-9]*\"\$/sha256 \"${tagHash}\"/g" "${tapFormula}.rb"

#Commit and push the auto-deployment
git commit --all --message="Upgrade '${tapFormula}' to '${tag}' (CircleCI auto-deploy)"
git push


exit 0
