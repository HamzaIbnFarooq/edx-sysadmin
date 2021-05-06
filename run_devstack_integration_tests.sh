#!/bin/bash
set -e

source /edx/app/edxapp/venvs/edxapp/bin/activate

cd /edx/app/edxapp/edx-platform
mkdir -p reports

sudo apt-get install libxmlsec1-dev pkg-config nodejs
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl daemon-reload
sudo systemctl start mongod
sudo systemctl status mongod   

pip install -r ./requirements/edx/testing.txt
pip install -r ./requirements/edx/paver.txt
sudo npm install -g rtlcss
paver update_assets lms --settings=test_static_optimized
echo '-------------------------------------------------'
cat test_root/staticfiles/lms/webpack-stats.json
echo '-------------------------------------------------'
cp test_root/staticfiles/lms/webpack-stats.json test_root/staticfiles/webpack-stats.json
echo '-------------------------------------------------'
cat test_root/staticfiles/webpack-stats.json
echo '-------------------------------------------------'

cd /edx-sysadmin
pip install -e .

# Install codecov so we can upload code coverage results
pip install codecov

# output the packages which are installed for logging
pip freeze

mkdir -p test_root  # for edx

set +e

# We're running pycodestyle directly here since pytest-pep8 hasn't been updated in a while and has a bug
# linting this project's code. pylint is also run directly since it seems cleaner to run them both
# separately than to run one as a plugin and one by itself.
echo "Running tests"
pytest
PYTEST_SUCCESS=$?
echo "Running pycodestyle"
pycodestyle edx_sysadmin tests
PYCODESTYLE_SUCCESS=$?
echo "Running pylint"

(cd /edx/app/edxapp/edx-platform; pylint /edx-sysadmin/edx_sysadmin)
PYLINT_SUCCESS=$?

if [[ $PYTEST_SUCCESS -ne 0 ]]
then
    echo "pytest exited with a non-zero status"
    exit $PYTEST_SUCCESS
fi
if [[ $PYCODESTYLE_SUCCESS -ne 0 ]]
then
    echo "pycodestyle exited with a non-zero status"
    exit $PYCODESTYLE_SUCCESS
fi
if [[ $PYLINT_SUCCESS -ne 0 ]]
then
    echo "pylint exited with a non-zero status"
    exit $PYLINT_SUCCESS
fi
