import yaml
import os, sys, subprocess
import time, random, string
from kubernetes import client, config

MPATH = "manifests"
CFILE = "test.yaml"

api = None

def rand_str(length=5):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

def loop(step):
    for i in range(step["Count"]):
        print("iteration", str(i))
        run_test(step)
        print("end of iteration")

def deploy_manifest(step):
    manifest = step["Manifest"]
    ns = step["Namespace"]

    path = os.path.join(MPATH, manifest)

    if "ManifestName" in step:
        o = yaml.safe_load(open(path, "r"))
        o["metadata"]["name"] = "test-" + rand_str() \
                if step["ManifestName"] == "Generate" else step["ManifestName"]

        path = "/tmp/test" + o["metadata"]["name"] 

        with open(path, "w+") as f:
            yaml.safe_dump(o, f)

    e = subprocess.run(["kubectl", "apply", "-n", ns, "-f", path],
            stdout=subprocess.DEVNULL)
    
    if e.returncode != 0:
        print("Error applying manifest")
        sys.exit(1)

def delete(step):
    ns = step['Namespace']

    e = subprocess.run(["kubectl", "delete", "ns", ns])
    
    if e.returncode != 0:
        print("Error scaling deployment")
        sys.exit(1)


def scale_deployment(step):
    ns = step['Namespace']
    nm = step['DeploymentName']
    rp = step['Replicas']

    e = subprocess.run(["kubectl", "scale", "deployment", nm, 
        "--replicas=" + str(rp), "-n", ns])
    
    if e.returncode != 0:
        print("Error scaling deployment")
        sys.exit(1)

def wait_for_all_deployments_completion(step):
    ns = "default"
    if "Namespace" in step:
        ns = step["Namespace"]
       
    while True:
        r = api.list_namespaced_deployment(namespace=ns, watch=False)
        
        count = 0
        for d in r.items:
            ready = d.status.ready_replicas
            replicas = d.status.replicas

            if ready == replicas:
                count = count + 1
        
        if count == len(r.items):
            return

        print("Waiting for all deployments to become ready %d/%d ..." % 
                (count, len(r.items)))
        time.sleep(1)

def parse_config():
    with open(CFILE, "r") as f:
        o = yaml.load(f)
        return o


switch = {
        "Loop": loop,
        "Deploy": deploy_manifest,
        "ScaleDeployment": scale_deployment,
        "WaitForAllDeploymentsCompletion": wait_for_all_deployments_completion
        }


def run_test(test):
    for step in test["Steps"]:
        func = switch[step["Name"]]
        print("Running", step['Name'])
        func(step)

def main():
    config.load_kube_config()
    global api
    api = client.AppsV1Api()

    test = parse_config()
    run_test(test)

main()
