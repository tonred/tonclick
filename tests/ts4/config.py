import os

from tonos_ts4 import ts4

BUILD_ARTIFACTS_PATH = os.path.dirname(os.path.realpath(__file__)) + '/../../build/'
VERBOSE = os.getenv('TS4_VERBOSE', 'False').lower() == 'true'

EMPTY_CELL = ts4.Cell(ts4.EMPTY_CELL)

INIT_TIP3_VALUE = 100
