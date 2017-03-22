#!/usr/bin/python
import os
import json
import shutil
from tempfile import NamedTemporaryFile

if os.path.isfile(os.path.join(os.getcwd(), 'config.json')):
	tmp = NamedTemporaryFile(delete=False)
	with open(os.path.join(os.getcwd(), 'config.json')) as config:
		data = json.loads(config.read())
		if data.get('dependencies'):
			data.pop('dependencies')
		if data.get('pre_dependencies'):
			data.pop('pre_dependencies')
		tmp.write(json.dumps(data, separators=(',', ':'), indent=4, sort_keys=True))
	tmp.close()
	shutil.copyfile(tmp.name, os.path.join(os.getcwd(), 'config.json'))
