<?php

/*
 * Copyright (C) 2026 Date Huang
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Stunmesh\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Stunmesh\Stunmesh;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'stunmesh';
    protected static $internalModelClass = '\OPNsense\Stunmesh\Stunmesh';

    public function searchPluginAction()
    {
        return $this->searchBase('plugins.plugin', ['enabled', 'name', 'type', 'builtin', 'description']);
    }

    public function getPluginAction($uuid = null)
    {
        return $this->getBase('plugin', 'plugins.plugin', $uuid);
    }

    public function addPluginAction()
    {
        return $this->addBase('plugin', 'plugins.plugin');
    }

    public function setPluginAction($uuid)
    {
        return $this->setBase('plugin', 'plugins.plugin', $uuid);
    }

    public function delPluginAction($uuid)
    {
        return $this->delBase('plugins.plugin', $uuid);
    }

    public function togglePluginAction($uuid, $enabled = null)
    {
        return $this->toggleBase('plugins.plugin', $uuid, $enabled);
    }

    public function searchInterfaceAction()
    {
        return $this->searchBase('interfaces.interface', ['enabled', 'instance', 'protocol', 'description']);
    }

    public function getInterfaceAction($uuid = null)
    {
        return $this->getBase('interface', 'interfaces.interface', $uuid);
    }

    public function addInterfaceAction()
    {
        return $this->addBase('interface', 'interfaces.interface');
    }

    public function setInterfaceAction($uuid)
    {
        return $this->setBase('interface', 'interfaces.interface', $uuid);
    }

    public function delInterfaceAction($uuid)
    {
        return $this->delBase('interfaces.interface', $uuid);
    }

    public function toggleInterfaceAction($uuid, $enabled = null)
    {
        return $this->toggleBase('interfaces.interface', $uuid, $enabled);
    }

    public function searchPeerAction()
    {
        return $this->searchBase('peers.peer', ['enabled', 'interface', 'peer', 'plugin', 'protocol', 'description']);
    }

    public function getPeerAction($uuid = null)
    {
        return $this->getBase('peer', 'peers.peer', $uuid);
    }

    public function addPeerAction()
    {
        return $this->addBase('peer', 'peers.peer');
    }

    public function setPeerAction($uuid)
    {
        return $this->setBase('peer', 'peers.peer', $uuid);
    }

    public function delPeerAction($uuid)
    {
        return $this->delBase('peers.peer', $uuid);
    }

    public function togglePeerAction($uuid, $enabled = null)
    {
        return $this->toggleBase('peers.peer', $uuid, $enabled);
    }
}
