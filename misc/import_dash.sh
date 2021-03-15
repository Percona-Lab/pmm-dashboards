#!/bin/bash

dashboards=(13266 12630 12470)
pmm_server="172.17.0.2"
user_pass="admin:admin"
folderName="General"

if [[ $# -eq 0 ]]; then
    echo " * No arguments are supplied. Default values will be used."
    echo " * Usage: import-dashboard-grafana-cloud  [FolderName] [<dashboardId> <dashboardId> ... ]"
    echo " * Dashboard(s) (${dashboards[@]}) will be uploaded into ${folderName} folder"
else
    if [[ $1 =~ ^[0-9]+$ ]]; then
        dashboards=( $@ )
        echo " * First argument isn't a folder name. $# dashbaord(s) ($@) will be uploaded into General folder."
        echo " * Usage: import-dashboard-grafana-cloud  [FolderName] [<dashboardId> <dashboardId> ... ]"
    else
        folderName="$1"
        if [[ $# > 1 ]]; then
            dashboards=( ${@/$folderName} )
        fi
        echo " * Dashbaord(s) (${dashboards[@]}) will be uploaded into $1 folder."
    fi
fi

if ! [[ ${folderName} == "General" ]]; then 
    folderId=$(curl -s -k -u ${user_pass} https://${pmm_server}/graph/api/folders | python -m json.tool | grep -B1 ${folderName} | head -1 | cut -d":" -f2 | cut -d"," -f1 | sed 's/ //g')
    if ! [[ ${folderId} =~ ^[0-9]+$ ]]; then
        echo " * Folder ${folderName} is NOT existed."
        folderId=$(curl -s -k -X POST -H "Content-Type: application/json" -d $(echo "{\"title\":\"${folderName}\"}") -u ${user_pass} https://${pmm_server}/graph/api/folders | cut -d":" -f2 | cut -d"," -f1)
        echo " * Folder ${folderName} has been created with id ${folderId}"    
    else 
        echo " * Found folderId ${folderId} for folder ${folderName}"
    fi;
else
    folderId=0
fi

for dashboard in "${dashboards[@]}";
    do 
        echo -e "\n * Dashboard: ${dashboard}"
        if ! [[ ${dashboard} =~ ^[0-9]+$ ]]
        then
            echo $(./cleanup-dash.py ${dashboard})
            response=$(echo "{\"dashboard\":$(cat ${dashboard}),\"overwrite\":true,\"folderId\":${folderId})}" | curl -s -k -X POST -H "Content-Type: application/json" -d @- -u ${user_pass} https://${pmm_server}/graph/api/dashboards/import)
            echo "   * Result of uploading file ${dashboard}: ${response}"
        fi;

        revision=1;
        while true; do
            response=$(curl -s https://grafana.com/api/dashboards/${dashboard}/revisions/${revision}/download | wc -l);
            if [ $response != 3 ]; then
                echo "   * Revision ${revision} exists"
            else
                echo "   * Revision ${revision} doesn't exist"
                        ((revision=revision-1));
                break;
            fi;

            ((revision=revision+1));
        done;

        if [ $revision != 0 ]; then
                response=$(echo "{\"dashboard\":$(curl -s https://grafana.com/api/dashboards/${dashboard}/revisions/${revision}/download),\"overwrite\":true,\"folderId\":${folderId}}" | curl -s -k -X POST -H "Content-Type: application/json" -d @- -u ${user_pass} https://${pmm_server}/graph/api/dashboards/import) 
                echo "   * Result of uploading ${revision} revision: ${response}"
                if [[ ${response} =~ "{\"message\":\"Failed to save dashboard\"}" ]]
                then
                    echo "   * Going to download dashbaord and modify datasources"
                    echo $(curl https://grafana.com/api/dashboards/${dashboard}/revisions/${revision}/download --output ${dashboard}-rev${revision}.json) 
                    echo $(./cleanup-dash.py ${dashboard}-rev${revision}.json)
                    response=$(echo "{\"dashboard\":$(cat ${dashboard}-rev${revision}.json),\"overwrite\":true,\"folderId\":${folderId}}" | curl -s -k -X POST -H "Content-Type: application/json" -d @- -u ${user_pass} https://${pmm_server}/graph/api/dashboards/import)
                    echo "   * Result of uploading file ${dashboard}-rev${revision}.json: ${response}"
                fi;

        else
                echo "   * Dashboard ${dashboard} doesn't exist"
        fi;

   done;
