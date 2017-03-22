#!/usr/bin/env python
import subprocess, shlex, shutil
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
from jinja2 import Template


AWS_ACCESS_KEY_ID="AKIAISJWKP26Z6FEW6OQ"
AWS_SECRET_ACCESS_KEY="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"

def commit(_dir, message, branch='master', remote='origin'):
    cur_dir = os.getcwd()
    os.chdir(_dir)
    os.system('''git add .''')
    os.system('''git commit -m "{0}"'''.format(message))
    os.system('''git push -u {0} {1}'''.format(remote, branch))
    os.chdir(cur_dir)


def configure_travis(clone_dir, repo, commit, repo_bucket, clobber, tools):
    if repo.get("travis_enabled"):
        print("Enabling Travis {0}/{1}".format(repo.get("org"), repo.get("name")))
        os.system("travis enable -r {0}/{1}".format(repo.get("org"), repo.get("name")))
        if clone_dir:
            # create_travis_config(repo_dir, repo_name, repo_bucket, pkg_name, deployment_tools_version)
            create_travis_config(clobber, clone_dir, repo.get("name"), repo_bucket, repo.get('pkg_name'), tools)
            travis_keys(os.path.join(clone_dir, repo.get('name')))
        else:
            print("Disabling Travis {0}/{1}".format(repo.get("org"), repo.get("name")))
            os.system("travis disable -r {0}/{1}".format(repo.get("org"), repo.get("name")))

        if commit and clone_dir and repo.get("travis_enabled"):
            commit(os.path.join(opt.clone_dir, repo.get("name")), "Enabling Travis")


def clone(clone_dir, repo):
    if os.path.isdir(opt.clone_dir):
        print("Cloning {0} to {1}/{0}".format(repo.get("name"), clone_dir))
        cur_dir = os.getcwd()
        os.chdir(clone_dir)
        os.system("git clone git@github.com:{0}/{1}".format(repo.get("org"), repo.get("name")))
        os.chdir(cur_dir)

def travis_keys(_dir):
    cur_dir = os.getcwd()
    os.chdir(_dir)
    os.system("travis encrypt --no-interactive AWS_ACCESS_KEY_ID={0} --add".format(AWS_ACCESS_KEY_ID))
    os.system("travis encrypt --no-interactive AWS_SECRET_ACCESS_KEY={0} --add".format(AWS_SECRET_ACCESS_KEY))
    os.chdir(cur_dir)

