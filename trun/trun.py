import yaml
import os, sys
import subprocess
from kubernetes import client, config

MPATH = "manifests"
CFILE = "test.yaml"

switch = {
        "Deploy": deploy_manifest,
        "WaitForAllDeploymentsCompletion": wait_for_all_deployments_completion
        }

def deploy_manifest(step):
    manifest = step["Manifest"]
    ns = step["Namespace"]

    path = os.path.join(MPATH, manifest)

    e = subprocess.run(["kubectl", "apply", "-n", ns, "-f", path],
            stdout=subprocess.DEVNULL)
    
    if e.returncode != 0:
        print("Error applying manifest")
        sys.exit(1)


def wait_for_all_deployments_completion(step):
    ns = "default"
    if "Namespace" in step:
        ns = step["Namespace"]

    api = client.AppsV1Api()
    deployments = api.list_namespaced_deployment(namespace=ns, watch=False)
    
    count = 0
#    for d in deployments:


def parse_config():
    with open(CFILE, "r") as f:
        o = yaml.load(f)
        return o

def run_test(steps):
    for step in steps:
        func = switch[step]
        func(step)


def main():
    config.load_kube_config()
    test = parse_config()
    run_test(test)

