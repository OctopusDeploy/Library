import path from 'node:path';
import * as fs from 'node:fs/promises';
import * as index from './index.js';
import * as detail from './detail.js';
import { toSlug }  from './formatting.js';

const templatePath = '../../step-templates';
const distributionPath = '../../integrations';

const files = await fs.readdir(templatePath);
const categories = {};

await cleanOutputFolder();

// Process individual templates

// TODO: Fetch from https://library.octopus.com/api/step-templates

const libraryData = await fetch('https://library.octopus.com/api/step-templates')
    .then(res => res.json());

for (let template of libraryData) {
    const category = getSafeCategory(template);

    await createCategory(category);

    categories[category].templates.push({
        id: template.Id,
        name: template.Name
    });

    await createMarkdown(category, template, template.HistoryUrl);
}


// for (let file of files) {
//     const json = await getTemplateData(file);

//     if (json == null) {
//         continue;
//     }

//     const category = getSafeCategory(json);

//     await createCategory(category);

//     categories[category].templates.push({
//         id: json.Id,
//         name: json.Name
//     });

//     await createMarkdown(category, json, file);
// }

// Process category index pages

for (let property in categories) {
    await createIndex(property, categories[property]);
}

console.log(categories);

async function cleanOutputFolder() {
    await fs.rm(distributionPath, { recursive: true, force: true });
}

async function getTemplateData(file) {
    const filePath = `${templatePath}/${file}`;
    const ext = path.extname(filePath);

    if (ext != '.json') {
        return null;
    }

    console.log(ext, filePath);

    const fileText = await fs.readFile(filePath, { encoding: 'utf8' });
    return JSON.parse(fileText);
}

function getSafeCategory(data) {
    const category = data.Category;
    
    if (category == null || category.length == 0) {
        console.warn(`There is no category for ${data.Name}. Using 'other'.`);
        return 'other';
    }

    while(category.charAt(0)== '-') {
        category = category.substring(1);
    }

    return category
        .toLowerCase()
        .replace(/\.net/g, 'dotnet')
        .trim();
}

async function createCategory(category) {
    const categoryExists = categories[category] != null;

    if (categoryExists) {
        categories[category].count++;
    } else {
        categories[category] = { count: 1, templates: []}
    }

    await fs.mkdir(`${distributionPath}/${toSlug(category)}`, { recursive: true });
}

async function createMarkdown(category, data, file) {
    const content = detail.getContent(category, data, file);

    await fs.writeFile(`${distributionPath}/${toSlug(category)}/${toSlug(data.Name)}.md`, content);
}

async function createIndex(name, data) {
    const content = index.getContent(name, data);

    await fs.writeFile(`${distributionPath}/${toSlug(name)}/index.md`, content);
}


