import { toDisplayDate, toMetaDate }  from './formatting.js';

export function getContent(category, data, file) {
const scriptBlock = '```';

return `---
layout: src/layouts/Default.astro
pubDate: ${toMetaDate(data.LastModifiedOn)}
title: '${data.Name}'
description: '${data.Description}'
---

${data.ActionType} exported ${toDisplayDate(data.LastModifiedOn)} by ${data.LastModifiedBy} belongs to '${data.Category}' category.

## Parameters

When steps based on the template are included in a project's deployment process, the parameters below can be set.

${getParameters(data)}

## Script body

Steps based on this template will execute the following *${data.Properties['Octopus.Action.Script.Syntax']}* script.

${scriptBlock}${data.Properties['Octopus.Action.Script.Syntax']}
${data.Properties['Octopus.Action.Script.ScriptBody']}
${scriptBlock}

Provided under the [Apache License version 2.0](https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt).

[Report an issue](https://github.com/OctopusDeploy/Library/issues/new?assignees=&labels=&projects=&template=bug-report.yml&title=${encodeURIComponent('Issue with ' + data.Name)}&step-template=${encodeURIComponent(data.Name)})

<div class="get-json">

To use this template in Octopus Deploy, copy the JSON below and paste it into the **Library → Step templates → Import** dialog.

${scriptBlock}json
${JSON.stringify(data, null, 2)}
${scriptBlock}

[History](https://github.com/OctopusDeploy/Library/commits/master/step-templates/${file})

</div>
`;
}

function getParameters(data) {
    const output = [];

    for(let param of data.Parameters) {
        output.push(`
<div class="param">

### ${param.Label}

\`${param.Name}${getDefaultParameterValue(param)}\`

${param.HelpText}

</div>
        `);
    }

    return output.join('');
}

function getDefaultParameterValue(param) {
    return param.DefaultValue == null
        ? ''
        : ` = ${param.DefaultValue}`
}
