import sys
import os

if os.path.dirname(sys.argv[0]):
	sys.path.append(os.path.dirname(sys.argv[0]) + "/lib")
else:
	sys.path.append("./lib")
from report import *

##call  doAlarm
