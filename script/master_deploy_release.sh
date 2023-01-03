#!/bin/bash
pushd .

########################### ENVIRONMENT VARIABLES #####################################
echo
echo "Determine environment variables..."

#environment variables:
git_repo_url=$(git remote get-url origin)
echo -e "\tgit_repo_url: ${git_repo_url}"
user_repo_id=$(echo "${git_repo_url}" | sed -E 's/https:\/\/\w*.\w*\///' | sed -E 's/\.git//')
echo -e "\tuser_repo_id: ${user_repo_id}"
pull_id=${3}
echo -e "\tpull_id: ${pull_id}"
git_pull_url="${git_repo_url}/pull/${pull_id}"
echo -e "\tgit_pull_url: ${git_pull_url}"

#config variables:
links="no-links" #do not post a link to diagram if present
git_branch_artifacts="artifacts"
git_base_branch_for_artifacts="master"
deployment_remote_name="deployment"


#secret variables:
git_username=${1}
git_access_token=${2}

########################### CHECK FOR PULL REQUEST #####################################
echo
echo "Check if this is a pull request:"
if [ "${pull_id}" -eq "${pull_id}" ] 2>/dev/null; then #always use single "[]" here so that "-eq" requires integers
	echo -e "\tThis is a pull request build. Script will stop here."
	echo -e "\tThis build is for pull request #${pull_id}."
	echo -e "\tAlso see: ${git_repo_url}/pull/${pull_id}"
	popd
	exit 0
else
	echo -e "\tThis is not a pull request build. Script will continue for deploying release PDF."
fi

########################### PULL REQUEST ONLY VARIABLES #####################################

#environment variables:
echo "Debug: Show git log history visually:"
git remote add deployment https://${git_username}:${git_access_token}@github.com/${user_repo_id}
echo git remote -v
git remote -v
echo git fetch --all
git fetch --all
echo git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} #--deepen=4 #Azure Pipelines per default fetches using '--depth=1'
git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} #--deepen=4 #Azure Pipelines per default fetches using '--depth=1'
echo git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} artifacts #--deepen=4 #Azure Pipelines per default fetches using '--depth=1'
git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} artifacts #--deepen=4 #Azure Pipelines per default fetches using '--depth=1'
echo git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} --deepen=4 #Azure Pipelines per default fetches using '--depth=1'
git fetch https://${git_username}:${git_access_token}@github.com/${user_repo_id} --deepen=4 #Azure Pipelines per default fetches using '--depth=1'
echo git log --graph --oneline --all
git log --graph --oneline --all
echo git branch --all
git branch --all
echo "Determine last git commit on current branch (should be = master):"
git_hash_last_commit=$(git rev-parse HEAD) # master branch commit
echo -e "\tgit_hash_last_commit: ${git_hash_last_commit}" #last commit on master branch

#config variables:
git_branch_for_ci_job="branch-ci-${git_hash_last_commit}"
artifact_dir="artifacts/latex/pdf/"
release_artifact_dir="artifacts/release/"
artifact_path="${artifact_dir}${git_hash_last_commit}.pdf"
release_artifact_path="${release_artifact_dir}script.pdf"

########################### CENTRAL EXIT POINT #####################################
git switch -c ${git_branch_for_ci_job} #switch to new branch pointing to current HEAD
quit(){
	echo "Exiting script with code ${1}"
	popd
	echo -e "\tTidy up working directory..."
	git add -u && git add *
	git status
	git reset --hard
	git checkout ${git_branch_for_ci_job}
	echo -e "\tTidy up working directory   ...DONE!"
	exit ${1}
}

########################### UPLOAD ARTIFACT #####################################
echo "Start uploading pdf build artifact..."
LEFT_TRIES=10
while true; do
	echo -e "\tCheckout branch ${git_branch_artifacts}"
	(git fetch ${deployment_remote_name} && git checkout -b ${git_branch_artifacts} ${deployment_remote_name}/${git_branch_artifacts} --) || quit 4
	echo -e "\tgit merge ${deployment_remote_name}/${git_base_branch_for_artifacts}"
	git -c user.name="CI for Necktschnagge" -c user.email="ci-for-necktschnagge@example.org" merge ${deployment_remote_name}/${git_base_branch_for_artifacts} || quit 5 # this is possibly concurrent to another job creating the same merge commit.
	echo -e "\tCopy script PDF"
	mkdir -p ./${artifact_dir}
	mkdir -p ./${release_artifact_dir}
	cp ./src/script.pdf "${artifact_path}" # if the file is already present, cp overwrites the old one.
	cp ${artifact_path} ${release_artifact_path} # if the file is already present, cp overwrites the old one.
	echo -e "\tgit add -f ${artifact_path}"
	git add -f "${artifact_path}"
	echo -e "\tgit add -f ${release_artifact_path}"
	git add -f "${release_artifact_path}"
	echo -e "\tgit status"
	git status
	echo -e "\tgit commit -m \"Automatic upload of script PDF\""
	#we may skip telling email with "-c user.email=ci-for-necktschnagge@example.org"; not needed but than we get some ugly mail adress from Azure setup.
	git -c user.name="CI for Necktschnagge" -c user.email="ci-for-necktschnagge@example.org" commit -m "Automatic upload of script PDF" # this is possibly concurrent to another job running this script.
	echo -e "\tgit status"
	git status
	echo -e "\tgit push" #this may fail after concurrent commits:
	git push https://${git_username}:${git_access_token}@github.com/${user_repo_id} ${git_branch_artifacts} && break
	echo
	echo
	echo -e "\tPush was not successful. Trying again..."
	git checkout ${git_branch_for_ci_job}
	git branch -D artifacts
	sleep $(($LEFT_TRIES))s
	let LEFT_TRIES=LEFT_TRIES-1
	if [ $LEFT_TRIES -lt 1 ]; then
		echo -e "\tFAILED:   Uploading pdf build artifact."
		#curl -H "Authorization: token ${git_access_token}" -X POST -d "{\"body\": \"ERROR: Failed to push preview artifact!\"}" "https://api.github.com/repos/${user_repo_id}/issues/${pull_id}/comments"
		quit 1
	fi
done

########################### POST COMMENT #####################################
#echo -e "\tUploading PDF build artifact... DONE"
#if [[ ${git_pull_labels} =~ ^.*${links}.*$ ]]; then
#	echo "Found label ${links}. Skip posting a comment to the pull request linking to the preview PDF."
#	quit 0
#fi
#echo "Posting comment into pull request..."
#curl -H "Authorization: token ${git_access_token}" -X POST -d "{\"body\": \"See script pre-build here: [${git_hash_last_commit}.pdf](https://github.com/${user_repo_id}/blob/artifacts/${artifact_path})\"}" "https://api.github.com/repos/${user_repo_id}/issues/${pull_id}/comments"	
#quit 0;
