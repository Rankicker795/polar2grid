#!/bin/bash
# Script for jenkins to run tests on polar2grid.

set -ex
export PATH="/usr/local/texlive/2019/bin/x86_64-linux":$PATH
cd "$WORKSPACE"

# Activate conda for bash.
/data/users/davidh/miniconda3/bin/conda init bash
# Restart the shell to enable conda.
source ~/.bashrc

# Documentation environment also has behave, while the build environment does not.
conda env update -n jenkins_p2g_docs -f "$WORKSPACE/build_environment.yml"
conda env update -n jenkins_p2g_docs -f "$WORKSPACE/jenkins_environment.yml"
conda activate jenkins_p2g_docs
pip install "$WORKSPACE"

commit_message=`git log --format=%B -n 1 $GIT_COMMIT`

if [[ "$(cut -d'-' -f1 <<<"$GIT_TAG_NAME")" = "g2g" ]] || [[ "$commit_message" =~ " ["g2g-skip-tests"]"$ ]]; then
    prefix=geo
else
    prefix=polar
fi

# Handle release vs test naming.
end="`date +"%Y%m%d-%H%M%S"`"
# If the tag is correct and a version was specified, make a version release.
if [[ "$GIT_TAG_NAME" =~ ^[pg]2g-v[0-9]+\.[0-9]+\.[0-9]+.* ]]; then
    # Removes prefix from $GIT_TAG_NAME.
    end="${GIT_TAG_NAME:5}"
fi

swbundle_name="${prefix}2grid-swbundle-${end}"
conda env update -n jenkins_p2g_swbundle -f "$WORKSPACE/build_environment.yml"
conda activate jenkins_p2g_swbundle
./create_conda_software_bundle.sh "${WORKSPACE}/${swbundle_name}"
conda activate jenkins_p2g_docs
if [[ ! "$commit_message" =~ " ["[pg]2g-skip-tests"]"$ ]]; then
    export POLAR2GRID_HOME="$WORKSPACE/$swbundle_name"
    cd "$WORKSPACE/integration_tests"
    behave --no-logcapture --no-color --no-capture -D datapath=/data/users/kkolman/integration_tests/polar2grid/integration_tests/p2g_test_data
fi
mkdir "/tmp/${prefix}2grid-${end}"
# Save tarball.
cp "${WORKSPACE}/${swbundle_name}.tar.gz" "/tmp/${prefix}2grid-${end}"
# Make docs.
cd "$WORKSPACE"/doc
make latexpdf POLAR2GRID_DOC="${prefix}"
cp "$WORKSPACE"/doc/build/latex/*.pdf "/tmp/${prefix}2grid-${end}"
# Clear out intermediate results and rebuild for HTML document.
make clean
# Needs to be second since Jenkins makes an html in workspace from the file generated by this command.
make html POLAR2GRID_DOC="${prefix}"
cp -r "$WORKSPACE"/doc/build/html "/tmp/${prefix}2grid-${end}"
chmod -R a+rX "/tmp/${prefix}2grid-${end}"
# Only copy to data/dist if the tag was correct, a version was specified, and the docs were successfully made.
if [[ "$GIT_TAG_NAME" =~ ^[pg]2g-v[0-9]+\.[0-9]+\.[0-9]+.* ]] && [[ ! "$commit_message" =~ " ["[pg]2g-skip-tests"]"$ ]]
then
    cp "${WORKSPACE}/${swbundle_name}.tar.gz" /data/dist
fi