import { toSlug }  from './formatting.js';

export function getContent(name, data) {
const scriptBlock = '```';

return `---
layout: src/layouts/Default.astro
title: '${name}'
---

<ul>
${getSteps(name, data)}
</ul>
`;
}

function getSteps(name, data) {
    const sorted = data.templates.sort((a, b) => String(a.name).localeCompare(String(b.name)))
    const output = [];
    for(let step of sorted) {
        output.push(`
<li>

![${name}](https://i.octopus.com/library/step-templates/${name}.png) [${step.name}](${`/${toSlug(name)}/${toSlug(step.name)}/`})

</li>
        `);
    }

    return output.join('');
}
