from os.path import dirname, join, abspath, isdir
from os import listdir
import sys

app_path = abspath(join(dirname(__file__), '..'))

lib_path = join(app_path, 'lib')
libs = [join(lib_path, item) for item in listdir(lib_path) if isdir(join(lib_path, item))]
map(sys.path.append, libs)
from bs4 import BeautifulSoup

from os.path import isdir, join
import requests_unixsocket
import time
from subprocess import check_output
import shutil
import uuid
from syncloud_app import logger

from syncloud_platform.application import api
from syncloud_platform.gaplib import fs, linux, gen

APP_NAME = 'rocketchat'
USER_NAME = 'rocketchat'
SYSTEMD_ROCKETCHAT = 'rocketchat-server'


def install():
    log = logger.get_logger('rocketchat_installer')

    app = api.get_app_setup(APP_NAME)
    app_dir = app.get_install_dir()
    app_data_dir = app.get_data_dir()

    linux.useradd(USER_NAME)

    log_path = join(app_data_dir, 'log')
    fs.makepath(log_path)

    variables = {
        'app_dir': app_dir,
        'app_data_dir': app_data_dir,
        'log_path': log_path,
        'app_url': app.app_url(),
        'web_secret': unicode(uuid.uuid4().hex)
    }

    templates_path = join(app_dir, 'config.templates')
    config_path = join(app_data_dir, 'config')

    gen.generate_files(templates_path, config_path, variables)

    fs.chownpath(app_dir, USER_NAME, recursive=True)
    fs.chownpath(app_data_dir, USER_NAME, recursive=True)

    app.add_service(SYSTEMD_ROCKETCHAT)
    

def remove():
    app = api.get_app_setup(APP_NAME)

    app.remove_service(SYSTEMD_ROCKETCHAT)

    app_dir = app.get_install_dir()

    fs.removepath(app_dir)