def repo_script(_dir, script):
    cur_dir = os.getcwd()
    os.chdir(_dir)
    print(script)
    p = subprocess.Popen(script, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    
    if p.returncode > 0:
        sys.stderr.write(err)
        sys.stderr.write("\n")
        sys.exit(p.returncode)
    else:
        print(out)
        print("\n")

    os.chdir(cur_dir)

def pkg_versions(pkg_name, branch_name=None, git_hash=None):
    if branch_name and branch_name != 'master':
        str_regex = "{0}-{1}{2}".format(pkg_name, 
                                        branch_name, 
                                        r"_(?P<version>[\d+\.]{5})_")

    if not branch_name or branch_name == 'master':
        str_regex = "{0}{1}".format(pkg_name, 
                                    r"_(?P<version>[\d+\.]{5})_")

    # print(str_regex)
    if git_hash:
        str_regex = str_regex+"-"+git_hash

    str_regex += "amd64.deb"
    # print(str_regex)
    regex = re.compile(str_regex)
    s = s3.connect_to_region('us-east-1')
    bucket = s.get_bucket('cb-devops-repo')
    versions = list()
    for key in bucket.get_all_keys(prefix=pkg_name):
        m = regex.search(key.name)
        if m:
            versions.append(semantic_version.Version(m.group('version')))
    return [str(x) for x in sorted(versions, reverse=True)]


def create_travis_config(clobber, repo_dir, repo_name, repo_bucket, pkg_name, deployment_tools_version):
    template_dir = os.path.join(os.path.dirname(__file__), "../templates")
    t = Template(open(os.path.join(template_dir, "travis.j2")).read())
    rendered_template_dir = os.path.join(repo_dir, repo_name)
    if clobber or not os.path.isfile(os.path.join(rendered_template_dir, '.travis.yml')):
        with open(os.path.join(rendered_template_dir, '.travis.yml'), 'w') as template:
            template.write(t.render(dict(deployment_tools_version=deployment_tools_version,
                                         pkg_name=pkg_name,
                                         repo_bucket=repo_bucket)))



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


def sanitize_path(path):
    path = os.path.expandvars(path)
    path = os.path.expanduser(path)
    path = os.path.abspath(path)
    return path

def repo_definition(repo_definition):
    repo_definition = sanitize_path(repo_definition)
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
    if opt.create or opt.update:
        if opt.create or opt.update:
            (username, password, mfa_code) = (raw_input("Username: ").strip(), 
                                              getpass("Password: ").strip(), 
                                              raw_input("MFA Code: ").strip())
            init_session(username, password, mfa_code)

    if not opt.repo_list:
        if opt.create or opt.update:
            create_repo(opt.org, opt.repo)
        
        repo = repo_definition(opt.repo)
        if opt.clone_dir:
            clone(opt.clone_dir, repo)            

        if opt.configure_travis:
            configure_travis(clone_dir, repo, commit, repo_bucket, clobber, tools)

        if opt.clone_dir and opt.script:
            run_script()
            script_dir = sanitize_path(os.path.join(opt.clone_dir, repo.get("name")))
            script = sanitize_path(opt.script)
            repo_script(script_dir, script)
            if opt.commit:
                commit(os.path.join(opt.clone_dir, repo.get("name")), "Executing: {0}".format(opt.script))
        
        if opt.clean and os.path.isdir(os.path.join(opt.clone_dir, repo.get("name"))):
            shutil.rmtree(os.path.join(opt.clone_dir, repo.get("name")))


    else:
        for x in glob.glob(os.path.join(opt.repo_list, '*.json')):
            repo_config = repo_definition(x)

            if opt.create or opt.update:
                repo = create_repo(opt.org, x)

            if opt.clone_dir:
                if not os.path.isdir(opt.clone_dir):
                    continue
                print("Cloning {0} to {1}/{0}".format(repo_config.get("name"), opt.clone_dir))
                cur_dir = os.getcwd()
                os.chdir(opt.clone_dir)
                os.system("git clone git@github.com:{0}/{1}".format(repo_config.get("org"), repo_config.get("name")))
                os.chdir(cur_dir)

            if opt.configure_travis:
                if x.get("travis_enabled"):
                    print("Enabling Travis")
                    os.system("travis enable -r {0}:{1}".format(repo_config.get("org"), repo_config.get("name")))
                    if opt.clone_dir:
                        # create_travis_config(repo_dir, repo_name, repo_bucket, pkg_name, deployment_tools_version)
                        create_travis_config(opt.clobber, opt.clone_dir, repo_config.get("name"), opt.repo_bucket, repo.get('pkg_name'), opt.tools)
                        travis_keys(os.path.join(opt.clone_dir, repo_config.get('name')))
                else:
                    print("Disabling Travis {0}/{1}".format(repo_config.get("org"), repo_config.get("name")))
                    os.system("travis disable -r {0}/{1}".format(repo_config.get("org"), repo_config.get("name")))

                if opt.commit and opt.clone_dir and repo_config.get("travis_enabled"):
                    commit(os.path.join(opt.clone_dir, repo_config.get("name")), "Enabling Travis")
            
            if opt.clone_dir and opt.script:
                script_dir = sanitize_path(os.path.join(opt.clone_dir, repo_config.get("name")))
                script = sanitize_path(opt.script)
                repo_script(script_dir, script)
                if opt.commit:
                    commit(os.path.join(opt.clone_dir, repo_config.get("name")), "Executing: {0}".format(opt.script))

            if opt.clean and os.path.isdir(os.path.join(opt.clone_dir, repo_config.get("name"))):
                shutil.rmtree(os.path.join(opt.clone_dir, repo_config.get("name")))

            
    sys.exit(0)


if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option('--org', default="ChartBoost")
    parser.add_option('--repo')
    parser.add_option('--create', default=False, action='store_true')
    parser.add_option('--update', default=False, action='store_true')
    parser.add_option('--script', default=False)
    parser.add_option('--travis', default=False, action='store_true', dest='configure_travis')
    parser.add_option('--clone', dest='clone_dir', default=False)
    parser.add_option('--clobber', action='store_true', default=False)
    parser.add_option('-d', dest='repo_list', default=False)
    parser.add_option('--commit', action='store_true', default=False)
    parser.add_option('--bucket', dest='repo_bucket', default='cb-devops-repo')
    parser.add_option('--tools', dest='tools', default='spinnaker-deployment-tools_0.1.2')
    parser.add_option('--clean', action='store_true', default=False)
    opt, arg = parser.parse_args()
    
    main(opt)



