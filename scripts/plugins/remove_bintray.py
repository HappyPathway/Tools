#!/usr/bin/python
import os
import json
import shutil
from tempfile import NamedTemporaryFile

if os.path.isfile(os.path.join(os.getcwd(), 'config.json')):
	tmp = NamedTemporaryFile(delete=False)
	with open(os.path.join(os.getcwd(), 'config.json')) as config:
		data = json.loads(config.read())
		data = dict([(k, v) for k, v in data.items() if 'bintray' not in k ])
		tmp.write(json.dumps(data, separators=(',', ':'), indent=4, sort_keys=True))
	tmp.close()
	shutil.copyfile(tmp.name, os.path.join(os.getcwd(), 'config.json'))
