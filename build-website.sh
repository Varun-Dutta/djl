#!/usr/bin/env bash

#Configure Git User
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

#Set Environment Variables
TESTING=false
VERSION_NUMBER=dev
while getopts "t:v:" arg; do
  case "$arg" in
    t)
      TESTING=$OPTARG
      ;;
    v)
      VERSION_NUMBER=$OPTARG
      ;;
  esac
done 
echo "TESTING set to $TESTING."

#These commits are necessary to switch to the gh-pages branch in the next step. 
git add . 
git commit -m "Debugging Commit" 

#Create gh-pages branch for mike, delete files that can interfere with mike, download previous versions of website from S3 Bucket. 
#docs-update branch instead of master in case user is running the workflow from a different branch, such as main. This allows the workflow to switch back to the docs-update branch rather than throwing an error because its looking for a master branch when none is found. 
git checkout -b docs-update
git branch gh-pages 
cd docs 
mike delete --all 
git checkout gh-pages 
cd .. 

#Download the index.html and versions.json for mike to reference
if [ "$TESTING" = "true" ]; then 
  aws s3 mv s3://updated-documentation-website/website/index.html . 
  aws s3 mv s3://updated-documentation-website/website/versions.json . 
else
  aws s3 mv s3://djl-ai/documentation/nightly/index.html .
  aws s3 mv s3://djl-ai/documentation/nightly/versions.json . 
fi 

#Commits are necssary to swtich to switch back to the docs-update branch. 
git add . 
git commit -m "Sync Finished" 

#Switch back to docs-update branch to invoke mike 
git checkout docs-update
cd docs
echo "deploying $VERSION_NUMBER"
if [ "$VERSION_NUMBER" = "master" ]; then
  VERSION_NUMBER=dev
fi
mike deploy $VERSION_NUMBER 
mike set-default $VERSION_NUMBER 

#Upload Artificats for New Version of the Website
git checkout gh-pages
cd .. 
ls
echo "Syncing..."
echo "The directory is" 
pwd 
if [ "$TESTING" = "true" ]; then
  aws s3 cp ./index.html s3://updated-documentation-website/website/index.html 
  aws s3 cp ./versions.json s3://updated-documentation-website/website/versions.json 
  aws s3 sync ./"$VERSION_NUMBER" s3://updated-documentation-website/website/"$VERSION_NUMBER" 
else
  aws s3 cp ./index.html s3://djl-ai/documentation/nightly/index.html 
  aws s3 cp ./versions.json s3://djl-ai/documentation/nightly/versions 
  aws s3 sync ./"$VERSION_NUMBER" s3://djl-ai/documentation/nightly/"$VERSION_NUMBER" 
  aws cloudfront create-invalidation --distribution-id E733IIDCG0G5U --paths "/*"
fi
