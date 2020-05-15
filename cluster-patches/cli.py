import click
import logging
import os, sys
import yaml, pickle

from enoslib.api import generate_inventory, run_ansible, run_command
from enoslib.service import Netem
from enoslib.api import discover_networks

import enos_kubernetes.tasks as t
from enos_kubernetes.constants import CONF, BUILD_CONF_PATH, DEFAULT_BUILD_CLUSTER

logging.basicConfig(level=logging.DEBUG)

from enos_kubernetes.constants import (
    ANSIBLE_DIR,
    )


@click.group()
def cli():
    pass


def load_config(file_path):
    """
    Read configuration from a file in YAML format.
    :param file_path: Path of the configuration file.
    :return:
    """
    with open(file_path) as f:
        configuration = yaml.safe_load(f)
    return configuration


def load_build_conf(provider, cluster=DEFAULT_BUILD_CLUSTER, working_dir=None):
    conf = load_config(BUILD_CONF_PATH)
    # yeah, that smells
    provider_conf = conf[provider]
    if provider == "g5k" or provider == "vmong5k":
        provider_conf["resources"]["machines"][0]["cluster"] = cluster
    if provider == "vmong5k":
        if working_dir is None:
            # force the working_dir
            working_dir = os.path.join(os.getcwd(), "working_dir")
            provider_conf["working_dir"] = working_dir
    return conf



@cli.command(help="Claim resources on Grid'5000 (frontend).")
@click.option("--force",
              is_flag=True,
              help="force redeployment")
@click.option("--conf",
              default=CONF,
              help="alternative configuration file")
@click.option("--env",
              help="alternative environment directory")
def g5k(force, conf, env):
    config = load_config(conf)
    t.g5k(config, force, env=env)


@cli.command(help="Claim resources on vagrant (localhost).")
@click.option("--force",
              is_flag=True,
              help="force redeployment")
@click.option("--conf",
              default=CONF,
              help="alternative configuration file")
@click.option("--env",
              help="alternative environment directory")
def vagrant(force, conf, env):
    config = load_config(conf)
    t.vagrant(config, force, env=env)


@cli.command(help="Claim resources on chameleon.")
@click.option("--force",
              is_flag=True,
              help="force redeployment")
@click.option("--conf",
              default=CONF,
              help="alternative configuration file")
@click.option("--env",
              help="alternative environment directory")
def chameleon(force, conf, env):
    config = load_config(conf)
    t.chameleon(config, force, env=env)


@cli.command(help="Generate the Ansible inventory [after g5k or vagrant].")
@click.option("--env",
              help="alternative environment directory")
def inventory(env):
    t.inventory(env=env)


@cli.command(help="Configure available resources [after deploy, inventory or\
             destroy].")
@click.option("--env",
              help="alternative environment directory")
def prepare(env):
    t.prepare(env=env)


@cli.command(help="Post install the deployement")
@click.option("--env",
              help="alternative environment directory")
def post_install(env):
    t.post_install(env=env)
    t.hints(env=env)


@cli.command(help="Give some hints on the deployment")
@click.option("--env",
              help="alternative environment directory")
def hints(env):
    t.hints(env=env)


@cli.command(help="Backup the deployed environment")
@click.option("--env",
              help="alternative environment directory")
def backup(env):
    t.backup(env=env)


@cli.command(help="Destroy the deployed environment")
@click.option("--env",
              help="alternative environment directory")
def destroy(env):
    t.destroy(env=env)


@cli.command(help="Resets Kubernetes (see kspray doc)")
@click.option("--env",
              help="alternative environment directory")
def reset(env):
    t.reset(env=env)


@cli.command(help="Claim resources from a PROVIDER and configure them.")
@click.argument("provider")
@click.option("--force", is_flag=True, help="force redeployment")
@click.option("--conf", default=CONF, help="alternative configuration file")
@click.option("--env", help="alternative environment directory")
@click.option("--only-netem", is_flag=True, default=False, help="Do not deploy, only apply Netem config")
@click.option("--prepare", is_flag=True, default=False, help="Only prepare experimentation environ")
@click.option("--cleanup", is_flag=True, default=False, help="Only cleanup")
def deploy(provider, force, conf, env, only_netem, prepare, cleanup):
    config = load_config(conf)

    # Extract tc config and leave the 
    # provider's config object intact
    tc = None
    if "tc" in config[provider]:
        tc = dict(config[provider]["tc"])
        config[provider].pop('tc', None)    
    
    if only_netem or prepare or cleanup:
        if not os.path.exists("current/env"):
            print("No current deploy env already exists !")
            sys.exit(1)

        with open("current/env", "rb") as f:
            env = pickle.load(f)
            
            if prepare:
                run_ansible([os.path.join(ANSIBLE_DIR, "prepare_exp.yml")],\
                        env["inventory"])

            elif cleanup:
                run_ansible([os.path.join(ANSIBLE_DIR, "cleanup_exp.yml")],\
                        env["inventory"])

            else:            
                r = discover_networks(env["roles"], env["networks"])
                netemObj = Netem(tc, roles=r)
                netemObj.deploy()
                netemObj.validate() 
        sys.exit(0)

    t.PROVIDERS[provider](config, force, env=env)
    t.inventory(env=env)
    
    t.prepare(env=env)
    t.post_install(env=env)
    t.hints(env=env)

@cli.command(help="Preconfigure a machine with all the dependency. only vmong5k for now")
@click.argument("provider")
@click.option("--cluster",
              default=DEFAULT_BUILD_CLUSTER,
              help="cluster to use for building the base image")
def build(provider, cluster):
    force = False
    t.PROVIDERS[provider](load_build_conf(provider, cluster=cluster), force)
    t.inventory()
    t.prepare()
    t.reset()
