function loadFields(){

    for( i = 0; i < fields.length; i++ )
    {
        getFieldValue(fields[i][0],fields[i][1],fields[i][2])
    }
}

function getFieldValue(id, path, data)
{
    jQuery.ajax({
        type:"POST",
        url: path,
        data: data,
        success: function (results){
            if(results.match(/\[/)){
                var array = JSON.parse(results)
                insertResults(array, id)
            }
            else
            {
                document.getElementById(id).innerHTML = results;
            }
        },
        error:function (){

        }
    })
}

function insertResults(result, id)
{
    var element = document.getElementById(id);
    element.innerHTML = result.length;
    element.setAttribute("ids", result.toString());
}

function drillDown(ids) {
    window.location = "/report/drill_down?patient_ids="+ids ;
}