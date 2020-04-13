import yaml

CFILE = "test.yaml"

switch = {


        }

def parse_config():
    with open(CFILE, "r") as f:
        o = yaml.load(f)
        return o

def run_test(steps):
    for step in steps:
        switch 
