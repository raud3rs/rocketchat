import os

import pytest
from subprocess import check_output
from syncloudlib.integration.hosts import add_host_alias

TMP_DIR = '/tmp/syncloud'


@pytest.fixture(scope="session")
def module_setup(request, device, artifact_dir):
    def module_teardown():
        device.run_ssh('journalctl > {0}/store-test.journalctl.log'.format(TMP_DIR), throw=False)
        device.scp_from_device('{0}/*'.format(TMP_DIR), artifact_dir)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def test_start(module_setup, app, device_host, domain, device):
    device.run_ssh('rm -rf {0}'.format(TMP_DIR), throw=False)
    device.run_ssh('mkdir {0}'.format(TMP_DIR), throw=False)
    add_host_alias(app, device_host, domain)


def test_sore(device, selenium):
    channel = os.environ["DRONE_BRANCH"]
    if channel == 'stable':
        channel = 'rc'
    device.activated()
    device.run_ssh('snap remove rocketchat')
    device.run_ssh('snap install rocketchat')
    device.run_ssh('/integration/install-snapd.sh')
    device.run_ssh('timeout 10m snap refresh rocketchat --channel={0}'.format(channel))

    selenium.open_app()
    selenium.screenshot('store-upgrade')

