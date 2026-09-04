#!/usr/local/bin/python3

"""
    Copyright (c) 2026 Date Huang
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.

    --------------------------------------------------------------------------------------

    Renders the OPNsense/Stunmesh config.yaml template with configd's own
    Template engine (modules.template.Template / modules.config.Config, the
    same classes template_ctl.py and "configctl template reload" use) and
    prints the result to stdout. The output is byte-for-byte what a real
    "configctl template reload OPNsense/Stunmesh" would write, but nothing
    under /usr/local/etc/stunmesh/ is touched: the template's target root is
    redirected to a throwaway temp directory, and only the rendered
    config.yaml is read back from there and printed.
"""

import sys
import shutil
import tempfile

# configd's own Python modules (modules.template, modules.config) live here,
# not on the default interpreter path.
sys.path.insert(0, '/usr/local/opnsense/service')

from modules import config, template  # noqa: E402

MODULE_NAME = 'OPNsense.Stunmesh'
CONFIG_XML = '/conf/config.xml'


def render():
    tmp_root = tempfile.mkdtemp(prefix='stunmesh-preview-')
    try:
        tmpl = template.Template(tmp_root)
        conf = config.Config(CONFIG_XML)
        tmpl.set_config(conf.get())

        filenames = tmpl.generate(MODULE_NAME)
        if filenames is None:
            raise RuntimeError('template engine failed to render %s' % MODULE_NAME)

        # +TARGETS for this module also renders /etc/rc.conf.d/stunmesh; only
        # the config.yaml output is wanted here.
        matches = [f for f in filenames if f.endswith('/config.yaml')]
        if len(matches) != 1:
            raise RuntimeError(
                'expected exactly one config.yaml in rendered output, got: %r' % filenames
            )

        with open(matches[0], 'r', encoding='utf-8') as fh:
            sys.stdout.write(fh.read())
    finally:
        shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == '__main__':
    try:
        render()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
