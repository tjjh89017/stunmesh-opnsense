{#
 # Copyright (c) 2026 Date Huang
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without modification,
 # are permitted provided that the following conditions are met:
 #
 # 1. Redistributions of source code must retain the above copyright notice,
 #    this list of conditions and the following disclaimer.
 #
 # 2. Redistributions in binary form must reproduce the above copyright notice,
 #    this list of conditions and the following disclaimer in the documentation
 #    and/or other materials provided with the distribution.
 #
 # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 # POSSIBILITY OF SUCH DAMAGE.
 #}

<style>
    /* The custom YAML box needs a monospace font and preserved indentation,
       matching how stunmesh-go itself reads the file. */
    #stunmesh\.general\.config {
        font-family: monospace;
        white-space: pre;
        overflow-wrap: normal;
        overflow-x: auto;
        tab-size: 2;
        line-height: 1.4;
        height: 20rem;
    }
    #stunmesh-current-config {
        font-family: monospace;
        white-space: pre;
        overflow-wrap: normal;
        overflow-x: auto;
        tab-size: 2;
        line-height: 1.4;
        max-height: 20rem;
        overflow-y: auto;
        background-color: var(--body-bg, #f5f5f5);
        border: 1px solid #ccc;
        padding: 8px;
        margin-top: 8px;
    }
</style>

<script>
    $(document).ready(function() {
        mapDataToFormUI({'frm_GeneralSettings': "/api/stunmesh/settings/get"}).done(function() {
            updateServiceControlUI('stunmesh');
        });

        $("#reconfigureAct").SimpleActionButton({
            onPreAction: function() {
                const dfObj = $.Deferred();
                saveFormToEndpoint("/api/stunmesh/settings/set", 'frm_GeneralSettings', dfObj.resolve, true, dfObj.reject);
                return dfObj;
            },
        });

        $("#grid-plugins").UIBootgrid(
            {   search:'/api/stunmesh/settings/search_plugin',
                get:'/api/stunmesh/settings/get_plugin/',
                set:'/api/stunmesh/settings/set_plugin/',
                add:'/api/stunmesh/settings/add_plugin/',
                del:'/api/stunmesh/settings/del_plugin/',
                toggle:'/api/stunmesh/settings/toggle_plugin/'
            }
        );

        $("#grid-interfaces").UIBootgrid(
            {   search:'/api/stunmesh/settings/search_interface',
                get:'/api/stunmesh/settings/get_interface/',
                set:'/api/stunmesh/settings/set_interface/',
                add:'/api/stunmesh/settings/add_interface/',
                del:'/api/stunmesh/settings/del_interface/',
                toggle:'/api/stunmesh/settings/toggle_interface/'
            }
        );

        $("#grid-peers").UIBootgrid(
            {   search:'/api/stunmesh/settings/search_peer',
                get:'/api/stunmesh/settings/get_peer/',
                set:'/api/stunmesh/settings/set_peer/',
                add:'/api/stunmesh/settings/add_peer/',
                del:'/api/stunmesh/settings/del_peer/',
                toggle:'/api/stunmesh/settings/toggle_peer/'
            }
        );

        // "Show current config" reads the deployed /usr/local/etc/stunmesh/config.yaml
        // via configd, regardless of configuration source.
        $("#showConfigAct").click(function(event) {
            event.preventDefault();
            ajaxCall(url = "/api/stunmesh/service/showconfig", sendData = {}, callback = function(data, status) {
                if (status != "success" || data['status'] != 'ok') {
                    $("#stunmesh-current-config").text("{{ lang._('Unable to read the current configuration.') }}");
                } else {
                    $("#stunmesh-current-config").text(data['config']);
                }
                $("#stunmesh-current-config-box").removeClass("hidden");
            });
        });

        // Copies the shown text into the custom YAML editor, client side only.
        $("#copyConfigAct").click(function(event) {
            event.preventDefault();
            $("#stunmesh\\.general\\.config").val($("#stunmesh-current-config").text());
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#plugins">{{ lang._('Storage plugins') }}</a></li>
    <li><a data-toggle="tab" href="#interfaces">{{ lang._('Interfaces') }}</a></li>
    <li><a data-toggle="tab" href="#peers">{{ lang._('Peers') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="general" class="tab-pane fade in active">
        {{ partial('layout_partials/base_form', ['fields': generalForm, 'id': 'frm_GeneralSettings']) }}
        <div class="col-md-12">
            <button class="btn btn-default" id="showConfigAct" type="button">{{ lang._('Show current config') }}</button>
            <button class="btn btn-default" id="copyConfigAct" type="button">{{ lang._('Copy to editor') }}</button>
            <p><small class="text-muted">{{ lang._('Custom YAML fully replaces the generated configuration; it is not merged with the tables.') }}</small></p>
            <div id="stunmesh-current-config-box" class="hidden">
                <pre id="stunmesh-current-config"></pre>
            </div>
        </div>
    </div>
    <div id="plugins" class="tab-pane fade in">
        <table id="grid-plugins" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogPlugin">
            <thead>
            <tr>
                <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('Enabled') }}</th>
                <th data-column-id="name" data-type="string">{{ lang._('Name') }}</th>
                <th data-column-id="type" data-type="string">{{ lang._('Type') }}</th>
                <th data-column-id="builtin" data-type="string">{{ lang._('Builtin') }}</th>
                <th data-column-id="description" data-type="string">{{ lang._('Description') }}</th>
                <th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
            <tr>
                <td></td>
                <td colspan="5">
                    <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                    <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                </td>
            </tr>
            </tfoot>
        </table>
    </div>
    <div id="interfaces" class="tab-pane fade in">
        <table id="grid-interfaces" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogInterface">
            <thead>
            <tr>
                <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('Enabled') }}</th>
                <th data-column-id="instance" data-type="string">{{ lang._('WireGuard instance') }}</th>
                <th data-column-id="protocol" data-type="string">{{ lang._('Protocol') }}</th>
                <th data-column-id="description" data-type="string">{{ lang._('Description') }}</th>
                <th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
            <tr>
                <td></td>
                <td colspan="4">
                    <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                    <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                </td>
            </tr>
            </tfoot>
        </table>
    </div>
    <div id="peers" class="tab-pane fade in">
        <table id="grid-peers" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogPeer">
            <thead>
            <tr>
                <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('Enabled') }}</th>
                <th data-column-id="interface" data-type="string">{{ lang._('WireGuard instance') }}</th>
                <th data-column-id="peer" data-type="string">{{ lang._('WireGuard peer') }}</th>
                <th data-column-id="plugin" data-type="string">{{ lang._('Storage plugin') }}</th>
                <th data-column-id="protocol" data-type="string">{{ lang._('Protocol') }}</th>
                <th data-column-id="description" data-type="string">{{ lang._('Description') }}</th>
                <th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
            <tr>
                <td></td>
                <td colspan="6">
                    <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                    <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                </td>
            </tr>
            </tfoot>
        </table>
    </div>
</div>

{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/stunmesh/service/reconfigure', 'data_service_widget': 'stunmesh'}) }}

{# include dialogs #}
{{ partial("layout_partials/base_dialog",['fields':formDialogPlugin,'id':'DialogPlugin','label':lang._('Edit storage plugin')])}}
{{ partial("layout_partials/base_dialog",['fields':formDialogInterface,'id':'DialogInterface','label':lang._('Edit interface')])}}
{{ partial("layout_partials/base_dialog",['fields':formDialogPeer,'id':'DialogPeer','label':lang._('Edit peer')])}}
