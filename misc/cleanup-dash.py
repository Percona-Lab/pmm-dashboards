#!/usr/bin/env python

import sys
import json

""" Prometheus has been replaced by VictoriaMetrics since PMM 2.13.0 """
datasources = [['${DS_METRICS}','Metrics'], 
               ['${DS_PTSUMMARY}','PTSummary'], 
               ['${DS_CLICKHOUSE}','ClickHouse'],
               ['${DS_PROMETHEUS_ALERTMANAGER}','Prometheus AlertManager']]


def drop_some_internal_elements(dashboard):
    knownDatsource = False
    for element in enumerate(dashboard.copy()):
        if '__inputs' in element:
            for inputs_index, inputs in enumerate(dashboard['__inputs']):
                for datasource in datasources:
                    if datasource[0] == dashboard['__inputs'][inputs_index]['name']:
                        knownDatsource = True
                        break;
                if not (knownDatsource):
                    datasources.append(['${' + dashboard['__inputs'][inputs_index]['name'] + '}','Metrics']) 
            del dashboard['__inputs']
        if '__requires' in element:
            del dashboard['__requires']
#    for datasource in datasources:
#        print '%s:%s' % (datasource[0], datasource[1])
    return dashboard


def fix_datasource(dashboard):
    for element in enumerate(dashboard.copy()):
        if 'panels' in element:
            for panel_index, panel in enumerate(dashboard['panels']):
                if 'datasource' in panel:
                    for datasource in datasources:
                        if panel['datasource'] == datasource[0]:
                            dashboard['panels'][panel_index]['datasource'] = datasource[1] 

                if 'panels' in panel:
                        if (len(dashboard['panels'][panel_index]['panels']) > 0):
                            for panelIn_index, panelIn in enumerate(dashboard['panels'][panel_index]['panels']):
                                if 'datasource' in panelIn:
                                    for datasource in datasources:
                                        if dashboard['panels'][panel_index]['panels'][panelIn_index]['datasource'] == datasource[0]:
                                            dashboard['panels'][panel_index]['panels'][panelIn_index]['datasource'] = datasource[1] 

                if 'mappingTypes' in panel:
                        for mappingTypes_index, mappingTypes in enumerate(dashboard['panels'][panel_index]['mappingTypes']):
                            if 'datasource' in mappingTypes:
                                    for datasource in datasources:
                                        if dashboard['panels'][panel_index]['mappingTypes'][mappingTypes_index]['datasource'] == datasource[0]:
                                            dashboard['panels'][panel_index]['mappingTypes'][mappingTypes_index]['datasource'] = datasource[1]

        if 'templating' in element:
            for panel_index, panel in enumerate(dashboard['templating']['list']):
                    if 'datasource' in panel.keys():
                        for datasource in datasources:
                            if panel['datasource'] == datasource[0]:
                                dashboard['templating']['list'][panel_index]['datasource'] = datasource[1]

    return dashboard


def main():
    """Execute cleanups."""
    with open(sys.argv[1], 'r') as dashboard_file:
        dashboard = json.loads(dashboard_file.read())

    # registered cleanupers.
    CLEANUPERS = [drop_some_internal_elements, fix_datasource]

    for func in CLEANUPERS:
        dashboard = func(dashboard)

    dashboard_json = json.dumps(dashboard, sort_keys=True, indent=4,
                                separators=(',', ': '))

    with open(sys.argv[1], 'w') as dashboard_file:
        dashboard_file.write(dashboard_json)
        dashboard_file.write('\n')

if __name__ == '__main__':
    main()