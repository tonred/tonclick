import os

BUILD_ARTIFACTS_PATH = os.path.dirname(os.path.realpath(__file__)) + '/../../build/'
VERBOSE = os.getenv('TS4_VERBOSE', 'False').lower() == 'true'
