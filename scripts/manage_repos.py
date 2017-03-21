#!/usr/bin/env python
import subprocess
import json
import re
import os
from collections import defaultdict
from boto import iam, s3
from requests import Session
from requests.auth import HTTPBasicAuth
import requests
import sys
import glob 
import semantic_version


def pkg_versions(pkg_name, branch_name=None):
    if branch_name:
        str_regex = "{0}-{1}{2}amd64.deb".format(pkg_name, 
                                                 branch_name, 
                                                 r"_(?P<version>[\d+\.]{5})_")
    else:
        str_regex = "{0}{1}amd64.deb".format(pkg_name, 
                                             r"_(?P<version>[\d+\.]{5})_")
    regex = re.compile(str_regex)
    s = s3.connect_to_region('us-east-1')
    bucket = s.get_bucket('cb-devops-repo')
    versions = list()
    for key in bucket.get_all_keys(prefix=pkg_name):
        m = regex.search(key.name)
        if m:
            versions.append(m.group('version'))
    return sorted(versions)


def init_session(username, password, mfa_code):
    global session
    session = requests.Session()
    session.auth = (username, password)
    session.headers.update({"X-GitHub-OTP": mfa_code })


def clear_repo_teams(org, repo_name):
    for team in list_teams(org):
        for repo in list_team_repos(org, team):
            # print("{0}: {1}".format(repo, team))
            if repo == repo_name:
                # print("Would remove team {0} from repo {1}".format(team, repo))
                remove_team_from_repo(org, team, repo_name)


def list_teams(org):
    # GET /orgs/:org/teams
    resp = session.get("https://api.github.com/orgs/{0}/teams".format(org))
    for team in resp.json():
        yield team.get('name')


def list_team_repos(org, team_name):
    # GET /teams/:id/repos
    team_id = get_team(org, team_name).get('id')
    resp = session.get("https://api.github.com/teams/{0}/repos".format(team_id))

    for repo in resp.json():
        yield repo.get('name')

    regex = re.compile("\<(?P<url>[^>]*)\>; rel=\"next\"")
    m =  regex.search(resp.headers.get('Link', "NOLINK"))
    while m:
        resp = session.get(m.group('url'))
        m =  regex.search(resp.headers.get('Link', "NOLINK"))
        for repo in resp.json():
            yield repo.get('name')

def remove_team_from_repo(org, team_name, repo_name):
    # DELETE /teams/:id/repos/:owner/:repo
    team = get_team(org, team_name).get('id')
    resp = session.delete("https://api.github.com/teams/{0}/repos/{1}/{2}".format(team, org, repo_name))
    return resp


def get_team(org, team_name):
    # /orgs/:org/teams
    resp = session.get("https://api.github.com/orgs/{0}/teams".format(org))
    for team in resp.json():
        if team.get('name') == team_name:
            return team


def add_team_permissions(org, repo, team_name, permission):
    # PUT /teams/:id/repos/:org/:repo
    team = get_team(org, team_name)
    resp = session.put("https://api.github.com/teams/{0}/repos/{1}/{2}".format(team.get('id'),
                                                                               org,
                                                                               repo.get('name')),
                                                                        data=json.dumps({"permission": permission}))
    return resp.text


def repo_definition(repo_definition):
    repo_definition = os.path.expandvars(repo_definition)
    repo_definition = os.path.expanduser(repo_definition)
    repo_definition = os.path.abspath(repo_definition)
    with open(repo_definition, 'r') as repo_def:
        payload = json.loads(repo_def.read())
    return payload


def repo_exists(org, repo_name):
    repos = list()
    resp = session.get("https://api.github.com/orgs/{0}/repos".format(org))
    for repo in resp.json():
        if repo.get('name') == repo_name:
            return True

    regex = re.compile("\<(?P<url>[^>]*)\>; rel=\"next\"")
    m =  regex.search(resp.headers.get('Link'))
    while m:
        resp = session.get(m.group('url'))
        m =  regex.search(resp.headers.get('Link', "NOLINK"))
        if not m:
            break
        for repo in resp.json():
            if repo.get('name') == repo_name:
                return True
    return False


def create_repo(org, _repo_definition):
    # POST /orgs/:org/repos
    repo = repo_definition(_repo_definition)

    if repo.get('teams'): 
        teams = repo.pop('teams')
    else:
        teams = None

    if not repo_exists(org, repo.get('name')):
        created_repo = session.post("https://api.github.com/orgs/{0}/repos".format(org),
                    data=json.dumps(repo)).json()
    else:
        clear_repo_teams(org, repo.get('name'))
        created_repo = {"name": repo.get("name"), "exists": True}

    if teams:
        for team in teams:
            add_team_permissions(org, created_repo, team.get('name'), team.get('permission'))

    return created_repo

def main(opt):
    from getpass import getpass
    (username, password, mfa_code) = (raw_input("Username: ").strip(), 
                                      getpass("Password: ").strip(), 
                                      raw_input("MFA Code: ").strip())
    init_session(username, password, mfa_code)

    if not opt.repo_list:

        repo = create_repo(opt.org,
                           opt.repo)
        print(json.dumps(repo, separators=(',', ':'), indent=4, sort_keys=True))

        repo = repo_definition(opt.repo)
        if opt.clone_dir:
            if os.path.isdir(opt.clone_dir):
                print("Cloning {0} to {1}/{0}".format(repo.get("name"), opt.clone_dir))
                cur_dir = os.getcwd()
                os.chdir(opt.clone_dir)
                os.system("git clone git@github.com:{0}/{1}".format(repo.get("org"), repo.get("name")))
                os.chdir(cur_dir)

        if repo.get("travis_enabled"):
            print("Enabling Travis {0}/{1}".format(repo.get("org"), repo.get("name")))
            os.system("travis enable -r {0}/{1}".format(repo.get("org"), repo.get("name")))

    else:
        for x in glob.glob(os.path.join(opt.repo_list, '*.json')):
            repo = create_repo(username,
                           password,
                           mfa_code, 
                           opt.org,
                           x,
                           opt.team_name)
            if opt.clone_dir:
                if not os.path.isdir(opt.clone_dir):
                    continue
                print("Cloning {0} to {1}/{0}".format(x.get("name"), opt.clone_dir))
                cur_dir = os.getcwd()
                os.chdir(opt.clone_dir)
                os.system("git clone git@github.com:{0}/{1}".format(x.get("org"), x.get("name")))
                os.chdir(cur_dir)

            if x.get("travis_enabled"):
                print("Enabling Travis")
                os.system("travis enable -r {0}:{1}".format(x.get("org"), x.get("name")))
            
            print(json.dumps(repo, separators=(',', ':'), indent=4, sort_keys=True))
    sys.exit(0)


if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option('--org', default="ChartBoost")
    parser.add_option('--repo')
    parser.add_option('--clone', dest='clone_dir', default=False)
    parser.add_option('-d', dest='repo_list', default=False)
    opt, arg = parser.parse_args()
    
    main(opt)



