#!/usr/bin/env python
import subprocess, shlex
import json
import re
import os
from collections import defaultdict
from boto import iam
from requests import Session
from requests.auth import HTTPBasicAuth
import requests
import sys
import glob 

current_dir = os.getcwd()
directories = []


def set_dir(_dir):
    _dir = os.path.expandvars(_dir)
    _dir = os.path.expanduser(_dir)
    _dir = os.path.abspath(_dir)
    current_dir = os.getcwd()
    try:
        os.chdir(dir)
        directories.append(_dir)
    except:
        os.chdir(current_dir)


def verify_branch(_dir, branch_name):
    set_dir(_dir)
    p = subprocess.Popen(shlex.split("git rev-parse --verify {0}".format(branch_name)), 
                            stdout=subprocess.PIPE, 
                            stderr=subprocess.PIPE)
    out, err = p.communicate()
    set_dir(current_dir)
    if p.returncode > 0:
        return False
    else:
        return True


def clone_repo(_dir, repo_url):
    fresh_clone = False
    if not os.path.isdir(_dir):
        os.system("git clone {0} {1}".format(repo_url, _dir))
        set_dir(_dir)
        fresh_clone = True
    else:
        set_dir(_dir)
        os.system("git pull")
    return fresh_clone


def create_branch(branch_name):
    print("Creating branch {0}".format(branch_name))
    os.system('git checkout -b {0}'.format(branch_name))


def reset_dirs():
    for x in directories:
        os.chdir(x)

def load_repos(repo, branch_name, repo_dir):
    if repo == 'all':
        repo_glob = os.path.join(repo_dir, '*.json')
    else:
        repo_glob = os.path.join(repo_dir, "{0}.json".format(repo))

    set_dir(repo_dir)
    for repo in glob.glob(repo_glob):
        print repo
        repo_data = json.loads(open(repo).read())
        clone_repo(repo_data.get('repo_dir'), repo_data.get('repo_url'))
        if branch_name != 'master' and not verify_branch(repo_data.get('repo_dir'), branch_name):
            create_branch(branch_name)


def main(opt):
    load_repos(opt.repo, opt.branch, opt.repo_dir)
    reset_dirs()



if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option('-r', '--repo', default='all')
    parser.add_option('-d', dest='repo_dir', default=False)
    parser.add_option('-b', '--branch', default='master')
    opt, arg = parser.parse_args()    
    main(opt)



